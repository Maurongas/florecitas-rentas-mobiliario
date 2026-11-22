-- =====================================================================
--  02_rutinas.sql
--  Programación en la base de datos (Actividad 10):
--    * Funciones almacenadas
--    * Procedimientos almacenados (con parámetros, transacciones y
--      manejo de errores)
--    * Triggers que hacen cumplir reglas de negocio y registran auditoría
--
--  Convenciones
--    - Los errores de regla de negocio usan SQLSTATE '45000' y el
--      mensaje empieza con el identificador de la regla (RN-xx).
--      La aplicación muestra ese mensaje tal cual al usuario.
--    - @app_empleado : variable de sesión que la aplicación fija al abrir
--      cada conexión con el id del empleado autenticado. Los triggers la
--      usan para la bitácora (quién hizo el cambio).
--    - @carga_historica : solo la usa 03_datos.sql para poder registrar
--      reservaciones con fechas pasadas (migración de la libreta en papel).
--      La aplicación NUNCA la fija.
--
--  Para evitar que la aplicación y los triggers ejecuten dos veces la
--  misma operación, la responsabilidad está dividida así:
--    * Los TRIGGERS cambian el estado de la reservación (Entregada /
--      Finalizada), copian el precio vigente y validan la disponibilidad.
--    * Los PROCEDIMIENTOS solo insertan los registros de negocio dentro de
--      una transacción; nunca actualizan el estado por su cuenta.
--    * La APLICACIÓN solo invoca procedimientos o hace DML simple; nunca
--      escribe el estado, el precio_unitario ni la bitácora.
-- =====================================================================

USE rentas_mobiliario;

DROP FUNCTION  IF EXISTS fn_dias_renta;
DROP FUNCTION  IF EXISTS fn_disponible;
DROP FUNCTION  IF EXISTS fn_total_reservacion;
DROP PROCEDURE IF EXISTS sp_crear_reservacion;
DROP PROCEDURE IF EXISTS sp_registrar_entrega;
DROP PROCEDURE IF EXISTS sp_registrar_devolucion;
DROP PROCEDURE IF EXISTS sp_cancelar_reservacion;
DROP PROCEDURE IF EXISTS sp_disponibilidad_rango;

DELIMITER $$

-- =====================================================================
-- FUNCIONES
-- =====================================================================

-- ---------------------------------------------------------------------
-- fn_dias_renta: días de renta = fecha_fin - fecha_inicio + 1 (derivado)
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_dias_renta(p_inicio DATE, p_fin DATE)
RETURNS INT
DETERMINISTIC
NO SQL
COMMENT 'Días de renta incluyendo inicio y fin'
BEGIN
  IF p_inicio IS NULL OR p_fin IS NULL OR p_fin < p_inicio THEN
    RETURN NULL;
  END IF;
  RETURN DATEDIFF(p_fin, p_inicio) + 1;
END$$

-- ---------------------------------------------------------------------
-- fn_disponible  (RN-01, RN-02)
-- Piezas disponibles de un artículo para TODO un rango de fechas.
-- Revisa día por día: disponible(d) = cantidad_total - piezas apartadas
-- ese día en reservaciones Confirmadas o Entregadas, y regresa el
-- mínimo del rango. p_excluir permite no contar una reservación
-- (la que se está modificando).
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_disponible(p_articulo INT UNSIGNED,
                              p_inicio   DATE,
                              p_fin      DATE,
                              p_excluir  INT UNSIGNED)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
COMMENT 'Disponibilidad mínima de un artículo en un rango (RN-01/RN-02)'
BEGIN
  DECLARE v_total     INT;
  DECLARE v_dia       DATE;
  DECLARE v_apartadas INT;
  DECLARE v_minimo    INT;

  IF p_inicio IS NULL OR p_fin IS NULL OR p_fin < p_inicio THEN
    RETURN NULL;
  END IF;

  SELECT cantidad_total INTO v_total
    FROM articulo
   WHERE id_articulo = p_articulo;

  IF v_total IS NULL THEN
    RETURN NULL;                       -- el artículo no existe
  END IF;

  SET v_minimo = v_total;
  SET v_dia    = p_inicio;

  WHILE v_dia <= p_fin DO
    SELECT COALESCE(SUM(d.cantidad), 0) INTO v_apartadas
      FROM detalle_reservacion d
      JOIN reservacion r ON r.id_reservacion = d.id_reservacion
     WHERE d.id_articulo = p_articulo
       AND r.estado IN ('Confirmada', 'Entregada')
       AND v_dia BETWEEN r.fecha_inicio AND r.fecha_fin
       AND r.id_reservacion <> COALESCE(p_excluir, 0);

    IF v_total - v_apartadas < v_minimo THEN
      SET v_minimo = v_total - v_apartadas;
    END IF;

    SET v_dia = v_dia + INTERVAL 1 DAY;
  END WHILE;

  RETURN v_minimo;
END$$

-- ---------------------------------------------------------------------
-- fn_total_reservacion (RN-06): suma de cantidad x precio x días
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_total_reservacion(p_id_reservacion INT UNSIGNED)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
COMMENT 'Total calculado de una reservación (RN-06)'
BEGIN
  DECLARE v_total DECIMAL(12,2);

  SELECT COALESCE(SUM(d.cantidad * d.precio_unitario), 0)
         * fn_dias_renta(r.fecha_inicio, r.fecha_fin)
    INTO v_total
    FROM reservacion r
    LEFT JOIN detalle_reservacion d ON d.id_reservacion = r.id_reservacion
   WHERE r.id_reservacion = p_id_reservacion
   GROUP BY r.id_reservacion, r.fecha_inicio, r.fecha_fin;

  RETURN v_total;   -- NULL si la reservación no existe
END$$

-- =====================================================================
-- PROCEDIMIENTOS ALMACENADOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_crear_reservacion
-- Operación de negocio multitabla: inserta RESERVACION y todos sus
-- DETALLE_RESERVACION en una sola transacción. Si algún renglón viola
-- una regla (p. ej. RN-03 sobreventa), se hace ROLLBACK de todo.
--
-- p_detalles: arreglo JSON  [{"id_articulo": 1, "cantidad": 50}, ...]
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_crear_reservacion(
  IN  p_id_cliente   INT UNSIGNED,
  IN  p_fecha_inicio DATE,
  IN  p_fecha_fin    DATE,
  IN  p_lugar        VARCHAR(150),
  IN  p_detalles     JSON,
  OUT p_id_reservacion INT UNSIGNED)
MODIFIES SQL DATA
COMMENT 'Crea una reservación con sus artículos (transaccional)'
BEGIN
  DECLARE v_renglones INT DEFAULT 0;
  DECLARE v_distintos INT DEFAULT 0;
  DECLARE v_validos   INT DEFAULT 0;
  DECLARE v_bloqueados INT DEFAULT 0;

  -- Cualquier error (de este procedimiento o de un trigger) deshace todo
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_id_reservacion = NULL;
    RESIGNAL;
  END;

  SET p_id_reservacion = NULL;

  -- Validaciones de parámetros --------------------------------------
  IF p_id_cliente IS NULL OR NOT EXISTS (SELECT 1 FROM cliente WHERE id_cliente = p_id_cliente) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente indicado no existe.';
  END IF;

  IF p_detalles IS NULL OR JSON_VALID(p_detalles) = 0
     OR JSON_TYPE(p_detalles) <> 'ARRAY' OR JSON_LENGTH(p_detalles) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: La reservación debe incluir al menos un artículo.';
  END IF;

  SELECT COUNT(*), COUNT(DISTINCT j.id_articulo),
         SUM(j.id_articulo IS NOT NULL AND j.cantidad IS NOT NULL AND j.cantidad > 0)
    INTO v_renglones, v_distintos, v_validos
    FROM JSON_TABLE(p_detalles, '$[*]' COLUMNS (
           id_articulo INT PATH '$.id_articulo' NULL ON ERROR,
           cantidad    INT PATH '$.cantidad'    NULL ON ERROR)) AS j;

  IF v_validos <> v_renglones THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: Cada artículo debe tener una cantidad mayor que cero.';
  END IF;

  IF v_distintos <> v_renglones THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un mismo artículo aparece más de una vez en la reservación.';
  END IF;

  START TRANSACTION;

    -- Bloquea las filas de los artículos involucrados para que dos
    -- reservaciones simultáneas no puedan apartar las mismas piezas.
    SELECT COUNT(*) INTO v_bloqueados
      FROM articulo a
      JOIN JSON_TABLE(p_detalles, '$[*]' COLUMNS (id_articulo INT PATH '$.id_articulo')) AS j
        ON j.id_articulo = a.id_articulo
       FOR UPDATE OF a;   -- solo se bloquea articulo (JSON_TABLE no es bloqueable)

    IF v_bloqueados <> v_renglones THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uno o más artículos no existen.';
    END IF;

    -- RN-05, RN-14 y estado inicial se validan en trg_reservacion_bi
    INSERT INTO reservacion (id_cliente, fecha_inicio, fecha_fin, lugar_evento)
    VALUES (p_id_cliente, p_fecha_inicio, p_fecha_fin, TRIM(p_lugar));

    SET p_id_reservacion = LAST_INSERT_ID();

    -- precio_unitario lo copia trg_detres_bi (RN-07) y la disponibilidad
    -- la valida el mismo trigger (RN-03). Aquí solo se manda NULL.
    INSERT INTO detalle_reservacion (id_reservacion, id_articulo, cantidad, precio_unitario)
    SELECT p_id_reservacion, j.id_articulo, j.cantidad, NULL
      FROM JSON_TABLE(p_detalles, '$[*]' COLUMNS (
             id_articulo INT PATH '$.id_articulo',
             cantidad    INT PATH '$.cantidad')) AS j;

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- sp_registrar_entrega (RN-09)
-- Solo inserta la ENTREGA. El cambio de estado a 'Entregada' lo hace el
-- trigger trg_entrega_ai (no se duplica la operación).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_entrega(
  IN  p_id_reservacion INT UNSIGNED,
  IN  p_id_empleado    INT UNSIGNED,
  IN  p_observaciones  VARCHAR(200),
  OUT p_id_entrega     INT UNSIGNED)
MODIFIES SQL DATA
COMMENT 'Registra la entrega de una reservación confirmada'
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_id_entrega = NULL;
    RESIGNAL;
  END;

  IF NOT EXISTS (SELECT 1 FROM reservacion WHERE id_reservacion = p_id_reservacion) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La reservación indicada no existe.';
  END IF;

  START TRANSACTION;
    -- Bloquea la reservación mientras se registra la entrega
    SELECT id_reservacion INTO p_id_entrega
      FROM reservacion WHERE id_reservacion = p_id_reservacion FOR UPDATE;

    INSERT INTO entrega (id_reservacion, id_empleado, observaciones)
    VALUES (p_id_reservacion, p_id_empleado, NULLIF(TRIM(p_observaciones), ''));

    SET p_id_entrega = LAST_INSERT_ID();
  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- sp_registrar_devolucion (RN-09, RN-10)
-- Inserta DEVOLUCION y un DETALLE_DEVOLUCION por cada artículo rentado.
-- p_detalles: [{"id_articulo":1,"cantidad_devuelta":48,"cantidad_danada":1}, ...]
-- Debe traer TODOS los artículos de la reservación.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_devolucion(
  IN  p_id_reservacion INT UNSIGNED,
  IN  p_id_empleado    INT UNSIGNED,
  IN  p_observaciones  VARCHAR(200),
  IN  p_detalles       JSON,
  OUT p_id_devolucion  INT UNSIGNED)
MODIFIES SQL DATA
COMMENT 'Registra la devolución de una reservación entregada (transaccional)'
BEGIN
  DECLARE v_rentados   INT DEFAULT 0;
  DECLARE v_recibidos  INT DEFAULT 0;
  DECLARE v_renglones  INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_id_devolucion = NULL;
    RESIGNAL;
  END;

  IF NOT EXISTS (SELECT 1 FROM reservacion WHERE id_reservacion = p_id_reservacion) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La reservación indicada no existe.';
  END IF;

  IF p_detalles IS NULL OR JSON_VALID(p_detalles) = 0 OR JSON_LENGTH(p_detalles) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La devolución debe revisar al menos un artículo.';
  END IF;

  SELECT COUNT(*) INTO v_rentados
    FROM detalle_reservacion WHERE id_reservacion = p_id_reservacion;

  SELECT COUNT(*), COUNT(DISTINCT d.id_articulo)
    INTO v_renglones, v_recibidos
    FROM JSON_TABLE(p_detalles, '$[*]' COLUMNS (id_articulo INT PATH '$.id_articulo')) AS j
    JOIN detalle_reservacion d
      ON d.id_reservacion = p_id_reservacion AND d.id_articulo = j.id_articulo;

  IF v_recibidos <> v_rentados OR v_renglones <> JSON_LENGTH(p_detalles) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La devolución debe incluir exactamente los artículos rentados en la reservación.';
  END IF;

  START TRANSACTION;
    SELECT id_reservacion INTO p_id_devolucion
      FROM reservacion WHERE id_reservacion = p_id_reservacion FOR UPDATE;

    -- RN-09 (estado Entregada) lo valida trg_devolucion_bi
    INSERT INTO devolucion (id_reservacion, id_empleado, observaciones)
    VALUES (p_id_reservacion, p_id_empleado, NULLIF(TRIM(p_observaciones), ''));

    SET p_id_devolucion = LAST_INSERT_ID();

    -- RN-10 lo valida trg_detdev_bi
    INSERT INTO detalle_devolucion (id_devolucion, id_articulo, cantidad_devuelta, cantidad_danada)
    SELECT p_id_devolucion, j.id_articulo, COALESCE(j.devuelta, 0), COALESCE(j.danada, 0)
      FROM JSON_TABLE(p_detalles, '$[*]' COLUMNS (
             id_articulo INT PATH '$.id_articulo',
             devuelta    INT PATH '$.cantidad_devuelta',
             danada      INT PATH '$.cantidad_danada')) AS j;

    -- El estado pasa a 'Finalizada' en trg_devolucion_ai
  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- sp_cancelar_reservacion (RN-08)
-- Solo se cancela una reservación Confirmada. La transición la valida
-- trg_reservacion_bu y la bitácora la escribe trg_reservacion_au.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cancelar_reservacion(IN p_id_reservacion INT UNSIGNED)
MODIFIES SQL DATA
COMMENT 'Cancela una reservación confirmada y libera sus piezas'
BEGIN
  DECLARE v_estado VARCHAR(15);

  SELECT estado INTO v_estado FROM reservacion WHERE id_reservacion = p_id_reservacion;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La reservación indicada no existe.';
  ELSEIF v_estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN-08: Solo se puede cancelar una reservación en estado Confirmada.';
  END IF;

  UPDATE reservacion SET estado = 'Cancelada' WHERE id_reservacion = p_id_reservacion;
END$$

-- ---------------------------------------------------------------------
-- sp_disponibilidad_rango
-- Consulta: artículos activos con su disponibilidad mínima en el rango.
-- p_id_categoria NULL = todas las categorías.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_disponibilidad_rango(
  IN p_fecha_inicio DATE,
  IN p_fecha_fin    DATE,
  IN p_id_categoria INT UNSIGNED)
READS SQL DATA
COMMENT 'Disponibilidad de todos los artículos en un rango'
BEGIN
  IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL OR p_fecha_fin < p_fecha_inicio THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-05: La fecha de fin no puede ser anterior a la fecha de inicio.';
  END IF;
  IF DATEDIFF(p_fecha_fin, p_fecha_inicio) > 30 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-14: El rango consultado no puede ser mayor a 31 días.';
  END IF;

  SELECT a.id_articulo,
         a.nombre,
         c.nombre                AS categoria,
         a.cantidad_total,
         a.precio_dia,
         fn_disponible(a.id_articulo, p_fecha_inicio, p_fecha_fin, NULL) AS disponible
    FROM articulo a
    JOIN categoria c ON c.id_categoria = a.id_categoria
   WHERE a.activo = 1
     AND (p_id_categoria IS NULL OR a.id_categoria = p_id_categoria)
   ORDER BY c.nombre, a.nombre;
END$$

-- =====================================================================
-- TRIGGERS
-- =====================================================================

-- ------------------------- RESERVACION -------------------------------

-- T1. BEFORE INSERT: RN-05 (no fechas pasadas), estado inicial Confirmada
CREATE TRIGGER trg_reservacion_bi
BEFORE INSERT ON reservacion
FOR EACH ROW
BEGIN
  IF NEW.fecha_fin < NEW.fecha_inicio THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-05: La fecha de fin no puede ser anterior a la fecha de inicio.';
  END IF;

  IF NEW.fecha_inicio < CURDATE() AND COALESCE(@carga_historica, 0) <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-05: No se aceptan reservaciones con fecha de inicio pasada.';
  END IF;

  IF DATEDIFF(NEW.fecha_fin, NEW.fecha_inicio) > 30 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-14: Una renta no puede durar más de 31 días.';
  END IF;

  -- Toda reservación nace Confirmada; los demás estados solo se alcanzan
  -- con entrega, devolución o cancelación (RN-08 / RN-09)
  SET NEW.estado = 'Confirmada';
  SET NEW.fecha_registro = COALESCE(NEW.fecha_registro, NOW());
END$$

-- T2. AFTER INSERT: auditoría
CREATE TRIGGER trg_reservacion_ai
AFTER INSERT ON reservacion
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
  VALUES ('reservacion', NEW.id_reservacion, 'INSERT',
          CONCAT('Cliente ', NEW.id_cliente, ', del ', NEW.fecha_inicio, ' al ', NEW.fecha_fin),
          @app_empleado, USER());
END$$

-- T3. BEFORE UPDATE: máquina de estados (RN-08, RN-09) y revalidación de
--     disponibilidad si cambian las fechas (RN-03)
CREATE TRIGGER trg_reservacion_bu
BEFORE UPDATE ON reservacion
FOR EACH ROW
BEGIN
  IF NEW.id_reservacion <> OLD.id_reservacion THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite cambiar el identificador de una reservación.';
  END IF;

  IF NEW.estado <> OLD.estado THEN
    IF NOT ( (OLD.estado = 'Confirmada' AND NEW.estado IN ('Entregada', 'Cancelada'))
          OR (OLD.estado = 'Entregada'  AND NEW.estado = 'Finalizada') ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-08: Cambio de estado no permitido para la reservación.';
    END IF;

    IF NEW.estado = 'Entregada'
       AND NOT EXISTS (SELECT 1 FROM entrega WHERE id_reservacion = NEW.id_reservacion) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-09: Para marcar Entregada se debe registrar la entrega.';
    END IF;

    IF NEW.estado = 'Finalizada'
       AND NOT EXISTS (SELECT 1 FROM devolucion WHERE id_reservacion = NEW.id_reservacion) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-09: Para marcar Finalizada se debe registrar la devolución.';
    END IF;
  END IF;

  IF NEW.id_cliente <> OLD.id_cliente AND OLD.estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede cambiar el cliente de una reservación Confirmada.';
  END IF;

  IF NEW.fecha_inicio <> OLD.fecha_inicio OR NEW.fecha_fin <> OLD.fecha_fin THEN
    IF OLD.estado <> 'Confirmada' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden cambiar las fechas de una reservación Confirmada.';
    END IF;
    IF NEW.fecha_fin < NEW.fecha_inicio THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-05: La fecha de fin no puede ser anterior a la fecha de inicio.';
    END IF;
    IF NEW.fecha_inicio < CURDATE() THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-05: No se aceptan reservaciones con fecha de inicio pasada.';
    END IF;
    IF DATEDIFF(NEW.fecha_fin, NEW.fecha_inicio) > 30 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-14: Una renta no puede durar más de 31 días.';
    END IF;
    IF EXISTS (SELECT 1
                 FROM detalle_reservacion d
                WHERE d.id_reservacion = NEW.id_reservacion
                  AND fn_disponible(d.id_articulo, NEW.fecha_inicio, NEW.fecha_fin, NEW.id_reservacion) < d.cantidad) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-03: Con las nuevas fechas no hay piezas suficientes de uno o más artículos.';
    END IF;
  END IF;
END$$

-- T4. AFTER UPDATE: auditoría de cambios de estado y de datos
CREATE TRIGGER trg_reservacion_au
AFTER UPDATE ON reservacion
FOR EACH ROW
BEGIN
  IF NEW.estado <> OLD.estado THEN
    INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
    VALUES ('reservacion', NEW.id_reservacion, 'ESTADO',
            CONCAT(OLD.estado, ' -> ', NEW.estado), @app_empleado, USER());
  END IF;
  IF NEW.fecha_inicio <> OLD.fecha_inicio OR NEW.fecha_fin <> OLD.fecha_fin
     OR NEW.lugar_evento <> OLD.lugar_evento OR NEW.id_cliente <> OLD.id_cliente THEN
    INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
    VALUES ('reservacion', NEW.id_reservacion, 'UPDATE',
            LEFT(CONCAT('Fechas ', OLD.fecha_inicio, '/', OLD.fecha_fin, ' -> ', NEW.fecha_inicio, '/', NEW.fecha_fin,
                        '; lugar: ', NEW.lugar_evento), 255),
            @app_empleado, USER());
  END IF;
END$$

-- T5. BEFORE DELETE: solo se eliminan reservaciones Canceladas
CREATE TRIGGER trg_reservacion_bd
BEFORE DELETE ON reservacion
FOR EACH ROW
BEGIN
  IF OLD.estado <> 'Cancelada' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RN-11: Solo se pueden eliminar reservaciones Canceladas; las demás forman parte del historial.';
  END IF;
  INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
  VALUES ('reservacion', OLD.id_reservacion, 'DELETE',
          CONCAT('Reservación cancelada eliminada (cliente ', OLD.id_cliente, ')'), @app_empleado, USER());
END$$

-- --------------------- DETALLE_RESERVACION ---------------------------

-- T6. BEFORE INSERT: RN-03 (sobreventa), RN-07 (copia de precio),
--     artículo activo y reservación modificable
CREATE TRIGGER trg_detres_bi
BEFORE INSERT ON detalle_reservacion
FOR EACH ROW
BEGIN
  DECLARE v_estado  VARCHAR(15);
  DECLARE v_inicio  DATE;
  DECLARE v_fin     DATE;
  DECLARE v_activo  TINYINT;
  DECLARE v_precio  DECIMAL(10,2);
  DECLARE v_nombre  VARCHAR(80);
  DECLARE v_disp    INT;
  DECLARE v_msg     VARCHAR(255);

  SELECT estado, fecha_inicio, fecha_fin INTO v_estado, v_inicio, v_fin
    FROM reservacion WHERE id_reservacion = NEW.id_reservacion;

  SELECT activo, precio_dia, nombre INTO v_activo, v_precio, v_nombre
    FROM articulo WHERE id_articulo = NEW.id_articulo;

  IF v_nombre IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El artículo indicado no existe.';
  END IF;

  IF v_estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden agregar artículos a una reservación Confirmada.';
  END IF;

  IF v_activo = 0 THEN
    SET v_msg = CONCAT('RN-11: El artículo "', v_nombre, '" está dado de baja y no se puede rentar.');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.cantidad IS NULL OR NEW.cantidad <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: La cantidad de cada artículo debe ser mayor que cero.';
  END IF;

  -- RN-07: el precio que se cobra es siempre el vigente; no se acepta otro
  SET NEW.precio_unitario = v_precio;

  -- RN-03: no se puede comprometer más de lo disponible en ningún día
  SET v_disp = fn_disponible(NEW.id_articulo, v_inicio, v_fin, NEW.id_reservacion);
  IF NEW.cantidad > v_disp THEN
    SET v_msg = CONCAT('RN-03: Solo hay ', GREATEST(v_disp, 0), ' pieza(s) disponible(s) de "', v_nombre,
                       '" del ', v_inicio, ' al ', v_fin, '; se pidieron ', NEW.cantidad, '.');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- T7. BEFORE UPDATE: precio inmutable (RN-07) y revalidación de RN-03
CREATE TRIGGER trg_detres_bu
BEFORE UPDATE ON detalle_reservacion
FOR EACH ROW
BEGIN
  DECLARE v_estado VARCHAR(15);
  DECLARE v_inicio DATE;
  DECLARE v_fin    DATE;
  DECLARE v_disp   INT;
  DECLARE v_msg    VARCHAR(255);

  IF NEW.id_reservacion <> OLD.id_reservacion OR NEW.id_articulo <> OLD.id_articulo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite cambiar la reservación o el artículo de un renglón; elimínelo y agréguelo de nuevo.';
  END IF;

  SELECT estado, fecha_inicio, fecha_fin INTO v_estado, v_inicio, v_fin
    FROM reservacion WHERE id_reservacion = NEW.id_reservacion;

  IF v_estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden modificar artículos de una reservación Confirmada.';
  END IF;

  SET NEW.precio_unitario = OLD.precio_unitario;   -- RN-07

  IF NEW.cantidad > OLD.cantidad THEN
    SET v_disp = fn_disponible(NEW.id_articulo, v_inicio, v_fin, NEW.id_reservacion);
    IF NEW.cantidad > v_disp THEN
      SET v_msg = CONCAT('RN-03: Solo hay ', GREATEST(v_disp, 0), ' pieza(s) disponible(s) para esas fechas; se pidieron ', NEW.cantidad, '.');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

-- T8. BEFORE DELETE: RN-04 (no dejar la reservación sin artículos)
CREATE TRIGGER trg_detres_bd
BEFORE DELETE ON detalle_reservacion
FOR EACH ROW
BEGIN
  DECLARE v_estado VARCHAR(15);
  DECLARE v_renglones INT;

  SELECT estado INTO v_estado FROM reservacion WHERE id_reservacion = OLD.id_reservacion;
  SELECT COUNT(*) INTO v_renglones FROM detalle_reservacion WHERE id_reservacion = OLD.id_reservacion;

  IF v_estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se pueden quitar artículos de una reservación Confirmada.';
  END IF;
  IF v_renglones <= 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-04: La reservación debe conservar al menos un artículo (cancélela si ya no se necesita).';
  END IF;
END$$

-- --------------------------- ENTREGA ---------------------------------

-- T9. BEFORE INSERT: RN-09 (solo Confirmada) y empleado activo
CREATE TRIGGER trg_entrega_bi
BEFORE INSERT ON entrega
FOR EACH ROW
BEGIN
  DECLARE v_estado VARCHAR(15);
  DECLARE v_activo TINYINT;

  SELECT estado INTO v_estado FROM reservacion WHERE id_reservacion = NEW.id_reservacion;
  SELECT activo INTO v_activo FROM empleado    WHERE id_empleado    = NEW.id_empleado;

  IF v_activo IS NULL OR v_activo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El empleado que registra la entrega no existe o está inactivo.';
  END IF;
  IF v_estado IS NULL OR v_estado <> 'Confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-09: Solo se puede entregar una reservación en estado Confirmada.';
  END IF;
END$$

-- T10. AFTER INSERT: la reservación pasa a Entregada
CREATE TRIGGER trg_entrega_ai
AFTER INSERT ON entrega
FOR EACH ROW
BEGIN
  UPDATE reservacion SET estado = 'Entregada' WHERE id_reservacion = NEW.id_reservacion;
END$$

-- -------------------------- DEVOLUCION -------------------------------

-- T11. BEFORE INSERT: RN-09 (solo si ya fue entregada)
CREATE TRIGGER trg_devolucion_bi
BEFORE INSERT ON devolucion
FOR EACH ROW
BEGIN
  DECLARE v_estado VARCHAR(15);
  DECLARE v_activo TINYINT;
  DECLARE v_entrega DATETIME;

  SELECT estado INTO v_estado FROM reservacion WHERE id_reservacion = NEW.id_reservacion;
  SELECT activo INTO v_activo FROM empleado    WHERE id_empleado    = NEW.id_empleado;
  SELECT fecha_hora INTO v_entrega FROM entrega WHERE id_reservacion = NEW.id_reservacion;

  IF v_activo IS NULL OR v_activo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El empleado que recibe la devolución no existe o está inactivo.';
  END IF;
  IF v_estado IS NULL OR v_estado <> 'Entregada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-09: Solo se puede registrar la devolución de una reservación Entregada.';
  END IF;
  IF NEW.fecha_hora < v_entrega THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha de devolución no puede ser anterior a la de entrega.';
  END IF;
END$$

-- T12. AFTER INSERT: la reservación pasa a Finalizada
CREATE TRIGGER trg_devolucion_ai
AFTER INSERT ON devolucion
FOR EACH ROW
BEGIN
  UPDATE reservacion SET estado = 'Finalizada' WHERE id_reservacion = NEW.id_reservacion;
END$$

-- ---------------------- DETALLE_DEVOLUCION ---------------------------

-- T13. BEFORE INSERT: RN-10 (devuelta + dañada <= rentada) y pertenencia
CREATE TRIGGER trg_detdev_bi
BEFORE INSERT ON detalle_devolucion
FOR EACH ROW
BEGIN
  DECLARE v_rentada INT;
  DECLARE v_msg VARCHAR(255);

  SELECT d.cantidad INTO v_rentada
    FROM devolucion dv
    JOIN detalle_reservacion d
      ON d.id_reservacion = dv.id_reservacion AND d.id_articulo = NEW.id_articulo
   WHERE dv.id_devolucion = NEW.id_devolucion;

  IF v_rentada IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El artículo no forma parte de la reservación que se está devolviendo.';
  END IF;
  IF NEW.cantidad_devuelta < 0 OR NEW.cantidad_danada < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las cantidades devueltas o dañadas no pueden ser negativas.';
  END IF;
  IF NEW.cantidad_devuelta + NEW.cantidad_danada > v_rentada THEN
    SET v_msg = CONCAT('RN-10: Devueltas (', NEW.cantidad_devuelta, ') + dañadas (', NEW.cantidad_danada,
                       ') no puede superar lo rentado (', v_rentada, ').');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- T14. BEFORE UPDATE: misma regla RN-10 al corregir una devolución
CREATE TRIGGER trg_detdev_bu
BEFORE UPDATE ON detalle_devolucion
FOR EACH ROW
BEGIN
  DECLARE v_rentada INT;
  DECLARE v_msg VARCHAR(255);

  IF NEW.id_devolucion <> OLD.id_devolucion OR NEW.id_articulo <> OLD.id_articulo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite cambiar la devolución o el artículo de un renglón.';
  END IF;

  SELECT d.cantidad INTO v_rentada
    FROM devolucion dv
    JOIN detalle_reservacion d
      ON d.id_reservacion = dv.id_reservacion AND d.id_articulo = NEW.id_articulo
   WHERE dv.id_devolucion = NEW.id_devolucion;

  IF NEW.cantidad_devuelta + NEW.cantidad_danada > v_rentada THEN
    SET v_msg = CONCAT('RN-10: Devueltas (', NEW.cantidad_devuelta, ') + dañadas (', NEW.cantidad_danada,
                       ') no puede superar lo rentado (', v_rentada, ').');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- --------------------------- ARTICULO --------------------------------

-- T15. BEFORE UPDATE: no reducir el inventario por debajo de lo ya comprometido
CREATE TRIGGER trg_articulo_bu
BEFORE UPDATE ON articulo
FOR EACH ROW
BEGIN
  DECLARE v_max_fin DATE;
  DECLARE v_min_disp INT;
  DECLARE v_comprometidas INT;
  DECLARE v_msg VARCHAR(255);

  IF NEW.cantidad_total < OLD.cantidad_total THEN
    SELECT MAX(r.fecha_fin) INTO v_max_fin
      FROM detalle_reservacion d
      JOIN reservacion r ON r.id_reservacion = d.id_reservacion
     WHERE d.id_articulo = OLD.id_articulo
       AND r.estado IN ('Confirmada', 'Entregada')
       AND r.fecha_fin >= CURDATE();

    IF v_max_fin IS NOT NULL THEN
      -- fn_disponible usa la cantidad anterior (aún no se guarda NEW)
      SET v_min_disp = fn_disponible(OLD.id_articulo, CURDATE(), v_max_fin, NULL);
      SET v_comprometidas = OLD.cantidad_total - v_min_disp;
      IF NEW.cantidad_total < v_comprometidas THEN
        SET v_msg = CONCAT('RN-03: Hay ', v_comprometidas, ' pieza(s) comprometidas en reservaciones vigentes; la cantidad total no puede ser menor.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;
  END IF;
END$$

-- T16. AFTER UPDATE: historial de precios y auditoría de bajas lógicas
CREATE TRIGGER trg_articulo_au
AFTER UPDATE ON articulo
FOR EACH ROW
BEGIN
  IF NEW.precio_dia <> OLD.precio_dia THEN
    INSERT INTO historial_precio (id_articulo, precio_anterior, precio_nuevo, id_empleado)
    VALUES (NEW.id_articulo, OLD.precio_dia, NEW.precio_dia, @app_empleado);
  END IF;
  IF NEW.activo <> OLD.activo THEN
    INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
    VALUES ('articulo', NEW.id_articulo, 'UPDATE',
            IF(NEW.activo = 1, 'Artículo reactivado', 'Artículo dado de baja (baja lógica)'),
            @app_empleado, USER());
  END IF;
END$$

-- --------------------------- EMPLEADO --------------------------------

-- T17. BEFORE UPDATE: siempre debe existir al menos un Administrador activo
CREATE TRIGGER trg_empleado_bu
BEFORE UPDATE ON empleado
FOR EACH ROW
BEGIN
  IF OLD.rol = 'Administrador' AND OLD.activo = 1
     AND (NEW.rol <> 'Administrador' OR NEW.activo = 0)
     AND (SELECT COUNT(*) FROM empleado
           WHERE rol = 'Administrador' AND activo = 1 AND id_empleado <> OLD.id_empleado) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-13: Debe existir al menos un Administrador activo.';
  END IF;
END$$

-- T18. BEFORE DELETE: mismo criterio
CREATE TRIGGER trg_empleado_bd
BEFORE DELETE ON empleado
FOR EACH ROW
BEGIN
  IF OLD.rol = 'Administrador' AND OLD.activo = 1
     AND (SELECT COUNT(*) FROM empleado
           WHERE rol = 'Administrador' AND activo = 1 AND id_empleado <> OLD.id_empleado) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-13: Debe existir al menos un Administrador activo.';
  END IF;
END$$

-- --------------------------- CLIENTE ---------------------------------

-- T19. AFTER DELETE: auditoría de clientes eliminados
CREATE TRIGGER trg_cliente_ad
AFTER DELETE ON cliente
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (tabla, id_registro, accion, detalle, id_empleado, usuario_bd)
  VALUES ('cliente', OLD.id_cliente, 'DELETE',
          LEFT(CONCAT('Cliente eliminado: ', OLD.nombre, ' ', OLD.apellidos, ' <', OLD.correo, '>'), 255),
          @app_empleado, USER());
END$$

DELIMITER ;
