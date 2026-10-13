# escanear-recopilatorios.ps1 - Revisa las fuentes CDT de TODO lo generado
# (salida/) y detecta paginas-recopilatorio (varias ofertas en 1 articulo)
# usando lib\catalogo.ps1.  Motivo: publicar un digesto como si fuera una
# oferta unica rompe la regla de "una URL = una oferta unica".
#
# Salida: datos\revision\catalogos\escaneo.jsonl (un registro por archivo;
#   reanudable: los OK no se repiten, los ERROR se reintentan).
# Fuente URL: fuentes\<stem>.txt (linea "URL: ...") si es convocatoriasdetrabajo;
#   fallback = enlace convocatoriasdetrabajo dentro del HTML de salida.
#
# USO:
#   .\escanear-recopilatorios.ps1                 # todo lo pendiente
#   .\escanear-recopilatorios.ps1 -Limite 50      # hasta 50 descargas (smoke)
#   .\escanear-recopilatorios.ps1 -PausaMs 900

param(
    [int]$Limite = 0,
    [int]$PausaMs = 1100
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $raiz 'lib\catalogo.ps1')
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dirRes = Join-Path $raiz 'datos\revision\catalogos'
New-Item -ItemType Directory -Path $dirRes -Force | Out-Null
$RutaRes = Join-Path $dirRes 'escaneo.jsonl'

$hechos = @{}
if (Test-Path $RutaRes) {
    foreach ($l in [IO.File]::ReadAllLines($RutaRes)) {
        if ($l.Trim() -eq '') { continue }
        try { $e = $l | ConvertFrom-Json } catch { continue }
        if ([string]$e.estado -eq 'OK') { $hechos[[string]$e.archivo] = $true }
    }
}
Write-Host ("[escaneo] ya escaneados OK: " + $hechos.Count)

# archivos publicados (para ordenar: primero lo que ya esta en el blog)
$pub = @{}
if (Test-Path (Join-Path $raiz 'publicaciones.txt')) {
    foreach ($l in [IO.File]::ReadAllLines((Join-Path $raiz 'publicaciones.txt'))) {
        if ($l -match '\|\s*(\S+-entrada\.html)\s*$') { $pub[$matches[1]] = $true }
    }
}

# pendientes: archivos de salida con fuente CDT
$pendientes = New-Object System.Collections.ArrayList
foreach ($f in (Get-ChildItem (Join-Path $raiz 'salida') -Filter '*.html')) {
    if ($hechos.ContainsKey($f.Name)) { continue }
    $fuente = ''
    $stem = $f.Name -replace '-entrada\.html$', ''
    $txt = Join-Path $raiz ('fuentes\' + $stem + '.txt')
    if (Test-Path $txt) {
        $l1 = [IO.File]::ReadLines($txt) | Select-Object -First 1
        if ($l1 -match '^URL:\s*(\S+)') { $fuente = $matches[1] }
    }
    if ($fuente -notmatch 'convocatoriasdetrabajo\.com') {
        $h = [IO.File]::ReadAllText($f.FullName)
        $m = [regex]::Match($h, 'href="(https://www\.convocatoriasdetrabajo\.com/[^"]+\.html)"')
        if ($m.Success) { $fuente = $m.Groups[1].Value } else { continue }
    }
    $null = $pendientes.Add([pscustomobject]@{ Archivo = $f.Name; Fuente = $fuente; Publicado = $pub.ContainsKey($f.Name) })
}
# primero los publicados (riesgo inmediato), luego el resto
$pendientes = @($pendientes | Sort-Object -Property @{Expression = 'Publicado'; Descending = $true}, Archivo)
Write-Host ("[escaneo] pendientes CDT: " + $pendientes.Count + " (publicados primero: " + (@($pendientes | Where-Object Publicado).Count) + ")")

$wc = New-Object System.Net.WebClient
$wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
$n = 0; $cats = 0; $errs = 0
foreach ($p in $pendientes) {
    if ($Limite -gt 0 -and $n -ge $Limite) { break }
    $n++
    $reg = [ordered]@{
        archivo = $p.Archivo; fuente = $p.Fuente; publicado = [bool]$p.Publicado
        estado = 'OK'; esCatalogo = $false; motivo = ''; encCas = 0; encNum = 0
        codPlaza = 0; enlaces = 0; error = ''; fecha = (Get-Date).ToString('o')
    }
    try {
        $bytes = $wc.DownloadData($p.Fuente)
        $html  = [Text.Encoding]::UTF8.GetString($bytes)
        $c = Test-EsCatalogoHtml $html
        $reg.esCatalogo = [bool]$c.EsCatalogo
        $reg.motivo     = [string]$c.Motivo
        $reg.encCas     = [int]$c.EncCas
        $reg.encNum     = [int]$c.EncNumerados
        $reg.codPlaza   = [int]$c.CodigoPlaza
        $reg.enlaces    = [int]$c.EnlacesOferta
        if ($c.EsCatalogo) { $cats++; Write-Host ("  CATALOGO: " + $p.Archivo + "  [" + $c.Motivo + "]") }
    } catch {
        $reg.estado = 'ERROR'; $reg.error = $_.Exception.Message; $errs++
        Write-Host ("  ERROR: " + $p.Archivo + " - " + $_.Exception.Message)
    }
    [IO.File]::AppendAllText($RutaRes, ((ConvertTo-Json $reg -Compress) + "`r`n"), $utf8)
    if ($n % 25 -eq 0) { Write-Host ("[escaneo] " + $n + "/" + $pendientes.Count + " | catalogos: " + $cats + " | errores: " + $errs) }
    Start-Sleep -Milliseconds $PausaMs
}
Write-Host ("[escaneo] FIN lote: escaneados=" + $n + " catalogos=" + $cats + " errores=" + $errs)
