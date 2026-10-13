# promover-historicas.ps1 - cambia estado HISTORICA -> NUEVA en cola-comun.jsonl
# SOLO las que: (1) tienen fecha de cierre vigente, (2) su HTML ya existe en
# salida\ y (3) trae los marcadores Fase A (regeneradas). Las demas quedan
# congeladas hasta que se regeneren.
#
# USO:
#   .\promover-historicas.ps1                 # SIMULACION (0 escrituras)
#   .\promover-historicas.ps1 -Aplicar        # escribe la cola
#
# La promocion NO toca la publicacion: publicar-blocker re-extrae la fecha de
# cierre del HTML y marca EXPIRADA si ya vencio.

param(
    [switch]$Aplicar
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RutaCola = Join-Path $BaseDir 'datos\cola\cola-comun.jsonl'
$DirSalida = Join-Path $BaseDir 'salida'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$hoy = (Get-Date).Date

function Leer-Cierre([string]$t) {
    if (-not $t) { return $null }
    foreach ($fmt in @('dd/MM/yyyy', 'yyyy-MM-dd', 'd/M/yyyy', 'dd-MM-yyyy')) {
        try { return ([datetime]::ParseExact($t.Trim(), $fmt, [Globalization.CultureInfo]::InvariantCulture)).Date } catch { }
    }
    return $null
}

$lineas = [IO.File]::ReadAllLines($RutaCola)
$promovidas = 0; $sinFecha = 0; $vencidas = 0; $sinHtml = 0; $sinFaseA = 0

foreach ($l in $lineas) {
    if ($l.Trim() -eq '') { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if ([string]$e.estadoPublicacion -ne 'HISTORICA') { continue }
    if ([string]$e.fuente -ne 'buscojobs') { continue }

    $c = Leer-Cierre ([string]$e.fechaCierre)
    if ($null -eq $c) { $sinFecha++; continue }
    if ($c -lt $hoy) { $vencidas++; continue }

    $p = Join-Path $DirSalida ([string]$e.archivo)
    if (-not (Test-Path -LiteralPath $p)) { $sinHtml++; continue }
    $html = [IO.File]::ReadAllText($p)
    if ($html -notmatch 'empleo-datos-ocultos' -or $html -notmatch '<strong>Categor') { $sinFaseA++; continue }

    $promovidas++
}

Write-Output ("SIMULACION: promovibles = " + $promovidas)
Write-Output ("  descartadas: sin fecha=" + $sinFecha + " | vencidas=" + $vencidas + " | sin HTML=" + $sinHtml + " | sin Fase A=" + $sinFaseA)

if (-not $Aplicar) {
    Write-Output "SIMULACION (0 escrituras). Usa -Aplicar para escribir la cola."
    exit 0
}

$lineas = [IO.File]::ReadAllLines($RutaCola)
$cambio = 0
for ($i = 0; $i -lt $lineas.Count; $i++) {
    $l = $lineas[$i]
    if ($l.Trim() -eq '') { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if ([string]$e.estadoPublicacion -ne 'HISTORICA') { continue }
    if ([string]$e.fuente -ne 'buscojobs') { continue }
    $c = Leer-Cierre ([string]$e.fechaCierre)
    if ($null -eq $c -or $c -lt $hoy) { continue }
    $p = Join-Path $DirSalida ([string]$e.archivo)
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $html = [IO.File]::ReadAllText($p)
    if ($html -notmatch 'empleo-datos-ocultos' -or $html -notmatch '<strong>Categor') { continue }
    $e.estadoPublicacion = 'NUEVA'
    $lineas[$i] = (ConvertTo-Json $e -Compress)
    $cambio++
}
[IO.File]::WriteAllLines($RutaCola, $lineas, $utf8)
Write-Output ("APLICADO: HISTORICA -> NUEVA: " + $cambio)
exit 0
