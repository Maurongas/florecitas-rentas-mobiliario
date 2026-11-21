using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Bitacora;

/// <summary>Consulta de la auditoría escrita por los triggers (solo lectura).</summary>
public class IndexModel(ReporteRepositorio reportes, CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public string? Tabla { get; set; }
    [BindProperty(SupportsGet = true)] public string? Accion { get; set; }

    public IReadOnlyList<BitacoraItem> Registros { get; private set; } = [];
    public IReadOnlyList<HistorialPrecio> Precios { get; private set; } = [];

    public async Task OnGetAsync()
    {
        Registros = await CargarAsync(() => reportes.BitacoraAsync(Tabla, Accion)) ?? [];
        if (!SinConexion) Precios = await CargarAsync(() => catalogo.HistorialPreciosAsync()) ?? [];
    }
}
