using System.ComponentModel.DataAnnotations;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Clientes;

public class ClienteForm
{
    public int IdCliente { get; set; }

    [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(60, MinimumLength = 2, ErrorMessage = "Entre 2 y 60 caracteres.")]
    [Display(Name = "Nombre(s)")]
    public string Nombre { get; set; } = "";

    [Required(ErrorMessage = "Los apellidos son obligatorios."), StringLength(80, MinimumLength = 2, ErrorMessage = "Entre 2 y 80 caracteres.")]
    [Display(Name = "Apellidos")]
    public string Apellidos { get; set; } = "";

    [Required(ErrorMessage = "El teléfono es obligatorio."), RegularExpression(@"^\d{10}$", ErrorMessage = "El teléfono debe tener exactamente 10 dígitos.")]
    [Display(Name = "Teléfono")]
    public string Telefono { get; set; } = "";

    [Required(ErrorMessage = "El correo es obligatorio."), EmailAddress(ErrorMessage = "Escribe un correo válido."), StringLength(100)]
    [Display(Name = "Correo electrónico")]
    public string Correo { get; set; } = "";

    [StringLength(150, ErrorMessage = "Máximo 150 caracteres."), Display(Name = "Dirección (opcional)")]
    public string? Direccion { get; set; }
}

public class EditarModel(ClienteRepositorio clientes) : PaginaBase
{
    [BindProperty] public ClienteForm Form { get; set; } = new();
    [BindProperty(SupportsGet = true)] public string? Volver { get; set; }
    public bool EsNuevo => Form.IdCliente == 0;

    public async Task<IActionResult> OnGetAsync(int? id)
    {
        if (id is null) return Page();
        var c = await CargarAsync(() => clientes.ObtenerAsync(id.Value));
        if (c is null) return SinConexion ? Page() : NotFound();
        Form = new ClienteForm { IdCliente = c.IdCliente, Nombre = c.Nombre, Apellidos = c.Apellidos, Telefono = c.Telefono, Correo = c.Correo, Direccion = c.Direccion };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid) return Page();

        var c = new Cliente
        {
            IdCliente = Form.IdCliente,
            Nombre = Form.Nombre.Trim(),
            Apellidos = Form.Apellidos.Trim(),
            Telefono = Form.Telefono.Trim(),
            Correo = Form.Correo.Trim().ToLowerInvariant(),
            Direccion = string.IsNullOrWhiteSpace(Form.Direccion) ? null : Form.Direccion.Trim()
        };
        var nuevo = EsNuevo;
        if (!await IntentarAsync(async () =>
            {
                if (nuevo) c.IdCliente = await clientes.CrearAsync(c);
                else await clientes.ActualizarAsync(c);
            }, nuevo ? $"Cliente {c.Nombre} registrado." : "Cambios guardados."))
            return Page();

        if (Volver == "reservacion") return RedirectToPage("/Reservaciones/Nueva", new { idCliente = c.IdCliente });
        return RedirectToPage("Detalle", new { id = c.IdCliente });
    }
}
