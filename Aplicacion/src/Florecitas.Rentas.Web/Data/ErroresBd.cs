using MySqlConnector;

namespace Florecitas.Rentas.Web.Data;

/// <summary>
/// Traduce los errores del SGBD a mensajes entendibles para el usuario.
/// Las reglas de negocio llegan como SIGNAL SQLSTATE '45000' (error 1644)
/// desde los triggers y procedimientos, y su mensaje ya viene redactado.
/// </summary>
public static class ErroresBd
{
    public static string Traducir(Exception ex) => ex switch
    {
        MySqlException m => TraducirMySql(m),
        TimeoutException => "La base de datos tardó demasiado en responder. Intente de nuevo.",
        _ => "Ocurrió un error inesperado. Intente de nuevo."
    };

    private static string TraducirMySql(MySqlException ex)
    {
        switch (ex.ErrorCode)
        {
            case MySqlErrorCode.UnableToConnectToHost:
            case MySqlErrorCode.AccessDenied:
            case MySqlErrorCode.UnknownDatabase:
                return "No se pudo conectar con la base de datos. Verifique que el servidor MySQL esté encendido y la configuración de conexión.";
        }

        return ex.Number switch
        {
            1644 => ex.Message,                                              // regla de negocio (SIGNAL 45000)
            1062 => "Ya existe un registro con ese valor " + CampoDuplicado(ex.Message) + ".",
            // 1451 lo reporta un usuario con privilegios sobre la tabla hija; 1217 es la
            // misma falla cuando el usuario de la app no puede ver el detalle de la FK
            1451 or 1217 =>"No se puede eliminar porque tiene registros relacionados (historial). Use la baja lógica si está disponible.",
            1452 or 1216 =>"El registro relacionado no existe (cliente, artículo o empleado inválido).",
            3819 => "Un dato no cumple las reglas de dominio de la base de datos (" + Restriccion(ex.Message) + ").",
            1048 => "Falta un dato obligatorio.",
            1406 => "Un texto excede la longitud permitida.",
            1213 or 1205 => "Otra operación estaba usando los mismos datos. Intente de nuevo.",
            _ => "Error de base de datos (" + ex.Number + "): " + ex.Message
        };
    }

    private static string CampoDuplicado(string msg)
    {
        if (msg.Contains("correo")) return "de correo";
        if (msg.Contains("usuario")) return "de usuario";
        if (msg.Contains("nombre")) return "de nombre";
        return "único";
    }

    private static string Restriccion(string msg)
    {
        var i = msg.IndexOf('\'');
        var j = i >= 0 ? msg.IndexOf('\'', i + 1) : -1;
        return i >= 0 && j > i ? msg[(i + 1)..j] : "CHECK";
    }

    public static bool EsDeConexion(Exception ex) =>
        ex is MySqlException m && (m.ErrorCode is MySqlErrorCode.UnableToConnectToHost
                                   or MySqlErrorCode.AccessDenied or MySqlErrorCode.UnknownDatabase);
}
