using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Florecitas.Rentas.Web.Security;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Florecitas.Rentas.Web.Pages;

/// <summary>
/// Base de todas las páginas: mensajes de confirmación/error (toasts) y
/// manejo uniforme de errores del SGBD (reglas de negocio, integridad,
/// errores de conexión).
/// </summary>
public abstract class PaginaBase : PageModel
{
    [TempData] public string? MensajeOk { get; set; }
    [TempData] public string? MensajeError { get; set; }

    /// <summary>true si la última consulta no pudo conectarse al SGBD.</summary>
    public bool SinConexion { get; protected set; }

    protected int IdEmpleado => int.TryParse(User.FindFirst(Claims.IdEmpleado)?.Value, out var id) ? id : 0;
    protected bool EsAdministrador => User.IsInRole(Roles.Administrador);

    /// <summary>
    /// Ejecuta una operación contra la BD. Si falla, coloca el mensaje
    /// traducido en ModelState (para mostrarlo junto al formulario, sin
    /// perder lo capturado) y regresa false.
    /// </summary>
    protected async Task<bool> IntentarAsync(Func<Task> accion, string? mensajeOk = null)
    {
        try
        {
            await accion();
            if (mensajeOk is not null) MensajeOk = mensajeOk;
            return true;
        }
        catch (Exception ex) when (ex is MySqlConnector.MySqlException or TimeoutException)
        {
            SinConexion = ErroresBd.EsDeConexion(ex);
            ModelState.AddModelError(string.Empty, ErroresBd.Traducir(ex));
            return false;
        }
    }

    /// <summary>Igual que IntentarAsync pero el error viaja en TempData (para redirecciones).</summary>
    protected async Task<IActionResult> AccionYRedirigirAsync(Func<Task> accion, string mensajeOk, Func<IActionResult> destino)
    {
        try
        {
            await accion();
            MensajeOk = mensajeOk;
        }
        catch (Exception ex) when (ex is MySqlConnector.MySqlException or TimeoutException)
        {
            MensajeError = ErroresBd.Traducir(ex);
        }
        return destino();
    }

    /// <summary>Carga datos de solo lectura; si no hay conexión muestra el estado de error en la página.</summary>
    protected async Task<T?> CargarAsync<T>(Func<Task<T>> consulta)
    {
        try
        {
            return await consulta();
        }
        catch (Exception ex) when (ex is MySqlConnector.MySqlException or TimeoutException)
        {
            SinConexion = ErroresBd.EsDeConexion(ex);
            ModelState.AddModelError(string.Empty, ErroresBd.Traducir(ex));
            return default;
        }
    }
}
