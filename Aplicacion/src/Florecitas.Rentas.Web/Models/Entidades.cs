namespace Florecitas.Rentas.Web.Models;

// Clases que reflejan las tablas y vistas de rentas_mobiliario.
// Dapper mapea snake_case (fecha_inicio) a PascalCase (FechaInicio).

public static class Estados
{
    public const string Confirmada = "Confirmada";
    public const string Entregada = "Entregada";
    public const string Finalizada = "Finalizada";
    public const string Cancelada = "Cancelada";
    public static readonly string[] Todos = [Confirmada, Entregada, Finalizada, Cancelada];
}

public static class Roles
{
    public const string Administrador = "Administrador";
    public const string Encargado = "Encargado";
}

public class Categoria
{
    public int IdCategoria { get; set; }
    public string Nombre { get; set; } = "";
    public string? Descripcion { get; set; }
    public int Articulos { get; set; }
}

public class Articulo
{
    public int IdArticulo { get; set; }
    public int IdCategoria { get; set; }
    public string Categoria { get; set; } = "";
    public string Nombre { get; set; } = "";
    public string? Descripcion { get; set; }
    public int CantidadTotal { get; set; }
    public decimal PrecioDia { get; set; }
    public bool Activo { get; set; }
    public int VecesRentado { get; set; }
    public int DisponibleHoy { get; set; }
}

public class Cliente
{
    public int IdCliente { get; set; }
    public string Nombre { get; set; } = "";
    public string Apellidos { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string Correo { get; set; } = "";
    public string? Direccion { get; set; }
    public int Reservaciones { get; set; }
    public decimal GastoTotal { get; set; }
    public string NombreCompleto => $"{Nombre} {Apellidos}";
}

public class Empleado
{
    public int IdEmpleado { get; set; }
    public string Nombre { get; set; } = "";
    public string Usuario { get; set; } = "";
    public string ContrasenaHash { get; set; } = "";
    public string Rol { get; set; } = Roles.Encargado;
    public bool Activo { get; set; }
    public int Entregas { get; set; }
    public int Devoluciones { get; set; }
}

/// <summary>Fila de la vista vw_reservacion_resumen.</summary>
public class ReservacionResumen
{
    public int IdReservacion { get; set; }
    public int IdCliente { get; set; }
    public string Cliente { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string Correo { get; set; } = "";
    public DateTime FechaRegistro { get; set; }
    public DateTime FechaInicio { get; set; }
    public DateTime FechaFin { get; set; }
    public int Dias { get; set; }
    public string LugarEvento { get; set; } = "";
    public string Estado { get; set; } = "";
    public int Articulos { get; set; }
    public int Piezas { get; set; }
    public decimal Total { get; set; }
    public DateTime? FechaEntrega { get; set; }
    public DateTime? FechaDevolucion { get; set; }
}

public class DetalleReservacion
{
    public int IdArticulo { get; set; }
    public string Articulo { get; set; } = "";
    public string Categoria { get; set; } = "";
    public int Cantidad { get; set; }
    public decimal PrecioUnitario { get; set; }
    public decimal PrecioActual { get; set; }
    public decimal Subtotal { get; set; }
}

public class MovimientoInfo
{
    public int Id { get; set; }
    public DateTime FechaHora { get; set; }
    public string Empleado { get; set; } = "";
    public string? Observaciones { get; set; }
}

public class DetalleDevolucion
{
    public int IdArticulo { get; set; }
    public string Articulo { get; set; } = "";
    public int Rentadas { get; set; }
    public int Devueltas { get; set; }
    public int Danadas { get; set; }
    public int Faltantes => Rentadas - Devueltas - Danadas;
}

public class Disponibilidad
{
    public int IdArticulo { get; set; }
    public string Nombre { get; set; } = "";
    public string Categoria { get; set; } = "";
    public int CantidadTotal { get; set; }
    public decimal PrecioDia { get; set; }
    public int Disponible { get; set; }
    public int PorcentajeLibre => CantidadTotal == 0 ? 0 : (int)Math.Round(100.0 * Math.Max(Disponible, 0) / CantidadTotal);
}

public class AgendaItem
{
    public int IdReservacion { get; set; }
    public string Pendiente { get; set; } = "";
    public DateTime FechaCompromiso { get; set; }
    public int DiasRestantes { get; set; }
    public string Cliente { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string LugarEvento { get; set; } = "";
}

public class BitacoraItem
{
    public long IdBitacora { get; set; }
    public string Tabla { get; set; } = "";
    public int IdRegistro { get; set; }
    public string Accion { get; set; } = "";
    public string? Detalle { get; set; }
    public string? Empleado { get; set; }
    public string UsuarioBd { get; set; } = "";
    public DateTime Fecha { get; set; }
}

public class HistorialPrecio
{
    public string Articulo { get; set; } = "";
    public decimal PrecioAnterior { get; set; }
    public decimal PrecioNuevo { get; set; }
    public DateTime FechaCambio { get; set; }
    public string? Empleado { get; set; }
}

public class IngresoMensual
{
    public string Mes { get; set; } = "";
    public int Rentas { get; set; }
    public int Piezas { get; set; }
    public decimal Ingresos { get; set; }
    public decimal TicketPromedio { get; set; }
}

public class ArticuloDesempeno
{
    public int IdArticulo { get; set; }
    public string Articulo { get; set; } = "";
    public string Categoria { get; set; } = "";
    public int CantidadTotal { get; set; }
    public decimal PrecioDia { get; set; }
    public bool Activo { get; set; }
    public int VecesRentado { get; set; }
    public int PiezasRentadas { get; set; }
    public decimal IngresoGenerado { get; set; }
}

public class FaltanteDano
{
    public int IdDevolucion { get; set; }
    public int IdReservacion { get; set; }
    public DateTime FechaDevolucion { get; set; }
    public string Cliente { get; set; } = "";
    public string Articulo { get; set; } = "";
    public int Rentadas { get; set; }
    public int Devueltas { get; set; }
    public int Danadas { get; set; }
    public int Faltantes { get; set; }
    public string Recibio { get; set; } = "";
}

public class ClienteFrecuente
{
    public int IdCliente { get; set; }
    public string Cliente { get; set; } = "";
    public int Reservaciones { get; set; }
    public decimal GastoTotal { get; set; }
    public DateTime UltimaRenta { get; set; }
}

public class Indicadores
{
    public int Confirmadas { get; set; }
    public int EnCurso { get; set; }
    public int DevolucionesAtrasadas { get; set; }
    public int EntregasProximos7 { get; set; }
    public decimal IngresosMes { get; set; }
    public decimal IngresosComprometidos { get; set; }
    public int ClientesActivos { get; set; }
    public int PiezasFueraHoy { get; set; }
}

public class Pagina<T>
{
    public IReadOnlyList<T> Elementos { get; init; } = [];
    public int Total { get; init; }
    public int NumeroPagina { get; init; }
    public int TamanoPagina { get; init; }
    public int TotalPaginas => TamanoPagina == 0 ? 0 : (int)Math.Ceiling(Total / (double)TamanoPagina);
}
