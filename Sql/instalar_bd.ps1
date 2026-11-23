# =====================================================================
#  Instala la base de datos rentas_mobiliario desde cero (Windows / PowerShell)
#  Uso:
#     .\instalar_bd.ps1                        # localhost:3306, usuario root (pide la clave)
#     .\instalar_bd.ps1 -Puerto 3307 -Pruebas  # ademas ejecuta 05_pruebas.sql
#  ADVERTENCIA: borra y vuelve a crear la base rentas_mobiliario.
# =====================================================================
param(
    [string]$Servidor = "localhost",
    [int]$Puerto = 3306,
    [string]$Usuario = "root",
    [string]$Mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
    [switch]$Pruebas
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Mysql)) { throw "No se encontro mysql.exe en '$Mysql'. Use -Mysql para indicar la ruta." }

$clave = Read-Host "Clave de MySQL para $Usuario (Enter si no tiene)" -AsSecureString
$plano = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clave))
$env:MYSQL_PWD = $plano   # evita escribir la clave en la linea de comandos

$scripts = @("01_esquema.sql", "02_rutinas.sql", "03_datos.sql", "04_consultas_vistas.sql", "06_seguridad_respaldo.sql")
if ($Pruebas) { $scripts += "05_pruebas.sql" }

try {
    foreach ($s in $scripts) {
        Write-Host "Ejecutando $s ..." -ForegroundColor Magenta
        $ruta = Join-Path $PSScriptRoot $s
        # Redireccion de cmd: envia el archivo tal cual (UTF-8) sin recodificarlo
        & cmd.exe /c "`"$Mysql`" -h $Servidor -P $Puerto -u $Usuario --default-character-set=utf8mb4 -t < `"$ruta`""
        if ($LASTEXITCODE -ne 0) { throw "Fallo $s" }
    }
    Write-Host "Base de datos instalada correctamente." -ForegroundColor Green
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
