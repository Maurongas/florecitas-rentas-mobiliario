using System.Data;
using System.Text.Json;
using Dapper;
using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Data;

public record RenglonReservacion(int IdArticulo, int Cantidad);
public record RenglonDevolucion(int IdArticulo, int CantidadDevuelta, int CantidadDanada);

public class FiltroReservaciones
{
    public string? Buscar { get; set; }
    public string? Estado { get; set; }
    public DateTime? Desde { get; set; }
    public DateTime? Hasta { get; set; }
    public int Pagina { get; set; } = 1;
}

/// <summary>
/// Reservaciones: las operaciones de negocio se delegan a los procedimientos
/// almacenados (sp_crear_reservacion, sp_registrar_entrega,
/// sp_registrar_devolucion, sp_cancelar_reservacion). Los triggers cambian
/// el estado y validan la disponibilidad; la aplicación nunca escribe el
/// estado ni el precio_unitario, para no duplicar esas operaciones.
/// </summary>
public sealed class ReservacionRepositorio(Db db)
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };

    // ------------------------------ Consultas -----------------------------
    public async Task<Pagina<ReservacionResumen>> BuscarAsync(FiltroReservaciones f, int tamano = 12)
    {
        var p = new
        {
            buscar = string.IsNullOrWhiteSpace(f.Buscar) ? null : f.Buscar.Trim(),
            estado = string.IsNullOrWhiteSpace(f.Estado) ? null : f.Estado,
            f.Desde,
            f.Hasta,
            tamano,
            desde_fila = (Math.Max(f.Pagina, 1) - 1) * tamano
        };
        const string filtro = @"
            WHERE (@buscar IS NULL OR cliente LIKE CONCAT('%', @buscar, '%')
                   OR lugar_evento LIKE CONCAT('%', @buscar, '%')
                   OR CAST(id_reservacion AS CHAR) = @buscar)
              AND (@estado IS NULL OR estado = @estado)
              AND (@Desde IS NULL OR fecha_fin >= @Desde)
              AND (@Hasta IS NULL OR fecha_inicio <= @Hasta)";

        var total = await db.EscalarAsync<int>("SELECT COUNT(*) FROM vw_reservacion_resumen " + filtro, p);
        var filas = await db.ConsultarAsync<ReservacionResumen>(
            "SELECT * FROM vw_reservacion_resumen " + filtro +
            " ORDER BY FIELD(estado,'Entregada','Confirmada','Finalizada','Cancelada'), fecha_inicio DESC LIMIT @tamano OFFSET @desde_fila", p);

        return new Pagina<ReservacionResumen> { Elementos = filas, Total = total, NumeroPagina = Math.Max(f.Pagina, 1), TamanoPagina = tamano };
    }

    public Task<ReservacionResumen?> ResumenAsync(int id) =>
        db.UnoAsync<ReservacionResumen>("SELECT * FROM vw_reservacion_resumen WHERE id_reservacion = @id", new { id });

    public Task<IReadOnlyList<DetalleReservacion>> DetallesAsync(int id) => db.ConsultarAsync<DetalleReservacion>(@"
        SELECT d.id_articulo, a.nombre AS articulo, c.nombre AS categoria, d.cantidad, d.precio_unitario,
               a.precio_dia AS precio_actual,
               d.cantidad * d.precio_unitario * fn_dias_renta(r.fecha_inicio, r.fecha_fin) AS subtotal
          FROM detalle_reservacion d
          JOIN reservacion r ON r.id_reservacion = d.id_reservacion
          JOIN articulo a    ON a.id_articulo    = d.id_articulo
          JOIN categoria c   ON c.id_categoria   = a.id_categoria
         WHERE d.id_reservacion = @id
         ORDER BY c.nombre, a.nombre", new { id });

    public Task<MovimientoInfo?> EntregaAsync(int id) => db.UnoAsync<MovimientoInfo>(@"
        SELECT en.id_entrega AS id, en.fecha_hora, e.nombre AS empleado, en.observaciones
          FROM entrega en JOIN empleado e ON e.id_empleado = en.id_empleado
         WHERE en.id_reservacion = @id", new { id });

    public Task<MovimientoInfo?> DevolucionAsync(int id) => db.UnoAsync<MovimientoInfo>(@"
        SELECT dv.id_devolucion AS id, dv.fecha_hora, e.nombre AS empleado, dv.observaciones
          FROM devolucion dv JOIN empleado e ON e.id_empleado = dv.id_empleado
         WHERE dv.id_reservacion = @id", new { id });

    public Task<IReadOnlyList<DetalleDevolucion>> DetallesDevolucionAsync(int idReservacion) => db.ConsultarAsync<DetalleDevolucion>(@"
        SELECT dr.id_articulo, a.nombre AS articulo, dr.cantidad AS rentadas,
               dd.cantidad_devuelta AS devueltas, dd.cantidad_danada AS danadas
          FROM devolucion dv
          JOIN detalle_devolucion dd  ON dd.id_devolucion  = dv.id_devolucion
          JOIN detalle_reservacion dr ON dr.id_reservacion = dv.id_reservacion AND dr.id_articulo = dd.id_articulo
          JOIN articulo a             ON a.id_articulo     = dd.id_articulo
         WHERE dv.id_reservacion = @idReservacion
         ORDER BY a.nombre", new { idReservacion });

    public Task<IReadOnlyList<BitacoraItem>> BitacoraAsync(int id) => db.ConsultarAsync<BitacoraItem>(@"
        SELECT b.id_bitacora, b.tabla, b.id_registro, b.accion, b.detalle, e.nombre AS empleado, b.usuario_bd, b.fecha
          FROM bitacora b LEFT JOIN empleado e ON e.id_empleado = b.id_empleado
         WHERE b.tabla = 'reservacion' AND b.id_registro = @id
         ORDER BY b.fecha, b.id_bitacora", new { id });

    /// <summary>Disponibilidad de todos los artículos activos en el rango (sp_disponibilidad_rango).</summary>
    public Task<IReadOnlyList<Disponibilidad>> DisponibilidadAsync(DateTime inicio, DateTime fin, int? idCategoria = null) =>
        db.ConsultarAsync<Disponibilidad>("sp_disponibilidad_rango",
            new { p_fecha_inicio = inicio.Date, p_fecha_fin = fin.Date, p_id_categoria = idCategoria },
            CommandType.StoredProcedure);

    /// <summary>Disponibilidad sin contar una reservación (para editar sus artículos).</summary>
    public Task<IReadOnlyList<Disponibilidad>> DisponibilidadParaAsync(int idReservacion) => db.ConsultarAsync<Disponibilidad>(@"
        SELECT a.id_articulo, a.nombre, c.nombre AS categoria, a.cantidad_total, a.precio_dia,
               fn_disponible(a.id_articulo, r.fecha_inicio, r.fecha_fin, r.id_reservacion) AS disponible
          FROM reservacion r
          CROSS JOIN articulo a
          JOIN categoria c ON c.id_categoria = a.id_categoria
         WHERE r.id_reservacion = @idReservacion AND a.activo = 1
         ORDER BY c.nombre, a.nombre", new { idReservacion });

    // ------------------------ Operaciones de negocio ----------------------
    /// <summary>Crea la reservación y sus artículos en una sola transacción (sp_crear_reservacion).</summary>
    public async Task<int> CrearAsync(int idCliente, DateTime inicio, DateTime fin, string lugar,
                                      IEnumerable<RenglonReservacion> renglones)
    {
        var p = new DynamicParameters();
        p.Add("p_id_cliente", idCliente);
        p.Add("p_fecha_inicio", inicio.Date);
        p.Add("p_fecha_fin", fin.Date);
        p.Add("p_lugar", lugar);
        p.Add("p_detalles", JsonSerializer.Serialize(renglones, Json));
        p.Add("p_id_reservacion", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await db.EjecutarAsync("sp_crear_reservacion", p, CommandType.StoredProcedure);
        return p.Get<int>("p_id_reservacion");
    }

    public async Task<int> RegistrarEntregaAsync(int idReservacion, int idEmpleado, string? observaciones)
    {
        var p = new DynamicParameters();
        p.Add("p_id_reservacion", idReservacion);
        p.Add("p_id_empleado", idEmpleado);
        p.Add("p_observaciones", observaciones);
        p.Add("p_id_entrega", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await db.EjecutarAsync("sp_registrar_entrega", p, CommandType.StoredProcedure);
        return p.Get<int>("p_id_entrega");
    }

    public async Task<int> RegistrarDevolucionAsync(int idReservacion, int idEmpleado, string? observaciones,
                                                    IEnumerable<RenglonDevolucion> renglones)
    {
        var p = new DynamicParameters();
        p.Add("p_id_reservacion", idReservacion);
        p.Add("p_id_empleado", idEmpleado);
        p.Add("p_observaciones", observaciones);
        p.Add("p_detalles", JsonSerializer.Serialize(renglones, Json));
        p.Add("p_id_devolucion", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await db.EjecutarAsync("sp_registrar_devolucion", p, CommandType.StoredProcedure);
        return p.Get<int>("p_id_devolucion");
    }

    public Task<int> CancelarAsync(int idReservacion) =>
        db.EjecutarAsync("sp_cancelar_reservacion", new { p_id_reservacion = idReservacion }, CommandType.StoredProcedure);

    // ------------------- Edición de una reservación Confirmada -------------
    // trg_reservacion_bu revalida RN-03/RN-05/RN-14 si cambian las fechas.
    public Task<int> ActualizarEncabezadoAsync(int id, int idCliente, DateTime inicio, DateTime fin, string lugar) =>
        db.EjecutarAsync(@"
            UPDATE reservacion
               SET id_cliente = @idCliente, fecha_inicio = @inicio, fecha_fin = @fin, lugar_evento = @lugar
             WHERE id_reservacion = @id",
            new { id, idCliente, inicio = inicio.Date, fin = fin.Date, lugar = lugar.Trim() });

    // precio_unitario = NULL: lo copia el trigger trg_detres_bi (RN-07)
    public Task<int> AgregarArticuloAsync(int id, int idArticulo, int cantidad) => db.EjecutarAsync(@"
        INSERT INTO detalle_reservacion (id_reservacion, id_articulo, cantidad, precio_unitario)
        VALUES (@id, @idArticulo, @cantidad, NULL)", new { id, idArticulo, cantidad });

    public Task<int> CambiarCantidadAsync(int id, int idArticulo, int cantidad) => db.EjecutarAsync(@"
        UPDATE detalle_reservacion SET cantidad = @cantidad
         WHERE id_reservacion = @id AND id_articulo = @idArticulo", new { id, idArticulo, cantidad });

    // trg_detres_bd impide dejar la reservación sin artículos (RN-04)
    public Task<int> QuitarArticuloAsync(int id, int idArticulo) => db.EjecutarAsync(
        "DELETE FROM detalle_reservacion WHERE id_reservacion = @id AND id_articulo = @idArticulo", new { id, idArticulo });

    // trg_reservacion_bd: solo se eliminan las Canceladas
    public Task<int> EliminarAsync(int id) =>
        db.EjecutarAsync("DELETE FROM reservacion WHERE id_reservacion = @id", new { id });
}
