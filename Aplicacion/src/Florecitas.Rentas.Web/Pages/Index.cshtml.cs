using Florecitas.Rentas.Web.Data;
using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Pages;

public class IndexModel(ReporteRepositorio reportes, ReservacionRepositorio reservaciones) : PaginaBase
{
    public Indicadores Kpi { get; private set; } = new();
    public IReadOnlyList<AgendaItem> Agenda { get; private set; } = [];
    public IReadOnlyList<IngresoMensual> Ingresos { get; private set; } = [];
    public IReadOnlyList<ArticuloDesempeno> TopArticulos { get; private set; } = [];
    public IReadOnlyList<Disponibilidad> OcupacionHoy { get; private set; } = [];

    public async Task OnGetAsync()
    {
        Kpi = await CargarAsync(reportes.IndicadoresAsync) ?? new();
        if (SinConexion) return;

        Agenda = await CargarAsync(() => reportes.AgendaAsync(14)) ?? [];
        Ingresos = await CargarAsync(() => reportes.IngresosMensualesAsync(DateTime.Today.AddMonths(-5).AddDays(1 - DateTime.Today.Day), null)) ?? [];
        TopArticulos = (await CargarAsync(() => reportes.DesempenoArticulosAsync(null)) ?? []).Take(5).ToList();
        OcupacionHoy = (await CargarAsync(() => reservaciones.DisponibilidadAsync(DateTime.Today, DateTime.Today)) ?? [])
            .OrderBy(d => d.PorcentajeLibre).Take(6).ToList();
    }
}
