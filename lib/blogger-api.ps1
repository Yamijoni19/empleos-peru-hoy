# lib\blogger-api.ps1 - capa compartida de API de Blogger para los scripts del proyecto.
#
# Lo que aporta (una sola vez, reutilizado por todos los scripts):
#   - refresco automatico del token (access_token caducado -> refresh_token)
#   - GET/POST/PUT/PATCH/DELETE con reintentos cortos y deteccion de 429
#   - blogId resuelto una vez por ejecucion (blogs/byurl)
#   - NEVERA: no imprime tokens por pantalla ni a logs.
#
# USO (desde otro script, en la misma carpeta raiz):
#   . "$PSScriptRoot\lib\blogger-api.ps1"
#   Inicializar-Blogger -BaseDir $PSScriptRoot
#   $r = Blogger-Api 'GET' "v3/blogs/$script:BlogId/posts?max-results=1" $null
#
# La respuesta se devuelve como objeto:
#   [pscustomobject]@{ ok; status; body; texto; error }

$script:BloggerToken = $null
$script:BloggerExpiry = $null
$script:BloggerRefresh = $null
$script:BloggerClientId = $null
$script:BloggerClientSecret = $null
$script:BlogId = $null
$script:BloggerBaseDir = $null
$script:BloggerUtf8 = New-Object System.Text.UTF8Encoding($false)

function Inicializar-Blogger {
    param([string]$BaseDir)
    $script:BloggerBaseDir = $BaseDir
    $rutaToken = Join-Path $BaseDir 'token-blogger.json'
    if (-not (Test-Path -LiteralPath $rutaToken)) { throw "FALTA $rutaToken" }
    $tk = Get-Content -LiteralPath $rutaToken -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:BloggerToken = [string]$tk.access_token
    $script:BloggerRefresh = [string]$tk.refresh_token
    $script:BloggerExpiry = $null
    $campoExpiry = $null
    if ($tk.PSObject.Properties.Name -contains 'expires_at') { $campoExpiry = 'expires_at' }
    elseif ($tk.PSObject.Properties.Name -contains 'expiry_date') { $campoExpiry = 'expiry_date' }
    if ($campoExpiry) {
        try { $script:BloggerExpiry = [datetime]::Parse([string]$tk.$campoExpiry, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }
    $rutaCred = Join-Path $BaseDir 'credentials.json'
    if (Test-Path -LiteralPath $rutaCred) {
        try {
            $cr = Get-Content -LiteralPath $rutaCred -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cr.installed) { $script:BloggerClientId = [string]$cr.installed.client_id; $script:BloggerClientSecret = [string]$cr.installed.client_secret }
            elseif ($cr.web) { $script:BloggerClientId = [string]$cr.web.client_id; $script:BloggerClientSecret = [string]$cr.web.client_secret }
        } catch { }
    }
    if (-not $script:BloggerToken) { throw "token vacio en $rutaToken" }
}

function Refrescar-Token-Blogger {
    if (-not $script:BloggerRefresh) { throw "no hay refresh_token" }
    if (-not $script:BloggerClientId) { throw "no hay credentials.json con client_id/client_secret" }
    $body = @{
        client_id = $script:BloggerClientId
        client_secret = $script:BloggerClientSecret
        refresh_token = $script:BloggerRefresh
        grant_type = 'refresh_token'
    }
    $r = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body $body -TimeoutSec 60
    $script:BloggerToken = [string]$r.access_token
    $script:BloggerExpiry = (Get-Date).ToUniversalTime().AddSeconds([int]$(if ($r.expires_in) { $r.expires_in } else { 3600 }))
    # se conservan expires_at + refresh_token (mismo esquema que ya usan los demas scripts)
    $salida = [ordered]@{
        access_token = $script:BloggerToken
        refresh_token = $script:BloggerRefresh
        expires_at = $script:BloggerExpiry.ToString('o')
        scope = 'https://www.googleapis.com/auth/blogger'
    }
    $rutaToken = Join-Path $script:BloggerBaseDir 'token-blogger.json'
    [IO.File]::WriteAllText($rutaToken, ($salida | ConvertTo-Json -Depth 6), $script:BloggerUtf8)
    return $true
}

function Asegurar-Token-Blogger {
    $vencido = $false
    if ($script:BloggerExpiry -and $script:BloggerExpiry -lt (Get-Date).ToUniversalTime().AddMinutes(3)) { $vencido = $true }
    if ($vencido) { [void](Refrescar-Token-Blogger) }
}

function Blogger-Api {
    param(
        [string]$Metodo,
        [string]$Ruta,            # ej. "v3/blogs/$id/posts?max-results=1"
        $Cuerpo = $null,
        [int]$Reintentos = 2,
        [int]$PausaMs = 700
    )
    if ($Ruta -notmatch '^https?://') { $Ruta = 'https://www.googleapis.com/blogger/' + $Ruta }
    $ultimoError = ''
    for ($intento = 0; $intento -le $Reintentos; $intento++) {
        try {
            Asegurar-Token-Blogger
            $h = @{ Authorization = 'Bearer ' + $script:BloggerToken }
            if ($null -eq $Cuerpo) {
                $resp = Invoke-WebRequest -Method $Metodo -Uri $Ruta -Headers $h -UseBasicParsing -TimeoutSec 90
            } else {
                $json = $Cuerpo | ConvertTo-Json -Depth 12
                $bytes = [Text.Encoding]::UTF8.GetBytes($json)
                $h['Content-Type'] = 'application/json; charset=utf-8'
                $resp = Invoke-WebRequest -Method $Metodo -Uri $Ruta -Headers $h -Body $bytes -UseBasicParsing -TimeoutSec 90
            }
            return [pscustomobject]@{ ok = $true; status = [int]$resp.StatusCode; body = $resp.Content; texto = $resp.Content; error = '' }
        } catch {
            $cod = 0
            if ($_.Exception.Response) { try { $cod = [int]$_.Exception.Response.StatusCode } catch { $cod = 0 } }
            $ultimoError = $_.Exception.Message
            if ($cod -eq 429) {
                # 429 = corte inmediato, sin reintentos (misma regla que aplicar-correcciones.ps1)
                return [pscustomobject]@{ ok = $false; status = 429; body = ''; texto = ''; error = '429 ' + $ultimoError }
            }
            if ($cod -ge 400 -and $cod -lt 500 -and $cod -ne 401 -and $cod -ne 403) {
                return [pscustomobject]@{ ok = $false; status = $cod; body = ''; texto = ''; error = $ultimoError }
            }
            if ($intento -lt $Reintentos) { Start-Sleep -Milliseconds ([Math]::Max($PausaMs, 1200)) }
        }
    }
    return [pscustomobject]@{ ok = $false; status = 0; body = ''; texto = ''; error = $ultimoError }
}

function Obtener-BlogId {
    if ($script:BlogId) { return $script:BlogId }
    $url = 'https://empleosperuhoy.blogspot.com'
    $r = Blogger-Api 'GET' ('v3/blogs/byurl?url=' + [uri]::EscapeDataString($url) + '&fields=id,name,url') $null
    if (-not $r.ok) { throw ("no se pudo resolver el blogId: " + $r.error) }
    $j = $r.body | ConvertFrom-Json
    $script:BlogId = [string]$j.id
    return $script:BlogId
}

function Blogger-429 {
    param([string]$R)
    return ($R -and $R.status -eq 429)
}
