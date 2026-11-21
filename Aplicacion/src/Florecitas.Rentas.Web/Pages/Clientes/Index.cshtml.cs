using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Clientes;

public class IndexModel(ClienteRepositorio clientes) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public string? Buscar { get; set; }
    [BindProperty(SupportsGet = true)] public int Pagina { get; set; } = 1;
    public Pagina<Cliente> Resultado { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Resultado = await CargarAsync(() => clientes.BuscarAsync(Buscar, Pagina)) ?? new();
    }

    // RN-11: un cliente con reservaciones no se borra (FK ON DELETE RESTRICT)
    public Task<IActionResult> OnPostEliminarAsync(int id) =>
        AccionYRedirigirAsync(() => clientes.EliminarAsync(id), "Cliente eliminado.",
            () => RedirectToPage(new { Buscar, Pagina }));
}
