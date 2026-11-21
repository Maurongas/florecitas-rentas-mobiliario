using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Empleados;

public class IndexModel(EmpleadoRepositorio empleados) : PaginaBase
{
    public IReadOnlyList<Empleado> Empleados { get; private set; } = [];

    public async Task OnGetAsync() => Empleados = await CargarAsync(empleados.TodosAsync) ?? [];

    // Empleados con entregas/devoluciones no se borran (FK RESTRICT): se desactivan
    public Task<IActionResult> OnPostEliminarAsync(int id)
    {
        if (id == IdEmpleado)
        {
            MensajeError = "No puedes eliminar tu propia cuenta.";
            return Task.FromResult<IActionResult>(RedirectToPage());
        }
        return AccionYRedirigirAsync(() => empleados.EliminarAsync(id), "Empleado eliminado.", () => RedirectToPage());
    }
}
