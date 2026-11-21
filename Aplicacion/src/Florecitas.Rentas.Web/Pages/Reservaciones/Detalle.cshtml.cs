using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Reservaciones;

public class DetalleModel(ReservacionRepositorio reservaciones, ClienteRepositorio clientes) : PaginaBase
{
    public ReservacionResumen R { get; private set; } = new();
    public IReadOnlyList<DetalleReservacion> Detalles { get; private set; } = [];
    public MovimientoInfo? Entrega { get; private set; }
    public MovimientoInfo? Devolucion { get; private set; }
    public IReadOnlyList<DetalleDevolucion> DetallesDevolucion { get; private set; } = [];
    public IReadOnlyList<BitacoraItem> Historial { get; private set; } = [];
    public IReadOnlyList<Disponibilidad> DisponibilidadEdicion { get; private set; } = [];
    public IReadOnlyList<Cliente> Clientes { get; private set; } = [];

    public bool EsEditable => R.Estado == Estados.Confirmada;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var r = await CargarAsync(() => reservaciones.ResumenAsync(id));
        if (SinConexion) return Page();
        if (r is null) return NotFound();
        R = r;

        Detalles = await reservaciones.DetallesAsync(id);
        Entrega = await reservaciones.EntregaAsync(id);
        Devolucion = await reservaciones.DevolucionAsync(id);
        if (Devolucion is not null) DetallesDevolucion = await reservaciones.DetallesDevolucionAsync(id);
        Historial = await reservaciones.BitacoraAsync(id);
        if (EsEditable)
        {
            DisponibilidadEdicion = await reservaciones.DisponibilidadParaAsync(id);
            Clientes = await clientes.TodosAsync();
        }
        return Page();
    }

    private IActionResult Volver(int id) => RedirectToPage(new { id });

    // ------------------------------ Acciones ------------------------------
    public Task<IActionResult> OnPostEntregaAsync(int id, string? observaciones) =>
        AccionYRedirigirAsync(() => reservaciones.RegistrarEntregaAsync(id, IdEmpleado, Recortar(observaciones, 200)),
            "Entrega registrada. La reservación ahora está Entregada.", () => Volver(id));

    public Task<IActionResult> OnPostCancelarAsync(int id) =>
        AccionYRedirigirAsync(() => reservaciones.CancelarAsync(id),
            "Reservación cancelada. Las piezas se liberaron.", () => Volver(id));

    public async Task<IActionResult> OnPostEliminarAsync(int id)
    {
        try
        {
            await reservaciones.EliminarAsync(id);
            MensajeOk = $"La reservación #{id} se eliminó.";
            return RedirectToPage("Index");
        }
        catch (MySqlConnector.MySqlException ex)
        {
            MensajeError = ErroresBd.Traducir(ex);
            return Volver(id);
        }
    }

    public async Task<IActionResult> OnPostEditarAsync(int id, int idCliente, DateTime? inicio, DateTime? fin, string? lugar)
    {
        if (inicio is null || fin is null || string.IsNullOrWhiteSpace(lugar) || lugar.Trim().Length < 5)
        {
            MensajeError = "Completa fechas y un lugar de al menos 5 caracteres.";
            return Volver(id);
        }
        if (fin < inicio)
        {
            MensajeError = "RN-05: La fecha de fin no puede ser anterior a la de inicio.";
            return Volver(id);
        }
        return await AccionYRedirigirAsync(() => reservaciones.ActualizarEncabezadoAsync(id, idCliente, inicio.Value, fin.Value, Recortar(lugar, 150)!),
            "Datos de la reservación actualizados.", () => Volver(id));
    }

    public Task<IActionResult> OnPostAgregarAsync(int id, int idArticulo, int cantidad)
    {
        if (cantidad <= 0)
        {
            MensajeError = "RN-04: La cantidad debe ser mayor que cero.";
            return Task.FromResult(Volver(id));
        }
        return AccionYRedirigirAsync(() => reservaciones.AgregarArticuloAsync(id, idArticulo, cantidad),
            "Artículo agregado a la reservación.", () => Volver(id));
    }

    public Task<IActionResult> OnPostCantidadAsync(int id, int idArticulo, int cantidad)
    {
        if (cantidad <= 0)
        {
            MensajeError = "RN-04: La cantidad debe ser mayor que cero. Para quitar el artículo usa el botón de eliminar.";
            return Task.FromResult(Volver(id));
        }
        return AccionYRedirigirAsync(() => reservaciones.CambiarCantidadAsync(id, idArticulo, cantidad),
            "Cantidad actualizada.", () => Volver(id));
    }

    public Task<IActionResult> OnPostQuitarAsync(int id, int idArticulo) =>
        AccionYRedirigirAsync(() => reservaciones.QuitarArticuloAsync(id, idArticulo),
            "Artículo quitado de la reservación.", () => Volver(id));

    private static string? Recortar(string? s, int max) =>
        string.IsNullOrWhiteSpace(s) ? null : (s.Trim().Length > max ? s.Trim()[..max] : s.Trim());
}
