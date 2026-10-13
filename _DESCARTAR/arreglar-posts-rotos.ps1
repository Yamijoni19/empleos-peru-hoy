# arreglar-posts-rotos.ps1 - borra del blog los posts que se publicaron con
# el titulo roto (TITULO_BLOGGER quedo ":" por el bug del JSON-LD que CT dejo
# de emitir) y los quita de publicaciones.txt para que publicar-blogger.ps1
# los vuelva a insertar con el titulo y el cuerpo ya corregidos.
#
# USO (PowerShell):
#   .\arreglar-posts-rotos.ps1 -Simular   # lista los que borraria (sin tocar nada)
#   .\arreglar-posts-rotos.ps1            # borra de verdad
#
# REGLAS:
#   - solo toca lineas de publicaciones.txt cuyo titulo es vacio o solo signos
#   - los posts con titulo bueno jamas se tocan
#   - 429 -> espera y reintenta (ejecutar cuando la cuota de Google este fresca)

param(
    [switch]$Simular,
    [string]$BlogUrl = "https://empleosperuhoy.blogspot.com"
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$credPath = Join-Path $raiz "credentials.json"
$tokenPath = Join-Path $raiz "token-blogger.json"
$logPath = Join-Path $raiz "publicaciones.txt"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inst = $null
if ($cred.installed) { $inst = $cred.installed }
elseif ($cred.web) { $inst = $cred.web }
if (-not $inst.client_id -or -not $inst.client_secret) {
    Write-Host "ERROR: credentials.json no trae client_id/client_secret."
    exit 1
}
$clientId = [string]$inst.client_id
$clientSec = [string]$inst.client_secret

$script:token = $null
if (Test-Path $tokenPath) {
    try { $script:token = Get-Content $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $script:token = $null }
}
if (-not $script:token -or -not $script:token.refresh_token) {
    Write-Host "ERROR: falta token-blogger.json (ejecuta primero publicar-blogger.ps1)."
    exit 1
}
$venc = [datetime]::Parse($script:token.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) {
    $t = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id = $clientId; client_secret = $clientSec
        refresh_token = $script:token.refresh_token; grant_type = "refresh_token"
    }
    $script:token.access_token = $t.access_token
    $script:token.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$t.expires_in).ToString('o')
    [IO.File]::WriteAllText($tokenPath, ($script:token | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
}

function Api([string]$Metodo, [string]$Uri, [int]$Reintentos = 6) {
    $intento = 0
    while ($true) {
        $intento++
        try {
            $p = @{ Method = $Metodo; Uri = $Uri; Headers = @{ Authorization = "Bearer " + $script:token.access_token } }
            if ($Metodo -eq "POST" -or $Metodo -eq "PUT") { $p.ContentType = "application/json; charset=utf-8" }
            return Invoke-RestMethod @p
        } catch {
            $cod = 0
            if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode }
            if ($cod -eq 401 -and $intento -eq 1) {
                $t = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
                    client_id = $clientId; client_secret = $clientSec
                    refresh_token = $script:token.refresh_token; grant_type = "refresh_token"
                }
                $script:token.access_token = $t.access_token
                continue
            }
            if ($cod -eq 429 -and $intento -le $Reintentos) {
                $zz = [Math]::Min(300, 30 * $intento)
                $det = ""
                try { if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $det = $_.ErrorDetails.Message } } catch { }
                Write-Host ("  429 (" + $intento + "/" + $Reintentos + ")" + $(if ($det) { ": " + $det.Substring(0, [Math]::Min(120, $det.Length)) } else { "" }) + " - espero " + $zz + "s")
                Start-Sleep -Seconds $zz
                continue
            }
            throw
        }
    }
}

function Norm([string]$u) {
    return ($u -replace '^https?://', '' -replace '/$', '').ToLower()
}

# ---------------------------------------------------------------- blog id
$blog = Api GET ("https://www.googleapis.com/blogger/v3/blogs/byurl?url=" + [uri]::EscapeDataString($BlogUrl) + "&fields=id,name,url")
$blogId = [string]$blog.id
Write-Host ("BLOG: " + $blog.name + " (id " + $blogId + ")")

# ---------------------------------------------------- lineas rotas del log
$lineas = @()
if (Test-Path $logPath) { $lineas = @([IO.File]::ReadAllLines($logPath)) }
$rotas = @()
foreach ($l in $lineas) {
    if ($l -match '\|\s*ERROR\s*\|') { continue }
    $p = $l -split ' \| '
    if ($p.Count -ge 4) {
        $tit = $p[1]
        if ($tit -eq '' -or $tit -match '^[\s\p{P}]+$' -or $tit.Trim().Length -lt 6) { $rotas += $l }
    }
}
Write-Host ("Lineas con titulo roto en publicaciones.txt: " + $rotas.Count)
if ($rotas.Count -eq 0) { Write-Host "Nada que arreglar."; exit 0 }

# ------------------------------------------------------- posts del blog
$items = @()
$tok = ""
do {
    $u = "https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts?maxResults=500&fetchBodies=false&fields=items(id,url,title),nextPageToken"
    if ($tok -ne "") { $u += "&pageToken=" + $tok }
    $r = Api GET $u
    if ($r.items) { $items += @($r.items) }
    $tok = ""
    if ($r.nextPageToken) { $tok = [string]$r.nextPageToken }
} while ($tok -ne "")
Write-Host ("Posts en el blog: " + $items.Count)

$porUrl = @{}
foreach ($it in $items) { $porUrl[(Norm ([string]$it.url))] = $it }

$borrar = @()
$noEncontrados = @()
foreach ($l in $rotas) {
    $p = $l -split ' \| '
    $u = Norm $p[2]
    if ($porUrl.ContainsKey($u)) { $borrar += @{ linea = $l; post = $porUrl[$u] } }
    else { $noEncontrados += $p[2] }
}
Write-Host ("Coincidencias a borrar: " + $borrar.Count + " | no encontrados: " + $noEncontrados.Count)
foreach ($u in $noEncontrados) { Write-Host ("  (no esta en el blog) " + $u) }

if ($Simular) {
    Write-Host ""
    Write-Host "SIMULACION - se borrarian estos posts:"
    foreach ($b in $borrar) { Write-Host ("  id " + $b.post.id + "  [" + $b.post.title + "]  " + $b.post.url) }
    exit 0
}

# ------------------------------------------------------------------ borrar
$ok = 0
$fail = 0
foreach ($b in $borrar) {
    try {
        Api DELETE ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $b.post.id)
        $ok++
        Write-Host ("BORRADO  " + $b.post.url + "   (id " + $b.post.id + ")")
        Start-Sleep -Milliseconds 800
    } catch {
        $fail++
        Write-Host ("ERROR al borrar id " + $b.post.id + ": " + $_.Exception.Message)
        if ($fail -ge 3) { Write-Host "3 fallos seguidos: me detengo (¿cuota de Google agotada? vuelve a intentar cuando se libere)."; break }
    }
}
Write-Host ("borrados: " + $ok + " | fallidos: " + $fail)

if ($ok -gt 0) {
    $quitar = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($b in $borrar) { [void]$quitar.Add($b.linea) }
    $nuevas = @($lineas | Where-Object { -not $quitar.Contains($_) })
    [IO.File]::WriteAllLines($logPath, $nuevas, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("publicaciones.txt: " + $lineas.Count + " -> " + $nuevas.Count + " lineas (las " + $ok + " rotas salieron)")
}
Write-Host ""
Write-Host "== RESUMEN =="
Write-Host ("  borrados: " + $ok + " | fallidos: " + $fail)
exit $(if ($fail -gt 0) { 1 } else { 0 })
