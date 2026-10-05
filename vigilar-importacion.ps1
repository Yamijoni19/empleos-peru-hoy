# vigilar-importacion.ps1 - espera a que Blogger termine de importar los XML
# del backfill y, cuando el numero de posts del blog sube al total esperado,
# ejecuta exportar-xml.ps1 -MarcarImportados (para que la API no duplique).
#
# USO (PowerShell):
#   .\vigilar-importacion.ps1               # espera y marca al terminar
#   .\vigilar-importacion.ps1 -Esperados 2951 -TiempoMaxMin 180
#
# Sondea con blogs/get (solo LECTURA; las lecturas no tienen el bloqueo 429
# que si tienen las inserciones). Sale con RC=0 si todo marco bien.

param(
    [int]$Esperados = 2951,
    [int]$TiempoMaxMin = 180,
    [int]$CadaSegundos = 45
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$tokenPath = Join-Path $raiz "token-blogger.json"
$credPath = Join-Path $raiz "credentials.json"
$BlogUrl = "https://empleosperuhoy.blogspot.com"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inst = $(if ($cred.installed) { $cred.installed } else { $cred.web })
$clientId = [string]$inst.client_id
$clientSec = [string]$inst.client_secret

$script:token = Get-Content $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Refrescar {
    $t = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id = $clientId; client_secret = $clientSec
        refresh_token = $script:token.refresh_token; grant_type = "refresh_token"
    }
    $script:token.access_token = $t.access_token
    $script:token.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$t.expires_in).ToString('o')
    [IO.File]::WriteAllText($tokenPath, ($script:token | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
}

function Total-Posts([string]$blogId) {
    $venc = [datetime]::Parse($script:token.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) { Refrescar }
    $u = "https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "?fields=id,posts/totalItems"
    for ($i = 1; $i -le 4; $i++) {
        try {
            $r = Invoke-RestMethod -Uri $u -Headers @{ Authorization = "Bearer " + $script:token.access_token }
            return [int]$r.posts.totalItems
        } catch {
            $cod = 0; if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode }
            if ($cod -eq 401) { Refrescar; continue }
            if ($cod -eq 429) { Start-Sleep -Seconds (30 * $i); continue }
            throw
        }
    }
    throw "no pude leer el total de posts"
}

# --------------------------------------------------------------- baseline
$venc0 = [datetime]::Parse($script:token.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
if ($venc0 -lt (Get-Date).ToUniversalTime().AddMinutes(2)) { Refrescar }
$blog = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/byurl?url=" + [uri]::EscapeDataString($BlogUrl) + "&fields=id,name,url") -Headers @{ Authorization = "Bearer " + $script:token.access_token }
$blogId = [string]$blog.id
$base = Total-Posts $blogId
$meta = $base + $Esperados
Write-Host ("Blog: " + $blog.name)
Write-Host ("Posts ahora: " + $base + " | esperados al terminar la importacion: " + $meta + " (+" + $Esperados + ")")
Write-Host ("Sondeo cada " + $CadaSegundos + "s, hasta " + $TiempoMaxMin + " min...")
Write-Host ""

$inicio = Get-Date
while ($true) {
    $total = Total-Posts $blogId
    $falta = $meta - $total
    Write-Host ("[" + (Get-Date -Format 'HH:mm:ss') + "] posts: " + $total + "  (faltan " + $(if ($falta -gt 0) { $falta } else { 0 }) + ")")
    if ($total -ge $meta) { break }
    if (((Get-Date) - $inicio).TotalMinutes -ge $TiempoMaxMin) {
        Write-Host ""
        Write-Host ("SE ACERCO EL TIEMPO MAXIMO: solo llego a " + $total + " de " + $meta + ".")
        Write-Host "Revisa en Blogger si quedaron XML sin importar; vuelve a correr el vigilante cuando los subas."
        exit 1
    }
    Start-Sleep -Seconds $CadaSegundos
}

Write-Host ""
Write-Host "== IMPORTACION COMPLETA: marco los archivos =="
& (Join-Path $raiz "exportar-xml.ps1") -MarcarImportados
Write-Host ""
Write-Host "Listo: los " + $Esperados + " archivos quedaron registrados en publicaciones.txt."
exit 0
