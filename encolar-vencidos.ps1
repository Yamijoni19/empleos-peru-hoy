# encolar-vencidos.ps1 - encola RETIRAR de posts cuya fecha de cierre ya paso.
#
# USO:
#   .\encolar-vencidos.ps1                  # encola todos los vencidos (max 0 = sin tope)
#   .\encolar-vencidos.ps1 -Maximo 10       # encola hasta 10 (cierre mas antiguo primero)
#
# Pagina el feed del blog con cuerpos, extrae "Fecha de cierre" con la misma
# regex de publicar-blogger.ps1 y agrega a datos\publicados\cola-correcciones.jsonl
# (el consumo lo hace aplicar-correcciones.ps1, de a pocos).

param(
    [int]$Maximo = 0,
    [int]$TopePendiente = 100
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$RutaToken = Join-Path $BaseDir 'token-blogger.json'
$RutaCred  = Join-Path $BaseDir 'credentials.json'
$RutaCola  = Join-Path $BaseDir 'datos\publicados\cola-correcciones.jsonl'

# Si ya hay suficientes retiradas pendientes, ni siquiera consultamos el blog.
$pendientes = 0
if (Test-Path -LiteralPath $RutaCola) {
    foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
        if ($l.Trim() -eq '') { continue }
        try { $e = $l | ConvertFrom-Json; if ([string]$e.accion -eq 'RETIRAR' -and [string]$e.estado -eq 'PENDIENTE') { $pendientes++ } } catch { }
    }
}
if ($TopePendiente -gt 0 -and $pendientes -ge $TopePendiente) {
    Write-Output ("RETIRADAS PENDIENTES: " + $pendientes + " (tope " + $TopePendiente + ") - no se consulta el blog.")
    exit 0
}

if (-not (Test-Path -LiteralPath $RutaToken)) { Write-Output "FALTA token-blogger.json"; exit 1 }
$tk = Get-Content $RutaToken -Raw -Encoding UTF8 | ConvertFrom-Json
$cr = Get-Content $RutaCred -Raw -Encoding UTF8 | ConvertFrom-Json
$clientId = [string]$cr.installed.client_id; if (-not $clientId) { $clientId = [string]$cr.web.client_id }
$clientSec = [string]$cr.installed.client_secret; if (-not $clientSec) { $clientSec = [string]$cr.web.client_secret }
$tok = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    client_id = $clientId; client_secret = $clientSec; refresh_token = [string]$tk.refresh_token; grant_type = 'refresh_token'
} -TimeoutSec 30
$access = [string]$tok.access_token
$blogId = '448950430489176641'

$existentes = @{}
if (Test-Path -LiteralPath $RutaCola) {
    foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
        if ($l.Trim() -eq '') { continue }
        try { $e = $l | ConvertFrom-Json; $existentes[[string]$e.url] = [string]$e.estado } catch { }
    }
}

$rixCierre = [regex]'(?is)Fecha\s+(?:de\s+)?cierre\s*:\s*</?[^>]*>?\s*([^\r\n<]{1,40})'
function Extraer-Cierre([string]$html) {
    $m = $rixCierre.Match([string]$html)
    if (-not $m.Success) { return $null }
    $t = ($m.Groups[1].Value -replace '[^0-9A-Za-z/ .-]', '').Trim()
    if ($t -notmatch '^\d{4}-\d{1,2}-\d{1,2}$' -and $t -notmatch '^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$') { return $null }
    foreach ($fmt in @('dd/MM/yyyy', 'yyyy-MM-dd', 'd/M/yyyy', 'dd-MM-yyyy', 'dd.MM.yyyy', 'd/M/yy')) {
        try { return ([datetime]::ParseExact($t, $fmt, [Globalization.CultureInfo]::InvariantCulture)).Date } catch { }
    }
    return $null
}

$hoy = (Get-Date).Date
$posts = @()
$pageToken = ''
$paginas = 0
while ($paginas -lt 40) {
    $uri = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?fetchBodies=true&status=live&maxResults=500&fields=items(id,url,title,status,content),nextPageToken"
    if ($pageToken) { $uri += "&pageToken=$pageToken" }
    $r = Invoke-RestMethod -Headers @{ Authorization = "Bearer $access" } -Uri $uri -TimeoutSec 120
    $items = @($r.items)
    foreach ($p in $items) { $posts += $p }
    $paginas++
    $pageToken = [string]$r.nextPageToken
    if ($items.Count -eq 0 -or -not $pageToken) { break }
}
Write-Output ("posts en blog: " + $posts.Count)

$vencidos = @()
$sinFecha = 0
foreach ($p in $posts) {
    $st = [string]$p.status
    if ($st -and $st -ne 'LIVE') { continue }
    $c = Extraer-Cierre ([string]$p.content)
    if ($null -eq $c) { $sinFecha++; continue }
    if ($c -lt $hoy) {
        $vencidos += [pscustomobject]@{ id = $p.id; url = [string]$p.url; title = [string]$p.title; cierre = $c }
    }
}
$vencidos = @($vencidos | Sort-Object cierre)
Write-Output ("vencidos LIVE con fecha: " + $vencidos.Count + " | sin fecha: " + $sinFecha)

$nuevos = 0; $omitidos = 0
foreach ($v in $vencidos) {
    if ($Maximo -gt 0 -and $nuevos -ge $Maximo) { break }
    if ($existentes.ContainsKey($v.url) -and $existentes[$v.url] -in @('PENDIENTE', 'RETIRADA')) { $omitidos++; continue }
    $item = [ordered]@{
        id = [string]$v.id; accion = 'RETIRAR'; clase = 'D'; prioridad = 1
        titulo = [string]$v.title; url = $v.url; archivoLocal = ''
        motivo = ('fecha de cierre ' + $v.cierre.ToString('dd/MM/yyyy') + ' ya pasada')
        idConservado = ''; tituloNuevo = ''; contenidoNuevo = ''
        fechaEncolada = (Get-Date).ToString('o'); estado = 'PENDIENTE'
    }
    [IO.File]::AppendAllText($RutaCola, ((ConvertTo-Json $item -Compress) + "`r`n"), $utf8)
    $nuevos++
    if ($nuevos -le 10) { Write-Output ("ENCOLADO: " + $v.id + " | cierre " + $v.cierre.ToString('dd/MM/yyyy') + " | " + $v.title) }
}
Write-Output ("nuevos en cola: " + $nuevos + " | ya encolados: " + $omitidos)
exit 0
