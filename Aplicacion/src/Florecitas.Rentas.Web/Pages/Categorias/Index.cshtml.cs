using System.ComponentModel.DataAnnotations;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Categorias;

public class CategoriaForm
{
    public int IdCategoria { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(40, MinimumLength = 3, ErrorMessage = "Entre 3 y 40 caracteres."), Display(Name = "Nombre")]
    public string Nombre { get; set; } = "";

    [StringLength(150, ErrorMessage = "Máximo 150 caracteres."), Display(Name = "Descripción")]
    public string? Descripcion { get; set; }
}

/// <summary>CRUD completo de CATEGORIA en una sola página (solo Administrador).</summary>
public class IndexModel(CatalogoRepositorio catalogo) : PaginaBase
{
    public IReadOnlyList<Categoria> Categorias { get; private set; } = [];
    [BindProperty] public CategoriaForm Form { get; set; } = new();
    public bool Editando => Form.IdCategoria > 0;

    public async Task OnGetAsync(int? editar)
    {
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        if (editar is int id && Categorias.FirstOrDefault(c => c.IdCategoria == id) is { } c)
            Form = new CategoriaForm { IdCategoria = c.IdCategoria, Nombre = c.Nombre, Descripcion = c.Descripcion };
    }

    public async Task<IActionResult> OnPostGuardarAsync()
    {
        if (ModelState.IsValid)
        {
            var c = new Categoria
            {
                IdCategoria = Form.IdCategoria, Nombre = Form.Nombre.Trim(),
                Descripcion = string.IsNullOrWhiteSpace(Form.Descripcion) ? null : Form.Descripcion.Trim()
            };
            var editando = Editando;
            if (await IntentarAsync(async () =>
                {
                    if (editando) await catalogo.ActualizarCategoriaAsync(c);
                    else await catalogo.CrearCategoriaAsync(c);
                }, editando ? "Categoría actualizada." : $"Categoría “{c.Nombre}” creada."))
                return RedirectToPage();
        }
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        return Page();
    }

    public Task<IActionResult> OnPostEliminarAsync(int id) =>
        AccionYRedirigirAsync(() => catalogo.EliminarCategoriaAsync(id), "Categoría eliminada.", () => RedirectToPage());
}
