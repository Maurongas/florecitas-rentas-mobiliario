using System.Globalization;
using Florecitas.Rentas.Web.Data;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Localization;

var builder = WebApplication.CreateBuilder(args);

// ----------------------------------------------------------------------
// Servicios
// ----------------------------------------------------------------------
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<Db>();
builder.Services.AddScoped<CatalogoRepositorio>();
builder.Services.AddScoped<ClienteRepositorio>();
builder.Services.AddScoped<EmpleadoRepositorio>();
builder.Services.AddScoped<ReservacionRepositorio>();
builder.Services.AddScoped<ReporteRepositorio>();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.LoginPath = "/Cuenta/Login";
        o.LogoutPath = "/Cuenta/Logout";
        o.AccessDeniedPath = "/Cuenta/AccesoDenegado";
        o.ExpireTimeSpan = TimeSpan.FromHours(8);
        o.SlidingExpiration = true;
        o.Cookie.HttpOnly = true;
        o.Cookie.SameSite = SameSiteMode.Strict;
        o.Cookie.Name = "florecitas.auth";
    });

builder.Services.AddAuthorizationBuilder()
    // RN-13: solo el Administrador modifica catálogo, precios y empleados
    .AddPolicy("SoloAdministrador", p => p.RequireRole("Administrador"))
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

builder.Services.AddRazorPages(o =>
{
    o.Conventions.AllowAnonymousToPage("/Cuenta/Login");
    o.Conventions.AllowAnonymousToPage("/Cuenta/AccesoDenegado");
    o.Conventions.AllowAnonymousToPage("/Error");
    o.Conventions.AuthorizeFolder("/Empleados", "SoloAdministrador");
    o.Conventions.AuthorizeFolder("/Categorias", "SoloAdministrador");
    o.Conventions.AuthorizeFolder("/Bitacora", "SoloAdministrador");
    o.Conventions.AuthorizePage("/Articulos/Editar", "SoloAdministrador");
});

var app = builder.Build();

// Formatos de México (moneda y fechas)
var mx = new CultureInfo("es-MX");
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(mx),
    SupportedCultures = [mx],
    SupportedUICultures = [mx]
});

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}
app.UseStatusCodePagesWithReExecute("/Error", "?codigo={0}");

app.UseHttpsRedirection();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Los archivos estáticos (CSS/JS/fuentes) se sirven sin sesión; las páginas no.
app.MapStaticAssets().AllowAnonymous();
app.MapRazorPages().WithStaticAssets();

app.Run();
