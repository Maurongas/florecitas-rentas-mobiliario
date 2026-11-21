using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Cuenta;

public class LoginModel(EmpleadoRepositorio empleados) : PaginaBase
{
    [BindProperty, Required(ErrorMessage = "Escriba su usuario."), Display(Name = "Usuario")]
    public string Usuario { get; set; } = "";

    [BindProperty, Required(ErrorMessage = "Escriba su contraseña."), DataType(DataType.Password), Display(Name = "Contraseña")]
    public string Contrasena { get; set; } = "";

    [BindProperty(SupportsGet = true)] public string? ReturnUrl { get; set; }

    public IActionResult OnGet()
    {
        if (User.Identity?.IsAuthenticated == true) return RedirectToPage("/Index");
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        Models.Empleado? emp = null;
        if (!await IntentarAsync(async () => emp = await empleados.PorUsuarioAsync(Usuario.Trim().ToLowerInvariant())))
            return Page();

        if (emp is null || !Contrasenas.Verificar(Contrasena, emp.ContrasenaHash))
        {
            ModelState.AddModelError(string.Empty, "Usuario o contraseña incorrectos.");
            return Page();
        }
        if (!emp.Activo)
        {
            ModelState.AddModelError(string.Empty, "Tu cuenta está inactiva. Consulta al administrador.");
            return Page();
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.Name, emp.Nombre),
            new(ClaimTypes.NameIdentifier, emp.Usuario),
            new(ClaimTypes.Role, emp.Rol),
            new(Claims.IdEmpleado, emp.IdEmpleado.ToString())
        };
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));

        MensajeOk = $"¡Hola, {emp.Nombre.Split(' ')[0]}!";
        return LocalRedirect(Url.IsLocalUrl(ReturnUrl) ? ReturnUrl! : "/");
    }
}
