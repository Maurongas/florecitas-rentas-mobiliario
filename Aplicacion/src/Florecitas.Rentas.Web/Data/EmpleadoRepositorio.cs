using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Data;

/// <summary>CRUD de EMPLEADO y autenticación.</summary>
public sealed class EmpleadoRepositorio(Db db)
{
    public Task<Empleado?> PorUsuarioAsync(string usuario) => db.UnoAsync<Empleado>(
        "SELECT id_empleado, nombre, usuario, contrasena_hash, rol, activo FROM empleado WHERE usuario = @usuario",
        new { usuario });

    public Task<IReadOnlyList<Empleado>> TodosAsync() => db.ConsultarAsync<Empleado>(@"
        SELECT e.id_empleado, e.nombre, e.usuario, e.rol, e.activo,
               (SELECT COUNT(*) FROM entrega en WHERE en.id_empleado = e.id_empleado)     AS entregas,
               (SELECT COUNT(*) FROM devolucion dv WHERE dv.id_empleado = e.id_empleado)  AS devoluciones
          FROM empleado e
         ORDER BY e.activo DESC, e.rol, e.nombre");

    public Task<IReadOnlyList<Empleado>> ActivosAsync() => db.ConsultarAsync<Empleado>(
        "SELECT id_empleado, nombre, usuario, rol, activo FROM empleado WHERE activo = 1 ORDER BY nombre");

    public Task<Empleado?> ObtenerAsync(int id) => db.UnoAsync<Empleado>(
        "SELECT id_empleado, nombre, usuario, rol, activo FROM empleado WHERE id_empleado = @id", new { id });

    public Task<int> CrearAsync(Empleado e) => db.EscalarAsync<int>(@"
        INSERT INTO empleado (nombre, usuario, contrasena_hash, rol, activo)
        VALUES (@Nombre, @Usuario, @ContrasenaHash, @Rol, @Activo);
        SELECT LAST_INSERT_ID();", e);

    // trg_empleado_bu garantiza que siempre quede un Administrador activo (RN-13)
    public Task<int> ActualizarAsync(Empleado e) => db.EjecutarAsync(@"
        UPDATE empleado SET nombre = @Nombre, usuario = @Usuario, rol = @Rol, activo = @Activo
         WHERE id_empleado = @IdEmpleado", e);

    public Task<int> CambiarContrasenaAsync(int id, string hash) => db.EjecutarAsync(
        "UPDATE empleado SET contrasena_hash = @hash WHERE id_empleado = @id", new { id, hash });

    public Task<int> EliminarAsync(int id) =>
        db.EjecutarAsync("DELETE FROM empleado WHERE id_empleado = @id", new { id });
}
