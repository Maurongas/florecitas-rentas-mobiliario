-- =====================================================================
--  04_consultas_vistas.sql
--  * 4 vistas con propósito funcional (las usa la aplicación)
--  * 12 consultas SQL documentadas:
--      Q01-Q03  JOIN de varias tablas
--      Q04-Q06  Subconsultas (EXISTS / NOT EXISTS / escalar)
--      Q07-Q09  Funciones agregadas con GROUP BY / HAVING
--      Q10-Q12  Libre elección: CTE recursivo, funciones de ventana,
--               operación de conjuntos (EXCEPT)
--  * Transacción con COMMIT y caso controlado con ROLLBACK
--
--  Ejecutar después de 01, 02 y 03.
-- =====================================================================

USE rentas_mobiliario;

-- =====================================================================
-- VISTAS
-- =====================================================================

-- V1. Resumen de cada reservación con cliente, días, piezas y total (RN-06).
--     La usa la aplicación para el listado y el reporte de reservaciones.
CREATE OR REPLACE VIEW vw_reservacion_resumen AS
SELECT r.id_reservacion,
       r.id_cliente,
       CONCAT(c.nombre, ' ', c.apellidos)                 AS cliente,
       c.telefono,
       c.correo,
       r.fecha_registro,
       r.fecha_inicio,
       r.fecha_fin,
       fn_dias_renta(r.fecha_inicio, r.fecha_fin)          AS dias,
       r.lugar_evento,
       r.estado,
       COUNT(d.id_articulo)                                AS articulos,
       COALESCE(SUM(d.cantidad), 0)                        AS piezas,
       COALESCE(SUM(d.cantidad * d.precio_unitario), 0)
         * fn_dias_renta(r.fecha_inicio, r.fecha_fin)      AS total,
       e.fecha_hora                                        AS fecha_entrega,
       dv.fecha_hora                                       AS fecha_devolucion
  FROM reservacion r
  JOIN cliente c                ON c.id_cliente      = r.id_cliente
  LEFT JOIN detalle_reservacion d ON d.id_reservacion = r.id_reservacion
  LEFT JOIN entrega e           ON e.id_reservacion  = r.id_reservacion
  LEFT JOIN devolucion dv       ON dv.id_reservacion = r.id_reservacion
 GROUP BY r.id_reservacion, r.id_cliente, c.nombre, c.apellidos, c.telefono, c.correo,
          r.fecha_registro, r.fecha_inicio, r.fecha_fin, r.lugar_evento, r.estado,
          e.fecha_hora, dv.fecha_hora;

-- V2. Desempeño de cada artículo: cuántas veces y cuántas piezas se han
--     rentado y cuánto ha generado (solo rentas efectivas: Entregada/Finalizada).
CREATE OR REPLACE VIEW vw_articulo_desempeno AS
SELECT a.id_articulo,
       a.nombre                         AS articulo,
       c.nombre                         AS categoria,
       a.cantidad_total,
       a.precio_dia,
       a.activo,
       COUNT(r.id_reservacion)          AS veces_rentado,
       COALESCE(SUM(d.cantidad), 0)     AS piezas_rentadas,
       COALESCE(SUM(d.cantidad * d.precio_unitario
                    * fn_dias_renta(r.fecha_inicio, r.fecha_fin)), 0) AS ingreso_generado
  FROM articulo a
  JOIN categoria c ON c.id_categoria = a.id_categoria
  LEFT JOIN detalle_reservacion d ON d.id_articulo = a.id_articulo
  LEFT JOIN reservacion r
         ON r.id_reservacion = d.id_reservacion
        AND r.estado IN ('Entregada', 'Finalizada')
 GROUP BY a.id_articulo, a.nombre, c.nombre, a.cantidad_total, a.precio_dia, a.activo;

-- V3. Faltantes y daños por devolución (RN-10): la diferencia entre lo
--     rentado y lo que regresó (bueno + dañado) es faltante.
CREATE OR REPLACE VIEW vw_faltantes_danos AS
SELECT dv.id_devolucion,
       dv.id_reservacion,
       dv.fecha_hora                         AS fecha_devolucion,
       CONCAT(c.nombre, ' ', c.apellidos)    AS cliente,
       a.id_articulo,
       a.nombre                              AS articulo,
       dr.cantidad                           AS rentadas,
       dd.cantidad_devuelta                  AS devueltas,
       dd.cantidad_danada                    AS danadas,
       dr.cantidad - dd.cantidad_devuelta - dd.cantidad_danada AS faltantes,
       em.nombre                             AS recibio
  FROM devolucion dv
  JOIN reservacion r           ON r.id_reservacion  = dv.id_reservacion
  JOIN cliente c               ON c.id_cliente      = r.id_cliente
  JOIN detalle_devolucion dd   ON dd.id_devolucion  = dv.id_devolucion
  JOIN detalle_reservacion dr  ON dr.id_reservacion = dv.id_reservacion
                              AND dr.id_articulo    = dd.id_articulo
  JOIN articulo a              ON a.id_articulo     = dd.id_articulo
  JOIN empleado em             ON em.id_empleado    = dv.id_empleado
 WHERE dd.cantidad_danada > 0
    OR dr.cantidad - dd.cantidad_devuelta - dd.cantidad_danada > 0;

-- V4. Agenda operativa: entregas por hacer (Confirmadas) y devoluciones
--     por recibir (Entregadas), con días de anticipación o de retraso.
CREATE OR REPLACE VIEW vw_agenda_operativa AS
SELECT r.id_reservacion,
       'Entrega'                               AS pendiente,
       r.fecha_inicio                          AS fecha_compromiso,
       DATEDIFF(r.fecha_inicio, CURDATE())     AS dias_restantes,
       CONCAT(c.nombre, ' ', c.apellidos)      AS cliente,
       c.telefono,
       r.lugar_evento
  FROM reservacion r
  JOIN cliente c ON c.id_cliente = r.id_cliente
 WHERE r.estado = 'Confirmada'
UNION ALL
SELECT r.id_reservacion,
       'Devolución',
       r.fecha_fin + INTERVAL 1 DAY,
       DATEDIFF(r.fecha_fin + INTERVAL 1 DAY, CURDATE()),
       CONCAT(c.nombre, ' ', c.apellidos),
       c.telefono,
       r.lugar_evento
  FROM reservacion r
  JOIN cliente c ON c.id_cliente = r.id_cliente
 WHERE r.estado = 'Entregada';

-- Demostración de consulta de las vistas
SELECT id_reservacion, cliente, fecha_inicio, fecha_fin, dias, estado, piezas, total
  FROM vw_reservacion_resumen
 WHERE estado IN ('Confirmada', 'Entregada')
 ORDER BY fecha_inicio;

SELECT * FROM vw_agenda_operativa ORDER BY fecha_compromiso;

-- =====================================================================
-- CONSULTAS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q01 (JOIN, 5 tablas). Detalle de cada artículo de las reservaciones
-- vigentes con su subtotal = cantidad x precio_unitario x días (RN-06).
-- ---------------------------------------------------------------------
SELECT r.id_reservacion,
       CONCAT(c.nombre, ' ', c.apellidos)  AS cliente,
       cat.nombre                          AS categoria,
       a.nombre                            AS articulo,
       d.cantidad,
       d.precio_unitario,
       fn_dias_renta(r.fecha_inicio, r.fecha_fin) AS dias,
       d.cantidad * d.precio_unitario * fn_dias_renta(r.fecha_inicio, r.fecha_fin) AS subtotal
  FROM reservacion r
  JOIN cliente c               ON c.id_cliente     = r.id_cliente
  JOIN detalle_reservacion d   ON d.id_reservacion = r.id_reservacion
  JOIN articulo a              ON a.id_articulo    = d.id_articulo
  JOIN categoria cat           ON cat.id_categoria = a.id_categoria
 WHERE r.estado IN ('Confirmada', 'Entregada')
 ORDER BY r.fecha_inicio, r.id_reservacion, cat.nombre, a.nombre;

-- ---------------------------------------------------------------------
-- Q02 (JOIN + LEFT JOIN). Trazabilidad: quién entregó y quién recibió
-- cada reservación, incluso las que aún no regresan.
-- ---------------------------------------------------------------------
SELECT r.id_reservacion,
       r.estado,
       e.fecha_hora   AS entregada_el,
       ee.nombre      AS entrego,
       dv.fecha_hora  AS devuelta_el,
       ed.nombre      AS recibio
  FROM reservacion r
  JOIN entrega e        ON e.id_reservacion   = r.id_reservacion
  JOIN empleado ee      ON ee.id_empleado     = e.id_empleado
  LEFT JOIN devolucion dv ON dv.id_reservacion = r.id_reservacion
  LEFT JOIN empleado ed ON ed.id_empleado     = dv.id_empleado
 ORDER BY e.fecha_hora DESC;

-- ---------------------------------------------------------------------
-- Q03 (JOIN + filtro por periodo + ordenamiento). Piezas comprometidas
-- por categoría para los próximos 30 días.
-- ---------------------------------------------------------------------
SELECT cat.nombre       AS categoria,
       a.nombre         AS articulo,
       r.id_reservacion,
       r.fecha_inicio,
       r.fecha_fin,
       d.cantidad
  FROM categoria cat
  JOIN articulo a             ON a.id_categoria   = cat.id_categoria
  JOIN detalle_reservacion d  ON d.id_articulo    = a.id_articulo
  JOIN reservacion r          ON r.id_reservacion = d.id_reservacion
 WHERE r.estado IN ('Confirmada', 'Entregada')
   AND r.fecha_inicio <= CURDATE() + INTERVAL 30 DAY
   AND r.fecha_fin    >= CURDATE()
 ORDER BY cat.nombre, a.nombre, r.fecha_inicio;

-- ---------------------------------------------------------------------
-- Q04 (Subconsulta NOT EXISTS). Clientes registrados que nunca han hecho
-- una reservación (candidatos para promoción).
-- ---------------------------------------------------------------------
SELECT c.id_cliente, c.nombre, c.apellidos, c.correo
  FROM cliente c
 WHERE NOT EXISTS (SELECT 1
                     FROM reservacion r
                    WHERE r.id_cliente = c.id_cliente);

-- ---------------------------------------------------------------------
-- Q05 (Subconsulta EXISTS correlacionada). Clientes que alguna vez
-- devolvieron material dañado o incompleto.
-- ---------------------------------------------------------------------
SELECT c.id_cliente, CONCAT(c.nombre, ' ', c.apellidos) AS cliente, c.telefono
  FROM cliente c
 WHERE EXISTS (SELECT 1
                 FROM reservacion r
                 JOIN devolucion dv          ON dv.id_reservacion = r.id_reservacion
                 JOIN detalle_devolucion dd  ON dd.id_devolucion  = dv.id_devolucion
                 JOIN detalle_reservacion dr ON dr.id_reservacion = r.id_reservacion
                                            AND dr.id_articulo    = dd.id_articulo
                WHERE r.id_cliente = c.id_cliente
                  AND (dd.cantidad_danada > 0
                       OR dd.cantidad_devuelta + dd.cantidad_danada < dr.cantidad))
 ORDER BY cliente;

-- ---------------------------------------------------------------------
-- Q06 (Subconsulta escalar en WHERE). Reservaciones finalizadas cuyo
-- total es mayor que el promedio de las reservaciones finalizadas.
-- ---------------------------------------------------------------------
SELECT id_reservacion, cliente, fecha_inicio, total
  FROM vw_reservacion_resumen
 WHERE estado = 'Finalizada'
   AND total > (SELECT AVG(total) FROM vw_reservacion_resumen WHERE estado = 'Finalizada')
 ORDER BY total DESC;

-- ---------------------------------------------------------------------
-- Q07 (Agregada + GROUP BY). Ingresos y número de rentas por mes
-- (rentas efectivas: Entregadas y Finalizadas).
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(fecha_inicio, '%Y-%m') AS mes,
       COUNT(*)                           AS rentas,
       SUM(piezas)                        AS piezas,
       SUM(total)                         AS ingresos,
       ROUND(AVG(total), 2)               AS ticket_promedio
  FROM vw_reservacion_resumen
 WHERE estado IN ('Entregada', 'Finalizada')
 GROUP BY DATE_FORMAT(fecha_inicio, '%Y-%m')
 ORDER BY mes;

-- ---------------------------------------------------------------------
-- Q08 (Agregada + GROUP BY + HAVING). Clientes frecuentes: con 2 o más
-- reservaciones no canceladas, con su gasto acumulado.
-- ---------------------------------------------------------------------
SELECT c.id_cliente,
       CONCAT(c.nombre, ' ', c.apellidos) AS cliente,
       COUNT(*)                           AS reservaciones,
       SUM(v.total)                       AS gasto_total,
       MAX(v.fecha_inicio)                AS ultima_renta
  FROM cliente c
  JOIN vw_reservacion_resumen v ON v.id_cliente = c.id_cliente
 WHERE v.estado <> 'Cancelada'
 GROUP BY c.id_cliente, c.nombre, c.apellidos
HAVING COUNT(*) >= 2
 ORDER BY reservaciones DESC, gasto_total DESC;

-- ---------------------------------------------------------------------
-- Q09 (Agregada + GROUP BY + HAVING). Artículos con daños o faltantes
-- acumulados, ordenados por piezas perdidas.
-- ---------------------------------------------------------------------
SELECT a.nombre                                                   AS articulo,
       SUM(dr.cantidad)                                           AS rentadas,
       SUM(dd.cantidad_danada)                                    AS danadas,
       SUM(dr.cantidad - dd.cantidad_devuelta - dd.cantidad_danada) AS faltantes,
       ROUND(100 * SUM(dr.cantidad - dd.cantidad_devuelta) / SUM(dr.cantidad), 2) AS pct_perdida
  FROM detalle_devolucion dd
  JOIN devolucion dv          ON dv.id_devolucion  = dd.id_devolucion
  JOIN detalle_reservacion dr ON dr.id_reservacion = dv.id_reservacion
                             AND dr.id_articulo    = dd.id_articulo
  JOIN articulo a             ON a.id_articulo     = dd.id_articulo
 GROUP BY a.id_articulo, a.nombre
HAVING SUM(dd.cantidad_danada) > 0
    OR SUM(dr.cantidad - dd.cantidad_devuelta - dd.cantidad_danada) > 0
 ORDER BY danadas + faltantes DESC;

-- ---------------------------------------------------------------------
-- Q10 (Libre: CTE recursivo). Calendario de ocupación día por día de la
-- "Silla Tiffany dorada" para las próximas 3 semanas (RN-01 / RN-02).
-- ---------------------------------------------------------------------
WITH RECURSIVE calendario (dia) AS (
  SELECT CURDATE()
  UNION ALL
  SELECT dia + INTERVAL 1 DAY FROM calendario WHERE dia < CURDATE() + INTERVAL 20 DAY
)
SELECT cal.dia,
       DAYNAME(cal.dia)                          AS dia_semana,
       a.cantidad_total,
       COALESCE(SUM(d.cantidad), 0)              AS apartadas,
       a.cantidad_total - COALESCE(SUM(d.cantidad), 0) AS disponibles
  FROM calendario cal
  CROSS JOIN articulo a
  LEFT JOIN reservacion r
         ON cal.dia BETWEEN r.fecha_inicio AND r.fecha_fin
        AND r.estado IN ('Confirmada', 'Entregada')
  LEFT JOIN detalle_reservacion d
         ON d.id_reservacion = r.id_reservacion
        AND d.id_articulo    = a.id_articulo
 WHERE a.nombre = 'Silla Tiffany dorada'
 GROUP BY cal.dia, a.cantidad_total
 ORDER BY cal.dia;

-- ---------------------------------------------------------------------
-- Q11 (Libre: función de ventana). Ranking de artículos más rentados
-- dentro de cada categoría y su participación en el ingreso de la categoría.
-- ---------------------------------------------------------------------
SELECT categoria,
       articulo,
       piezas_rentadas,
       ingreso_generado,
       RANK() OVER (PARTITION BY categoria ORDER BY piezas_rentadas DESC) AS lugar_en_categoria,
       ROUND(100 * ingreso_generado
             / NULLIF(SUM(ingreso_generado) OVER (PARTITION BY categoria), 0), 1) AS pct_ingreso_categoria
  FROM vw_articulo_desempeno
 ORDER BY categoria, lugar_en_categoria;

-- ---------------------------------------------------------------------
-- Q12 (Libre: operación de conjuntos EXCEPT). Artículos que ya se han
-- rentado alguna vez pero NO tienen ninguna reservación futura.
-- ---------------------------------------------------------------------
SELECT a.id_articulo, a.nombre
  FROM articulo a
  JOIN detalle_reservacion d ON d.id_articulo = a.id_articulo
  JOIN reservacion r ON r.id_reservacion = d.id_reservacion
 WHERE r.estado IN ('Entregada', 'Finalizada')
EXCEPT
SELECT a.id_articulo, a.nombre
  FROM articulo a
  JOIN detalle_reservacion d ON d.id_articulo = a.id_articulo
  JOIN reservacion r ON r.id_reservacion = d.id_reservacion
 WHERE r.estado = 'Confirmada'
ORDER BY id_articulo;

-- =====================================================================
-- TRANSACCIONES
-- =====================================================================

-- ---------------------------------------------------------------------
-- TX-1: COMMIT. Alta de un cliente nuevo y su reservación como una sola
-- unidad de trabajo (se usa INSERT directo para mostrar el control
-- explícito de la transacción; los triggers siguen validando RN-03/RN-07).
-- ---------------------------------------------------------------------
START TRANSACTION;

  INSERT INTO cliente (nombre, apellidos, telefono, correo, direccion)
  VALUES ('Regina', 'Salazar Ponce', '6461234530', 'regina.salazar@example.com', 'Col. Bustamante 55, Ensenada')
  ON DUPLICATE KEY UPDATE telefono = VALUES(telefono);

  SET @id_cliente_tx = (SELECT id_cliente FROM cliente WHERE correo = 'regina.salazar@example.com');

  INSERT INTO reservacion (id_cliente, fecha_inicio, fecha_fin, lugar_evento)
  VALUES (@id_cliente_tx, CURDATE() + INTERVAL 45 DAY, CURDATE() + INTERVAL 45 DAY, 'Salón Bustamante, Ensenada');
  SET @id_res_tx = LAST_INSERT_ID();

  INSERT INTO detalle_reservacion (id_reservacion, id_articulo, cantidad, precio_unitario)
  VALUES (@id_res_tx, 1, 40, 1.00),   -- el trigger reemplaza 1.00 por el precio vigente (RN-07)
         (@id_res_tx, 5, 5, 1.00);

COMMIT;

SELECT id_reservacion, cliente, fecha_inicio, piezas, total
  FROM vw_reservacion_resumen WHERE id_reservacion = @id_res_tx;
SELECT id_articulo, cantidad, precio_unitario FROM detalle_reservacion WHERE id_reservacion = @id_res_tx;

-- ---------------------------------------------------------------------
-- TX-2: ROLLBACK controlado. Se simula un ajuste masivo de precios y se
-- revierte; al final los precios quedan como estaban y el historial de
-- precios tampoco registra nada (el INSERT del trigger también se revierte).
-- ---------------------------------------------------------------------
SELECT id_articulo, nombre, precio_dia FROM articulo WHERE id_categoria = 1;
SELECT COUNT(*) AS cambios_de_precio_antes FROM historial_precio;

START TRANSACTION;
  UPDATE articulo SET precio_dia = ROUND(precio_dia * 1.50, 2) WHERE id_categoria = 1;
  SELECT id_articulo, nombre, precio_dia AS precio_dentro_de_tx FROM articulo WHERE id_categoria = 1;
ROLLBACK;

SELECT id_articulo, nombre, precio_dia AS precio_despues_rollback FROM articulo WHERE id_categoria = 1;
SELECT COUNT(*) AS cambios_de_precio_despues FROM historial_precio;
