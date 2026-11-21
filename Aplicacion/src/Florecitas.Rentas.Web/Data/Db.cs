using System.Data;
using Dapper;
using MySqlConnector;

namespace Florecitas.Rentas.Web.Data;

/// <summary>
/// Punto único de acceso al SGBD. Abre conexiones MySQL con la cadena de
/// conexión del servidor (nunca se envía al navegador) y fija la variable
/// de sesión @app_empleado para que los triggers registren en la bitácora
/// qué empleado hizo cada cambio.
/// </summary>
public sealed class Db
{
    private readonly string _cadena;
    private readonly IHttpContextAccessor _http;

    static Db()
    {
        // id_reservacion -> IdReservacion, fecha_inicio -> FechaInicio, etc.
        DefaultTypeMap.MatchNamesWithUnderscores = true;
    }

    public Db(IConfiguration configuracion, IHttpContextAccessor http)
    {
        _cadena = configuracion.GetConnectionString("Rentas")
                  ?? throw new InvalidOperationException("Falta la cadena de conexión 'Rentas'.");
        _http = http;
    }

    public async Task<MySqlConnection> AbrirAsync(CancellationToken ct = default)
    {
        var cn = new MySqlConnection(_cadena);
        await cn.OpenAsync(ct);

        var idEmpleado = _http.HttpContext?.User.FindFirst(Security.Claims.IdEmpleado)?.Value;
        await cn.ExecuteAsync("SET @app_empleado = @id",
            new { id = int.TryParse(idEmpleado, out var id) ? id : (int?)null });
        return cn;
    }

    public async Task<IReadOnlyList<T>> ConsultarAsync<T>(string sql, object? p = null, CommandType tipo = CommandType.Text)
    {
        await using var cn = await AbrirAsync();
        return (await cn.QueryAsync<T>(sql, p, commandType: tipo)).AsList();
    }

    public async Task<T?> UnoAsync<T>(string sql, object? p = null)
    {
        await using var cn = await AbrirAsync();
        return await cn.QueryFirstOrDefaultAsync<T>(sql, p);
    }

    public async Task<T> EscalarAsync<T>(string sql, object? p = null)
    {
        await using var cn = await AbrirAsync();
        return (await cn.ExecuteScalarAsync<T>(sql, p))!;
    }

    public async Task<int> EjecutarAsync(string sql, object? p = null, CommandType tipo = CommandType.Text)
    {
        await using var cn = await AbrirAsync();
        return await cn.ExecuteAsync(sql, p, commandType: tipo);
    }
}
