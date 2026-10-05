# publicar-backfill-estado.ps1 - paso final del backfill del Estado:
#   1) reintenta las URLs que fallaron (generar-lote -ReintentarFallidas)
#   2) mueve a reporte\rechazadas\ los HTML que siguen fallando (no se publican)
#   3) publica todo lo que quedo OK (publicar-blogger -Si)
#
# USO: powershell -NoProfile -ExecutionPolicy Bypass -File publicar-backfill-estado.ps1

$ErrorActionPreference = 'Continue'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirReporte = Join-Path $raiz 'reporte'
$dirSalida  = Join-Path $raiz 'salida'
$urlsBackfill = Join-Path $raiz 'urls-backfill.txt'

$rechDir = Join-Path $dirReporte 'rechazadas'
if (-not (Test-Path $rechDir)) { New-Item -ItemType Directory -Path $rechDir | Out-Null }

function Ultimo-Reporte {
    return (Get-ChildItem $dirReporte -Filter 'reporte-*.txt' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1)
}
function Urls-De-Reporte($rep, [string]$tipo) {
    $res = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ($null -eq $rep -or -not (Test-Path $rep.FullName)) { return $res }
    foreach ($l in [IO.File]::ReadAllLines($rep.FullName)) {
        if ($tipo -eq 'ERROR') {
            $m = [regex]::Match($l, '^ERROR\|\s+(\S+)')
            if ($m.Success) { [void]$res.Add($m.Groups[1].Value) }
        } else {
            $m = [regex]::Match($l, '^OK\s*\|.*\|\s*(\S+)\s*$')
            if ($m.Success) { [void]$res.Add($m.Groups[1].Value) }
        }
    }
    return $res
}
function Slugs-De($urls) {
    $s = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($u in $urls) {
        try {
            $seg = ([Uri]$u).Segments[-1]
            $seg = $seg -replace '\.html$', ''
            if ($seg -ne '') { [void]$s.Add($seg) }
        } catch { }
    }
    return $s
}

# ------------------------------------------------------------------ 1) reintento
$repBase = Ultimo-Reporte
Write-Host ("== BASE: " + $(if ($repBase) { $repBase.Name } else { "(sin reporte)" }))
$fallidasBase = Urls-De-Reporte $repBase 'ERROR'
Write-Host ("   fallidas en la base: " + $fallidasBase.Count)

Write-Host "== REINTENTANDO FALLIDAS =="
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $raiz 'generar-lote.ps1') -Urls $urlsBackfill -ReintentarFallidas
$repNuevo = Ultimo-Reporte
$okNuevo = @()
if ($repNuevo -and $repBase -and $repNuevo.FullName -ne $repBase.FullName) { $okNuevo = Urls-De-Reporte $repNuevo 'OK' }
$okSlugs = @(Slugs-De $okNuevo)
Write-Host ("   recuperadas en el reintento: " + $okSlugs.Count + "  (reporte " + $(if ($repNuevo) { $repNuevo.Name } else { "-" }) + ")")

# ------------------------------------------------------- 2) rechazar lo que fallo
$failSlugs = Slugs-De $fallidasBase
$moved = 0
foreach ($slug in $failSlugs) {
    if ($okSlugs.Count -gt 0 -and $okSlugs -contains $slug) { continue }
    $f = Join-Path $dirSalida ($slug + "-entrada.html")
    if (Test-Path -LiteralPath $f) {
        Move-Item -LiteralPath $f -Destination (Join-Path $rechDir ($slug + "-entrada.html")) -Force
        $moved++
    }
}
Write-Host ("== RECHAZADAS movidas a reporte\rechazadas\: " + $moved)

$pendientes = @(Get-ChildItem $dirSalida -Filter '*-entrada.html' -ErrorAction SilentlyContinue)
Write-Host ("   quedan " + $pendientes.Count + " archivos en salida\")

# --------------------------------------------------------------- 3) publicar
Write-Host "== PUBLICAR =="
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $raiz 'publicar-blogger.ps1') -Si
Write-Host "== FIN BACKFILL =="
