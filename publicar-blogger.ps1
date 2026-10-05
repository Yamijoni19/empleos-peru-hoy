# publicar-blogger.ps1 - publica las entradas generadas en salida\ directamente
# en Blogger (con la etiqueta Empleo), sin pegar nada a mano.
#
# USO (PowerShell):
#   .\publicar-blogger.ps1 -Simular          # que se publicaria (sin tocar nada)
#   .\publicar-blogger.ps1                   # publica todo lo pendiente de salida\
#   .\publicar-blogger.ps1 -Ultimas 3        # solo las 3 entradas mas recientes
#   .\publicar-blogger.ps1 -Draft            # entra como borrador (para revisar)
#   .\publicar-blogger.ps1 -SoloHtml "salida\xxx-entrada.html"
#   .\publicar-blogger.ps1 -Simular -Ultimas 3   # vista previa rapida
#
# REGLAS DE SEGURIDAD:
#   - antes de publicar comprueba contra el blog: si el titulo ya existe,
#     esa entrada se SALTA (usa -Forzar para saltarte la comprobacion)
#   - pregunta "Continuar? (s/N)" antes de publicar (usa -Si para no preguntar)
#   - todo se envia en UTF-8 (los acentos llegan bien a Blogger)
#
# SETUP UNICO (si pide algo faltante, el propio script te lo explica):
#   1) https://console.cloud.google.com/  -> crear proyecto
#   2) APIs y servicios -> Biblioteca -> "Blogger API v3" -> Habilitar
#   3) Pantalla de consentimiento -> Externo -> tu correo como usuario de prueba
#   4) Credenciales -> Crear credenciales -> ID de cliente OAuth ->
#      Tipo "Aplicacion de escritorio" -> descargar JSON ->
#      guardarlo como "credentials.json" en ESTA carpeta
#   5) Ejecutar este script: abre el navegador para autorizar y ya queda listo
#      (el token se guarda en token-blogger.json, solo en este equipo)
#
# Cada publicacion queda registrada en publicaciones.txt:
#   fecha | titulo | url-del-post | archivo.html

param(
    [switch]$Draft,
    [switch]$Simular,
    [int]$Ultimas = 0,
    [string]$SoloHtml = "",
    [string]$BlogUrl = "https://empleosperuhoy.blogspot.com",
    [switch]$Si,
    [switch]$Forzar,
    [string[]]$Excluir = @(),

    # ================= FASE 2 + 3: freno de emergencia y cola segura =================
    # Limite por corrida. -1 = usa config\publicacion.json (configuracion normal).
    # Es un FRENO TEMPORAL: se sube editando la configuracion o pasando -MaxPorCorrida 50
    # (o 100, 200, ...). NUNCA existe corrida ilimitada: si falta el dato o es <=0,
    # se vuelve al freno temporal de 5.
    [int]$MaxPorCorrida = -1,

    # Historicas (backfill): solo con esta marca explicita. Automaticamente NUNCA.
    [switch]$Backfill,

    # La cola distingue NUEVA / ACTUALIZADA / CORRECCION / HISTORICA / EXPIRADA.
    # Las dos marcas siguientes solo ENCOLAN (orden de prioridad); la actualizacion
    # de un post ya publicado se aplicara en una intervencion posterior.
    [switch]$PublicarActualizaciones,
    [switch]$PublicarCorrecciones,

    # Desactiva la proteccion contra anomalias SOLO para diagnostico.
    [switch]$SinProteccionAnomalia
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirSalida = Join-Path $raiz "salida"
$credPath = Join-Path $raiz "credentials.json"
$tokenPath = Join-Path $raiz "token-blogger.json"
$logPath = Join-Path $raiz "publicaciones.txt"
$scope = "https://www.googleapis.com/auth/blogger"
$puerto = 8765

# -Excluir puede venir como "bj-*,ct-*" (powershell -File no acepta dos
# valores para el mismo parametro): se parte por comas.
$Excluir = @($Excluir | ForEach-Object { ([string]$_) -split ',' } | Where-Object { $_ -ne '' })

# ======================================= configuracion de la cola (FASE 2/3)
# El limite NO esta hardcodeado en el codigo: vive en config\publicacion.json
# y puede sobreescribirse por parametro (-MaxPorCorrida 50 | 100 | ...).
$DirCola      = Join-Path $raiz "datos\cola"
$CfgColaPath  = Join-Path $raiz "config\publicacion.json"
$RutaHistBas  = Join-Path $DirCola "historico-bloqueado.txt"   # baseline congelado
$RutaRegistro = Join-Path $DirCola "registro-colas.json"       # estado por archivo
$RutaAlertas  = Join-Path $DirCola "alertas.txt"               # ALERTA de volumen
$RutaHistorial= Join-Path $DirCola "historial-correras.json"   # media de corridas
$RutaColaAct  = Join-Path $DirCola "cola-actual.json"          # snapshot de la cola
New-Item -ItemType Directory -Path $DirCola -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $raiz "config") -Force | Out-Null

# Defaults TEMPORALES (freno de emergencia mientras Blogger responde 429).
$Cfg = @{
    modo          = 'local'
    maxPorCorrida = 5
    cola          = @{ prioridades = @('NUEVA', 'ACTUALIZADA', 'CORRECCION', 'EXPIRADA', 'HISTORICA') }
    anomalia      = @{ activa = $true; topeAbsoluto = 100; maxTitulosRepetidos = 3; factorSobreMedia = 3.0; ventanaDias = 7 }
    # PUBLICACION APAGADA mientras Blogger siga en 429. Se enciende en
    # config\publicacion.json (publicacion.activada = true), sin tocar codigo.
    publicacion   = @{ activada = $false }
    backfill      = @{ activado = $false }
    cooldown429   = @{ minutos = 240 }
    scheduler     = @{ frecuenciaMin = 60 }
}
if (Test-Path $CfgColaPath) {
    try {
        $j = Get-Content $CfgColaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $j.maxPorCorrida) { $Cfg.maxPorCorrida = [int]$j.maxPorCorrida }
        if ($j.cola -and $j.cola.prioridades) { $Cfg.cola.prioridades = @($j.cola.prioridades | ForEach-Object { ([string]$_).ToUpper() }) }
        if ($j.anomalia) {
            if ($null -ne $j.anomalia.activa)            { $Cfg.anomalia.activa = [bool]$j.anomalia.activa }
            if ($null -ne $j.anomalia.topeAbsoluto)      { $Cfg.anomalia.topeAbsoluto = [int]$j.anomalia.topeAbsoluto }
            if ($null -ne $j.anomalia.maxTitulosRepetidos) { $Cfg.anomalia.maxTitulosRepetidos = [int]$j.anomalia.maxTitulosRepetidos }
            if ($null -ne $j.anomalia.factorSobreMedia)  { $Cfg.anomalia.factorSobreMedia = [double]$j.anomalia.factorSobreMedia }
            if ($null -ne $j.anomalia.ventanaDias)       { $Cfg.anomalia.ventanaDias = [int]$j.anomalia.ventanaDias }
        }
        if ($j.publicacion -and $null -ne $j.publicacion.activada) { $Cfg.publicacion.activada = [bool]$j.publicacion.activada }
        if ($j.backfill -and $null -ne $j.backfill.activado)       { $Cfg.backfill.activado = [bool]$j.backfill.activado }
        if ($j.cooldown429 -and $null -ne $j.cooldown429.minutos)  { $Cfg.cooldown429.minutos = [int]$j.cooldown429.minutos }
        if ($j.scheduler -and $null -ne $j.scheduler.frecuenciaMin) { $Cfg.scheduler.frecuenciaMin = [int]$j.scheduler.frecuenciaMin }
        # --- llaves planas de config\publicacion.json: mandan sobre las anidadas ---
        if ($null -ne $j.topeAbsoluto)        { $Cfg.anomalia.topeAbsoluto     = [int]$j.topeAbsoluto }
        if ($null -ne $j.factorAnomalia)      { $Cfg.anomalia.factorSobreMedia = [double]$j.factorAnomalia }
        if ($null -ne $j.ventanaAnomalia)     { $Cfg.anomalia.ventanaDias      = [int]$j.ventanaAnomalia }
        if ($null -ne $j.permitirBackfill)    { $Cfg.backfill.activado         = [bool]$j.permitirBackfill }
        if ($null -ne $j.frecuenciaScheduler) { $Cfg.scheduler.frecuenciaMin   = [int]$j.frecuenciaScheduler }
        if ($j.modo) { $Cfg.modo = [string]$j.modo }
    } catch { Write-Host ("  AVISO: config\publicacion.json ilegible, se usan los defaults temporales (" + $_.Exception.Message + ")") }
}

$RutaCooldown429 = Join-Path $DirCola "cooldown-429.json"
$RutaLog429      = Join-Path $DirCola "registro-429.txt"

# ============================================================ PUERTAS DE SEGURIDAD
# 1) publicacion activada en configuracion (SIN esto no se hace NI UN GET/POST)
# 2) cooldown 429 activo (tras un 429 no se insiste)
# 3) backfill solo si esta habilitado en configuracion
if (-not $Simular) {
    if (-not [bool]$Cfg.publicacion.activada) {
        Write-Host ""
        Write-Host "== PUBLICACION DESACTIVADA EN CONFIGURACION =="
        Write-Host "   config\publicacion.json -> publicacion.activada = false"
        Write-Host "   (Blogger responde 429; para publicar: activar ahi SIN tocar codigo)"
        Write-Host "   Cola intacta: no se hizo ninguna peticion a Blogger."
        exit 0
    }
    if (Test-Path $RutaCooldown429) {
        try {
            $cd = Get-Content $RutaCooldown429 -Raw -Encoding UTF8 | ConvertFrom-Json
            $hasta = [datetime]$cd.hasta
            if ((Get-Date) -lt $hasta) {
                Write-Host ""
                Write-Host ("== COOLDOWN 429 ACTIVO: sin publicar hasta " + $hasta.ToString('yyyy-MM-dd HH:mm') + " ==")
                Write-Host ("   registro: " + $RutaLog429)
                Write-Host "   Cola intacta: no se hizo ninguna peticion a Blogger."
                exit 0
            }
        } catch { }
    }
    if ($Backfill -and -not [bool]$Cfg.backfill.activado) {
        Write-Host "BLOCKADO: -Backfill requiere backfill.activado=true en config\publicacion.json."
        exit 1
    }
}

# Limite efectivo: parametro > configuracion; nunca <=0 (corrida ilimitada).
$MaxEfectivo = [int]$Cfg.maxPorCorrida
if ($MaxPorCorrida -gt 0) { $MaxEfectivo = $MaxPorCorrida }
if ($MaxEfectivo -lt 1)   { $MaxEfectivo = 5 }
$MaxCola = [int]$Cfg.anomalia.topeAbsoluto
if ($MaxCola -lt 1) { $MaxCola = 100 }
$AlertasActivas = ([bool]$Cfg.anomalia.activa -and -not $SinProteccionAnomalia)

function Registrar-Alerta([string]$m) {
    $linea = "[{0}] ALERTA | {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($script:RutaAlertas, ($linea + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) } catch { }
    Write-Host $linea
}

# --- PROTECCION 429: corta ya, registra fecha/hora y error, y deja cooldown.
#     No reintenta, no espera segundos para volver a golpear la misma cuota.
function Registrar-Cooldown429([string]$msg) {
    $ahora = Get-Date
    $min = [int]$Cfg.cooldown429.minutos
    if ($min -lt 30) { $min = 30 }
    $hasta = $ahora.AddMinutes($min)
    $limpio = ($msg -replace '\s+', ' ').Trim()
    try {
        [IO.File]::WriteAllText($RutaCooldown429,
            (([pscustomobject]@{ desde = $ahora.ToString('o'); hasta = $hasta.ToString('o'); minutos = $min; motivo = $limpio }) | ConvertTo-Json),
            (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
    try {
        [IO.File]::AppendAllText($RutaLog429,
            ("[{0}] 429 | hasta {1} | {2}" -f $ahora.ToString('yyyy-MM-dd HH:mm:ss'), $hasta.ToString('yyyy-MM-dd HH:mm'), $limpio) + "`r`n",
            (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
    Write-Host ("        429 -> COOLDOWN " + $min + " min (hasta " + $hasta.ToString('yyyy-MM-dd HH:mm') + "); NINGUN POST mas en esta corrida")
}

# --- mutex: una sola instancia de publicacion a la vez ---
# (si la tarea diaria arranca mientras el backfill sigue corriendo,
#  la segunda instancia se sale sin tocar nada y sin duplicar posts)
$script:mtx = New-Object System.Threading.Mutex($false, "EmpleosPublicarBlogger")
$script:mtxLibre = $true
try { $script:mtxLibre = $script:mtx.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $script:mtxLibre = $true }
if (-not $script:mtxLibre) {
    Write-Host "YA HAY OTRA INSTANCIA DE PUBLICACION CORRIENDO: salgo sin tocar nada."
    $script:mtx.Dispose()
    exit 0
}


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

function Paso([string]$t) { Write-Host ""; Write-Host ("== " + $t + " ==") }
function Aviso([string]$t) { Write-Host ("  AVISO: " + $t) }

function ExplicarSetup {
    Write-Host ""
    Write-Host "FALTA EL SETUP DE GOOGLE (se hace UNA sola vez, ~10 minutos):"
    Write-Host ""
    Write-Host "  1. Abre https://console.cloud.google.com/ con la cuenta del blog"
    Write-Host "     -> Crear proyecto (ej: empleos-blogger)"
    Write-Host "  2. APIs y servicios -> Biblioteca -> buscar 'Blogger API v3' -> Habilitar"
    Write-Host "  3. APIs y servicios -> Pantalla de consentimiento -> Tipo: Externo"
    Write-Host "     -> agregar tu correo como Usuario de prueba -> Guardar"
    Write-Host "  4. APIs y servicios -> Credenciales -> Crear credenciales"
    Write-Host "     -> ID de cliente OAuth -> Tipo: Aplicacion de escritorio -> Crear"
    Write-Host "     -> descargar el JSON"
    Write-Host "  5. Renombra el JSON descargado a:  credentials.json"
    Write-Host ("     y guardalo en:  " + $raiz)
    Write-Host "  6. Vuelve a ejecutar este script."
}

# ---------------------------------------------------------------- credenciales
if (-not (Test-Path $credPath)) {
    Write-Host "ERROR: no existe credentials.json"
    ExplicarSetup
    exit 1
}
try { $cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    Write-Host ("ERROR: credentials.json no es JSON valido - " + $_.Exception.Message); exit 1
}
$inst = $cred
if ($cred.installed) { $inst = $cred.installed }
elseif ($cred.web) { $inst = $cred.web }
if (-not $inst.client_id -or -not $inst.client_secret) {
    Write-Host "ERROR: credentials.json no trae client_id/client_secret."
    ExplicarSetup
    exit 1
}
$clientId = [string]$inst.client_id
$clientSec = [string]$inst.client_secret
$redirect = "http://localhost:" + $puerto + "/"

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

function Flujo-Consentimiento {
    Paso "AUTORIZACION (primera vez)"
    $maxIntentos = 6
    for ($intento = 1; $intento -le $maxIntentos; $intento++) {
        $ch = ""
        $ver = Nuevo-Verifier ([ref]$ch)
        $dummy = ""
        $est = Nuevo-Verifier ([ref]$dummy)
        $auth = "https://accounts.google.com/o/oauth2/v2/auth?" +
            "client_id=" + [uri]::EscapeDataString($clientId) +
            "&redirect_uri=" + [uri]::EscapeDataString($redirect) +
            "&response_type=code" +
            "&scope=" + [uri]::EscapeDataString($scope) +
            "&access_type=offline&prompt=consent" +
            "&state=" + [uri]::EscapeDataString($est) +
            "&code_challenge=" + $ch + "&code_challenge_method=S256"
        $lis = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $puerto)
        $lis.Start()
        $lis6 = $null
        try {
            $lis6 = New-Object System.Net.Sockets.TcpListener([Net.IPAddress]::IPv6Loopback, $puerto)
            $lis6.Start()
        } catch { $lis6 = $null }
        Write-Host "  [intento $intento/$maxIntentos] Abriendo el navegador... acepta el acceso con la cuenta del blog (usa la pestana mas reciente)."
        Start-Process $auth
        $ini = Get-Date
        $codigo = ""
        while (((Get-Date) - $ini).TotalSeconds -lt 300) {
            $cli = $null
            if ($lis.Pending()) { $cli = $lis.AcceptTcpClient() }
            elseif ($null -ne $lis6 -and $lis6.Pending()) { $cli = $lis6.AcceptTcpClient() }
            if ($null -eq $cli) { Start-Sleep -Milliseconds 250; continue }
            $st = $cli.GetStream()
            $rd = New-Object System.IO.StreamReader($st)
            $req = ""
            while ($true) { $ln = $rd.ReadLine(); if ($null -eq $ln -or $ln -eq "") { break }; $req += $ln + "`n"; if ($req.Length -gt 8192) { break } }
            $m = [regex]::Match($req, 'GET\s+/\?([^\s]+)')
            $qry = ""
            if ($m.Success) { $qry = $m.Groups[1].Value }
            $codigoRaw = $null
            if ($qry -match '(?:^|&)code=([^&]+)') { $codigoRaw = [uri]::UnescapeDataString($Matches[1]) }
            $stateOk = $false
            if ($qry -match '(?:^|&)state=([^&]+)') { $stateOk = ([uri]::UnescapeDataString($Matches[1]) -eq $est) }
            $acepta = ($null -ne $codigoRaw) -and $stateOk
            if ($acepta) { $codigo = $codigoRaw }
            if ($acepta) {
                $html = "<html><body style='font-family:sans-serif;text-align:center;margin-top:60px'>" +
                        "<h2>Listo, ya puedes cerrar esta ventana</h2>" +
                        "<p>Vuelve a la terminal.</p></body></html>"
            } else {
                $html = "<html><body style='font-family:sans-serif;text-align:center;margin-top:60px'>" +
                        "<h2>Esperando autorizacion...</h2>" +
                        "<p>Si ya la diste, cierra esta pestana. Si no, vuelve a la pestana mas reciente del navegador.</p></body></html>"
            }
            $hb = [Text.Encoding]::UTF8.GetBytes($html)
            $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: " + $hb.Length + "`r`nConnection: close`r`n`r`n")
            $st.Write($head, 0, $head.Length)
            $st.Write($hb, 0, $hb.Length)
            $cli.Close()
            if ($acepta) { break }
        }
        $lis.Stop()
        if ($null -ne $lis6) { $lis6.Stop() }
        if ($codigo -eq "") {
            Write-Host "  No llego el codigo en el intento $intento; reabriendo el navegador..."
            continue
        }
        try {
            $tok = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
                code = $codigo; client_id = $clientId; client_secret = $clientSec
                redirect_uri = $redirect; grant_type = "authorization_code"; code_verifier = $ver
            }
            if (-not $tok.refresh_token) { throw "Google no devolvio refresh_token" }
            $obj = @{
                access_token  = [string]$tok.access_token
                refresh_token = [string]$tok.refresh_token
                expires_at    = (Get-Date).ToUniversalTime().AddSeconds([int]$tok.expires_in).ToString('o')
            }
            [IO.File]::WriteAllText($tokenPath, ($obj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  Token guardado en token-blogger.json."
            return $obj
        } catch {
            Write-Host "  El codigo no sirvio ($($_.Exception.Message)); reintento con una pestana nueva..."
            continue
        }
    }
    Write-Host "  ERROR: no se pudo autorizar tras $maxIntentos intentos."
    exit 1
}

function Refrescar([string]$refresh) {
    return Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id = $clientId; client_secret = $clientSec
        refresh_token = $refresh; grant_type = "refresh_token"
    }
}

$script:token = $null
if (Test-Path $tokenPath) {
    try { $script:token = Get-Content $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $script:token = $null }
}
if (-not $script:token -or -not $script:token.refresh_token) {
    $script:token = Flujo-Consentimiento
} else {
    $venc = [datetime]::Parse($script:token.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) {
        try {
            $t = Refrescar $script:token.refresh_token
            $script:token.access_token = $t.access_token
            $script:token.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$t.expires_in).ToString('o')
            [IO.File]::WriteAllText($tokenPath, ($script:token | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
        } catch {
            Aviso ("no se pudo refrescar el token (" + $_.Exception.Message + "); se pide autorizacion otra vez")
            $script:token = Flujo-Consentimiento
        }
    }
}

function Api([string]$Metodo, [string]$Uri, $Cuerpo, [int]$Reintentos = 6) {
    $intento = 0
    while ($true) {
        $intento++
        try {
            $p = @{ Method = $Metodo; Uri = $Uri; Headers = @{ Authorization = "Bearer " + $script:token.access_token }; ContentType = "application/json; charset=utf-8" }
            if ($null -ne $Cuerpo) { $p.Body = [Text.Encoding]::UTF8.GetBytes(($Cuerpo | ConvertTo-Json -Depth 6)) }
            return Invoke-RestMethod @p
        } catch {
            $cod = 0
            if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode }
            $msg = $_.Exception.Message
            if ($cod -eq 401 -and $intento -eq 1) {
                $t = Refrescar $script:token.refresh_token
                $script:token.access_token = $t.access_token
                continue
            }
            if ($cod -eq 429) {
                # 429 = cuota agotada: CORTE INMEDIATO. Ni reintentos ni esperas;
                # el llamador registra fecha/hora, activa cooldown y conserva la cola.
                $det = ""
                try { if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $det = $_.ErrorDetails.Message } } catch { }
                $script:hubo429 = $true
                if ($det -ne "") { throw ("429 Too Many Requests: " + $det.Substring(0, [Math]::Min(300, $det.Length))) }
                throw "429 Too Many Requests (cuota de Blogger agotada)"
            }
            if ($cod -eq 403 -and $intento -le $Reintentos) {
                Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $intento)))
                continue
            }
            if ($cod -eq 403) { Write-Host ("  ERROR 403: " + $msg + "  (¿la Blogger API no esta habilitada en tu proyecto de Google Cloud?)") }
            throw
        }
    }
}

# ---------------------------------------------------------------- blog id
Paso "BLOG"
try {
    $blog = Api GET ("https://www.googleapis.com/blogger/v3/blogs/byurl?url=" + [uri]::EscapeDataString($BlogUrl) + "&fields=id,name,url")
} catch { Write-Host ("ERROR: no se pudo leer el blog " + $BlogUrl + " - " + $_.Exception.Message); exit 1 }
$blogId = [string]$blog.id
Write-Host ("  " + $blog.name + "  (id " + $blogId + ")")

# ---------------------------------------------------------------- pendientes
$publicadas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $logPath) {
    foreach ($l in [IO.File]::ReadAllLines($logPath)) {
        if ($l -match '\|\s*([^\|]+\.html)\s*$') { [void]$publicadas.Add($Matches[1].Trim()) }
    }
}

$archivos = @()
if ($SoloHtml -ne "") {
    if (-not (Test-Path $SoloHtml)) { Write-Host ("ERROR: no existe " + $SoloHtml); exit 1 }
    $archivos = @(Get-Item $SoloHtml)
} else {
    $archivos = @(Get-ChildItem $dirSalida -Filter "*-entrada.html" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    $archivos = @($archivos | Where-Object { -not $publicadas.Contains($_.Name) })
    foreach ($pat in $Excluir) { $archivos = @($archivos | Where-Object { $_.Name -notlike $pat }) }
    if ($Ultimas -gt 0 -and $archivos.Count -gt $Ultimas) { $archivos = @($archivos | Select-Object -Last $Ultimas) }
}

if ($archivos.Count -eq 0) { Write-Host "Nada pendiente de publicar en salida\."; exit 0 }

$rxMeta = [regex]'(?s)<!--\s*ETIQUETA_BLOGGER\s*=\s*(?<et>[^\r\n]*?)\s+TITULO_BLOGGER\s*=\s*(?<ti>.*?)\s*-->'
$rxH1 = [regex]'(?is)<h1[^>]*>(.*?)</h1>'

function ExtraerTitulo([string]$html) {
    $m = $rxMeta.Match($html)
    if ($m.Success) { $t = $m.Groups['ti'].Value.Trim(); if ($t -ne "") { return $t } }
    $mh = $rxH1.Match($html)
    if ($mh.Success) { return ([Net.WebUtility]::HtmlDecode(($mh.Groups[1].Value -replace '<[^>]+>', '')).Trim()) }
    return ""
}

function Hash-Archivo([string]$ruta) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($ruta)))) -replace '-', '') }
    finally { $sha.Dispose() }
}

# ============================================================ COLA SEGURA (FASE 3)
# Regla: "HTML existente" NO es lo mismo que "publicacion nueva".
# 1) baseline: todo lo que exista ahora y no este publicado queda HISTORICA (congelada).
# 2) registro: estado por archivo (NUEVA/ACTUALIZADA/CORRECCION/EXPIRADA/HISTORICA).
# 3) solo NUEVA entra automaticamente; historicas solo con -Backfill (proceso explicito).
if (-not (Test-Path $RutaHistBas) -and $SoloHtml -eq "") {
    $base = @(Get-ChildItem $dirSalida -Filter "*-entrada.html" -ErrorAction SilentlyContinue |
        Where-Object { -not $publicadas.Contains($_.Name) } | ForEach-Object { $_.Name })
    [IO.File]::WriteAllLines($RutaHistBas, @($base), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("  COLA: baseline historico creado con " + $base.Count + " archivos congelados -> " + $RutaHistBas)
}
$historico = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $RutaHistBas) {
    foreach ($l in [IO.File]::ReadAllLines($RutaHistBas)) { $l = $l.Trim(); if ($l -ne '') { [void]$historico.Add($l) } }
}

$registro = @{}
if (Test-Path $RutaRegistro) {
    try {
        $regJson = Get-Content $RutaRegistro -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $regJson.PSObject.Properties) { $registro[$p.Name] = $p.Value }
    } catch { Write-Host "  AVISO: registro-colas ilegible; se reconstruye desde cero" }
}

$omitidos = @{}
$colaClasificada = @()
foreach ($f in $archivos) {
    $hash = Hash-Archivo $f.FullName
    $reg  = $registro[$f.Name]
    $tit  = ExtraerTitulo ([IO.File]::ReadAllText($f.FullName))
    $estado = ''
    $motivo = ''
    if ($reg -and [string]$reg.estado -eq 'PUBLICADA') {
        if ([string]$reg.hash -eq $hash) { continue }   # sin cambios: no vuelve a la cola
        $titReg = [string]$reg.titulo
        if ($titReg -ne '' -and $titReg -eq $tit) {
            $estado = 'CORRECCION'; $motivo = 'mismo titulo, contenido corregido tras publicar'
        } else {
            $estado = 'ACTUALIZADA'; $motivo = 'titulo/contenido cambiado tras publicar'
        }
    } elseif ($historico.Contains($f.Name)) {
        $estado = 'HISTORICA'; $motivo = 'pertenece al baseline congelado (backfill solo explicito)'
    } else {
        $estado = 'NUEVA'; $motivo = 'detectada despues del baseline'
    }
    $colaClasificada += [pscustomobject]@{
        archivo = $f.Name; item = $f; titulo = $tit; estado = $estado
        hash = $hash; motivo = $motivo
    }
}

# --- prioridad: NUEVA > ACTUALIZADA > CORRECCION > EXPIRADA > HISTORICA ------------
$orden = @{}
for ($i = 0; $i -lt $Cfg.cola.prioridades.Count; $i++) { $orden[$Cfg.cola.prioridades[$i]] = $i }
# Marcar EXPIRADA esta preparado en la cola (permiso = $false, nunca se publica);
# el calculo de vigencia se decide en una intervencion posterior.
$permisos = @{
    'NUEVA'       = $true                                    # automatica
    'ACTUALIZADA' = [bool]$PublicarActualizaciones            # explicita (encolada hoy)
    'CORRECCION'  = [bool]$PublicarCorrecciones               # explicita (encolada hoy)
    'EXPIRADA'    = $false                                    # nunca se publica
    'HISTORICA'   = [bool]$Backfill                           # solo proceso explicito
}
$elegibles = @()
foreach ($c in $colaClasificada) {
    $k = $c.estado.ToUpper()
    if ($permisos.ContainsKey($k) -and $permisos[$k]) { $elegibles += $c }
    else {
        $omitidos[$c.estado] = 1 + $(if ($omitidos.ContainsKey($c.estado)) { $omitidos[$c.estado] } else { 0 })
    }
}
$elegibles = @($elegibles | Sort-Object -Property `
    @{ Expression = { $o = 99; if ($orden.ContainsKey($_.estado.ToUpper())) { $o = $orden[$_.estado.ToUpper()] }; $o } }, `
    @{ Expression = { $_.archivo } })

# ====================================================== PROTECCION CONTRA ANOMALIAS
# Separada del limite: NO impide publicar mucho, detecta comportamiento anormal
# (tope absoluto absurdo, titulos repetidos, volumen muy superior al habitual).
$alertas = @()
if ($AlertasActivas) {
    if ($MaxEfectivo -gt $MaxCola) {
        $alertas += ("MaxPorCorrida=" + $MaxEfectivo + " supera el tope absoluto permitido (" + $MaxCola + ")")
        $MaxEfectivo = $MaxCola
    }
    $maxRep = [int]$Cfg.anomalia.maxTitulosRepetidos
    if ($maxRep -gt 0) {
        $reps = @($elegibles | Where-Object { $_.titulo -ne '' } | Group-Object titulo | Where-Object { $_.Count -gt $maxRep })
        if ($reps.Count -gt 0) {
            $ej = @($reps | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object { $_.Name + " x" + $_.Count })
            $alertas += ("titulos repetidos mas de " + $maxRep + " veces (posible fuga del extractor): " + ($ej -join ' | '))
        }
    }
    $media = 0
    if (Test-Path $RutaHistorial) {
        try {
            $hj = Get-Content $RutaHistorial -Raw -Encoding UTF8 | ConvertFrom-Json
            $corte = (Get-Date).AddDays(-[int]$Cfg.anomalia.ventanaDias)
            $ult = @($hj | Where-Object { try { ([datetime]$_.fecha) -ge $corte } catch { $false } })
            if ($ult.Count -gt 0) { $media = [double]($ult | Measure-Object -Property publicadas -Average).Average }
        } catch { $media = 0 }
    }
    $factor = [double]$Cfg.anomalia.factorSobreMedia
    # Se compara lo que SE VA A PUBLICAR (no el backlog acumulado): un backlog
    # grande por si solo no es anomalo, lo anomalo es dar un salto en el volumen
    # publicado sin haber subido antes la media.
    $porPublicar = [Math]::Min($elegibles.Count, $MaxEfectivo)
    if ($media -gt 0 -and $porPublicar -gt ($media * $factor)) {
        $alertas += ("volumen a publicar " + $porPublicar + " supera " + $factor + "x la media de las ultimas corridas (" + [math]::Round($media, 1) + "); backlog=" + $elegibles.Count)
    }
}

if ($alertas.Count -gt 0) {
    foreach ($a in $alertas) { Registrar-Alerta $a }
    Registrar-Alerta ("COLA DETENIDA: esta corrida NO publica nada. Revisar antes de reintentar.")
    $resumen = [pscustomobject]@{
        generado = (Get-Date).ToString('o'); estado = 'DETENIDA'
        maxPorCorrida = $MaxEfectivo; candidatos = $colaClasificada.Count
        elegibles = $elegibles.Count; publicadas = 0
        porEstado = $omitidos; alertas = $alertas
    }
    try { [IO.File]::WriteAllText($RutaColaAct, ($resumen | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false))) } catch { }
    Write-Host ""
    Write-Host "== COLA DETENIDA POR ANOMALIA =="
    Write-Host ("  log de alertas: " + $RutaAlertas)
    try { $script:mtx.ReleaseMutex() } catch { }
    $script:mtx.Dispose()
    exit 2
}

# ---------------------------------------------------------- limite por corrida
# Siempre hay tope: nunca se procesan todos los pendientes de una corrida.
$antesCola   = $elegibles.Count
$procesar    = @($elegibles | Select-Object -First $MaxEfectivo)
$congelados  = $antesCola - $procesar.Count
$archivos    = @($procesar | ForEach-Object { $_.item })
$estadoPorArch = @{}
foreach ($c in $colaClasificada) { $estadoPorArch[$c.archivo] = $c.estado }

$totales = @{}
foreach ($c in $colaClasificada) { $totales[$c.estado] = 1 + $(if ($totales.ContainsKey($c.estado)) { $totales[$c.estado] } else { 0 }) }
$snapshot = [pscustomobject]@{
    generado      = (Get-Date).ToString('o')
    estado        = 'ABIERTA'
    maxPorCorrida = $MaxEfectivo
    candidatos    = $colaClasificada.Count
    porEstado     = $totales
    omitidos      = $omitidos
    seleccionados = $procesar.Count
    diferidos     = $congelados
    orden         = $Cfg.cola.prioridades
    publicadas    = 0
    simuladas     = 0
    errores       = 0
    nota          = "las historicas del baseline no se publican sin -Backfill; ACTUALIZADA/CORRECCION se encolan hasta tener mecanismo de actualizacion"
}
try { [IO.File]::WriteAllText($RutaColaAct, ($snapshot | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false))) } catch { }

Write-Host ""
Write-Host ("  COLA: candidatos=" + $colaClasificada.Count +
    " | NUEVA=" + $(if ($totales.ContainsKey('NUEVA')) { $totales['NUEVA'] } else { 0 }) +
    " ACTUALIZADA=" + $(if ($totales.ContainsKey('ACTUALIZADA')) { $totales['ACTUALIZADA'] } else { 0 }) +
    " CORRECCION=" + $(if ($totales.ContainsKey('CORRECCION')) { $totales['CORRECCION'] } else { 0 }) +
    " HISTORICA=" + $(if ($totales.ContainsKey('HISTORICA')) { $totales['HISTORICA'] } else { 0 }))
Write-Host ("  COLA: limite por corrida=" + $MaxEfectivo + " | se encolan " + $procesar.Count + " y se diferiden " + $congelados)
foreach ($k in @($omitidos.Keys)) { Write-Host ("  COLA: fuera de esta corrida -> " + $k + " x" + $omitidos[$k]) }

if ($procesar.Count -eq 0) {
    Write-Host ""
    Write-Host "Nada elegible en esta corrida (todo lo pendiente esta congelado en la cola)."
    Write-Host ("  detalle: " + $RutaColaAct)
    try { $script:mtx.ReleaseMutex() } catch { }
    $script:mtx.Dispose()
    exit 0
}

# ------------------------------------------------- comprobacion contra el blog
# si el titulo de la entrada ya existe publicado en el blog, NO se vuelve a
# publicar (evita duplicados). Con -Forzar se salta esta comprobacion.
if (-not $Forzar -and -not $Simular -and $archivos.Count -gt 0) {
    $enBlog = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $ini = 1
    $trTotal = 0
    $seg = 0
    while ($true) {
        try {
            $j = Invoke-RestMethod -Uri ("https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=" + $ini)
        } catch { break }
        if ($trTotal -eq 0) { try { $trTotal = [int]$j.feed.'openSearch$totalResults'.'$t' } catch { $trTotal = 0 } }
        $entries = @(); if ($j -and $j.feed -and $j.feed.entry) { $entries = @($j.feed.entry) }
        if ($entries.Count -eq 0 -or $null -eq $entries[0]) { break }
        foreach ($x in $entries) {
            $tt = ""
            try { $tt = [Net.WebUtility]::HtmlDecode(([string]$x.title.'$t')).Trim() } catch { $tt = "" }
            if ($tt -ne "") { [void]$enBlog.Add($tt) }
        }
        $ini += $entries.Count
        $seg++
        if ($ini -gt $trTotal -or $seg -gt 80) { break }
    }
    $quedan = @()
    foreach ($f in $archivos) {
        $tt = ExtraerTitulo ([IO.File]::ReadAllText($f.FullName))
        if ($tt -ne "" -and $enBlog.Contains($tt)) {
            Aviso ("titulo ya publicado en el blog, lo salto: " + $f.Name)
        } else { $quedan += $f }
    }
    $archivos = $quedan
    if ($archivos.Count -eq 0) { Write-Host "Nada pendiente: todo lo de salida\ ya esta en el blog."; exit 0 }
}

if (-not $Simular -and -not $Si) {
    Write-Host ""
    Write-Host ("Se van a publicar hasta " + $archivos.Count + " entradas (limite por corrida: " + $MaxEfectivo + ") en " + $BlogUrl)
    $r = Read-Host "  Continuar? (s/N)"
    if ($r -notmatch '^[sS]') { Write-Host "Cancelado, no se publico nada."; exit 0 }
}

function Guardar-Registro {
    try {
        $obj = [ordered]@{}
        foreach ($k in ($registro.Keys | Sort-Object)) { $obj[$k] = $registro[$k] }
        [IO.File]::WriteAllText($RutaRegistro, (($obj | ConvertTo-Json -Depth 6)), (New-Object System.Text.UTF8Encoding($false)))
    } catch { Write-Host ("  AVISO: no se pudo guardar el registro de cola (" + $_.Exception.Message + ")") }
}

Paso ("PUBLICAR " + $archivos.Count + " ENTRADA(S)" + $(if ($Draft) { " - BORRADORES" } else { "" }) + "  [limite " + $MaxEfectivo + "]")
if ($Simular) { Write-Host "  (SIMULACION: no se publica nada)" }

$ok = 0
$fail = 0
$n = 0
$encoladas = 0
foreach ($f in $archivos) {
    $n++
    $html = [IO.File]::ReadAllText($f.FullName)
    $titulo = ExtraerTitulo $html
    $etiqueta = "Empleo"
    $m = $rxMeta.Match($html)
    if ($m.Success) { $etiqueta = $m.Groups['et'].Value.Trim() }
    if ($titulo -eq "") { $titulo = $f.BaseName -replace '-entrada$', '' }

    # ACTUALIZADA / CORRECCION: se encolan pero NO crean un post nuevo.
    # El mecanismo de actualizacion del post existente llega en una intervencion posterior.
    $est = ''
    if ($estadoPorArch.ContainsKey($f.Name)) { $est = [string]$estadoPorArch[$f.Name] }
    if ($est -eq 'ACTUALIZADA' -or $est -eq 'CORRECCION') {
        $encoladas++
        $registro[$f.Name] = [pscustomobject]@{
            estado = $est; hash = (Hash-Archivo $f.FullName); titulo = $titulo
            url = ''; fecha = (Get-Date).ToString('o'); intentos = 0
            nota = 'pendiente: el post ya existe, NO se crea una entrada nueva'
        }
        Guardar-Registro
        Write-Host ("[" + $n + "/" + $archivos.Count + "] ENCOLADA (" + $est + ", sin publicar) " + $titulo)
        continue
    }

    if ($Simular) {
        Write-Host ("[" + $n + "/" + $archivos.Count + "] SIMULAR | " + $titulo + "  [" + $etiqueta + "]  <- " + $f.Name)
        $ok++
        continue
    }

    try {
        $post = Api POST ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts?fields=id,url") @{
            title = $titulo; content = $html; labels = @($etiqueta)
            status = $(if ($Draft) { "DRAFT" } else { "LIVE" })
        }
        $ok++
        $script:seq429 = 0
        [IO.File]::AppendAllText($logPath, ((Get-Date -Format 'yyyy-MM-dd HH:mm') + " | " + $titulo + " | " + $post.url + " | " + $f.Name + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        $registro[$f.Name] = [pscustomobject]@{
            estado = 'PUBLICADA'; hash = (Hash-Archivo $f.FullName); titulo = $titulo
            url = $post.url; fecha = (Get-Date).ToString('o'); intentos = 0
            cola = $est
        }
        Guardar-Registro
        Write-Host ("[" + $n + "/" + $archivos.Count + "] OK   " + $titulo)
        Write-Host ("        " + $post.url)
        Start-Sleep -Milliseconds 2000
    } catch {
        $fail++
        $msg = $_.Exception.Message
        $intentos = 1
        if ($registro.ContainsKey($f.Name) -and $registro[$f.Name].intentos) { $intentos = [int]$registro[$f.Name].intentos + 1 }
        [IO.File]::AppendAllText($logPath, ((Get-Date -Format 'yyyy-MM-dd HH:mm') + " | ERROR | " + $f.Name + " | " + $msg + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        $registro[$f.Name] = [pscustomobject]@{
            estado = 'ERROR'; hash = (Hash-Archivo $f.FullName); titulo = $titulo
            url = ''; fecha = (Get-Date).ToString('o'); intentos = $intentos
            motivo = $msg; cola = $est
        }
        Guardar-Registro
        Write-Host ("[" + $n + "/" + $archivos.Count + "] ERROR " + $f.Name + " - " + $msg)
        if ($msg -match '429') {
            # Cuota agotada: corto de inmediato (sin reintentos ni esperas),
            # registro fecha/hora+error, activo cooldown y dejo la cola intacta.
            Registrar-Cooldown429 $msg
            $script:hubo429 = $true
            break
        } else { $script:seq429 = 0 }
    }
}

# historial de corridas: base de la proteccion contra anomalias (media por ventana)
# en SIMULACION no se registra nada como publicado (0 POST reales).
if (-not $Simular) {
    try {
        $histCorr = @()
        if (Test-Path $RutaHistorial) { $histCorr = @(Get-Content $RutaHistorial -Raw -Encoding UTF8 | ConvertFrom-Json) }
        $histCorr += [pscustomobject]@{ fecha = (Get-Date).ToString('o'); publicadas = $ok; errores = $fail; encoladas = $encoladas; maxPorCorrida = $MaxEfectivo }
        [IO.File]::WriteAllText($RutaHistorial, (($histCorr | ConvertTo-Json -Depth 4)), (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}
$snapshot.estado = 'EJECUTADA'
if ($Simular) { $snapshot.estado = 'SIMULADA' }
if ($script:hubo429) { $snapshot.estado = 'CORTADA-429' }
$snapshot.seleccionados = $archivos.Count
$snapshot.publicadas = $(if ($Simular) { 0 } else { $ok })
$snapshot.simuladas = $(if ($Simular) { $ok } else { 0 })
$snapshot.errores = $fail
if ($Simular) { $snapshot.nota = "SIMULACION: 0 POST reales; nada se registro como publicado" }
if ($script:hubo429) { $snapshot.nota = "429: corrida cortada, cola conservada, cooldown activo (datos\cola\cooldown-429.json)" }
try { [IO.File]::WriteAllText($RutaColaAct, ($snapshot | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false))) } catch { }

Write-Host ""
Write-Host "== RESUMEN =="
if ($Simular) { Write-Host ("  SIMULACION: " + $ok + " entradas revisadas, 0 POST reales | errores: " + $fail) }
else { Write-Host ("  publicadas: " + $ok + " | errores: " + $fail + " | encoladas sin publicar: " + $encoladas + $(if ($Draft) { " (borradores)" } else { "" })) }
if ($script:hubo429) { Write-Host "  429: corrida cortada sin reintentos; cooldown activo; cola conservada" }
Write-Host ("  limite por corrida: " + $MaxEfectivo + " (config\\publicacion.json o -MaxPorCorrida)")
Write-Host ("  log: " + $logPath)
try { $script:mtx.ReleaseMutex() } catch { }
$script:mtx.Dispose()
exit $(if ($fail -gt 0) { 1 } else { 0 })
