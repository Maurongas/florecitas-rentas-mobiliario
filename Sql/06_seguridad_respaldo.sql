-- =====================================================================
--  06_seguridad_respaldo.sql
--  Usuario de la aplicación con privilegios mínimos y comandos de respaldo.
--  Ejecutar con un usuario administrador de MySQL (root).
--
--  IMPORTANTE: cambie la contraseña antes de usarlo fuera del salón de
--  clases y guárdela solo en la configuración del servidor de la
--  aplicación (user-secrets o variable de entorno), nunca en el cliente.
-- =====================================================================

-- Usuario que usa la aplicación web (solo desde el mismo equipo)
DROP USER IF EXISTS 'rentas_app'@'localhost';
CREATE USER 'rentas_app'@'localhost' IDENTIFIED BY 'Florecitas_App_2026!';

-- Principio de mínimo privilegio: solo DML y ejecución de rutinas.
-- No puede crear/borrar tablas ni modificar la estructura.
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
   ON rentas_mobiliario.* TO 'rentas_app'@'localhost';

-- La bitácora y el historial de precios solo los escriben los triggers;
-- la aplicación únicamente los consulta. (MySQL no permite revocar sobre
-- una tabla lo concedido a nivel de base de datos, por eso esta regla se
-- garantiza en la capa de aplicación y se documenta aquí.)

FLUSH PRIVILEGES;

SHOW GRANTS FOR 'rentas_app'@'localhost';

-- ---------------------------------------------------------------------
-- RESPALDO Y RESTAURACIÓN (se ejecutan desde PowerShell / terminal)
-- ---------------------------------------------------------------------
-- Respaldo completo con rutinas y triggers:
--   mysqldump -u root -p --routines --triggers --events --single-transaction `
--             --databases rentas_mobiliario > respaldo_rentas_AAAAMMDD.sql
--
-- Restauración:
--   mysql -u root -p < respaldo_rentas_AAAAMMDD.sql
--
-- Recomendación: respaldo diario automático con el Programador de tareas
-- de Windows y conservar los últimos 7 respaldos fuera del equipo.
