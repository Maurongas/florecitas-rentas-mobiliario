-- =====================================================================
--  Proyecto final - Base de datos
--  Control de rentas de mobiliario para eventos
--  Equipo Florecitas (UABC - FIAD)
--
--  01_esquema.sql
--  Crea la base de datos, las tablas, llaves y restricciones
--  (integridad de entidad, referencial y de dominio).
--  SGBD: MySQL 8.0
--
--  Ejecución:  mysql -u root -p < 01_esquema.sql
--  ADVERTENCIA: borra y vuelve a crear la base de datos rentas_mobiliario.
-- =====================================================================

DROP DATABASE IF EXISTS rentas_mobiliario;
CREATE DATABASE rentas_mobiliario
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE rentas_mobiliario;

-- ---------------------------------------------------------------------
-- CATEGORIA: tipo general de mobiliario (Sillas, Mesas, Manteles, ...)
-- ---------------------------------------------------------------------
CREATE TABLE categoria (
  id_categoria  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(40)   NOT NULL,
  descripcion   VARCHAR(150)  NULL,
  CONSTRAINT pk_categoria        PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categoria_nombre UNIQUE (nombre),
  CONSTRAINT ck_categoria_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) >= 3)
) ENGINE = InnoDB COMMENT = 'Tipos generales de mobiliario';

-- ---------------------------------------------------------------------
-- ARTICULO: modelo concreto que se renta. Inventario por cantidad.
-- ---------------------------------------------------------------------
CREATE TABLE articulo (
  id_articulo     INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_categoria    INT UNSIGNED   NOT NULL,
  nombre          VARCHAR(80)    NOT NULL,
  descripcion     VARCHAR(200)   NULL,
  cantidad_total  INT            NOT NULL,
  precio_dia      DECIMAL(10,2)  NOT NULL,
  activo          TINYINT(1)     NOT NULL DEFAULT 1,
  CONSTRAINT pk_articulo            PRIMARY KEY (id_articulo),
  CONSTRAINT uq_articulo_cat_nombre UNIQUE (id_categoria, nombre),
  CONSTRAINT fk_articulo_categoria  FOREIGN KEY (id_categoria)
      REFERENCES categoria (id_categoria)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_articulo_cantidad   CHECK (cantidad_total BETWEEN 0 AND 100000),
  CONSTRAINT ck_articulo_precio     CHECK (precio_dia > 0),
  CONSTRAINT ck_articulo_activo     CHECK (activo IN (0, 1)),
  CONSTRAINT ck_articulo_nombre     CHECK (CHAR_LENGTH(TRIM(nombre)) >= 3)
) ENGINE = InnoDB COMMENT = 'Inventario de mobiliario (por modelo y cantidad)';

-- ---------------------------------------------------------------------
-- CLIENTE: persona que renta mobiliario
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
  id_cliente  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nombre      VARCHAR(60)   NOT NULL,
  apellidos   VARCHAR(80)   NOT NULL,
  telefono    VARCHAR(15)   NOT NULL,
  correo      VARCHAR(100)  NOT NULL,
  direccion   VARCHAR(150)  NULL,
  CONSTRAINT pk_cliente         PRIMARY KEY (id_cliente),
  CONSTRAINT uq_cliente_correo  UNIQUE (correo),
  CONSTRAINT ck_cliente_telefono CHECK (telefono REGEXP '^[0-9]{10}$'),
  CONSTRAINT ck_cliente_correo   CHECK (correo REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]{2,}$'),
  CONSTRAINT ck_cliente_nombre   CHECK (CHAR_LENGTH(TRIM(nombre)) >= 2 AND CHAR_LENGTH(TRIM(apellidos)) >= 2)
) ENGINE = InnoDB COMMENT = 'Clientes que rentan mobiliario';

CREATE INDEX ix_cliente_apellidos ON cliente (apellidos, nombre);

-- ---------------------------------------------------------------------
-- EMPLEADO: usuarios del sistema (Administrador / Encargado)
-- ---------------------------------------------------------------------
CREATE TABLE empleado (
  id_empleado      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nombre           VARCHAR(100)  NOT NULL,
  usuario          VARCHAR(30)   NOT NULL,
  contrasena_hash  VARCHAR(255)  NOT NULL,
  rol              VARCHAR(15)   NOT NULL DEFAULT 'Encargado',
  activo           TINYINT(1)    NOT NULL DEFAULT 1,
  CONSTRAINT pk_empleado          PRIMARY KEY (id_empleado),
  CONSTRAINT uq_empleado_usuario  UNIQUE (usuario),
  CONSTRAINT ck_empleado_rol      CHECK (rol IN ('Administrador', 'Encargado')),
  CONSTRAINT ck_empleado_usuario  CHECK (usuario REGEXP '^[a-z0-9._]{4,30}$'),
  CONSTRAINT ck_empleado_hash     CHECK (CHAR_LENGTH(contrasena_hash) >= 40),
  CONSTRAINT ck_empleado_activo   CHECK (activo IN (0, 1))
) ENGINE = InnoDB COMMENT = 'Empleados que operan el sistema';

-- ---------------------------------------------------------------------
-- RESERVACION: solicitud de renta para un periodo de fechas
-- ---------------------------------------------------------------------
CREATE TABLE reservacion (
  id_reservacion  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_cliente      INT UNSIGNED  NOT NULL,
  fecha_registro  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_inicio    DATE          NOT NULL,
  fecha_fin       DATE          NOT NULL,
  lugar_evento    VARCHAR(150)  NOT NULL,
  estado          VARCHAR(15)   NOT NULL DEFAULT 'Confirmada',
  CONSTRAINT pk_reservacion          PRIMARY KEY (id_reservacion),
  CONSTRAINT fk_reservacion_cliente  FOREIGN KEY (id_cliente)
      REFERENCES cliente (id_cliente)
      ON UPDATE CASCADE ON DELETE RESTRICT,            -- RN-11
  CONSTRAINT ck_reservacion_fechas   CHECK (fecha_fin >= fecha_inicio),                  -- RN-05
  CONSTRAINT ck_reservacion_duracion CHECK (DATEDIFF(fecha_fin, fecha_inicio) <= 30),     -- RN-14
  CONSTRAINT ck_reservacion_estado   CHECK (estado IN ('Confirmada', 'Entregada', 'Finalizada', 'Cancelada')), -- RN-08
  CONSTRAINT ck_reservacion_lugar    CHECK (CHAR_LENGTH(TRIM(lugar_evento)) >= 5)
) ENGINE = InnoDB COMMENT = 'Reservaciones de mobiliario';

CREATE INDEX ix_reservacion_fechas ON reservacion (fecha_inicio, fecha_fin);
CREATE INDEX ix_reservacion_estado ON reservacion (estado);

-- ---------------------------------------------------------------------
-- DETALLE_RESERVACION: entidad asociativa RESERVACION <-> ARTICULO (N:M)
-- ---------------------------------------------------------------------
CREATE TABLE detalle_reservacion (
  id_reservacion   INT UNSIGNED   NOT NULL,
  id_articulo      INT UNSIGNED   NOT NULL,
  cantidad         INT            NOT NULL,
  precio_unitario  DECIMAL(10,2)  NOT NULL,
  CONSTRAINT pk_detalle_reservacion PRIMARY KEY (id_reservacion, id_articulo),
  CONSTRAINT fk_detres_reservacion  FOREIGN KEY (id_reservacion)
      REFERENCES reservacion (id_reservacion)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_detres_articulo     FOREIGN KEY (id_articulo)
      REFERENCES articulo (id_articulo)
      ON UPDATE CASCADE ON DELETE RESTRICT,            -- RN-11
  CONSTRAINT ck_detres_cantidad     CHECK (cantidad > 0),          -- RN-04
  CONSTRAINT ck_detres_precio       CHECK (precio_unitario > 0)
) ENGINE = InnoDB COMMENT = 'Artículos incluidos en cada reservación';

CREATE INDEX ix_detres_articulo ON detalle_reservacion (id_articulo);

-- ---------------------------------------------------------------------
-- ENTREGA: registro de salida del material (1:1 con RESERVACION)
-- ---------------------------------------------------------------------
CREATE TABLE entrega (
  id_entrega      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_reservacion  INT UNSIGNED  NOT NULL,
  id_empleado     INT UNSIGNED  NOT NULL,
  fecha_hora      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  observaciones   VARCHAR(200)  NULL,
  CONSTRAINT pk_entrega              PRIMARY KEY (id_entrega),
  CONSTRAINT uq_entrega_reservacion  UNIQUE (id_reservacion),   -- RN-09: máximo una entrega
  CONSTRAINT fk_entrega_reservacion  FOREIGN KEY (id_reservacion)
      REFERENCES reservacion (id_reservacion)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_entrega_empleado     FOREIGN KEY (id_empleado)
      REFERENCES empleado (id_empleado)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = 'Entregas de mobiliario al cliente';

-- ---------------------------------------------------------------------
-- DEVOLUCION: registro de regreso del material (1:1 con RESERVACION)
-- ---------------------------------------------------------------------
CREATE TABLE devolucion (
  id_devolucion   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_reservacion  INT UNSIGNED  NOT NULL,
  id_empleado     INT UNSIGNED  NOT NULL,
  fecha_hora      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  observaciones   VARCHAR(200)  NULL,
  CONSTRAINT pk_devolucion             PRIMARY KEY (id_devolucion),
  CONSTRAINT uq_devolucion_reservacion UNIQUE (id_reservacion),   -- RN-09: máximo una devolución
  CONSTRAINT fk_devolucion_reservacion FOREIGN KEY (id_reservacion)
      REFERENCES reservacion (id_reservacion)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_devolucion_empleado    FOREIGN KEY (id_empleado)
      REFERENCES empleado (id_empleado)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB COMMENT = 'Devoluciones de mobiliario';

-- ---------------------------------------------------------------------
-- DETALLE_DEVOLUCION: entidad débil; depende de DEVOLUCION
-- ---------------------------------------------------------------------
CREATE TABLE detalle_devolucion (
  id_devolucion      INT UNSIGNED  NOT NULL,
  id_articulo        INT UNSIGNED  NOT NULL,
  cantidad_devuelta  INT           NOT NULL DEFAULT 0,
  cantidad_danada    INT           NOT NULL DEFAULT 0,
  CONSTRAINT pk_detalle_devolucion PRIMARY KEY (id_devolucion, id_articulo),
  CONSTRAINT fk_detdev_devolucion  FOREIGN KEY (id_devolucion)
      REFERENCES devolucion (id_devolucion)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_detdev_articulo    FOREIGN KEY (id_articulo)
      REFERENCES articulo (id_articulo)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_detdev_cantidades  CHECK (cantidad_devuelta >= 0 AND cantidad_danada >= 0)
) ENGINE = InnoDB COMMENT = 'Revisión por artículo de cada devolución';

-- ---------------------------------------------------------------------
-- Tablas de apoyo (solo las escriben los triggers)
-- ---------------------------------------------------------------------
-- HISTORIAL_PRECIO: cada cambio de ARTICULO.precio_dia (problema "los precios
-- cambian sin que quede registro").
CREATE TABLE historial_precio (
  id_historial     INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_articulo      INT UNSIGNED   NOT NULL,
  precio_anterior  DECIMAL(10,2)  NOT NULL,
  precio_nuevo     DECIMAL(10,2)  NOT NULL,
  fecha_cambio     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_empleado      INT UNSIGNED   NULL,
  CONSTRAINT pk_historial_precio PRIMARY KEY (id_historial),
  CONSTRAINT fk_histprecio_articulo FOREIGN KEY (id_articulo)
      REFERENCES articulo (id_articulo)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_histprecio_empleado FOREIGN KEY (id_empleado)
      REFERENCES empleado (id_empleado)
      ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT ck_histprecio_distinto CHECK (precio_anterior <> precio_nuevo)
) ENGINE = InnoDB COMMENT = 'Historial de cambios de precio (auditoría)';

-- BITACORA: auditoría general de operaciones relevantes.
CREATE TABLE bitacora (
  id_bitacora  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  tabla        VARCHAR(40)      NOT NULL,
  id_registro  INT UNSIGNED     NOT NULL,
  accion       VARCHAR(20)      NOT NULL,
  detalle      VARCHAR(255)     NULL,
  id_empleado  INT UNSIGNED     NULL,
  usuario_bd   VARCHAR(100)     NOT NULL,
  fecha        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_bitacora PRIMARY KEY (id_bitacora),
  CONSTRAINT ck_bitacora_accion CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE', 'ESTADO'))
) ENGINE = InnoDB COMMENT = 'Bitácora de auditoría escrita por triggers';

CREATE INDEX ix_bitacora_tabla ON bitacora (tabla, id_registro);
CREATE INDEX ix_bitacora_fecha ON bitacora (fecha);
