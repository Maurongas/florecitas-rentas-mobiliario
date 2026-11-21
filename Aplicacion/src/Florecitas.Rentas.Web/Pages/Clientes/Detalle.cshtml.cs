using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Clientes;

public class DetalleModel(ClienteRepositorio clientes) : PaginaBase
{
    public Cliente C { get; private set; } = new();
    public IReadOnlyList<ReservacionResumen> Historial { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var c = await CargarAsync(() => clientes.ObtenerAsync(id));
        if (c is null) return SinConexion ? Page() : NotFound();
        C = c;
        Historial = await clientes.HistorialAsync(id);
        return Page();
    }

    public async Task<IActionResult> OnPostEliminarAsync(int id)
    {
        try
        {
            await clientes.EliminarAsync(id);
            MensajeOk = "Cliente eliminado.";
            return RedirectToPage("Index");
        }
        catch (MySqlConnector.MySqlException ex)
        {
            MensajeError = ErroresBd.Traducir(ex);
            return RedirectToPage(new { id });
        }
    }
}
