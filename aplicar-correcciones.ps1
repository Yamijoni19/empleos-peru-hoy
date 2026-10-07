# aplicar-correcciones.ps1 - MANTENIMIENTO de los posts YA publicados.
#
# Aplica la cola de datos\publicados\cola-correcciones.jsonl (generada por
# inspeccionar-publicados.ps1) y las actualizaciones ACTUALIZADA/CORRECCION de
# datos\cola\cola-comun.jsonl (actualiza el post EXISTENTE, nunca crea otro).
#
# USO:
#   .\aplicar-correcciones.ps1                    # SIMULACION (0 escrituras)
#   .\aplicar-correcciones.ps1 -Aplicar           # RETIRAR = BORRADOR (reversible) + correcciones
#   .\aplicar-correcciones.ps1 -Aplicar -RetirarComo Borrar   # RETIRAR = DELETE permanente
#   .\aplicar-correcciones.ps1 -Aplicar -MaxCorrecciones 5
#
# RETIRAR (por defecto Borrador): se usa posts.revert (POST .../posts/{id}/revert),
#   que pasa el post publicado a DRAFT: deja de verse en el blog (URL publica 404)
#   pero se recupera desde Blogger o con posts.publish. Con -RetirarComo Borrar
#   se usa DELETE (borrado permanente, sin papelera en la API).
#
# CANDADOS (todos deben cumplirse para escribir):
#   1) -Aplicar explícito           (sin él: solo simulación)
#   2) config\publicacion.json -> publicacion.activada = true
#   3) config\publicacion.json -> correcciones.activadas = true
#   4) sin cooldown 429 activo
#   5) límite por corrida (correcciones.maxPorCorrida / -MaxCorrecciones)
#   6) tope absoluto de la configuración (topeAbsoluto)
#   7) pausa entre operaciones (correcciones.pausaMs)
#   8) ante 429: CORTE INMEDIATO, cola conservada, cooldown activo, sin reintentos
#
# REGISTRO (datos\publicados\registro-historico.txt):
#   CORRECCION | fecha | postId | motivo | resultado
#   RETIRO     | fecha | postId | URL | motivo
#   DUPLICADO  | fecha | postIdConservado | postIdRetirado | motivo

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [switch]$Aplicar,
    [int]$MaxCorrecciones = -1,
    [int]$PausaMs = -1,
    [string]$SoloId = '',
    [ValidateSet('Borrador','Borrar')]
    [string]$RetirarComo = 'Borrador'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)

$DirDatos    = Join-Path $BaseDir 'datos\publicados'
$DirCola     = Join-Path $BaseDir 'datos\cola'
$RutaColaCor = Join-Path $DirDatos 'cola-correcciones.jsonl'
$RutaRegHist = Join-Path $DirDatos 'registro-historico.txt'
$RutaLog     = Join-Path $DirDatos 'aplicar.log'
$RutaCfg     = Join-Path $BaseDir 'config\publicacion.json'
$RutaCooldown= Join-Path $DirCola 'cooldown-429.txt'
$RutaCooldownJson = Join-Path $DirCola 'cooldown-429.json'
$RutaLog429  = Join-Path $DirCola 'registro-429.txt'
$DirColaComun= Join-Path $DirCola 'cola-comun.jsonl'
$RutaToken   = Join-Path $BaseDir 'token-blogger.json'
$RutaCred    = Join-Path $BaseDir 'credentials.json'
New-Item -ItemType Directory -Path $DirDatos -Force | Out-Null

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($RutaLog, ($l + "`r`n"), $utf8) } catch { }
    Write-Host ("[correcciones] " + $m)
}
function Registrar([string]$linea) {
    try { [IO.File]::AppendAllText($RutaRegHist, ($linea + "`r`n"), $utf8) } catch { }
}

# ---------------------------------------------------------------- configuracion
$Cfg = @{
    modo = 'local'
    publicacion = @{ activada = $false }
    correcciones = @{ activadas = $false; maxPorCorrida = 10; pausaMs = 2500 }
    topeAbsoluto = 100
    cooldown429 = @{ minutos = 240 }
}
if (Test-Path $RutaCfg) {
    try {
        $j = Get-Content $RutaCfg -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($j.modo) { $Cfg.modo = [string]$j.modo }
        if ($j.publicacion -and $null -ne $j.publicacion.activada) { $Cfg.publicacion.activada = [bool]$j.publicacion.activada }
        if ($j.correcciones) {
            if ($null -ne $j.correcciones.activadas)      { $Cfg.correcciones.activadas = [bool]$j.correcciones.activadas }
            if ($null -ne $j.correcciones.maxPorCorrida)  { $Cfg.correcciones.maxPorCorrida = [int]$j.correcciones.maxPorCorrida }
            if ($null -ne $j.correcciones.pausaMs)        { $Cfg.correcciones.pausaMs = [int]$j.correcciones.pausaMs }
        }
        if ($null -ne $j.topeAbsoluto) { $Cfg.topeAbsoluto = [int]$j.topeAbsoluto }
        if ($j.cooldown429 -and $null -ne $j.cooldown429.minutos) { $Cfg.cooldown429.minutos = [int]$j.cooldown429.minutos }
        if ($null -ne $j.maxPorCorrida) { }
    } catch { Log ("  AVISO: config ilegible, defaults seguros (" + $_.Exception.Message + ")") }
}
if ($MaxCorrecciones -le 0) { $MaxCorrecciones = [int]$Cfg.correcciones.maxPorCorrida }
if ($PausaMs -lt 0) { $PausaMs = [int]$Cfg.correcciones.pausaMs }
if ($MaxCorrecciones -gt [int]$Cfg.topeAbsoluto) { $MaxCorrecciones = [int]$Cfg.topeAbsoluto }

# ---------------------------------------------------------------- cola
if (-not (Test-Path $RutaColaCor)) { Log ("no hay cola: " + $RutaColaCor + " (corre inspeccionar-publicados.ps1 primero)"); exit 0 }
$items = New-Object System.Collections.Generic.List[object]
foreach ($l in [IO.File]::ReadAllLines($RutaColaCor)) {
    $l = $l.Trim(); if ($l -eq '') { continue }
    try { $items.Add(($l | ConvertFrom-Json)) } catch { }
}
$pendientes = @($items | Where-Object { [string]$_.estado -eq 'PENDIENTE' })
if ($SoloId -ne '') { $pendientes = @($pendientes | Where-Object { [string]$_.id -eq $SoloId }) }
$pendientes = @($pendientes | Sort-Object prioridad, fechaEncolada)

# actualizaciones ACTUALIZADA/CORRECCION de la cola comun (post existente)
$actualizaciones = New-Object System.Collections.Generic.List[object]
if (Test-Path $DirColaComun) {
    foreach ($l in [IO.File]::ReadAllLines($DirColaComun)) {
        $l = $l.Trim(); if ($l -eq '') { continue }
        try {
            $o = $l | ConvertFrom-Json
            if ([string]$o.estadoPublicacion -in @('ACTUALIZADA', 'CORRECCION')) { $actualizaciones.Add($o) }
        } catch { }
    }
}
$plan = @($pendientes)
if ($MaxCorrecciones -lt $plan.Count) { $plan = @($plan | Select-Object -First $MaxCorrecciones) }

Log ""
Log ("=== PLAN DE MANTENIMIENTO ===")
Log ("  modo            : " + $(if ($Aplicar) { 'APLICAR (escrituras reales)' } else { 'SIMULACION (0 escrituras)' }))
Log ("  cola pendiente  : " + $pendientes.Count + "  (se procesarian hasta " + $MaxCorrecciones + ")")
Log ("  actualizaciones : " + $actualizaciones.Count + " (ACTUALIZADA/CORRECCION de la cola comun)")
    Log ("  pausa           : " + $PausaMs + " ms entre operaciones")
    Log ("  RETIRAR como    : " + $(if ($RetirarComo -eq 'Borrador') { 'BORRADOR (posts.revert -> DRAFT, reversible)' } else { 'DELETE permanente' }))
foreach ($p in ($plan | Group-Object accion | Sort-Object Name)) { Log ("    " + $p.Name + ": " + $p.Count) }

# ---------------------------------------------------------------- candados
function Salir-Candado([string]$motivo) {
    Log ("CANCELADO: " + $motivo)
    Log ("  0 escrituras realizadas; la cola queda intacta.")
    exit 0
}
if ($Aplicar) {
    if (-not [bool]$Cfg.publicacion.activada) { Salir-Candado 'publicacion.activada=false en config\publicacion.json' }
    if (-not [bool]$Cfg.correcciones.activadas) { Salir-Candado 'correcciones.activadas=false en config\publicacion.json' }
    if (Test-Path $RutaCooldownJson) {
        try {
            $cd = Get-Content $RutaCooldownJson -Raw -Encoding UTF8 | ConvertFrom-Json
            if ((Get-Date) -lt ([datetime]$cd.hasta)) { Salir-Candado ("cooldown 429 activo hasta " + ([datetime]$cd.hasta).ToString('yyyy-MM-dd HH:mm')) }
        } catch { }
    }
} else {
    if ($plan.Count -eq 0 -and $actualizaciones.Count -eq 0) { Log "nada pendiente"; exit 0 }
    Log ""
    Log "--- SIMULACION (no se escribe nada) ---"
    $n = 0
    foreach ($p in $plan) {
        $n++
        $extra = ''
        if ([string]$p.accion -eq 'RETIRAR' -and [string]$p.idConservado -ne '') { $extra = "  [duplicado de " + $p.idConservado + "]" }
        $modo = ''
        if ([string]$p.accion -eq 'RETIRAR') { $modo = '  [' + $RetirarComo + ']' }
        Log ("  " + $p.accion.PadRight(8) + " | " + $p.id + " | " + ([string]$p.titulo).Substring(0, [Math]::Min(70, ([string]$p.titulo).Length)) + $extra + $modo)
    }
    if ($actualizaciones.Count -gt 0) {
        foreach ($a in $actualizaciones) { Log ("  ACTUALIZAR | " + $a.clave + " | " + ([string]$a.titulo).Substring(0, [Math]::Min(70, ([string]$a.titulo).Length))) }
    }
    Log ""
    Log ("SIMULACION OK: " + $plan.Count + " operaciones preparadas, 0 escrituras reales.")
    exit 0
}

# ================================================================= ESCRITURAS
$Token = $null; $Expiry = [datetime]::MinValue; $Refresh = $null; $ClientId = $null; $ClientSecret = $null
if (-not (Test-Path $RutaToken)) { Log ("FALTA " + $RutaToken + " (no se escribira nada)"); exit 1 }
try {
    $tk = Get-Content $RutaToken -Raw -Encoding UTF8 | ConvertFrom-Json
    $Token = [string]$tk.access_token; $Refresh = [string]$tk.refresh_token
    if ($tk.expiry_date) { $Expiry = [datetime]::FromFileTime([int64]$tk.expiry_date) }
    elseif ($tk.expires_at) {
        try { $Expiry = [datetime]::Parse([string]$tk.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime() } catch { }
    }
} catch { Log ("token ilegible: " + $_.Exception.Message); exit 1 }
if (Test-Path $RutaCred) {
    try {
        $cr = Get-Content $RutaCred -Raw -Encoding UTF8 | ConvertFrom-Json
        $ClientId = [string]$cr.installed.client_id; $ClientSecret = [string]$cr.installed.client_secret
        if (-not $ClientId) { $ClientId = [string]$cr.web.client_id; $ClientSecret = [string]$cr.web.client_secret }
    } catch { }
}
function Refrescar-Token {
    if (-not $Refresh -or -not $ClientId -or -not $ClientSecret) { return $false }
    try {
        $r = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
            client_id = $ClientId; client_secret = $ClientSecret; refresh_token = $Refresh; grant_type = 'refresh_token'
        } -TimeoutSec 30
        $script:Token = [string]$r.access_token
        if ($r.expires_in) { $script:Expiry = (Get-Date).AddSeconds([int]$r.expires_in) }
        # Add-Member -Force: el token puede no traer expiry_date (solo expires_at)
        $tk | Add-Member -NotePropertyName access_token -NotePropertyValue $script:Token -Force
        $tk | Add-Member -NotePropertyName expiry_date  -NotePropertyValue $script:Expiry.ToFileTime() -Force
        $tk | Add-Member -NotePropertyName expires_at    -NotePropertyValue $script:Expiry.ToUniversalTime().ToString('o') -Force
        [IO.File]::WriteAllText($RutaToken, ($tk | ConvertTo-Json -Depth 6), $utf8)
        $script:ultimaRecarga = Get-Date
        Log "  access_token refrescado"
        return $true
    } catch { Log ("  AVISO: refresh fallido (" + $_.Exception.Message + ")"); return $false }
}
$script:ultimaRecarga = [datetime]::MinValue
# comparar SIEMPRE en UTC: un DateTime Kind=Utc comparado con hora local por ticks
# (sin convertir) nunca detecta la caducidad cuando la fecha UTC ya cambio de dia.
$expUtc = switch ($Expiry.Kind) {
    ([DateTimeKind]::Utc) { $Expiry }
    ([DateTimeKind]::Local) { $Expiry.ToUniversalTime() }
    default { [DateTime]::SpecifyKind($Expiry, [DateTimeKind]::Local).ToUniversalTime() }
}
if ($Expiry -ne [datetime]::MinValue -and $expUtc -lt [datetime]::UtcNow.AddMinutes(-5)) { [void](Refrescar-Token) }
if (-not $Token) { Log "no hay access_token: nada que aplicar"; exit 1 }

$script:BlogId = $null
function Obtener-BlogId {
    if ($script:BlogId) { return $script:BlogId }
    $u = [uri]::EscapeDataString('https://empleosperuhoy.blogspot.com/')
    $url = "https://www.googleapis.com/blogger/v3/blogs/byurl?url=" + $u + "&fields=id,name,url"
    $r = $null
    try {
        $r = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $script:Token" } -TimeoutSec 30
    } catch {
        $cod = 0; if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode }
        if ($cod -eq 401 -and (Refrescar-Token)) {
            $r = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $script:Token" } -TimeoutSec 30
        } else { throw }
    }
    $script:BlogId = [string]$r.id
    return $script:BlogId
}
# Api con POLITICA DE 429: corte inmediato, sin reintentos.
function Api([string]$metodo, [string]$uri, $cuerpo) {
    $h = @{ Authorization = "Bearer $script:Token"; 'Content-Type' = 'application/json; charset=utf-8' }
    try {
        if ($null -eq $cuerpo) {
            return Invoke-WebRequest -Method $metodo -Uri $uri -Headers $h -UseBasicParsing -TimeoutSec 60
        } else {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($cuerpo | ConvertTo-Json -Depth 8 -Compress))
            return Invoke-WebRequest -Method $metodo -Uri $uri -Headers $h -Body $bytes -UseBasicParsing -TimeoutSec 60
        }
    } catch {
        $resp = $_.Exception.Response
        $cod = 0; if ($resp) { $cod = [int]$resp.StatusCode }
        if ($cod -eq 429) {
            $script:hubo429 = $true
            throw [System.Exception]::new("429 " + $_.Exception.Message)
        }
        if ($cod -eq 401) {
            # token caducado en caliente: un refresco (con minimo 60 s entre
            # intentos) y un solo reintento; si vuelve 401 se propaga el error
            if (((Get-Date) - $script:ultimaRecarga).TotalSeconds -gt 60 -and (Refrescar-Token)) {
                return Api $metodo $uri $cuerpo
            }
            throw [System.Exception]::new("401 " + $_.Exception.Message)
        }
        if ($cod -in @(404, 410)) { return @{ ausente = $true; codigo = $cod } }
        throw
    }
}

$MaxTotal = [Math]::Min($MaxCorrecciones, [int]$Cfg.topeAbsoluto)
$hechas = 0; $retiradas = 0; $omitidas = 0; $errores = 0; $actualizadas = 0
$fuera = $false
$asignadas = @{}
foreach ($p in $plan) { $asignadas[[string]$p.id] = $p }

function Marcar([string]$id, [string]$estado, [string]$nota) {
    foreach ($it in $items) {
        if ([string]$it.id -eq $id) {
            $it | Add-Member -NotePropertyName estado -NotePropertyValue $estado -Force
            $it | Add-Member -NotePropertyName aplicadaEn -NotePropertyValue ((Get-Date).ToString('o')) -Force
            if ($nota) { $it | Add-Member -NotePropertyName notaAplicacion -NotePropertyValue $nota -Force }
        }
    }
}
function Guardar-Cola {
    try {
        $ls = New-Object System.Collections.Generic.List[string]
        foreach ($it in $items) { $ls.Add(($it | ConvertTo-Json -Compress -Depth 6)) }
        [IO.File]::WriteAllLines($RutaColaCor, $ls, $utf8)
    } catch { Log ("  AVISO: no se pudo reescribir la cola: " + $_.Exception.Message) }
}

Log ""
Log ("=== ESCRITURA ===")
Log ("  limite efectivo: " + $MaxTotal + " operaciones, pausa " + $PausaMs + " ms")

try {
    $idBlog = Obtener-BlogId
    Log ("  blog: " + $idBlog)
} catch {
    Log ("  FALLO al obtener el blog: " + $_.Exception.Message)
    exit 1
}

$idx = 0
foreach ($p in $plan) {
    $idx++
    if ($hechas + $retiradas + $actualizadas -ge $MaxTotal) { Log ("  tope " + $MaxTotal + " alcanzado: se corta con " + ($plan.Count - $idx + 1) + " pendientes"); break }
    $pid_ = [string]$p.id; $accion = [string]$p.accion
    $etiqueta = "[" + $idx + "/" + $plan.Count + "] " + $accion + " " + $pid_
    try {
        if ($accion -eq 'RETIRAR') {
            if ($RetirarComo -eq 'Borrador') {
                # Blogger API v3: posts.revert = publicado -> borrador (PATCH status no funciona).
                $r = Api 'POST' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $pid_ + "/revert") $null
            } else {
                $r = Api 'DELETE' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $pid_) $null
            }
            $modo = if ($RetirarComo -eq 'Borrador') { 'BORRADOR' } else { 'DELETE' }
            if ($r -is [hashtable] -and $r.ausente) {
                Marcar $pid_ 'YA-AUSENTE' ("post no encontrado (HTTP " + $r.codigo + ")")
                Registrar ("RETIRO | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $pid_ + " | " + [string]$p.url + " | " + [string]$p.motivo + " | YA-AUSENTE")
                $omitidas++
                Log ("  " + $etiqueta + " -> ya no existe (OK)")
            } else {
                Marcar $pid_ 'RETIRADA' $modo
                Registrar ("RETIRO | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $pid_ + " | " + [string]$p.url + " | " + [string]$p.motivo + " | MODO=" + $modo)
                if ([string]$p.idConservado -ne '') {
                    Registrar ("DUPLICADO | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + [string]$p.idConservado + " | " + $pid_ + " | " + [string]$p.motivo)
                }
                $retiradas++
                Log ("  " + $etiqueta + " -> RETIRADO (" + $modo + ")")
            }
        } elseif ($accion -eq 'CORREGIR') {
            $get = Api 'GET' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $pid_ + "?fields=id,title,content,labels,status") $null
            if ($get -is [hashtable] -and $get.ausente) {
                Marcar $pid_ 'YA-AUSENTE' ("post no encontrado (HTTP " + $get.codigo + ")")
                $omitidas++
                Log ("  " + $etiqueta + " -> no existe (se omite)")
            } else {
                $actual = $get.Content | ConvertFrom-Json
                $cuerpo = @{ id = $pid_ }
                if ([string]$p.contenidoNuevo -ne '') { $cuerpo.content = [string]$p.contenidoNuevo } else { $cuerpo.content = [string]$actual.content }
                if ([string]$p.tituloNuevo -ne '')   { $cuerpo.title = [string]$p.tituloNuevo }   else { $cuerpo.title = [string]$actual.title }
                if ($actual.labels) { $cuerpo.labels = @($actual.labels) }
                $put = Api 'PUT' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $pid_) $cuerpo
                if ($put -is [hashtable] -and $put.ausente) {
                    Marcar $pid_ 'ERROR' 'PUT no aplicado'
                    $errores++; $fuera = $true
                    Log ("  " + $etiqueta + " -> ERROR")
                } else {
                    Marcar $pid_ 'CORREGIDA' ''
                    Registrar ("CORRECCION | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $pid_ + " | " + [string]$p.motivo + " | OK")
                    $hechas++
                    Log ("  " + $etiqueta + " -> CORREGIDO")
                }
            }
        } else {
            Marcar $pid_ 'OMITIDA' ("accion desconocida: " + $accion); $omitidas++
            Log ("  " + $etiqueta + " -> accion desconocida")
        }
    } catch {
        if ($script:hubo429) {
            Marcar $pid_ 'PENDIENTE' 'corte 429: queda pendiente'
            $hasta = (Get-Date).AddMinutes([int]$Cfg.cooldown429.minutos)
            try {
                [IO.File]::WriteAllText($RutaCooldown, $hasta.ToString('o'), $utf8)
                [IO.File]::WriteAllText($RutaCooldownJson, (@{ activo = $true; hasta = $hasta.ToString('o'); motivo = '429 en aplicar-correcciones.ps1' } | ConvertTo-Json), $utf8)
                [IO.File]::AppendAllText($RutaLog429, ("429 | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $etiqueta + " | " + $_.Exception.Message + "`r`n"), $utf8)
            } catch { }
            $fuera = $true
            Log ("  " + $etiqueta + " -> CORTE INMEDIATO por 429")
            break
        }
        Marcar $pid_ 'ERROR' $_.Exception.Message
        Registrar ("CORRECCION | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $pid_ + " | " + [string]$p.motivo + " | ERROR: " + $_.Exception.Message)
        $errores++; $fuera = $true
        Log ("  " + $etiqueta + " -> ERROR: " + $_.Exception.Message)
        break
    }
    if ($PausaMs -gt 0) { Start-Sleep -Milliseconds $PausaMs }
}

# ---- actualizaciones de la cola comun (post existente por url) ----------------
if (-not $fuera -and $actualizaciones.Count -gt 0 -and ($hechas + $retiradas) -lt $MaxTotal) {
    $mapa = @{}
    $invs = @(Get-ChildItem -Path $DirDatos -Filter 'inventario-*.jsonl' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    foreach ($f in $invs) {
        foreach ($l in [IO.File]::ReadAllLines($f.FullName)) {
            $l = $l.Trim(); if ($l -eq '') { continue }
            try { $o = $l | ConvertFrom-Json; if ($o.url -and $o.id -and -not $mapa[[string]$o.url]) { $mapa[[string]$o.url] = [string]$o.id } } catch { }
        }
        if ($mapa.Count -gt 0) { break }
    }
    Log ("  mapa url->postId: " + $mapa.Count + " (respaldos locales)")
    foreach ($a in $actualizaciones) {
        if (($hechas + $retiradas + $actualizadas) -ge $MaxTotal) { break }
        $idA = $mapa[[string]$a.url]
        if (-not $idA) {
            Log ("  ACTUALIZAR " + [string]$a.clave + " -> sin postId (no se toca nada)")
            continue
        }
        try {
            $get = Api 'GET' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $idA + "?fields=id,title,content,labels") $null
            if ($get -is [hashtable] -and $get.ausente) { Log ("  ACTUALIZAR " + $idA + " -> no existe"); continue }
            $actual = $get.Content | ConvertFrom-Json
            $cuerpo = @{ id = $idA; title = [string]$actual.title; content = [string]$actual.content }
            if ($actual.labels) { $cuerpo.labels = @($actual.labels) }
            [void](Api 'PUT' ("https://www.googleapis.com/blogger/v3/blogs/$idBlog/posts/" + $idA) $cuerpo)
            Registrar ("CORRECCION | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | " + $idA + " | actualizacion de cola comun (" + [string]$a.estadoPublicacion + ") | OK")
            $actualizadas++
            Log ("  ACTUALIZAR " + $idA + " -> OK")
        } catch {
            if ($script:hubo429) { Log "  429 durante actualizaciones: corte"; $fuera = $true; break }
            Log ("  ACTUALIZAR " + $idA + " -> ERROR: " + $_.Exception.Message)
        }
        if ($PausaMs -gt 0) { Start-Sleep -Milliseconds $PausaMs }
    }
}

Guardar-Cola

Log ""
Log ("=== RESUMEN MANTENIMIENTO ===")
Log ("  CORREGIDOS : " + $hechas)
Log ("  RETIRADOS  : " + $retiradas)
Log ("  YA AUSENTES: " + $omitidas)
Log ("  ACTUALIZ.  : " + $actualizadas)
Log ("  ERRORES    : " + $errores)
Log ("  en cola    : " + (@($items | Where-Object { [string]$_.estado -eq 'PENDIENTE' }).Count) + " pendientes de " + $items.Count)
Log ("  registro   : " + $RutaRegHist)
if ($script:hubo429) {
    Log ("  COOLDOWN 429 activo " + [int]$Cfg.cooldown429.minutos + " min; cola conservada; reintentar despues.")
    exit 1
}
Log "hecho."
