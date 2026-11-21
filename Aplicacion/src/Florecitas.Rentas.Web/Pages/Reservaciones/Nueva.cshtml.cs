using System.ComponentModel.DataAnnotations;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Reservaciones;

public class RenglonEntrada
{
    public int? IdArticulo { get; set; }
    public int? Cantidad { get; set; }
}

public class NuevaModel(ReservacionRepositorio reservaciones, ClienteRepositorio clientes, CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty, Required(ErrorMessage = "Selecciona el cliente."), Display(Name = "Cliente")]
    public int? IdCliente { get; set; }

    [BindProperty, Required(ErrorMessage = "Indica la fecha de inicio."), DataType(DataType.Date), Display(Name = "Fecha de inicio")]
    public DateTime? Inicio { get; set; }

    [BindProperty, Required(ErrorMessage = "Indica la fecha de fin."), DataType(DataType.Date), Display(Name = "Fecha de fin")]
    public DateTime? Fin { get; set; }

    [BindProperty, Required(ErrorMessage = "Escribe el lugar del evento."),
     StringLength(150, MinimumLength = 5, ErrorMessage = "El lugar debe tener entre 5 y 150 caracteres."),
     Display(Name = "Lugar del evento")]
    public string? Lugar { get; set; }

    [BindProperty] public List<RenglonEntrada> Renglones { get; set; } = [];

    public IReadOnlyList<Cliente> Clientes { get; private set; } = [];
    public IReadOnlyList<Articulo> Articulos { get; private set; } = [];

    public async Task OnGetAsync(int? idCliente, DateTime? inicio, DateTime? fin)
    {
        IdCliente = idCliente;
        Inicio = inicio ?? DateTime.Today.AddDays(7);
        Fin = fin ?? Inicio;
        Renglones = [new RenglonEntrada()];
        await CargarListasAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        // Validaciones en la aplicación (la BD vuelve a validar todo)
        var renglones = Renglones.Where(r => r.IdArticulo.HasValue || r.Cantidad.HasValue).ToList();

        if (Inicio.HasValue && Inicio.Value.Date < DateTime.Today)
            ModelState.AddModelError(nameof(Inicio), "RN-05: No se aceptan reservaciones con fecha de inicio pasada.");
        if (Inicio.HasValue && Fin.HasValue && Fin < Inicio)
            ModelState.AddModelError(nameof(Fin), "RN-05: La fecha de fin no puede ser anterior a la de inicio.");
        if (Inicio.HasValue && Fin.HasValue && (Fin.Value - Inicio.Value).Days > 30)
            ModelState.AddModelError(nameof(Fin), "RN-14: Una renta no puede durar más de 31 días.");
        if (renglones.Count == 0)
            ModelState.AddModelError(nameof(Renglones), "RN-04: Agrega al menos un artículo.");
        if (renglones.Any(r => !r.IdArticulo.HasValue || r.Cantidad is null or <= 0))
            ModelState.AddModelError(nameof(Renglones), "RN-04: Cada renglón necesita artículo y una cantidad mayor que cero.");
        if (renglones.Where(r => r.IdArticulo.HasValue).GroupBy(r => r.IdArticulo).Any(g => g.Count() > 1))
            ModelState.AddModelError(nameof(Renglones), "Un artículo aparece más de una vez; junta las cantidades en un solo renglón.");

        if (ModelState.IsValid)
        {
            var id = 0;
            var ok = await IntentarAsync(async () =>
                id = await reservaciones.CrearAsync(IdCliente!.Value, Inicio!.Value, Fin!.Value, Lugar!.Trim(),
                    renglones.Select(r => new RenglonReservacion(r.IdArticulo!.Value, r.Cantidad!.Value))));
            if (ok)
            {
                MensajeOk = $"Reservación #{id} confirmada. Las piezas quedaron apartadas.";
                return RedirectToPage("Detalle", new { id });
            }
        }

        // Se conserva todo lo capturado y se marca el error
        if (Renglones.Count == 0) Renglones.Add(new RenglonEntrada());
        await CargarListasAsync();
        return Page();
    }

    private async Task CargarListasAsync()
    {
        Clientes = await CargarAsync(clientes.TodosAsync) ?? [];
        Articulos = await CargarAsync(() => catalogo.ArticulosAsync(null, null, false)) ?? [];
    }
}
