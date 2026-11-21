using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Florecitas.Rentas.Web.Pages;

[ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
[IgnoreAntiforgeryToken]
public class ErrorModel : PageModel
{
    public string? RequestId { get; set; }
    public int Codigo { get; set; }

    public void OnGet(int? codigo)
    {
        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier;
        Codigo = codigo ?? 500;
    }
}
