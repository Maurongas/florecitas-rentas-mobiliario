using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Data;

/// <summary>CRUD de CLIENTE.</summary>
public sealed class ClienteRepositorio(Db db)
{
    public async Task<Pagina<Cliente>> BuscarAsync(string? buscar, int pagina, int tamano = 12)
    {
        var p = new
        {
            buscar = string.IsNullOrWhiteSpace(buscar) ? null : buscar.Trim(),
            tamano,
            desde = (Math.Max(pagina, 1) - 1) * tamano
        };
        const string filtro = @"
            WHERE (@buscar IS NULL
                   OR CONCAT(c.nombre, ' ', c.apellidos) LIKE CONCAT('%', @buscar, '%')
                   OR c.correo LIKE CONCAT('%', @buscar, '%')
                   OR c.telefono LIKE CONCAT('%', @buscar, '%'))";

        var total = await db.EscalarAsync<int>("SELECT COUNT(*) FROM cliente c " + filtro, p);
        var filas = await db.ConsultarAsync<Cliente>(@"
            SELECT c.id_cliente, c.nombre, c.apellidos, c.telefono, c.correo, c.direccion,
                   COUNT(v.id_reservacion) AS reservaciones,
                   COALESCE(SUM(CASE WHEN v.estado <> 'Cancelada' THEN v.total END), 0) AS gasto_total
              FROM cliente c
              LEFT JOIN vw_reservacion_resumen v ON v.id_cliente = c.id_cliente " + filtro + @"
             GROUP BY c.id_cliente, c.nombre, c.apellidos, c.telefono, c.correo, c.direccion
             ORDER BY c.apellidos, c.nombre
             LIMIT @tamano OFFSET @desde", p);

        return new Pagina<Cliente> { Elementos = filas, Total = total, NumeroPagina = Math.Max(pagina, 1), TamanoPagina = tamano };
    }

    public Task<IReadOnlyList<Cliente>> TodosAsync() => db.ConsultarAsync<Cliente>(
        "SELECT id_cliente, nombre, apellidos, telefono, correo FROM cliente ORDER BY nombre, apellidos");

    public Task<Cliente?> ObtenerAsync(int id) => db.UnoAsync<Cliente>(
        "SELECT id_cliente, nombre, apellidos, telefono, correo, direccion FROM cliente WHERE id_cliente = @id", new { id });

    public Task<int> CrearAsync(Cliente c) => db.EscalarAsync<int>(@"
        INSERT INTO cliente (nombre, apellidos, telefono, correo, direccion)
        VALUES (@Nombre, @Apellidos, @Telefono, @Correo, @Direccion);
        SELECT LAST_INSERT_ID();", c);

    public Task<int> ActualizarAsync(Cliente c) => db.EjecutarAsync(@"
        UPDATE cliente SET nombre = @Nombre, apellidos = @Apellidos, telefono = @Telefono,
                           correo = @Correo, direccion = @Direccion
         WHERE id_cliente = @IdCliente", c);

    // RN-11: si tiene reservaciones, la FK (ON DELETE RESTRICT) lo impide
    public Task<int> EliminarAsync(int id) =>
        db.EjecutarAsync("DELETE FROM cliente WHERE id_cliente = @id", new { id });

    public Task<IReadOnlyList<ReservacionResumen>> HistorialAsync(int id) => db.ConsultarAsync<ReservacionResumen>(
        "SELECT * FROM vw_reservacion_resumen WHERE id_cliente = @id ORDER BY fecha_inicio DESC", new { id });
}
