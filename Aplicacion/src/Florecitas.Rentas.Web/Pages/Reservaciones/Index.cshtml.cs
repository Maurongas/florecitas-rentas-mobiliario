using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Reservaciones;

public class IndexModel(ReservacionRepositorio reservaciones) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public FiltroReservaciones Filtro { get; set; } = new();

    // Permite /Reservaciones?Estado=Confirmada y ?Buscar=texto (búsqueda global)
    [BindProperty(SupportsGet = true)] public string? Estado { get; set; }
    [BindProperty(SupportsGet = true)] public string? Buscar { get; set; }
    [BindProperty(SupportsGet = true)] public int Pagina { get; set; } = 1;

    public Pagina<ReservacionResumen> Resultado { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Filtro.Estado ??= Estado;
        Filtro.Buscar ??= Buscar;
        Filtro.Pagina = Pagina;
        if (Filtro.Desde.HasValue && Filtro.Hasta.HasValue && Filtro.Hasta < Filtro.Desde)
        {
            ModelState.AddModelError(string.Empty, "La fecha 'hasta' no puede ser anterior a 'desde'.");
            return;
        }
        Resultado = await CargarAsync(() => reservaciones.BuscarAsync(Filtro)) ?? new();
    }

    public bool HayFiltros => !string.IsNullOrWhiteSpace(Filtro.Buscar) || !string.IsNullOrWhiteSpace(Filtro.Estado)
                              || Filtro.Desde.HasValue || Filtro.Hasta.HasValue;
}
