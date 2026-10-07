<#
  actualizar-contadores.ps1
  Calcula los contadores REALES por sector (Privado / Estado) a partir del
  feed vivo de Blogger y los escribe en las paginas Inicio y Empleos.

  No inventa numeros: lee el feed etiquetado "Empleo" y clasifica cada
  publicacion con las mismas reglas del tema (clasificarContratante).

  Uso:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\actualizar-contadores.ps1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\actualizar-contadores.ps1 -SoloCalcular

  -SoloCalcular  solo calcula y guarda datos/contadores.json (no toca Blogger)
#>
param(
  [switch]$SoloCalcular
)

$ErrorActionPreference = "Stop"
$d = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$d\lib\blogger-api.ps1"

function Norm([string]$s) {
  if (-not $s) { return "" }
  $s = $s.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
  }
  return ($sb.ToString().Normalize([Text.NormalizationForm]::FormC)).ToLower().Trim()
}

function Clasificar-Contratante([string]$valor) {
  $n = Norm $valor
  if ((-not $n) -or ($n -like "no especific*")) { return "NoEspecificado" }
  if (($n -match "estado") -or ($n -match "publico") -or ($n -match "gobierno") -or
      ($n -match "municipal") -or ($n -match "region") -or ($n -match "ministerio") -or
      ($n -match "gob\.") -or ($n -match "cas 728")) { return "Estado" }
  if (($n -match "privad") -or ($n -match "empresa privada")) { return "Privado" }
  return "Otro"
}

# ---------------------------------------------------------------
# 1) Leer el feed vivo (150 por peticion)
# ---------------------------------------------------------------
$base = "https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json&max-results=150"
$totalEmpleo = 0
$privado = 0
$estado = 0
$otro = 0
$sinEtiqueta = 0
$start = 1
$sw = [Diagnostics.Stopwatch]::StartNew()

Write-Output "Leyendo feed vivo de Empleo..."
while ($true) {
  $url = $base + "&start-index=" + $start
  $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 120
  $j = $r.Content | ConvertFrom-Json
  if ($j.feed.'openSearch$totalResults') {
    $totalEmpleo = [int]$j.feed.'openSearch$totalResults'.'$t'
  }
  $entries = $j.feed.entry
  if (-not $entries) { break }
  foreach ($e in $entries) {
    $html = ""
    if ($e.content) { $html = [string]$e.content.'$t' }
    $m = [regex]::Match($html, "Tipo\s+(?:de\s+)?contratante\s*:\s*(?:</strong>)?\s*([^<\r\n]{1,60})", "IgnoreCase")
    if ($m.Success) {
      $sec = Clasificar-Contratante $m.Groups[1].Value
      switch ($sec) {
        "Privado"      { $privado++ }
        "Estado"       { $estado++ }
        "NoEspecificado" { $sinEtiqueta++ }
        default        { $otro++ }
      }
    } else {
      $sinEtiqueta++
    }
  }
  if ($entries.Count -lt 150) { break }
  $start += 150
  if ($start -gt 10000) { break }
}

if ($totalEmpleo -lt ($privado + $estado + $otro + $sinEtiqueta)) {
  $totalEmpleo = $privado + $estado + $otro + $sinEtiqueta
}

$contadores = [ordered]@{
  fecha            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  fuente           = "feed vivo /-Empleo (max-results=150)"
  totalEmpleo      = $totalEmpleo
  privado          = $privado
  estado           = $estado
  otrosContratante = $otro
  sinContratante   = $sinEtiqueta
  segundos         = [math]::Round($sw.Elapsed.TotalSeconds, 1)
}

$outJson = Join-Path $d "datos\contadores.json"
if (-not (Test-Path (Split-Path $outJson))) { New-Item -ItemType Directory -Path (Split-Path $outJson) -Force | Out-Null }
$contadores | ConvertTo-Json | Set-Content -Path $outJson -Encoding UTF8

Write-Output ("Total publicaciones con etiqueta Empleo: " + $totalEmpleo)
Write-Output ("  Privado: " + $privado)
Write-Output ("  Estado : " + $estado)
Write-Output ("  Otro contratante: " + $otro)
Write-Output ("  Sin contratante : " + $sinEtiqueta)
Write-Output ("Guardado en " + $outJson)

if ($SoloCalcular) { exit 0 }

# ---------------------------------------------------------------
# 2) Escribir los contadores en las paginas
# ---------------------------------------------------------------
Inicializar-Blogger -BaseDir $d
$idBlog = Obtener-BlogId
$utf8 = New-Object System.Text.UTF8Encoding($false)
$respaldo = Join-Path $d "RESPALDO\lote-20261005\paginas"
if (-not (Test-Path $respaldo)) { New-Item -ItemType Directory -Path $respaldo -Force | Out-Null }

$paginas = @(
  @{ id = "8016677489055603868"; archivo = "EMPLEOS-PAGE.html"; url = "https://empleosperuhoy.blogspot.com/p/empleos.html";  nombre = "Empleos" },
  @{ id = "6455216063914630465"; archivo = "INICIO-PAGE.html";  url = "https://empleosperuhoy.blogspot.com/p/inicio.html";   nombre = "Inicio" }
)

$patron = '(?s)(data-sector-num="(?:privado|estado)"[^>]*?data-sector-total=")(\d+)("[^>]*?>)([^<]*)'

foreach ($p in $paginas) {

  $rutaLocal = Join-Path $d $p.archivo
  $html = [IO.File]::ReadAllText($rutaLocal, [Text.Encoding]::UTF8)

  $coincidencias = [regex]::Matches($html, $patron)
  if ($coincidencias.Count -eq 0) {
    Write-Output ("  AVISO: " + $p.archivo + " no tiene huecos data-sector-num; no se modifica")
    continue
  }

  # reemplazar de atras hacia adelante para conservar los indices
  for ($i = $coincidencias.Count - 1; $i -ge 0; $i--) {
    $m = $coincidencias[$i]
    $sector = if ($m.Groups[1].Value -match '"(privado|estado)') { $Matches[1] } else { "" }
    if ($sector -eq "privado") { $numero = [string]$privado }
    elseif ($sector -eq "estado") { $numero = [string]$estado }
    else { continue }
    $nuevo = $m.Groups[1].Value + $numero + $m.Groups[3].Value + $numero
    $html = $html.Remove($m.Index, $m.Length).Insert($m.Index, $nuevo)
  }

  [IO.File]::WriteAllText($rutaLocal, $html, $utf8)
  Write-Output ("  " + $p.archivo + ": " + $coincidencias.Count + " hueco(s) -> privado=" + $privado + " estado=" + $estado)

  $g = Blogger-Api 'GET' ("v3/blogs/$idBlog/pages/" + $p.id + "?fields=id,title,content") $null
  if (-not $g.ok) { Write-Output ("    ERROR al leer la pagina: " + $g.status + " " + $g.error); continue }
  $actual = $g.body | ConvertFrom-Json
  $bak = Join-Path $respaldo ("live-" + $p.nombre.ToLower() + "-pre-contadores.html")
  [IO.File]::WriteAllText($bak, [string]$actual.content, $utf8)

  $cuerpo = @{
    id      = $p.id
    title   = [string]$actual.title
    content = [string]$html
  }
  $put = Blogger-Api 'PUT' ("v3/blogs/$idBlog/pages/" + $p.id) $cuerpo
  if (-not $put.ok) {
    Write-Output ("    ERROR al guardar: " + $put.status + " " + $put.error)
    continue
  }

  # verificar que la pagina sigue publicada
  $ok = $false
  for ($intento = 0; $intento -lt 3; $intento++) {
    try {
      $res = Invoke-WebRequest -UseBasicParsing -Uri $p.url -TimeoutSec 60
      if ($res.StatusCode -eq 200) { $ok = $true; break }
    } catch { Start-Sleep -Seconds 3 }
  }
  if (-not $ok) {
    Write-Output ("    AVISO: " + $p.url + " no responde 200 tras el guardado; se intenta publicar")
    $pub = Blogger-Api 'POST' ("v3/blogs/$idBlog/pages/" + $p.id + "/publish") @{}
    if ($pub.ok) { Write-Output "    pagina republicada" } else { Write-Output ("    ERROR publicar: " + $pub.status + " " + $pub.error) }
  } else {
    Write-Output ("    guardada y publicada: " + $p.url)
  }
}
