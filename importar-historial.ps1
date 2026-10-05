# importar-historial.ps1 - siembra historial-urls.txt con las convocatorias que
# YA estan publicadas en el blog, para que obtener-urls no las vuelva a ofrecer.
#
# USO (PowerShell):
#   .\importar-historial.ps1
#   .\importar-historial.ps1 -Blog "https://empleosperuhoy.blogspot.com"
#
# Baja el feed del blog (de la mas reciente a la mas vieja) y extrae de cada
# entrada las URLs de convocatoriasdetrabajo.com (linea 'Fuente:' del bloque
# oculto y cualquier otro enlace al sitio). Guarda todo en historial-urls.txt.

param(
    [string]$Blog = "https://empleosperuhoy.blogspot.com",
    [int]$PorPagina = 500
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$historialPath = Join-Path $raiz "historial-urls.txt"

$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
function Bajar([string]$u) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = $ua
    $bytes = $wc.DownloadData($u)
    $wc.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

$historial = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $historialPath) {
    foreach ($l in [IO.File]::ReadAllLines($historialPath)) {
        $l = $l.Trim()
        if ($l -ne "") { [void]$historial.Add($l) }
    }
}
Write-Host ("Historial actual: " + $historial.Count + " URLs")

$rxArt = [regex]'(?i)https?://(?:www\.)?convocatoriasdetrabajo\.com/(?:oferta-de-empleo|oportunidad-laboral)-[A-Za-z0-9\-]+\.html'

$inicio   = 1
$entradas = 0
$nuevas   = 0
$todas    = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

while ($true) {
    $feedUrl = $Blog.TrimEnd('/') + "/feeds/posts/default?alt=json&max-results=" + $PorPagina + "&start-index=" + $inicio
    try { $json = Bajar $feedUrl } catch { Write-Host ("ERROR: no se pudo bajar el feed " + $feedUrl + " - " + $_.Exception.Message); exit 1 }
    try { $j = $json | ConvertFrom-Json } catch { Write-Host ("ERROR: el feed no es JSON valido (" + $_.Exception.Message + ")"); exit 1 }

    $entry = $null
    if ($j.feed -and $j.feed.entry) { $entry = @($j.feed.entry) }
    if (-not $entry -or $entry.Count -eq 0) { break }

    foreach ($e in $entry) {
        $entradas++
        $texto = ""
        if ($e.content -and $e.content.'$t') { $texto = [string]$e.content.'$t' }
        elseif ($e.summary -and $e.summary.'$t') { $texto = [string]$e.summary.'$t' }
        if ($texto -eq "") { continue }
        foreach ($m in $rxArt.Matches($texto)) {
            $u = $m.Value -replace '^http://', 'https://'
            if ($u -match '/www\./') { continue }
            if ($todas.Add($u)) {
                if ($historial.Add($u)) { $nuevas++ }
            }
        }
    }
    Write-Host ("  feed " + $inicio + ".." + ($inicio + $entry.Count - 1) + ": " + $entradas + " entradas leidas, " + $todas.Count + " convocatorias unicas")
    if ($entry.Count -lt $PorPagina) { break }
    $inicio += $PorPagina
    Start-Sleep -Milliseconds 300
}

if ($historial.Count -gt 0) {
    $orden = @($historial | Sort-Object)
    [IO.File]::WriteAllText($historialPath, (($orden -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host ""
Write-Host ("HISTORIAL: " + $entradas + " entradas del blog leidas")
Write-Host ("  convocatorias unicas encontradas: " + $todas.Count)
Write-Host ("  nuevas agregadas al historial:    " + $nuevas)
Write-Host ("  total en historial-urls.txt:      " + $historial.Count)
exit 0
