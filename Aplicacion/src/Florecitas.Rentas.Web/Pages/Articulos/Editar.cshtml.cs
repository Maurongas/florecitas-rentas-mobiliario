using System.ComponentModel.DataAnnotations;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Articulos;

public class ArticuloForm
{
    public int IdArticulo { get; set; }

    [Required(ErrorMessage = "Selecciona una categoría."), Display(Name = "Categoría")]
    public int? IdCategoria { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(80, MinimumLength = 3, ErrorMessage = "Entre 3 y 80 caracteres."), Display(Name = "Nombre del modelo")]
    public string Nombre { get; set; } = "";

    [StringLength(200, ErrorMessage = "Máximo 200 caracteres."), Display(Name = "Descripción")]
    public string? Descripcion { get; set; }

    [Required(ErrorMessage = "Indica cuántas piezas hay."), Range(0, 100000, ErrorMessage = "Entre 0 y 100,000 piezas."), Display(Name = "Cantidad total")]
    public int? CantidadTotal { get; set; }

    [Required(ErrorMessage = "Indica el precio por día."), Range(0.01, 1000000, ErrorMessage = "El precio debe ser mayor que cero."), Display(Name = "Precio por día")]
    public decimal? PrecioDia { get; set; }

    [Display(Name = "Disponible para renta")]
    public bool Activo { get; set; } = true;
}

public class EditarModel(CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty] public ArticuloForm Form { get; set; } = new();
    public IReadOnlyList<Categoria> Categorias { get; private set; } = [];
    public IReadOnlyList<HistorialPrecio> Precios { get; private set; } = [];
    public bool EsNuevo => Form.IdArticulo == 0;

    public async Task<IActionResult> OnGetAsync(int? id)
    {
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        if (id is null || SinConexion) return Page();
        var a = await catalogo.ArticuloAsync(id.Value);
        if (a is null) return NotFound();
        Form = new ArticuloForm
        {
            IdArticulo = a.IdArticulo, IdCategoria = a.IdCategoria, Nombre = a.Nombre, Descripcion = a.Descripcion,
            CantidadTotal = a.CantidadTotal, PrecioDia = a.PrecioDia, Activo = a.Activo
        };
        Precios = await catalogo.HistorialPreciosAsync(a.IdArticulo);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (ModelState.IsValid)
        {
            var a = new Articulo
            {
                IdArticulo = Form.IdArticulo, IdCategoria = Form.IdCategoria!.Value, Nombre = Form.Nombre.Trim(),
                Descripcion = string.IsNullOrWhiteSpace(Form.Descripcion) ? null : Form.Descripcion.Trim(),
                CantidadTotal = Form.CantidadTotal!.Value, PrecioDia = Math.Round(Form.PrecioDia!.Value, 2), Activo = Form.Activo
            };
            var nuevo = EsNuevo;
            if (await IntentarAsync(async () =>
                {
                    if (nuevo) await catalogo.CrearArticuloAsync(a);
                    else await catalogo.ActualizarArticuloAsync(a);
                }, nuevo ? $"Artículo “{a.Nombre}” agregado al catálogo." : "Artículo actualizado. Las reservaciones ya hechas conservan su precio (RN-07)."))
                return RedirectToPage("Index");
        }
        Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
        if (!EsNuevo) Precios = await CargarAsync(() => catalogo.HistorialPreciosAsync(Form.IdArticulo)) ?? [];
        return Page();
    }
}
