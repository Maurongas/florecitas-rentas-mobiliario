-- =====================================================================
--  03_datos.sql
--  Datos de prueba FICTICIOS y reproducibles.
--
--  * Las fechas son relativas a CURDATE(), para que el script siempre
--    deje: historial pasado (finalizadas), rentas en curso (entregadas)
--    y reservaciones futuras (confirmadas), sin importar el día en que
--    se ejecute.
--  * Las reservaciones se cargan con los MISMOS procedimientos y triggers
--    que usa la aplicación, así que los datos de prueba también pasan
--    por todas las reglas de negocio (RN-03, RN-07, RN-09, RN-10...).
--  * @carga_historica = 1 permite registrar reservaciones pasadas
--    (migración de la libreta). Se apaga al final del script.
--
--  Usuarios de prueba (contraseñas solo para el entorno de pruebas):
--    admin          / Admin2026!       (Administrador)
--    carlos.ibarra  / Encargado2026!   (Encargado)
--    diana.soto     / Encargado2026!   (Encargado)
--    jorge.pena     / Encargado2026!   (Encargado, INACTIVO)
-- =====================================================================

USE rentas_mobiliario;

SET @carga_historica = 1;
SET @app_empleado = NULL;

-- ------------------------------ CATEGORIAS ---------------------------
INSERT INTO categoria (id_categoria, nombre, descripcion) VALUES
 (1, 'Sillas',   'Sillas plegables, Tiffany e infantiles'),
 (2, 'Mesas',    'Mesas redondas, rectangulares, infantiles y de cóctel'),
 (3, 'Manteles', 'Manteles, caminos de mesa y cubre sillas'),
 (4, 'Carpas',   'Carpas y toldos para exteriores'),
 (5, 'Decoración e iluminación', 'Series de luces, arcos y accesorios decorativos');

-- ------------------------------ ARTICULOS ----------------------------
INSERT INTO articulo (id_articulo, id_categoria, nombre, descripcion, cantidad_total, precio_dia, activo) VALUES
 ( 1, 1, 'Silla plegable blanca',       'Plástico resistente, uso exterior',              150,   12.00, 1),
 ( 2, 1, 'Silla Tiffany dorada',        'Resina color oro con cojín blanco',               100,   25.00, 1),
 ( 3, 1, 'Silla infantil de colores',   'Para niños de 3 a 8 años',                         60,    8.00, 1),
 ( 4, 2, 'Mesa redonda 10 personas',    '1.80 m de diámetro',                               12,   90.00, 1),
 ( 5, 2, 'Mesa rectangular tablón',     '2.40 x 0.75 m, 8 personas',                        20,   70.00, 1),
 ( 6, 2, 'Mesa infantil',               '1.20 x 0.60 m, altura 50 cm',                      10,   45.00, 1),
 ( 7, 2, 'Mesa de cóctel alta',         'Periquera de 1.10 m de altura',                     8,   60.00, 1),
 ( 8, 3, 'Mantel redondo blanco',       'Para mesa de 1.80 m, a piso',                      40,   35.00, 1),
 ( 9, 3, 'Mantel rectangular blanco',   'Para tablón de 2.40 m',                            40,   30.00, 1),
 (10, 3, 'Camino de mesa dorado',       'Satín dorado de 2.70 m',                           50,   15.00, 1),
 (11, 3, 'Cubre silla con moño',        'Licra blanca con moño de color a elegir',         120,   10.00, 1),
 (12, 4, 'Carpa 6 x 6 m',               'Lona blanca con laterales, hasta 40 personas',      3,  850.00, 1),
 (13, 4, 'Carpa 10 x 5 m',              'Estructura de aluminio, hasta 60 personas',         2, 1200.00, 1),
 (14, 4, 'Toldo plegable 3 x 3 m',      'Ideal para playa o jardín',                         6,  400.00, 1),
 (15, 5, 'Serie de luces cálidas 10 m', 'Foco LED tipo vintage',                            25,   50.00, 1),
 (16, 5, 'Arco floral para ceremonia',  'Estructura metálica con flores artificiales',       2,  600.00, 1),
 (17, 5, 'Calentador de exterior',      'De gas, tipo hongo (dado de baja por seguridad)',   4,  300.00, 0);

-- ------------------------------ CLIENTES -----------------------------
-- Datos ficticios (correos con dominio reservado example.com)
INSERT INTO cliente (id_cliente, nombre, apellidos, telefono, correo, direccion) VALUES
 ( 1, 'María Fernanda', 'López Herrera',     '6461234501', 'mafer.lopez@example.com',     'Calle Ruiz 120, Zona Centro, Ensenada'),
 ( 2, 'José Luis',      'Martínez Ochoa',    '6461234502', 'jl.martinez@example.com',     'Av. Reforma 455, Ensenada'),
 ( 3, 'Ana Karen',      'Sánchez Villa',     '6461234503', 'karen.sanchez@example.com',   NULL),
 ( 4, 'Ricardo',        'Gómez Navarro',     '6461234504', 'ricardo.gomez@example.com',   'Fracc. Bahía 33, Ensenada'),
 ( 5, 'Lucía',          'Ramírez Castro',    '6461234505', 'lucia.ramirez@example.com',   'Col. Moderna 78, Ensenada'),
 ( 6, 'Fernando',       'Torres Medina',     '6461234506', 'fer.torres@example.com',      'Col. Chapultepec 210, Ensenada'),
 ( 7, 'Daniela',        'Flores Aguilar',    '6461234507', 'dani.flores@example.com',     NULL),
 ( 8, 'Club de Leones', 'Ensenada A.C.',     '6461234508', 'contacto.leones@example.com', 'Blvd. Costero 1500, Ensenada'),
 ( 9, 'Gabriela',       'Hernández Ruiz',    '6461234509', 'gaby.hernandez@example.com',  'Valle de Guadalupe km 12'),
 (10, 'Miguel Ángel',   'Díaz Fuentes',      '6461234510', 'miguel.diaz@example.com',     NULL),
 (11, 'Sociedad de Alumnos', 'FIAD UABC',    '6461234511', 'sociedad.fiad@example.com',   'Carretera Transpeninsular 3917'),
 (12, 'Paola',          'Vargas Espinoza',   '6461234512', 'paola.vargas@example.com',    'Fracc. Lomitas 45, Ensenada'),
 (13, 'Arturo',         'Morales Peña',      '6461234513', 'arturo.morales@example.com',  NULL),
 (14, 'Sofía',          'Castillo Ibarra',   '6461234514', 'sofia.castillo@example.com',  'Col. Obrera 12, Ensenada'),
 (15, 'Eventos Riviera', 'S.A. de C.V.',     '6461234515', 'ventas.riviera@example.com',  'Blvd. Costero y Riviera s/n'),
 (16, 'Jorge',          'Mendoza Lara',      '6461234516', 'jorge.mendoza@example.com',   'Fracc. Playa Ensenada 89'),
 (17, 'Valeria',        'Ortiz Salgado',     '6461234517', 'valeria.ortiz@example.com',   NULL),
 (18, 'Héctor',         'Rojas Domínguez',   '6461234518', 'hector.rojas@example.com',    'Col. Hidalgo 301, Ensenada'),
 (19, 'Mariana',        'Cruz Beltrán',      '6461234519', 'mariana.cruz@example.com',    NULL),
 (20, 'Grupo Industrial', 'El Sauzal',       '6461234520', 'rh.sauzal@example.com',       'Parque Industrial El Sauzal'),
 (21, 'Camila',         'Reyes Montoya',     '6461234521', 'camila.reyes@example.com',    NULL),
 (22, 'Andrés',         'Navarro Quintero',  '6461234522', 'andres.navarro@example.com',  'Col. Esperanza 77, Ensenada');

-- ------------------------------ EMPLEADOS ----------------------------
-- Contraseñas guardadas con PBKDF2-SHA256 (100,000 iteraciones, sal aleatoria) - RN-12
INSERT INTO empleado (id_empleado, nombre, usuario, contrasena_hash, rol, activo) VALUES
 (1, 'Laura Méndez Ruiz', 'admin',
     'pbkdf2-sha256$100000$5CKWa/abxCJoVwL/CMqOjg==$yeqTh1Q4Olbi7tXwNdDiA/vSK/qj+13D7+SmDaP5Puo=', 'Administrador', 1),
 (2, 'Carlos Ibarra Soto', 'carlos.ibarra',
     'pbkdf2-sha256$100000$qEHPnpkpXyxorHRwrr9f2w==$EDk1dAZkHIiwOrbPTDmBzx0qzgmg7DP1KVdrzhFsyRU=', 'Encargado', 1),
 (3, 'Diana Soto Vega', 'diana.soto',
     'pbkdf2-sha256$100000$qEHPnpkpXyxorHRwrr9f2w==$EDk1dAZkHIiwOrbPTDmBzx0qzgmg7DP1KVdrzhFsyRU=', 'Encargado', 1),
 (4, 'Jorge Peña Lugo', 'jorge.pena',
     'pbkdf2-sha256$100000$qEHPnpkpXyxorHRwrr9f2w==$EDk1dAZkHIiwOrbPTDmBzx0qzgmg7DP1KVdrzhFsyRU=', 'Encargado', 1);

-- ---------------------------------------------------------------------
-- Procedimiento auxiliar SOLO para la carga de datos (se elimina al final)
-- Crea la reservación con sp_crear_reservacion y, según la etapa,
-- registra entrega, devolución o cancelación con fechas coherentes.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS pr_seed_reservacion;
DELIMITER $$
CREATE PROCEDURE pr_seed_reservacion(
  IN p_cliente   INT UNSIGNED,
  IN p_inicio    DATE,
  IN p_dias      INT,
  IN p_lugar     VARCHAR(150),
  IN p_detalles  JSON,
  IN p_etapa     VARCHAR(12),     -- confirmada | entregada | finalizada | cancelada
  IN p_emp_ent   INT UNSIGNED,
  IN p_emp_dev   INT UNSIGNED,
  IN p_ajustes   JSON)            -- devoluciones con faltantes/daños
BEGIN
  DECLARE v_id  INT UNSIGNED;
  DECLARE v_fin DATE;
  DECLARE v_dev INT UNSIGNED;
  DECLARE v_aux INT UNSIGNED;

  SET v_fin = p_inicio + INTERVAL (p_dias - 1) DAY;
  CALL sp_crear_reservacion(p_cliente, p_inicio, v_fin, p_lugar, p_detalles, v_id);

  -- fecha de registro realista: entre 8 y 30 días antes del evento
  UPDATE reservacion
     SET fecha_registro = LEAST(NOW(), TIMESTAMP(p_inicio - INTERVAL (8 + (v_id * 7) % 23) DAY, '12:30:00'))
   WHERE id_reservacion = v_id;

  IF p_etapa IN ('entregada', 'finalizada') THEN
    INSERT INTO entrega (id_reservacion, id_empleado, fecha_hora, observaciones)
    VALUES (v_id, p_emp_ent, TIMESTAMP(p_inicio - INTERVAL 1 DAY, '17:00:00'),
            'Entregado y acomodado en el lugar del evento');
  END IF;

  IF p_etapa = 'finalizada' THEN
    INSERT INTO devolucion (id_reservacion, id_empleado, fecha_hora, observaciones)
    VALUES (v_id, p_emp_dev, TIMESTAMP(v_fin + INTERVAL 1 DAY, '11:00:00'),
            IF(p_ajustes IS NULL, 'Material completo y en buen estado', 'Se detectaron faltantes o daños'));
    SET v_dev = LAST_INSERT_ID();

    INSERT INTO detalle_devolucion (id_devolucion, id_articulo, cantidad_devuelta, cantidad_danada)
    SELECT v_dev, d.id_articulo,
           COALESCE(j.devuelta, d.cantidad),
           COALESCE(j.danada, 0)
      FROM detalle_reservacion d
      LEFT JOIN JSON_TABLE(COALESCE(p_ajustes, JSON_ARRAY()), '$[*]' COLUMNS (
                  id_articulo INT PATH '$.id_articulo',
                  devuelta    INT PATH '$.cantidad_devuelta',
                  danada      INT PATH '$.cantidad_danada')) AS j
             ON j.id_articulo = d.id_articulo
     WHERE d.id_reservacion = v_id;
  END IF;

  IF p_etapa = 'cancelada' THEN
    CALL sp_cancelar_reservacion(v_id);
  END IF;
END$$
DELIMITER ;

SET @hoy = CURDATE();
-- Próximo viernes con al menos una semana de anticipación (ejemplo del análisis)
SET @viernes = @hoy + INTERVAL (((4 - WEEKDAY(@hoy) + 7) % 7) + 7) DAY;

-- --------------------- Historial: reservaciones finalizadas ----------
CALL pr_seed_reservacion( 1, @hoy - INTERVAL 118 DAY, 1, 'Salón Los Arcos, Ensenada',
  '[{"id_articulo":1,"cantidad":80},{"id_articulo":4,"cantidad":8},{"id_articulo":8,"cantidad":8}]', 'finalizada', 2, 3, NULL);
CALL pr_seed_reservacion( 2, @hoy - INTERVAL 110 DAY, 2, 'Rancho El Mirador, Valle de Guadalupe',
  '[{"id_articulo":2,"cantidad":60},{"id_articulo":5,"cantidad":6},{"id_articulo":9,"cantidad":6},{"id_articulo":12,"cantidad":1}]',
  'finalizada', 2, 2, '[{"id_articulo":2,"cantidad_devuelta":58,"cantidad_danada":1}]');
CALL pr_seed_reservacion( 3, @hoy - INTERVAL 101 DAY, 1, 'Escuela Primaria Benito Juárez',
  '[{"id_articulo":3,"cantidad":40},{"id_articulo":6,"cantidad":6}]', 'finalizada', 3, 3, NULL);
CALL pr_seed_reservacion( 4, @hoy - INTERVAL 95 DAY, 1, 'Jardín Bugambilias',
  '[{"id_articulo":1,"cantidad":100},{"id_articulo":4,"cantidad":10},{"id_articulo":8,"cantidad":10},{"id_articulo":11,"cantidad":100}]',
  'finalizada', 4, 2, '[{"id_articulo":8,"cantidad_devuelta":9,"cantidad_danada":1}]');
CALL pr_seed_reservacion( 5, @hoy - INTERVAL 88 DAY, 3, 'Playa Hermosa, área de palapas',
  '[{"id_articulo":14,"cantidad":4},{"id_articulo":1,"cantidad":50},{"id_articulo":5,"cantidad":5}]', 'finalizada', 2, 3, NULL);
CALL pr_seed_reservacion( 6, @hoy - INTERVAL 80 DAY, 1, 'Casa particular, Col. Chapultepec',
  '[{"id_articulo":1,"cantidad":30},{"id_articulo":5,"cantidad":3},{"id_articulo":9,"cantidad":3}]', 'finalizada', 3, 2, NULL);
CALL pr_seed_reservacion( 7, @hoy - INTERVAL 73 DAY, 2, 'Hotel Coral, terraza',
  '[{"id_articulo":2,"cantidad":80},{"id_articulo":4,"cantidad":10},{"id_articulo":8,"cantidad":10},{"id_articulo":10,"cantidad":10},{"id_articulo":16,"cantidad":1}]',
  'finalizada', 2, 3, '[{"id_articulo":10,"cantidad_devuelta":9,"cantidad_danada":0}]');
CALL pr_seed_reservacion( 1, @hoy - INTERVAL 66 DAY, 1, 'Salón Los Arcos, Ensenada',
  '[{"id_articulo":1,"cantidad":120},{"id_articulo":4,"cantidad":12}]', 'finalizada', 3, 3, NULL);
CALL pr_seed_reservacion( 8, @hoy - INTERVAL 60 DAY, 1, 'Club de Leones, Blvd. Costero',
  '[{"id_articulo":5,"cantidad":15},{"id_articulo":9,"cantidad":15},{"id_articulo":1,"cantidad":90}]',
  'finalizada', 2, 2, '[{"id_articulo":1,"cantidad_devuelta":85,"cantidad_danada":3}]');
CALL pr_seed_reservacion( 9, @hoy - INTERVAL 52 DAY, 2, 'Viñedo Santo Tomás',
  '[{"id_articulo":13,"cantidad":1},{"id_articulo":2,"cantidad":70},{"id_articulo":4,"cantidad":7},{"id_articulo":15,"cantidad":10}]',
  'finalizada', 3, 2, NULL);
CALL pr_seed_reservacion(10, @hoy - INTERVAL 45 DAY, 1, 'Parroquia San Miguel, salón anexo',
  '[{"id_articulo":1,"cantidad":60},{"id_articulo":5,"cantidad":6}]', 'finalizada', 2, 3, NULL);
CALL pr_seed_reservacion( 2, @hoy - INTERVAL 38 DAY, 1, 'Rancho El Mirador, Valle de Guadalupe',
  '[{"id_articulo":2,"cantidad":50},{"id_articulo":7,"cantidad":6},{"id_articulo":15,"cantidad":8}]', 'finalizada', 3, 3, NULL);
CALL pr_seed_reservacion(11, @hoy - INTERVAL 31 DAY, 1, 'Gimnasio Universitario UABC',
  '[{"id_articulo":1,"cantidad":150},{"id_articulo":5,"cantidad":20}]',
  'finalizada', 2, 2, '[{"id_articulo":1,"cantidad_devuelta":147,"cantidad_danada":2}]');
CALL pr_seed_reservacion(12, @hoy - INTERVAL 24 DAY, 2, 'Quinta Los Olivos',
  '[{"id_articulo":12,"cantidad":2},{"id_articulo":1,"cantidad":80},{"id_articulo":4,"cantidad":8},{"id_articulo":8,"cantidad":8},{"id_articulo":11,"cantidad":80}]',
  'finalizada', 3, 2, NULL);
CALL pr_seed_reservacion(13, @hoy - INTERVAL 17 DAY, 1, 'Salón Imperial',
  '[{"id_articulo":2,"cantidad":90},{"id_articulo":4,"cantidad":9},{"id_articulo":8,"cantidad":9},{"id_articulo":10,"cantidad":9}]',
  'finalizada', 2, 3, NULL);
CALL pr_seed_reservacion( 3, @hoy - INTERVAL 10 DAY, 1, 'Escuela Primaria Benito Juárez',
  '[{"id_articulo":3,"cantidad":50},{"id_articulo":6,"cantidad":8}]', 'finalizada', 3, 2, NULL);

-- --------------------- Cancelada en el pasado ------------------------
CALL pr_seed_reservacion(14, @hoy - INTERVAL 20 DAY, 1, 'Terraza Bahía, Ensenada',
  '[{"id_articulo":1,"cantidad":40}]', 'cancelada', NULL, NULL, NULL);

-- --------------------- Rentas en curso (entregadas) ------------------
CALL pr_seed_reservacion(15, @hoy - INTERVAL 2 DAY, 4, 'Centro de Convenciones Riviera',
  '[{"id_articulo":1,"cantidad":100},{"id_articulo":5,"cantidad":15},{"id_articulo":9,"cantidad":15},{"id_articulo":15,"cantidad":10}]',
  'entregada', 2, NULL, NULL);
CALL pr_seed_reservacion( 4, @hoy - INTERVAL 1 DAY, 2, 'Jardín Bugambilias',
  '[{"id_articulo":2,"cantidad":40},{"id_articulo":4,"cantidad":4},{"id_articulo":8,"cantidad":4}]',
  'entregada', 3, NULL, NULL);
-- Devolución atrasada (terminó hace 5 días y no ha regresado)
CALL pr_seed_reservacion(16, @hoy - INTERVAL 6 DAY, 2, 'Casa particular, Fracc. Playa Ensenada',
  '[{"id_articulo":3,"cantidad":20},{"id_articulo":6,"cantidad":3}]', 'entregada', 2, NULL, NULL);

-- --------------------- Futuras (confirmadas) -------------------------
-- Ejemplo del documento de análisis: 100 sillas Tiffany,
-- 60 del jueves al sábado y 30 del viernes al domingo => el viernes quedan 10.
CALL pr_seed_reservacion(17, @viernes - INTERVAL 1 DAY, 3, 'Salón Las Palmas, Ensenada',
  '[{"id_articulo":2,"cantidad":60},{"id_articulo":4,"cantidad":6}]', 'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion(18, @viernes, 3, 'Jardín El Encino, El Sauzal',
  '[{"id_articulo":2,"cantidad":30},{"id_articulo":5,"cantidad":4},{"id_articulo":12,"cantidad":1}]', 'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion( 5, @hoy + INTERVAL 5 DAY, 1, 'Playa Hermosa, área de palapas',
  '[{"id_articulo":14,"cantidad":3},{"id_articulo":1,"cantidad":40}]', 'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion(19, @hoy + INTERVAL 16 DAY, 1, 'Salón Imperial',
  '[{"id_articulo":1,"cantidad":120},{"id_articulo":4,"cantidad":12},{"id_articulo":8,"cantidad":12},{"id_articulo":11,"cantidad":120}]',
  'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion(14, @hoy + INTERVAL 12 DAY, 1, 'Terraza Bahía, Ensenada',
  '[{"id_articulo":1,"cantidad":60},{"id_articulo":4,"cantidad":6}]', 'cancelada', NULL, NULL, NULL);

-- --------------------- Cambio de precios (RN-07) ---------------------
-- Las reservaciones anteriores conservan el precio con el que se hicieron;
-- el trigger trg_articulo_au deja el registro en historial_precio.
SET @app_empleado = 1;
UPDATE articulo SET precio_dia = 14.00  WHERE id_articulo = 1;
UPDATE articulo SET precio_dia = 28.00  WHERE id_articulo = 2;
UPDATE articulo SET precio_dia = 900.00 WHERE id_articulo = 12;
SET @app_empleado = NULL;

-- --------------------- Futuras con precio nuevo ----------------------
CALL pr_seed_reservacion(20, @hoy + INTERVAL 21 DAY, 1, 'Posada empresarial, nave industrial El Sauzal',
  '[{"id_articulo":1,"cantidad":150},{"id_articulo":5,"cantidad":20},{"id_articulo":15,"cantidad":20},{"id_articulo":13,"cantidad":2}]',
  'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion( 6, @hoy + INTERVAL 23 DAY, 2, 'Casa particular, Col. Chapultepec',
  '[{"id_articulo":2,"cantidad":40},{"id_articulo":4,"cantidad":4},{"id_articulo":16,"cantidad":1}]', 'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion( 7, @hoy + INTERVAL 27 DAY, 1, 'Hotel Coral, terraza',
  '[{"id_articulo":2,"cantidad":100},{"id_articulo":4,"cantidad":10},{"id_articulo":8,"cantidad":10},{"id_articulo":10,"cantidad":10}]',
  'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion(11, @hoy + INTERVAL 30 DAY, 1, 'Gimnasio Universitario UABC',
  '[{"id_articulo":1,"cantidad":150},{"id_articulo":5,"cantidad":20}]', 'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion( 9, @hoy + INTERVAL 33 DAY, 2, 'Viñedo Santo Tomás',
  '[{"id_articulo":13,"cantidad":1},{"id_articulo":12,"cantidad":1},{"id_articulo":2,"cantidad":60},{"id_articulo":7,"cantidad":8}]',
  'confirmada', NULL, NULL, NULL);
CALL pr_seed_reservacion(12, @hoy + INTERVAL 40 DAY, 1, 'Quinta Los Olivos',
  '[{"id_articulo":1,"cantidad":80},{"id_articulo":4,"cantidad":8},{"id_articulo":8,"cantidad":8}]', 'confirmada', NULL, NULL, NULL);

-- El encargado Jorge Peña dejó de trabajar en el negocio: baja lógica
UPDATE empleado SET activo = 0 WHERE id_empleado = 4;

DROP PROCEDURE pr_seed_reservacion;
SET @carga_historica = NULL;

-- Resumen de la carga
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'articulo', COUNT(*) FROM articulo
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'empleado', COUNT(*) FROM empleado
UNION ALL SELECT 'reservacion', COUNT(*) FROM reservacion
UNION ALL SELECT 'detalle_reservacion', COUNT(*) FROM detalle_reservacion
UNION ALL SELECT 'entrega', COUNT(*) FROM entrega
UNION ALL SELECT 'devolucion', COUNT(*) FROM devolucion
UNION ALL SELECT 'detalle_devolucion', COUNT(*) FROM detalle_devolucion
UNION ALL SELECT 'historial_precio', COUNT(*) FROM historial_precio
UNION ALL SELECT 'bitacora', COUNT(*) FROM bitacora;
