# =====================================================================
#  Sube la parte de un integrante al repositorio con commits propios.
#
#  Uso (desde la carpeta del repositorio clonado):
#     .\docs\colaboracion\subir_parte.ps1 -Integrante josselyn -Origen C:\ruta\Equipo_Florecitas_ProyectoFinal_BD
#  Integrante: josselyn | veronica | mauro
#  Origen:     carpeta con el proyecto completo (la que comparte Mauro en .zip)
#
#  Que hace:
#    1. Actualiza main y crea tu rama (parte-...).
#    2. Copia tus archivos desde -Origen y hace un commit por cada paso del
#       plan (docs/colaboracion/plan_commits.json) con TU usuario de Git.
#    3. Sube la rama y abre el Pull Request (si tienes GitHub CLI "gh").
#  Usa -SinSubir para solo hacer los commits locales y revisarlos antes.
#  (Archivo en ASCII a proposito: Windows PowerShell 5.1 lee los .ps1 sin BOM como ANSI.)
# =====================================================================
param(
    [Parameter(Mandatory = $true)][ValidateSet("josselyn", "veronica", "mauro")][string]$Integrante,
    [Parameter(Mandatory = $true)][string]$Origen,
    [switch]$SinSubir
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') fallo" }
}

$repo = (& git rev-parse --show-toplevel 2>$null)
if (-not $repo) { throw "Ejecuta este script dentro de la carpeta del repositorio clonado." }
$repo = $repo -replace "/", "\"
$Origen = (Resolve-Path $Origen).Path
if (-not (Test-Path (Join-Path $Origen "Sql\01_esquema.sql"))) { throw "La carpeta -Origen no parece ser el proyecto completo." }

$nombreGit = (& git config user.name)
$correoGit = (& git config user.email)
if (-not $nombreGit -or -not $correoGit) {
    throw "Configura tu identidad primero:  git config --global user.name ""Tu Nombre""  y  git config --global user.email ""tu-correo-de-github"""
}

$planTexto = [IO.File]::ReadAllText((Join-Path $repo "docs\colaboracion\plan_commits.json"), [Text.Encoding]::UTF8)
$plan = ($planTexto | ConvertFrom-Json).$Integrante
Write-Host "Integrante: $($plan.nombre)  |  Git: $nombreGit <$correoGit>  |  Rama: $($plan.rama)" -ForegroundColor Magenta

Push-Location $repo
try {
    $cambios = (& git status --porcelain)
    if ($cambios) { throw "Tienes cambios sin guardar en el repositorio. Haz commit o descartalos antes." }

    Invoke-Git checkout main
    Invoke-Git pull --ff-only origin main
    $existe = (& git branch --list $plan.rama)
    if ($existe) { Invoke-Git checkout $plan.rama } else { Invoke-Git checkout -b $plan.rama }

    $utf8 = New-Object Text.UTF8Encoding $false
    $n = 0
    foreach ($c in $plan.commits) {
        foreach ($r in $c.rutas) {
            $src = Join-Path $Origen ($r -replace "/", "\")
            $dst = Join-Path $repo ($r -replace "/", "\")
            if (-not (Test-Path $src)) { throw "No existe en el origen: $r" }
            if ((Get-Item $src).PSIsContainer) {
                New-Item -ItemType Directory -Force $dst | Out-Null
                Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
            } else {
                New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
                Copy-Item -Path $src -Destination $dst -Force
            }
            Invoke-Git add -- $r
        }
        & git diff --cached --quiet
        if ($LASTEXITCODE -eq 0) { Write-Host "  (sin cambios) $($c.mensaje)"; continue }
        $tmp = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($tmp, $c.mensaje, $utf8)
        Invoke-Git commit -q -F $tmp
        Remove-Item $tmp
        $n++
        Write-Host "  commit $n : $($c.mensaje)" -ForegroundColor Green
    }

    if ($SinSubir) {
        Write-Host "Commits listos en la rama $($plan.rama). Revisa con 'git log --oneline' y sube con: git push -u origin $($plan.rama)"
        return
    }

    Invoke-Git push -u origin $plan.rama
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        & gh pr create --base main --head $plan.rama --title $plan.titulo_pr --body "Parte de $($plan.nombre). Ver docs/COLABORACION.md."
        Write-Host "Pull Request creado. Avisa al equipo para revisarlo y hacer merge." -ForegroundColor Green
    } else {
        Write-Host "Rama subida. Abre el Pull Request en GitHub: pestana 'Pull requests' -> 'New pull request' -> base: main, compare: $($plan.rama)"
    }
}
finally {
    Pop-Location
}
