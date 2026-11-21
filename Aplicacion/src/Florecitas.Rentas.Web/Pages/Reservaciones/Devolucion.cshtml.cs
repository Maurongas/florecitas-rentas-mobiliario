using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Reservaciones;

public class RenglonRevision
{
    public int IdArticulo { get; set; }
    public string Articulo { get; set; } = "";
    public int Rentadas { get; set; }
    public int Devueltas { get; set; }
    public int Danadas { get; set; }
}

public class DevolucionModel(ReservacionRepositorio reservaciones) : PaginaBase
{
    public ReservacionResumen R { get; private set; } = new();
    [BindProperty] public List<RenglonRevision> Renglones { get; set; } = [];
    [BindProperty] public string? Observaciones { get; set; }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var r = await CargarAsync(() => reservaciones.ResumenAsync(id));
        if (SinConexion) return Page();
        if (r is null) return NotFound();
        if (r.Estado != Estados.Entregada)
        {
            MensajeError = "RN-09: Solo se puede registrar la devolución de una reservación Entregada.";
            return RedirectToPage("Detalle", new { id });
        }
        R = r;
        // Por omisión se propone que todo regresó en buen estado
        Renglones = (await reservaciones.DetallesAsync(id))
            .Select(d => new RenglonRevision { IdArticulo = d.IdArticulo, Articulo = d.Articulo, Rentadas = d.Cantidad, Devueltas = d.Cantidad })
            .ToList();
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(int id)
    {
        var r = await CargarAsync(() => reservaciones.ResumenAsync(id));
        if (r is null) return SinConexion ? Page() : NotFound();
        R = r;

        // Validación en la interfaz de RN-10 (la BD la vuelve a validar en trg_detdev_bi)
        foreach (var x in Renglones)
        {
            if (x.Devueltas < 0 || x.Danadas < 0)
                ModelState.AddModelError(string.Empty, $"{x.Articulo}: las cantidades no pueden ser negativas.");
            else if (x.Devueltas + x.Danadas > x.Rentadas)
                ModelState.AddModelError(string.Empty, $"RN-10 · {x.Articulo}: devueltas ({x.Devueltas}) + dañadas ({x.Danadas}) supera lo rentado ({x.Rentadas}).");
        }
        if (!ModelState.IsValid) return Page();

        var ok = await IntentarAsync(() => reservaciones.RegistrarDevolucionAsync(id, IdEmpleado,
            string.IsNullOrWhiteSpace(Observaciones) ? null : Observaciones.Trim()[..Math.Min(200, Observaciones.Trim().Length)],
            Renglones.Select(x => new RenglonDevolucion(x.IdArticulo, x.Devueltas, x.Danadas))));
        if (!ok) return Page();

        var faltan = Renglones.Sum(x => x.Rentadas - x.Devueltas - x.Danadas);
        var danadas = Renglones.Sum(x => x.Danadas);
        MensajeOk = faltan + danadas == 0
            ? "Devolución registrada: todo regresó completo. Reservación finalizada."
            : $"Devolución registrada con {danadas} pieza(s) dañada(s) y {faltan} faltante(s). Reservación finalizada.";
        return RedirectToPage("Detalle", new { id });
    }
}
