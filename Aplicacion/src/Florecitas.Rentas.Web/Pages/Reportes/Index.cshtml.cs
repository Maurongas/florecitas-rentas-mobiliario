using System.Globalization;
using System.Text;
using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace Florecitas.Rentas.Web.Pages.Reportes;

/// <summary>
/// Módulo de reportes: consultas multitabla y vistas (vw_reservacion_resumen,
/// vw_articulo_desempeno, vw_faltantes_danos) con filtros y exportación CSV.
/// </summary>
public class IndexModel(ReporteRepositorio reportes, CatalogoRepositorio catalogo) : PaginaBase
{
    [BindProperty(SupportsGet = true)] public string Tab { get; set; } = "ingresos";
    [BindProperty(SupportsGet = true)] public DateTime? Desde { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? Hasta { get; set; }
    [BindProperty(SupportsGet = true)] public int? IdCategoria { get; set; }
    [BindProperty(SupportsGet = true)] public int Minimo { get; set; } = 2;

    public IReadOnlyList<IngresoMensual> Ingresos { get; private set; } = [];
    public IReadOnlyList<ArticuloDesempeno> Articulos { get; private set; } = [];
    public IReadOnlyList<FaltanteDano> Faltantes { get; private set; } = [];
    public IReadOnlyList<ClienteFrecuente> Frecuentes { get; private set; } = [];
    public IReadOnlyList<Categoria> Categorias { get; private set; } = [];

    public async Task OnGetAsync()
    {
        if (Desde.HasValue && Hasta.HasValue && Hasta < Desde)
        {
            ModelState.AddModelError(string.Empty, "La fecha 'hasta' no puede ser anterior a 'desde'.");
            return;
        }
        Minimo = Math.Clamp(Minimo, 1, 50);
        switch (Tab)
        {
            case "articulos":
                Categorias = await CargarAsync(catalogo.CategoriasAsync) ?? [];
                Articulos = await CargarAsync(() => reportes.DesempenoArticulosAsync(IdCategoria)) ?? [];
                break;
            case "faltantes":
                Faltantes = await CargarAsync(() => reportes.FaltantesDanosAsync(Desde, Hasta)) ?? [];
                break;
            case "clientes":
                Frecuentes = await CargarAsync(() => reportes.ClientesFrecuentesAsync(Minimo)) ?? [];
                break;
            default:
                Tab = "ingresos";
                Ingresos = await CargarAsync(() => reportes.IngresosMensualesAsync(Desde, Hasta)) ?? [];
                break;
        }
    }

    /// <summary>Exporta el reporte activo a CSV (abre en Excel).</summary>
    public async Task<IActionResult> OnGetCsvAsync()
    {
        await OnGetAsync();
        if (!ModelState.IsValid) return Page();

        var inv = CultureInfo.InvariantCulture;
        var sb = new StringBuilder();
        static string Q(string s) => "\"" + s.Replace("\"", "\"\"") + "\"";
        switch (Tab)
        {
            case "articulos":
                sb.AppendLine("Articulo,Categoria,Total,PrecioDia,VecesRentado,PiezasRentadas,IngresoGenerado");
                foreach (var a in Articulos)
                    sb.AppendLine(string.Join(",", Q(a.Articulo), Q(a.Categoria), a.CantidadTotal, a.PrecioDia.ToString(inv), a.VecesRentado, a.PiezasRentadas, a.IngresoGenerado.ToString(inv)));
                break;
            case "faltantes":
                sb.AppendLine("Devolucion,Reservacion,Fecha,Cliente,Articulo,Rentadas,Devueltas,Danadas,Faltantes,Recibio");
                foreach (var f in Faltantes)
                    sb.AppendLine(string.Join(",", f.IdDevolucion, f.IdReservacion, f.FechaDevolucion.ToString("yyyy-MM-dd HH:mm"), Q(f.Cliente), Q(f.Articulo), f.Rentadas, f.Devueltas, f.Danadas, f.Faltantes, Q(f.Recibio)));
                break;
            case "clientes":
                sb.AppendLine("Cliente,Reservaciones,GastoTotal,UltimaRenta");
                foreach (var c in Frecuentes)
                    sb.AppendLine(string.Join(",", Q(c.Cliente), c.Reservaciones, c.GastoTotal.ToString(inv), c.UltimaRenta.ToString("yyyy-MM-dd")));
                break;
            default:
                sb.AppendLine("Mes,Rentas,Piezas,Ingresos,TicketPromedio");
                foreach (var i in Ingresos)
                    sb.AppendLine(string.Join(",", i.Mes, i.Rentas, i.Piezas, i.Ingresos.ToString(inv), i.TicketPromedio.ToString(inv)));
                break;
        }
        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
        return File(bytes, "text/csv", $"reporte_{Tab}_{DateTime.Today:yyyyMMdd}.csv");
    }
}
