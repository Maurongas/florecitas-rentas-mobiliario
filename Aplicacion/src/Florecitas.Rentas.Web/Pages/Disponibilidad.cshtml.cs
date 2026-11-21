using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages;

public class DisponibilidadModel(ReservacionRepositorio reservaciones, CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public DateTime? Inicio { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? Fin { get; set; }
    [BindProperty(SupportsGet = true)] public int? IdCategoria { get; set; }

    public IReadOnlyList<Disponibilidad> Resultados { get; private set; } = [];
    public IReadOnlyList<Categoria> Categorias { get; private set; } = [];
    public int Dias => Inicio.HasValue && Fin.HasValue ? (Fin.Value - Inicio.Value).Days + 1 : 0;

    public async Task OnGetAsync()
    {
        Inicio ??= DateTime.Today;
        Fin ??= Inicio;
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        if (SinConexion) return;

        if (Fin < Inicio)
        {
            ModelState.AddModelError(string.Empty, "RN-05: La fecha de fin no puede ser anterior a la fecha de inicio.");
            return;
        }
        if (Dias > 31)
        {
            ModelState.AddModelError(string.Empty, "RN-14: El rango no puede ser mayor a 31 días.");
            return;
        }
        Resultados = await CargarAsync(() => reservaciones.DisponibilidadAsync(Inicio.Value, Fin.Value, IdCategoria)) ?? [];
    }

    /// <summary>
    /// Endpoint JSON (mismo servidor, misma sesión) que usa el formulario de
    /// nueva reservación para mostrar la disponibilidad en vivo. Es solo una
    /// vista previa: la validación definitiva la hace el trigger trg_detres_bi.
    /// </summary>
    public async Task<IActionResult> OnGetJsonAsync(DateTime inicio, DateTime fin, int? excluir)
    {
        if (fin < inicio || (fin - inicio).Days > 30)
            return BadRequest(new { error = "Rango de fechas inválido (RN-05 / RN-14)." });
        try
        {
            var datos = excluir is int id
                ? await reservaciones.DisponibilidadParaAsync(id)
                : await reservaciones.DisponibilidadAsync(inicio, fin);
            return new JsonResult(datos.Select(d => new { d.IdArticulo, d.Disponible, d.PrecioDia }));
        }
        catch (MySqlConnector.MySqlException ex)
        {
            return StatusCode(503, new { error = ErroresBd.Traducir(ex) });
        }
    }
}
