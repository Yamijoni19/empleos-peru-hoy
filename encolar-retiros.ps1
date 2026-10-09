param(
    [string[]]$Urls,
    [string]$Motivo = 'compilacion o prefijo doble (publicado con script pre-fase-a)'
)
$ErrorActionPreference = 'Stop'
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$RutaToken = Join-Path $BaseDir 'token-blogger.json'
$RutaCred  = Join-Path $BaseDir 'credentials.json'
$RutaCola  = Join-Path $BaseDir 'datos\publicados\cola-correcciones.jsonl'

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
foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
    if ($l.Trim() -eq '') { continue }
    try { $e = $l | ConvertFrom-Json; $existentes[[string]$e.url] = [string]$e.estado } catch { }
}

$porId = @{}
$start = 1; $paginas = 0
while ($paginas -lt 20) {
    $r = Invoke-RestMethod -Headers @{ Authorization = "Bearer $access" } -Uri ("https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?fetchBodies=false&maxResults=500&startIndex=$start&fields=items(id,url,title,status)") -TimeoutSec 60
    $n = @($r.items).Count
    foreach ($p in @($r.items)) { $porId[[string]$p.url] = $p }
    $paginas++
    if ($n -eq 0) { break }
    $start += $n
}
Write-Output ("posts en blog: " + $porId.Count)

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
