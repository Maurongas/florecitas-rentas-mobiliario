using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Articulos;

public class IndexModel(CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public string? Buscar { get; set; }
    [BindProperty(SupportsGet = true)] public int? IdCategoria { get; set; }
    [BindProperty(SupportsGet = true)] public bool Inactivos { get; set; }

    public IReadOnlyList<Articulo> Articulos { get; private set; } = [];
    public IReadOnlyList<Categoria> Categorias { get; private set; } = [];
    public bool PuedeEditar => EsAdministrador;

    public async Task OnGetAsync()
    {
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        if (!SinConexion) Articulos = await CargarAsync(() => catalogo.ArticulosAsync(Buscar, IdCategoria, Inactivos)) ?? [];
    }

    private IActionResult Volver() => RedirectToPage(new { Buscar, IdCategoria, Inactivos });

    // RN-11 / RN-13: baja lógica solo por el Administrador
    public Task<IActionResult> OnPostActivoAsync(int id, bool activo)
    {
        if (!EsAdministrador) return Task.FromResult<IActionResult>(Forbid());
        return AccionYRedirigirAsync(() => catalogo.CambiarActivoArticuloAsync(id, activo),
            activo ? "Artículo reactivado." : "Artículo dado de baja; ya no aparecerá para nuevas reservaciones.", Volver);
    }

    public Task<IActionResult> OnPostEliminarAsync(int id)
    {
        if (!EsAdministrador) return Task.FromResult<IActionResult>(Forbid());
        return AccionYRedirigirAsync(() => catalogo.EliminarArticuloAsync(id), "Artículo eliminado.", Volver);
    }
}
