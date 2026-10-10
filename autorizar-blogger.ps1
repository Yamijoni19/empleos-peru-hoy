# autorizar-blogger.ps1 - regenera token-blogger.json (flujo OAuth con PKCE y
# listener en localhost). El navegador se abre solo: aprueba con la cuenta del
# blog y listo. No publica nada.
#
# USO: powershell -NoProfile -ExecutionPolicy Bypass -File .\autorizar-blogger.ps1

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$tokenPath = Join-Path $raiz 'token-blogger.json'
$credPath = Join-Path $raiz 'credentials.json'
$scope = 'https://www.googleapis.com/auth/blogger'
$puerto = 8765

try { $cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    Write-Host ('ERROR: credentials.json no es JSON valido - ' + $_.Exception.Message); exit 1
}
$inst = $cred
if ($cred.installed) { $inst = $cred.installed }
elseif ($cred.web) { $inst = $cred.web }
if (-not $inst.client_id -or -not $inst.client_secret) {
    Write-Host 'ERROR: credentials.json no trae client_id/client_secret.'; exit 1
}
$clientId = [string]$inst.client_id
$clientSec = [string]$inst.client_secret
$redirect = 'http://localhost:' + $puerto + '/'

function Nuevo-Verifier([ref]$challenge) {
    $b = New-Object byte[] 64
    $rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
    $rng.GetBytes($b)
    $v = [Convert]::ToBase64String($b) -replace '\+', '-' -replace '/', '_' -replace '=', ''
    $sha = [Security.Cryptography.SHA256]::Create()
    $h = $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($v))
    $challenge.Value = [Convert]::ToBase64String($h) -replace '\+', '-' -replace '/', '_' -replace '=', ''
    return $v
}

$maxIntentos = 3
for ($intento = 1; $intento -le $maxIntentos; $intento++) {
    $ch = ''
    $ver = Nuevo-Verifier ([ref]$ch)
    $dummy = ''
    $est = Nuevo-Verifier ([ref]$dummy)
    $auth = 'https://accounts.google.com/o/oauth2/v2/auth?' +
        'client_id=' + [uri]::EscapeDataString($clientId) +
        '&redirect_uri=' + [uri]::EscapeDataString($redirect) +
        '&response_type=code' +
        '&scope=' + [uri]::EscapeDataString($scope) +
        '&access_type=offline&prompt=consent' +
        '&state=' + [uri]::EscapeDataString($est) +
        '&code_challenge=' + $ch + '&code_challenge_method=S256'
    $lis = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $puerto)
    $lis.Start()
    $lis6 = $null
    try {
        $lis6 = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::IPv6Loopback, $puerto)
        $lis6.Start()
    } catch { $lis6 = $null }
    Write-Host ("  [intento $intento/$maxIntentos] Abriendo el navegador... aprueba con la cuenta del blog.")
    Start-Process $auth
    $ini = Get-Date
    $codigo = ''
    while (((Get-Date) - $ini).TotalSeconds -lt 300) {
        $cli = $null
        if ($lis.Pending()) { $cli = $lis.AcceptTcpClient() }
        elseif ($null -ne $lis6 -and $lis6.Pending()) { $cli = $lis6.AcceptTcpClient() }
        if ($null -eq $cli) { Start-Sleep -Milliseconds 250; continue }
        $st = $cli.GetStream()
        $rd = New-Object System.IO.StreamReader($st)
        $req = ''
        while ($true) { $ln = $rd.ReadLine(); if ($null -eq $ln -or $ln -eq '') { break }; $req += $ln + "`n"; if ($req.Length -gt 8192) { break } }
        $m = [regex]::Match($req, 'GET\s+/\?([^\s]+)')
        $qry = ''
        if ($m.Success) { $qry = $m.Groups[1].Value }
        $codigoRaw = $null
        if ($qry -match '(?:^|&)code=([^&]+)') { $codigoRaw = [uri]::UnescapeDataString($Matches[1]) }
        $stateOk = $false
        if ($qry -match '(?:^|&)state=([^&]+)') { $stateOk = ([uri]::UnescapeDataString($Matches[1]) -eq $est) }
        $acepta = ($null -ne $codigoRaw) -and $stateOk
        if ($acepta) { $codigo = $codigoRaw }
        if ($acepta) {
            $html = '<html><body style="font-family:sans-serif;text-align:center;margin-top:60px">' +
                    '<h2>Listo, ya puedes cerrar esta ventana</h2>' +
                    '<p>Vuelve a la terminal.</p></body></html>'
        } else {
            $html = '<html><body style="font-family:sans-serif;text-align:center;margin-top:60px">' +
                    '<h2>Esperando autorizacion...</h2>' +
                    '<p>Si ya la diste, cierra esta pestana.</p></body></html>'
        }
        $hb = [Text.Encoding]::UTF8.GetBytes($html)
        $head = [Text.Encoding]::ASCII.GetBytes('HTTP/1.1 200 OK' + "`r`n" + 'Content-Type: text/html; charset=utf-8' + "`r`n" + 'Content-Length: ' + $hb.Length + "`r`n" + 'Connection: close' + "`r`n`r`n")
        $st.Write($head, 0, $head.Length)
        $st.Write($hb, 0, $hb.Length)
        $cli.Close()
        if ($acepta) { break }
    }
    $lis.Stop()
    if ($null -ne $lis6) { $lis6.Stop() }
    if ($codigo -eq '') {
        Write-Host '  No llego el codigo; reabriendo el navegador...'
        continue
    }
    try {
        $tok = Invoke-RestMethod -Uri 'https://oauth2.googleapis.com/token' -Method Post -Body @{
            code = $codigo; client_id = $clientId; client_secret = $clientSec
            redirect_uri = $redirect; grant_type = 'authorization_code'; code_verifier = $ver
        }
        if (-not $tok.refresh_token) { throw 'Google no devolvio refresh_token' }
        $obj = @{
            access_token  = [string]$tok.access_token
            refresh_token = [string]$tok.refresh_token
            expires_at    = (Get-Date).ToUniversalTime().AddSeconds([int]$tok.expires_in).ToString('o')
        }
        [IO.File]::WriteAllText($tokenPath, ($obj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
        Write-Host '  Token guardado en token-blogger.json.'
        Write-Host 'RESULTADO: OK'
        exit 0
    } catch {
        Write-Host ('  El codigo no sirvio (' + $_.Exception.Message + '); reintento...')
        continue
    }
}
Write-Host 'RESULTADO: FALLO - no se obtuvo token'
exit 1
