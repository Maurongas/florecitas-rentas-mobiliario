-- =====================================================================
--  05_pruebas.sql
--  Casos de prueba de la base de datos: casos VÁLIDOS y NO VÁLIDOS que
--  activan triggers, funciones, procedimientos y restricciones.
--
--  Cada caso se ejecuta con pr_probar (espera o no un error) o con
--  pr_verificar (evalúa una condición que debe ser verdadera). El
--  resultado OBSERVADO se guarda en la tabla temporal tmp_resultado y se
--  muestra al final, así la matriz de pruebas se llena con lo que el SGBD
--  realmente respondió.
--
--  Ejecutar después de 01-04. Modifica datos (crea reservaciones de
--  prueba); para volver al estado inicial, reinstalar con 01-04.
-- =====================================================================

USE rentas_mobiliario;

DROP TEMPORARY TABLE IF EXISTS tmp_resultado;
CREATE TEMPORARY TABLE tmp_resultado (
  n          INT AUTO_INCREMENT PRIMARY KEY,
  id_prueba  VARCHAR(10),
  regla      VARCHAR(20),
  descripcion VARCHAR(200),
  esperado   VARCHAR(20),
  observado  VARCHAR(400),
  estado     VARCHAR(6)
);

DROP PROCEDURE IF EXISTS pr_probar;
DROP PROCEDURE IF EXISTS pr_verificar;

DELIMITER $$
-- Ejecuta una sentencia y registra si produjo error o no
CREATE PROCEDURE pr_probar(IN p_id VARCHAR(10), IN p_regla VARCHAR(20), IN p_desc VARCHAR(200),
                           IN p_sql TEXT, IN p_espera_error TINYINT)
BEGIN
  DECLARE v_estado CHAR(5) DEFAULT NULL;
  DECLARE v_msg    TEXT    DEFAULT NULL;
  DECLARE v_errno  INT     DEFAULT NULL;

  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
      GET DIAGNOSTICS CONDITION 1 v_estado = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT, v_errno = MYSQL_ERRNO;
    SET @pr_sql = p_sql;
    PREPARE st FROM @pr_sql;
    EXECUTE st;
    DEALLOCATE PREPARE st;
  END;

  INSERT INTO tmp_resultado (id_prueba, regla, descripcion, esperado, observado, estado)
  VALUES (p_id, p_regla, p_desc,
          IF(p_espera_error = 1, 'Rechazo', 'Éxito'),
          IF(v_msg IS NULL, 'Ejecutado sin error', CONCAT('Error ', v_errno, ' (', v_estado, '): ', v_msg)),
          IF((v_msg IS NOT NULL) = (p_espera_error = 1), 'PASA', 'FALLA'));
END$$

-- Evalúa una expresión booleana (SELECT que regresa 1 si se cumple)
CREATE PROCEDURE pr_verificar(IN p_id VARCHAR(10), IN p_regla VARCHAR(20), IN p_desc VARCHAR(200),
                              IN p_expr TEXT)
BEGIN
  SET @pr_ok = NULL;
  SET @pr_sql = CONCAT('SELECT (', p_expr, ') INTO @pr_ok');
  PREPARE st FROM @pr_sql;
  EXECUTE st;
  DEALLOCATE PREPARE st;

  INSERT INTO tmp_resultado (id_prueba, regla, descripcion, esperado, observado, estado)
  VALUES (p_id, p_regla, p_desc, 'Verdadero',
          IF(@pr_ok = 1, 'La condición se cumple', CONCAT('La condición NO se cumple (', COALESCE(@pr_ok, 'NULL'), ')')),
          IF(@pr_ok = 1, 'PASA', 'FALLA'));
END$$
DELIMITER ;

SET @app_empleado = 2;
SET @viernes = CURDATE() + INTERVAL (((4 - WEEKDAY(CURDATE()) + 7) % 7) + 7) DAY;

-- ---------------------------------------------------------------------
-- RN-01 / RN-02 / RN-03: disponibilidad y sobreventa (ejemplo del análisis)
-- ---------------------------------------------------------------------
CALL pr_verificar('P01', 'RN-01/RN-02', 'El viernes del ejemplo quedan 10 sillas Tiffany (100 - 60 - 30) y el lunes siguiente 100',
  'fn_disponible(2, @viernes, @viernes, NULL) = 10 AND fn_disponible(2, @viernes + INTERVAL 3 DAY, @viernes + INTERVAL 3 DAY, NULL) = 100');

CALL pr_probar('P02', 'RN-03', 'Pedir 20 sillas Tiffany para el viernes (solo hay 10) se rechaza',
  'CALL sp_crear_reservacion(21, @viernes, @viernes, ''Casa de prueba, Ensenada'', ''[{"id_articulo":2,"cantidad":20}]'', @id_p02)', 1);

CALL pr_probar('P03', 'RN-03', 'Pedir exactamente las 10 sillas Tiffany disponibles el viernes se acepta',
  'CALL sp_crear_reservacion(21, @viernes, @viernes, ''Casa de prueba, Ensenada'', ''[{"id_articulo":2,"cantidad":10},{"id_articulo":5,"cantidad":1}]'', @id_p03)', 0);

CALL pr_verificar('P04', 'RN-03', 'Después de P03 la disponibilidad del viernes es 0',
  'fn_disponible(2, @viernes, @viernes, NULL) = 0');

CALL pr_probar('P05', 'RN-03 (atomicidad)', 'Reservación con un renglón válido y otro que excede: se rechaza y no queda nada guardado (ROLLBACK)',
  'CALL sp_crear_reservacion(22, @viernes + INTERVAL 7 DAY, @viernes + INTERVAL 7 DAY, ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":5},{"id_articulo":13,"cantidad":3}]'', @id_p05)', 1);

CALL pr_verificar('P06', 'RN-03 (atomicidad)', 'El cliente 22 sigue sin reservaciones después del rechazo de P05',
  'NOT EXISTS (SELECT 1 FROM reservacion WHERE id_cliente = 22)');

-- ---------------------------------------------------------------------
-- RN-04 / RN-05 / RN-14: validaciones de la reservación
-- ---------------------------------------------------------------------
CALL pr_probar('P07', 'RN-04', 'Reservación sin artículos se rechaza',
  'CALL sp_crear_reservacion(21, CURDATE() + INTERVAL 50 DAY, CURDATE() + INTERVAL 50 DAY, ''Salón de prueba'', ''[]'', @id_p07)', 1);

CALL pr_probar('P08', 'RN-04', 'Cantidad cero se rechaza',
  'CALL sp_crear_reservacion(21, CURDATE() + INTERVAL 50 DAY, CURDATE() + INTERVAL 50 DAY, ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":0}]'', @id_p08)', 1);

CALL pr_probar('P09', 'RN-05', 'Fecha de inicio en el pasado se rechaza',
  'CALL sp_crear_reservacion(21, CURDATE() - INTERVAL 1 DAY, CURDATE(), ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":5}]'', @id_p09)', 1);

CALL pr_probar('P10', 'RN-05', 'Fecha de fin anterior a la de inicio se rechaza',
  'CALL sp_crear_reservacion(21, CURDATE() + INTERVAL 10 DAY, CURDATE() + INTERVAL 8 DAY, ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":5}]'', @id_p10)', 1);

CALL pr_probar('P11', 'RN-14', 'Renta de 40 días se rechaza',
  'CALL sp_crear_reservacion(21, CURDATE() + INTERVAL 10 DAY, CURDATE() + INTERVAL 49 DAY, ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":5}]'', @id_p11)', 1);

CALL pr_probar('P12', 'RN-11', 'No se puede rentar un artículo dado de baja (Calentador de exterior)',
  'CALL sp_crear_reservacion(21, CURDATE() + INTERVAL 50 DAY, CURDATE() + INTERVAL 50 DAY, ''Salón de prueba'', ''[{"id_articulo":17,"cantidad":1}]'', @id_p12)', 1);

-- ---------------------------------------------------------------------
-- RN-06 / RN-07: total calculado y precio congelado
-- ---------------------------------------------------------------------
CALL pr_probar('P13', 'RN-07', 'Insertar un renglón con precio_unitario falso (1.00)',
  'INSERT INTO detalle_reservacion (id_reservacion, id_articulo, cantidad, precio_unitario) VALUES (@id_p03, 15, 2, 1.00)', 0);

CALL pr_verificar('P14', 'RN-07', 'El trigger reemplazó el precio falso por el vigente del artículo (50.00)',
  '(SELECT precio_unitario FROM detalle_reservacion WHERE id_reservacion = @id_p03 AND id_articulo = 15) = 50.00');

CALL pr_verificar('P15', 'RN-06/RN-07', 'La reservación 1 conserva su total original (1960.00) aunque el precio de la silla subió de 12 a 14',
  'fn_total_reservacion(1) = 1960.00 AND (SELECT precio_dia FROM articulo WHERE id_articulo = 1) = 14.00');

-- ---------------------------------------------------------------------
-- RN-08 / RN-09: ciclo de vida (entrega, devolución, cancelación)
-- ---------------------------------------------------------------------
CALL pr_probar('P16', 'RN-09', 'Registrar devolución de una reservación que aún no se entrega se rechaza',
  'CALL sp_registrar_devolucion(@id_p03, 2, ''prueba'', ''[{"id_articulo":2,"cantidad_devuelta":10,"cantidad_danada":0},{"id_articulo":5,"cantidad_devuelta":1,"cantidad_danada":0},{"id_articulo":15,"cantidad_devuelta":2,"cantidad_danada":0}]'', @dev_p16)', 1);

CALL pr_probar('P17', 'RN-09', 'Registrar la entrega de una reservación Confirmada',
  'CALL sp_registrar_entrega(@id_p03, 2, ''Entrega de prueba'', @ent_p17)', 0);

CALL pr_verificar('P18', 'RN-09 (trigger)', 'El trigger trg_entrega_ai cambió el estado a Entregada',
  '(SELECT estado FROM reservacion WHERE id_reservacion = @id_p03) = ''Entregada''');

CALL pr_probar('P19', 'RN-09', 'Una segunda entrega de la misma reservación se rechaza',
  'CALL sp_registrar_entrega(@id_p03, 3, ''Duplicada'', @ent_p19)', 1);

CALL pr_probar('P20', 'RN-10', 'Devolución con devueltas + dañadas mayor que lo rentado se rechaza',
  'CALL sp_registrar_devolucion(@id_p03, 2, ''prueba'', ''[{"id_articulo":2,"cantidad_devuelta":10,"cantidad_danada":1},{"id_articulo":5,"cantidad_devuelta":1,"cantidad_danada":0},{"id_articulo":15,"cantidad_devuelta":2,"cantidad_danada":0}]'', @dev_p20)', 1);

CALL pr_verificar('P21', 'RN-10 (atomicidad)', 'Tras el rechazo de P20 no quedó ninguna devolución parcial y sigue Entregada',
  'NOT EXISTS (SELECT 1 FROM devolucion WHERE id_reservacion = @id_p03) AND (SELECT estado FROM reservacion WHERE id_reservacion = @id_p03) = ''Entregada''');

CALL pr_probar('P22', 'RN-10', 'Devolución válida con 1 silla dañada y 1 faltante',
  'CALL sp_registrar_devolucion(@id_p03, 3, ''Una silla rota y una faltante'', ''[{"id_articulo":2,"cantidad_devuelta":8,"cantidad_danada":1},{"id_articulo":5,"cantidad_devuelta":1,"cantidad_danada":0},{"id_articulo":15,"cantidad_devuelta":2,"cantidad_danada":0}]'', @dev_p22)', 0);

CALL pr_verificar('P23', 'RN-09/RN-10', 'Estado Finalizada y la vista vw_faltantes_danos reporta 1 dañada y 1 faltante',
  '(SELECT estado FROM reservacion WHERE id_reservacion = @id_p03) = ''Finalizada'' AND (SELECT CONCAT(danadas, ''/'', faltantes) FROM vw_faltantes_danos WHERE id_reservacion = @id_p03 AND id_articulo = 2) = ''1/1''');

CALL pr_probar('P24', 'RN-08', 'Cancelar una reservación Finalizada se rechaza',
  'CALL sp_cancelar_reservacion(@id_p03)', 1);

CALL pr_probar('P25', 'RN-08', 'Forzar con UPDATE el regreso de Finalizada a Confirmada se rechaza (trigger)',
  'UPDATE reservacion SET estado = ''Confirmada'' WHERE id_reservacion = @id_p03', 1);

-- Cancelar una reservación confirmada libera piezas
SET @disp_antes = fn_disponible(2, @viernes, @viernes, NULL);
SET @res_ejemplo_b = (SELECT MIN(r.id_reservacion) FROM reservacion r JOIN detalle_reservacion d ON d.id_reservacion = r.id_reservacion
                       WHERE r.fecha_inicio = @viernes AND d.id_articulo = 2 AND d.cantidad = 30 AND r.estado = 'Confirmada');
CALL pr_probar('P26', 'RN-08', 'Cancelar la reservación de 30 sillas Tiffany del viernes',
  'CALL sp_cancelar_reservacion(@res_ejemplo_b)', 0);
CALL pr_verificar('P27', 'RN-08', 'Al cancelar se liberan las 30 piezas en la disponibilidad del viernes',
  'fn_disponible(2, @viernes, @viernes, NULL) = @disp_antes + 30');

CALL pr_probar('P28', 'RN-11', 'Eliminar una reservación que no está cancelada se rechaza',
  'DELETE FROM reservacion WHERE id_reservacion = 1', 1);

-- ---------------------------------------------------------------------
-- Integridad referencial y de dominio
-- ---------------------------------------------------------------------
CALL pr_probar('P29', 'RN-11 (FK)', 'Eliminar un cliente con reservaciones se rechaza (ON DELETE RESTRICT)',
  'DELETE FROM cliente WHERE id_cliente = 1', 1);

CALL pr_probar('P30', 'RN-11 (FK)', 'Eliminar un artículo con historial se rechaza (ON DELETE RESTRICT)',
  'DELETE FROM articulo WHERE id_articulo = 1', 1);

CALL pr_probar('P31', 'RN-12 (UNIQUE)', 'Registrar un cliente con correo repetido se rechaza',
  'INSERT INTO cliente (nombre, apellidos, telefono, correo) VALUES (''Otra'', ''Persona'', ''6460000000'', ''mafer.lopez@example.com'')', 1);

CALL pr_probar('P32', 'Dominio (CHECK)', 'Teléfono con letras se rechaza',
  'INSERT INTO cliente (nombre, apellidos, telefono, correo) VALUES (''Otra'', ''Persona'', ''64612AB345'', ''otra.persona@example.com'')', 1);

CALL pr_probar('P33', 'Dominio (CHECK)', 'Precio negativo en artículo se rechaza',
  'UPDATE articulo SET precio_dia = -5 WHERE id_articulo = 3', 1);

CALL pr_probar('P34', 'Dominio (CHECK)', 'Rol de empleado fuera del catálogo se rechaza',
  'UPDATE empleado SET rol = ''Gerente'' WHERE id_empleado = 2', 1);

CALL pr_probar('P35', 'Referencial (FK)', 'Reservación para un cliente inexistente se rechaza',
  'CALL sp_crear_reservacion(999, CURDATE() + INTERVAL 50 DAY, CURDATE() + INTERVAL 50 DAY, ''Salón de prueba'', ''[{"id_articulo":1,"cantidad":5}]'', @id_p35)', 1);

-- ---------------------------------------------------------------------
-- RN-13 y reglas de inventario
-- ---------------------------------------------------------------------
CALL pr_probar('P36', 'RN-13', 'Dar de baja al único Administrador activo se rechaza',
  'UPDATE empleado SET activo = 0 WHERE id_empleado = 1', 1);

CALL pr_probar('P37', 'RN-03', 'Reducir el inventario de sillas plegables por debajo de lo ya comprometido se rechaza',
  'UPDATE articulo SET cantidad_total = 50 WHERE id_articulo = 1', 1);

CALL pr_probar('P38', 'RN-03', 'Cambiar las fechas de una reservación a días sin piezas suficientes se rechaza',
  CONCAT('UPDATE reservacion SET fecha_inicio = @viernes, fecha_fin = @viernes WHERE id_reservacion = ',
         (SELECT MIN(r.id_reservacion) FROM reservacion r JOIN detalle_reservacion d ON d.id_reservacion = r.id_reservacion
           WHERE r.estado = 'Confirmada' AND d.id_articulo = 2 AND d.cantidad = 100)), 1);

-- ---------------------------------------------------------------------
-- Auditoría
-- ---------------------------------------------------------------------
CALL pr_verificar('P39', 'Auditoría', 'La bitácora registró los cambios de estado de la reservación de prueba (Confirmada->Entregada->Finalizada)',
  '(SELECT COUNT(*) FROM bitacora WHERE tabla = ''reservacion'' AND id_registro = @id_p03 AND accion = ''ESTADO'') = 2');

CALL pr_probar('P40', 'Auditoría', 'Cambio de precio del mantel redondo (35 -> 38)',
  'UPDATE articulo SET precio_dia = 38.00 WHERE id_articulo = 8', 0);

CALL pr_verificar('P41', 'Auditoría', 'historial_precio guardó el precio anterior y el nuevo con el empleado de la sesión',
  'EXISTS (SELECT 1 FROM historial_precio WHERE id_articulo = 8 AND precio_anterior = 35.00 AND precio_nuevo = 38.00 AND id_empleado = 2)');

-- ---------------------------------------------------------------------
-- Resultado de la ejecución
-- ---------------------------------------------------------------------
SELECT id_prueba, regla, descripcion, esperado, observado, estado
  FROM tmp_resultado ORDER BY n;

SELECT estado, COUNT(*) AS casos FROM tmp_resultado GROUP BY estado;

DROP PROCEDURE pr_probar;
DROP PROCEDURE pr_verificar;
SET @app_empleado = NULL;
