param(
    [string[]]$Urls,
    [string]$UrlsArchivo = '',
    [string]$Motivo = 'compilacion o prefijo doble (publicado con script pre-fase-a)'
)
$ErrorActionPreference = 'Stop'
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$RutaCola  = Join-Path $BaseDir 'datos\publicados\cola-correcciones.jsonl'
if ($UrlsArchivo -ne '') {
    $Urls = @([IO.File]::ReadAllLines($UrlsArchivo) | Where-Object { $_.Trim() -ne '' })
}

$existentes = @{}
foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
    if ($l.Trim() -eq '') { continue }
    try { $e = $l | ConvertFrom-Json; $existentes[[string]$e.url] = [string]$e.estado } catch { }
}

# Inventario de posts VIVOS via feed publico: el API posts.list IGNORA
# startIndex (devolvio siempre los mismos 500 aunque hay ~2800 vivos) y los
# retiros de posts antiguos quedaban perdidos con "NO ENCONTRADO EN BLOG".
$porId = @{}
$si = 1; $paginas = 0; $total = 0
while ($paginas -lt 40) {
    $f = Invoke-RestMethod -Uri ("https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=500&start-index=$si") -TimeoutSec 60
    $entries = @($f.feed.entry)
    foreach ($e in $entries) {
        $url = ''
        foreach ($lnk in @($e.link)) { if ([string]$lnk.rel -eq 'alternate') { $url = [string]$lnk.href; break } }
        $id = ''
        if ([string]$e.id.'$t' -match 'post-(\d+)$') { $id = $matches[1] }
        if ($url) { $porId[$url] = [pscustomobject]@{ id = $id; url = $url; title = [string]$e.title.'$t' } }
    }
    $paginas++
    try { $total = [int]$f.feed.'opensearch$totalResults'.'$t' } catch { }
    if ($entries.Count -eq 0) { break }
    $si += $entries.Count
    if ($si -gt $total) { break }
}
Write-Output ("posts vivos en blog: " + $porId.Count + " (total feed " + $total + ")")

$nuevos = 0
foreach ($u in $Urls) {
    if ($existentes.ContainsKey($u) -and $existentes[$u] -in @('PENDIENTE', 'RETIRADA')) {
        Write-Output ("YA ENCOLADO: " + $u + " (" + $existentes[$u] + ")"); continue
    }
    $p = $porId[$u]
    if (-not $p) { Write-Output ("NO ENCONTRADO EN BLOG: " + $u); continue }
    $item = [ordered]@{
        id = [string]$p.id; accion = 'RETIRAR'; clase = 'D'; prioridad = 1
        titulo = [string]$p.title; url = $u; archivoLocal = ''; motivo = $Motivo
        idConservado = ''; tituloNuevo = ''; contenidoNuevo = ''
        fechaEncolada = (Get-Date).ToString('o'); estado = 'PENDIENTE'
    }
    [IO.File]::AppendAllText($RutaCola, ((ConvertTo-Json $item -Compress) + "`r`n"), $utf8)
    $nuevos++
    Write-Output ("ENCOLADO RETIRAR: " + $p.id + " | " + $p.title)
}
Write-Output ("nuevos en cola: " + $nuevos)
