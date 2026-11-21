using System.ComponentModel.DataAnnotations;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Florecitas.Rentas.Web.Security;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Empleados;

public class EmpleadoForm
{
    public int IdEmpleado { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(100, MinimumLength = 3), Display(Name = "Nombre completo")]
    public string Nombre { get; set; } = "";

    [Required(ErrorMessage = "El usuario es obligatorio."),
     RegularExpression(@"^[a-z0-9._]{4,30}$", ErrorMessage = "De 4 a 30 caracteres: minúsculas, números, punto o guion bajo."),
     Display(Name = "Usuario")]
    public string Usuario { get; set; } = "";

    [Required, Display(Name = "Rol")]
    public string Rol { get; set; } = Roles.Encargado;

    [Display(Name = "Activo")]
    public bool Activo { get; set; } = true;

    [DataType(DataType.Password), Display(Name = "Contraseña")]
    public string? Contrasena { get; set; }

    [DataType(DataType.Password), Display(Name = "Confirmar contraseña"), Compare(nameof(Contrasena), ErrorMessage = "Las contraseñas no coinciden.")]
    public string? Confirmar { get; set; }
}

public class EditarModel(EmpleadoRepositorio empleados) : PaginaBase
{
    [BindProperty] public EmpleadoForm Form { get; set; } = new();
    public bool EsNuevo => Form.IdEmpleado == 0;

    public async Task<IActionResult> OnGetAsync(int? id)
    {
        if (id is null) return Page();
        var e = await CargarAsync(() => empleados.ObtenerAsync(id.Value));
        if (e is null) return SinConexion ? Page() : NotFound();
        Form = new EmpleadoForm { IdEmpleado = e.IdEmpleado, Nombre = e.Nombre, Usuario = e.Usuario, Rol = e.Rol, Activo = e.Activo };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (Form.Rol is not (Roles.Administrador or Roles.Encargado))
            ModelState.AddModelError("Form.Rol", "Rol inválido.");
        if (EsNuevo || !string.IsNullOrEmpty(Form.Contrasena))
        {
            var err = Contrasenas.Validar(Form.Contrasena);
            if (err is not null) ModelState.AddModelError("Form.Contrasena", err);
        }
        if (!EsNuevo && Form.IdEmpleado == IdEmpleado && (!Form.Activo || Form.Rol != Roles.Administrador))
            ModelState.AddModelError(string.Empty, "No puedes quitarte el rol de Administrador ni desactivar tu propia cuenta.");
        if (!ModelState.IsValid) return Page();

        var e = new Empleado
        {
            IdEmpleado = Form.IdEmpleado, Nombre = Form.Nombre.Trim(), Usuario = Form.Usuario.Trim().ToLowerInvariant(),
            Rol = Form.Rol, Activo = Form.Activo,
            ContrasenaHash = string.IsNullOrEmpty(Form.Contrasena) ? "" : Contrasenas.Cifrar(Form.Contrasena)
        };
        var nuevo = EsNuevo;
        var ok = await IntentarAsync(async () =>
        {
            if (nuevo)
            {
                await empleados.CrearAsync(e);
            }
            else
            {
                await empleados.ActualizarAsync(e);
                if (e.ContrasenaHash.Length > 0) await empleados.CambiarContrasenaAsync(e.IdEmpleado, e.ContrasenaHash);
            }
        }, nuevo ? $"Empleado {e.Nombre} registrado." : "Empleado actualizado.");

        return ok ? RedirectToPage("Index") : Page();
    }
}
