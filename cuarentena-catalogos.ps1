# cuarentena-catalogos.ps1 - Acciona los hallazgos de escanear-recopilatorios.ps1:
# para cada pagina-recopilatorio detectada en datos\revision\catalogos\escaneo.jsonl:
#   1. si esta PUBLICADA en el blog -> encola RETIRAR (encolar-retiros.ps1)
#   2. la saca de datos\cola\cola-comun.jsonl (no debe publicarse)
#   3. mueve el HTML de salida/ a datos\revision\catalogos\fuera\
#   4. anota la URL fuente en datos\cola\rechazadas.txt (evita re-encolar)
#
# USO:
#   .\cuarentena-catalogos.ps1 -DryRun     # solo muestra el plan
#   .\cuarentena-catalogos.ps1             # aplica todo
# Idempotente: repetir no duplica nada.

param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$RutaRes   = Join-Path $raiz 'datos\revision\catalogos\escaneo.jsonl'
$dirFuera  = Join-Path $raiz 'datos\revision\catalogos\fuera'
$RutaCola  = Join-Path $raiz 'datos\cola\cola-comun.jsonl'
$RutaRech  = Join-Path $raiz 'datos\cola\rechazadas.txt'
$RutaPub   = Join-Path $raiz 'publicaciones.txt'
New-Item -ItemType Directory -Path $dirFuera -Force | Out-Null

$catalogos = @{}
foreach ($l in [IO.File]::ReadAllLines($RutaRes)) {
    if ($l.Trim() -eq '') { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if ($e.estado -eq 'OK' -and $e.esCatalogo) { $catalogos[[string]$e.archivo] = $e }
}
if ($catalogos.Count -eq 0) { Write-Host '[cuarentena] sin catalogos en escaneo.jsonl'; exit 0 }
Write-Host ("[cuarentena] catalogos detectados: " + $catalogos.Count)

# archivo -> blogUrl (ultima publicacion gana)
$pubMap = @{}
foreach ($l in [IO.File]::ReadAllLines($RutaPub)) {
    if ($l -match '^(.*?)\s\|\s(.*?)\s\|\s(https://empleosperuhoy\.blogspot\.com/\S+)\s\|\s(\S+-entrada\.html)\s*$') {
        $pubMap[$matches[4]] = $matches[3]
    }
}

# que catalogos siguen en la cola
$lineasCola = [IO.File]::ReadAllLines($RutaCola)
$enCola = @{}
foreach ($l in $lineasCola) { if ($l.Trim()) { try { $e = $l | ConvertFrom-Json; if ($catalogos.ContainsKey([string]$e.archivo)) { $enCola[[string]$e.archivo] = $true } } catch { } } }
Write-Host ("[cuarentena] en cola-comun: " + $enCola.Count + " | publicados: " + (@($catalogos.Keys | Where-Object { $pubMap.ContainsKey($_) }).Count))

# rechazadas ya existentes (evitar duplicar)
$rechPrev = @{}
if (Test-Path $RutaRech) { foreach ($l in [IO.File]::ReadAllLines($RutaRech)) { if ($l -match '\|\sCOMPILACION-POST\s\|\s(\S+)') { $rechPrev[$matches[1]] = $true } } }

$urlsRetiro = @()
foreach ($arch in ($catalogos.Keys | Sort-Object)) {
    $c = $catalogos[$arch]
    $rutaHtml = Join-Path $raiz ('salida\' + $arch)
    $enSalida = Test-Path $rutaHtml
    $dest = Join-Path $dirFuera $arch
    $enColaB = $enCola.ContainsKey($arch)
    $pubUrl = if ($pubMap.ContainsKey($arch)) { $pubMap[$arch] } else { '' }
    $enRech = $rechPrev.ContainsKey($arch)

    Write-Host ("  " + $arch)
    Write-Host ("     publicado=" + $(if ($pubUrl) { 'SI ' + $pubUrl } else { 'no' }) + " | enCola=" + $enColaB + " | html=" + $enSalida + " | " + $c.motivo)

    if ($DryRun) { continue }

    if ($enSalida) {
        if (-not (Test-Path $dest)) { Move-Item -LiteralPath $rutaHtml -Destination $dest }
    }
    if (-not $enRech) {
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
        [IO.File]::AppendAllText($RutaRech, ("{0} | COMPILACION-POST | {1} | {2}`r`n" -f $ts, $arch, $c.fuente), $utf8)
    }
    if ($pubUrl) { $urlsRetiro += $pubUrl }
}

if (-not $DryRun -and $enCola.Count -gt 0) {
    $nuevas = @($lineasCola | Where-Object {
        if ($_.Trim() -eq '') { $false; return }
        try { $e = $_ | ConvertFrom-Json; -not $catalogos.ContainsKey([string]$e.archivo) } catch { $true }
    })
    $tmp = $RutaCola + '.tmp'
    [IO.File]::WriteAllLines($tmp, $nuevas, $utf8)
    Move-Item -LiteralPath $tmp -Destination $RutaCola -Force
    Write-Host ("[cuarentena] cola-comun: " + $lineasCola.Count + " -> " + $nuevas.Count + " lineas")
}

if (-not $DryRun -and $urlsRetiro.Count -gt 0) {
    Write-Host ("[cuarentena] encolando " + $urlsRetiro.Count + " retiros...")
    & (Join-Path $raiz 'encolar-retiros.ps1') -Urls $urlsRetiro -Motivo 'recopilatorio (varias ofertas en 1 pagina); detector catalogos'
}
Write-Host '[cuarentena] listo'
