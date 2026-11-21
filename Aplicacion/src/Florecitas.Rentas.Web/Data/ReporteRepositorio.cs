using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Data;

/// <summary>Consultas de tablero, reportes y auditoría (vistas y consultas multitabla).</summary>
public sealed class ReporteRepositorio(Db db)
{
    public async Task<Indicadores> IndicadoresAsync() => (await db.UnoAsync<Indicadores>(@"
        SELECT
          (SELECT COUNT(*) FROM reservacion WHERE estado = 'Confirmada')                             AS confirmadas,
          (SELECT COUNT(*) FROM reservacion WHERE estado = 'Entregada')                              AS en_curso,
          (SELECT COUNT(*) FROM reservacion WHERE estado = 'Entregada' AND fecha_fin < CURDATE())    AS devoluciones_atrasadas,
          (SELECT COUNT(*) FROM reservacion WHERE estado = 'Confirmada'
              AND fecha_inicio BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY)                    AS entregas_proximos7,
          (SELECT COALESCE(SUM(total), 0) FROM vw_reservacion_resumen
            WHERE estado IN ('Entregada', 'Finalizada')
              AND fecha_inicio >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
              AND fecha_inicio <  DATE_FORMAT(CURDATE(), '%Y-%m-01') + INTERVAL 1 MONTH)            AS ingresos_mes,
          (SELECT COALESCE(SUM(total), 0) FROM vw_reservacion_resumen WHERE estado = 'Confirmada')  AS ingresos_comprometidos,
          (SELECT COUNT(DISTINCT id_cliente) FROM reservacion
            WHERE estado <> 'Cancelada' AND fecha_inicio >= CURDATE() - INTERVAL 90 DAY)            AS clientes_activos,
          (SELECT COALESCE(SUM(d.cantidad), 0) FROM detalle_reservacion d
             JOIN reservacion r ON r.id_reservacion = d.id_reservacion
            WHERE r.estado = 'Entregada')                                                           AS piezas_fuera_hoy"))!;

    public Task<IReadOnlyList<AgendaItem>> AgendaAsync(int dias = 14) => db.ConsultarAsync<AgendaItem>(@"
        SELECT * FROM vw_agenda_operativa
         WHERE dias_restantes <= @dias
         ORDER BY dias_restantes, id_reservacion", new { dias });

    public Task<IReadOnlyList<IngresoMensual>> IngresosMensualesAsync(DateTime? desde, DateTime? hasta) =>
        db.ConsultarAsync<IngresoMensual>(@"
            SELECT DATE_FORMAT(fecha_inicio, '%Y-%m') AS mes,
                   COUNT(*) AS rentas, SUM(piezas) AS piezas, SUM(total) AS ingresos,
                   ROUND(AVG(total), 2) AS ticket_promedio
              FROM vw_reservacion_resumen
             WHERE estado IN ('Entregada', 'Finalizada')
               AND (@desde IS NULL OR fecha_inicio >= @desde)
               AND (@hasta IS NULL OR fecha_inicio <= @hasta)
             GROUP BY DATE_FORMAT(fecha_inicio, '%Y-%m')
             ORDER BY mes", new { desde, hasta });

    public Task<IReadOnlyList<ArticuloDesempeno>> DesempenoArticulosAsync(int? idCategoria) =>
        db.ConsultarAsync<ArticuloDesempeno>(@"
            SELECT v.* FROM vw_articulo_desempeno v
              JOIN articulo a ON a.id_articulo = v.id_articulo
             WHERE @idCategoria IS NULL OR a.id_categoria = @idCategoria
             ORDER BY v.ingreso_generado DESC", new { idCategoria });

    public Task<IReadOnlyList<FaltanteDano>> FaltantesDanosAsync(DateTime? desde, DateTime? hasta) =>
        db.ConsultarAsync<FaltanteDano>(@"
            SELECT * FROM vw_faltantes_danos
             WHERE (@desde IS NULL OR fecha_devolucion >= @desde)
               AND (@hasta IS NULL OR fecha_devolucion < @hasta + INTERVAL 1 DAY)
             ORDER BY fecha_devolucion DESC", new { desde, hasta });

    public Task<IReadOnlyList<ClienteFrecuente>> ClientesFrecuentesAsync(int minimo = 2) =>
        db.ConsultarAsync<ClienteFrecuente>(@"
            SELECT c.id_cliente, CONCAT(c.nombre, ' ', c.apellidos) AS cliente,
                   COUNT(*) AS reservaciones, SUM(v.total) AS gasto_total, MAX(v.fecha_inicio) AS ultima_renta
              FROM cliente c
              JOIN vw_reservacion_resumen v ON v.id_cliente = c.id_cliente
             WHERE v.estado <> 'Cancelada'
             GROUP BY c.id_cliente, c.nombre, c.apellidos
            HAVING COUNT(*) >= @minimo
             ORDER BY reservaciones DESC, gasto_total DESC", new { minimo });

    public Task<IReadOnlyList<BitacoraItem>> BitacoraAsync(string? tabla, string? accion, int limite = 200) =>
        db.ConsultarAsync<BitacoraItem>(@"
            SELECT b.id_bitacora, b.tabla, b.id_registro, b.accion, b.detalle, e.nombre AS empleado, b.usuario_bd, b.fecha
              FROM bitacora b LEFT JOIN empleado e ON e.id_empleado = b.id_empleado
             WHERE (@tabla IS NULL OR b.tabla = @tabla)
               AND (@accion IS NULL OR b.accion = @accion)
             ORDER BY b.fecha DESC, b.id_bitacora DESC
             LIMIT @limite",
            new { tabla = string.IsNullOrWhiteSpace(tabla) ? null : tabla, accion = string.IsNullOrWhiteSpace(accion) ? null : accion, limite });
}
