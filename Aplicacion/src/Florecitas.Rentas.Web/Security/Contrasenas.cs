using System.Security.Cryptography;
using System.Text;

namespace Florecitas.Rentas.Web.Security;

public static class Claims
{
    public const string IdEmpleado = "id_empleado";
}

/// <summary>
/// RN-12: las contraseñas se guardan cifradas con PBKDF2-SHA256 y sal aleatoria.
/// Formato: pbkdf2-sha256$iteraciones$sal_base64$hash_base64
/// (el mismo que usa 03_datos.sql para los usuarios de prueba).
/// </summary>
public static class Contrasenas
{
    private const int Iteraciones = 100_000;
    private const int TamSal = 16;
    private const int TamHash = 32;

    public static string Cifrar(string contrasena)
    {
        var sal = RandomNumberGenerator.GetBytes(TamSal);
        var hash = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(contrasena), sal, Iteraciones,
                                             HashAlgorithmName.SHA256, TamHash);
        return $"pbkdf2-sha256${Iteraciones}${Convert.ToBase64String(sal)}${Convert.ToBase64String(hash)}";
    }

    public static bool Verificar(string contrasena, string guardado)
    {
        var partes = guardado.Split('$');
        if (partes.Length != 4 || partes[0] != "pbkdf2-sha256" || !int.TryParse(partes[1], out var iter))
            return false;
        try
        {
            var sal = Convert.FromBase64String(partes[2]);
            var esperado = Convert.FromBase64String(partes[3]);
            var calculado = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(contrasena), sal, iter,
                                                      HashAlgorithmName.SHA256, esperado.Length);
            return CryptographicOperations.FixedTimeEquals(calculado, esperado);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    /// <summary>Reglas mínimas: 8 caracteres, una letra y un número.</summary>
    public static string? Validar(string? contrasena)
    {
        if (string.IsNullOrWhiteSpace(contrasena) || contrasena.Length < 8)
            return "La contraseña debe tener al menos 8 caracteres.";
        if (!contrasena.Any(char.IsLetter) || !contrasena.Any(char.IsDigit))
            return "La contraseña debe incluir al menos una letra y un número.";
        return null;
    }
}
