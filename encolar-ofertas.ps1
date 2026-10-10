# encolar-ofertas.ps1 - COLA COMUN de ofertas validas (PRIVADO + ESTADO).
#
# Lee todo lo pendiente de salida\ (ofertas generadas por el flujo principal),
# extrae los campos normalizados, los deduplica y los deja en la cola:
#
#   datos\cola\cola-comun.jsonl   (un JSON por oferta, una clave por oferta)
#   datos\cola\rechazadas.txt     (RECHAZADA | fecha | URL | motivo)
#
# Campos por oferta: titulo, empresa, sector, fuente, url, id, ubicacion,
# modalidad, fecha, salario (min/max/moneda/texto/fuente_salario), descripcion,
# validacion, estadoPublicacion.
#
# ESTADOS DE PUBLICACION:
#   PUBLICADA  -> ya existe en el blog (se omite de la cola)
#   HISTORICA  -> esta en el baseline congelado (bloqueada, sin -Backfill)
#   NUEVA      -> detectada despues del baseline (puede publicarse)
#   EXPIRADA   -> fecha de cierre anterior a hoy (nunca se publica)
#
# DEDUPLICACION (en este orden):
#   1) id de la fuente  2) URL normalizada  3) fingerprint(sha256)  4) empresa+titulo
#   La URL solo identifica la oferta si es unica: si dos archivos distintos
#   comparten URL (listados, portales externos, carpetas) NO son la misma
#   oferta y se baja a fingerprint.
#
# USO:  .\encolar-ofertas.ps1        (incremental y sin publicar nada)

param(
    [switch]$RepasarTodo,
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Stop'
$DirSalida   = Join-Path $BaseDir 'salida'
$DirCola     = Join-Path $BaseDir 'datos\cola'
$RutaCola    = Join-Path $DirCola 'cola-comun.jsonl'
$RutaRech    = Join-Path $DirCola 'rechazadas.txt'
$RutaHistBas = Join-Path $DirCola 'historico-bloqueado.txt'
$RutaLog     = Join-Path $BaseDir 'publicaciones.txt'
$RutaRechBum = Join-Path $BaseDir 'bumeran\rechazadas.txt'
$RutaNormBum = Join-Path $BaseDir 'bumeran\normalizado'
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $DirCola -Force | Out-Null

function Log([string]$m) { Write-Host ("[encolar] " + $m) }

# ------------------------------------------------------------------ fuentes
$publicadas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $RutaLog) {
    foreach ($l in [IO.File]::ReadAllLines($RutaLog)) {
        if ($l -match '\|\s*([^\|]+\.html)\s*$') { [void]$publicadas.Add($Matches[1].Trim()) }
    }
}
$historico = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $RutaHistBas) {
    foreach ($l in [IO.File]::ReadAllLines($RutaHistBas)) { $l = $l.Trim(); if ($l -ne '') { [void]$historico.Add($l) } }
}

# fichas de Bumeran (id -> ficha) para enriquecer la cola
$fichasBum = @{}
if (Test-Path $RutaNormBum) {
    foreach ($f in @(Get-ChildItem $RutaNormBum -Filter '*.json' -File)) {
        try { $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; $fichasBum[[string]$j.id] = $j } catch { }
    }
}

# estado previo (archivo -> registro): conserva PUBLICADA y encoladoEn
$prevPorArchivo = @{}
if (Test-Path $RutaCola) {
    foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
        $l = $l.Trim(); if ($l -eq '') { continue }
        try {
            $r = $l | ConvertFrom-Json
            $a = [string]$r.archivo
            if ($a -ne '') { $prevPorArchivo[$a] = $r }
        } catch { }
    }
}
Log ("estado previo de la cola: " + $prevPorArchivo.Count + " ofertas")

# ------------------------------------------------------------------ utilidades
function Normalizar-Url([string]$u) {
    $s = ([string]$u).Trim().ToLower()
    $s = [regex]::Replace($s, '[?#].*$', '')
    $s = [regex]::Replace($s, '/+$', '')
    return $s
}
function Hash-Texto([string]$t) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)))) -replace '-', '').Substring(0, 32) }
    finally { $sha.Dispose() }
}
function Sector-De([string]$nombre) {
    if ($nombre -like 'bum-*') { return 'privado' }
    if ($nombre -like 'bj-*')  { return 'privado' }
    if ($nombre -like 'ct-*')  { return 'estado' }
    if ($nombre -like 'oportunidad-laboral-*') { return 'estado' }
    if ($nombre -like 'oferta-de-empleo-*')    { return 'estado' }
    return 'desconocido'
}
function Fuente-De([string]$nombre, [string]$sector) {
    if ($nombre -like 'bum-*') { return 'bumeran' }
    if ($nombre -like 'bj-*')  { return 'buscojobs' }
    if ($nombre -like 'oferta-de-empleo-*')    { return 'convocatoriasdetrabajo' }
    if ($sector -eq 'estado')  { return 'convocatoriasdetrabajo' }
    return 'desconocida'
}
function Campo-Texto([string]$html, [string]$rx) {
    $m = [regex]::Match($html, $rx)
    if (-not $m.Success) { return '' }
    $v = [Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
    $v = ($v -replace '<[^>]+>', ' ')
    $v = ($v -replace '\s+', ' ').Trim()
    return $v
}

$rxTitulo = [regex]'(?s)TITULO_BLOGGER\s*=\s*(.+?)\s*-->'
$rxHrefPost = [regex]'href="(https?://[^"]+)"'
$rxEmpresa  = [regex]'(?is)empleo-empresa">\s*(?:<[^>]+>\s*)*([^<]{2,120})'
$rxSalarioH = [regex]'(?is)empleo-salario-header">\s*((?:<[^>]+>\s*)*)([^<]{1,60})'
$rxSalarioB = [regex]'(?is)<strong>\s*Salario:\s*</strong>\s*([^<]{1,80})'
$rxUbi      = [regex]'(?is)<strong>\s*Ubicaci[oó]n:\s*</strong>\s*([^<]{1,80})'
$rxUbiCard  = [regex]'(?is)empleo-info-label">Ubicaci[oó]n</div>\s*<div class="empleo-info-value">\s*(?:<[^>]+>\s*)*([^<]{1,80})'
$rxModal    = [regex]'(?is)empleo-info-label">Modalidad</div>\s*<div class="empleo-info-value">\s*(?:<[^>]+>\s*)*([^<]{1,60})'
$rxModalB   = [regex]'(?is)<strong>\s*Modalidad:\s*</strong>\s*([^<]{1,60})'
$rxFuente   = [regex]'(?is)<strong>\s*Fuente:\s*</strong>\s*(https?://[^\s<]+)'
$rxPub      = [regex]'(?is)<strong>\s*Fecha publicaci[oó]n:\s*</strong>\s*([^<]{1,40})'
$rxCie      = [regex]'(?is)<strong>\s*Fecha cierre:\s*</strong>\s*([^<]{1,40})'
$rxDesc     = [regex]'(?is)<h2>\s*Descripci[oó]n del puesto\s*</h2>\s*(?:<[^>]+>\s*)*<p>\s*([^<]{80,4000})'

# ------------------------------------------------------------------ barrido
$urlReclamadas = @{}
$clavesEnUso   = @{}
$cola          = @{}
$archivos = @(Get-ChildItem $DirSalida -Filter '*-entrada.html' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
$nuevas = 0; $historicas = 0; $publicadasCnt = 0; $actualizadas = 0; $expiradas = 0; $duplicadas = 0
$hoy = Get-Date

foreach ($f in $archivos) {
    if ($publicadas.Contains($f.Name)) { $publicadasCnt++; continue }
    $html = [IO.File]::ReadAllText($f.FullName)

    $titulo = Campo-Texto $html $rxTitulo.ToString()
    if ($titulo -eq '') { $titulo = Campo-Texto $html '(?is)<h1[^>]*>\s*([^<]{4,200})' }
    if ($titulo -eq '') { $titulo = $f.BaseName -replace '-entrada$', '' }

    $empresa = Campo-Texto $html $rxEmpresa.ToString()
    if ($empresa -eq '') { $empresa = 'No especificado' }

    $salarioTxt = ''
    $mSal = $rxSalarioH.Match($html)
    if ($mSal.Success) { $salarioTxt = ([Net.WebUtility]::HtmlDecode(($mSal.Groups[2].Value -replace '<[^>]+>', ' ')).Trim()) }
    if ($salarioTxt -eq '') { $salarioTxt = Campo-Texto $html $rxSalarioB.ToString() }
    if ($salarioTxt -eq '' -or $salarioTxt -eq 'A convenir') { $salarioTxt = 'No especificado' }

    $salMin = $null; $salMax = $null
    if ($salarioTxt -ne 'No especificado') {
        $vals = @()
        foreach ($mm in @([regex]::Matches($salarioTxt, '(\d[\d.,]{2,8})'))) {
            $t = $mm.Groups[1].Value
            if ($t -match '^\d{1,3}([.,]\d{3})+$') { $t = $t -replace '[.,]', '' }
            $v = $null
            if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)) {
                if ($v -ge 100 -and $v -le 100000) { $vals += $v }
            }
        }
        if ($vals.Count -ge 1) { $salMin = $vals[0]; $salMax = $vals[0] }
        if ($vals.Count -ge 2) { $salMax = $vals[$vals.Count - 1] }
    }

    $ubi   = Campo-Texto $html $rxUbi.ToString();    if ($ubi -eq '')   { $ubi = Campo-Texto $html $rxUbiCard.ToString() }
    $modal = Campo-Texto $html $rxModalB.ToString(); if ($modal -eq '') { $modal = Campo-Texto $html $rxModal.ToString() }
    if ($ubi -eq '')   { $ubi = 'No especificado' }
    if ($modal -eq '') { $modal = 'No especificado' }

    $url = Campo-Texto $html $rxFuente.ToString()
    if ($url -eq '') { $mH = $rxHrefPost.Match($html); if ($mH.Success) { $url = $mH.Groups[1].Value } }
    $urlNorm = Normalizar-Url $url

    $fPub = Campo-Texto $html $rxPub.ToString()
    $fCie = Campo-Texto $html $rxCie.ToString()
    $desc = Campo-Texto $html $rxDesc.ToString()
    $sector = Sector-De $f.Name
    $fuente = Fuente-De $f.Name $sector

    # ------------------------------------------------------------- deduplicacion
    $clave = ''
    $id = ''
    if ($f.Name -match '^bum-(\d+)-') { $id = 'bumeran-' + $Matches[1]; $clave = 'id:' + $id }
    elseif ($f.Name -match '-id-([0-9a-fA-F]{4,})-') { $id = $Matches[1]; $clave = 'id:' + $id + ':' + $fuente }
    elseif ($f.Name -match '(\d{5,})-entrada\.html$') { $id = $Matches[1]; $clave = 'id:' + $id + ':' + $fuente }
    if ($clave -eq '') {
        if ($urlNorm -ne '') {
            $hUrl = Hash-Texto $urlNorm
            if ($urlReclamadas.ContainsKey($hUrl)) {
                $clave = 'hash:' + (Hash-Texto $f.Name)
            } else {
                $clave = 'url:' + $hUrl
                $urlReclamadas[$hUrl] = $f.Name
            }
        } else {
            $clave = 'hash:' + (Hash-Texto $f.Name)
        }
    }
    if ($clavesEnUso.ContainsKey($clave)) {
        $duplicadas++
        Log ("DUP: " + $f.Name + " -> misma clave que " + $clavesEnUso[$clave] + " (" + $clave + ")")
        continue
    }
    $clavesEnUso[$clave] = $f.Name

    # ------------------------------------------------------------- estado
    $prev = $null
    if ($prevPorArchivo.ContainsKey($f.Name)) { $prev = $prevPorArchivo[$f.Name] }

    # Una entrada ya promovida a NUEVA (regenerada con promover-historicas.ps1)
    # no vuelve a HISTORICA aunque su archivo este en el baseline congelado.
    $promovida = ($null -ne $prev -and [string]$prev.estadoPublicacion -eq 'NUEVA')
    $estado = 'NUEVA'
    if ($historico.Contains($f.Name) -and -not $promovida) { $estado = 'HISTORICA' }
    elseif ($fCie -ne '' -and $fCie -ne 'No especificado') {
        $d = $null
        foreach ($fmt in @('yyyy-MM-dd', 'dd/MM/yyyy', 'd/M/yyyy', 'dd-MM-yyyy')) {
            try { $d = [datetime]::ParseExact($fCie, $fmt, [Globalization.CultureInfo]::InvariantCulture); break } catch { }
        }
        if ($null -eq $d) { try { $d = [datetime]::Parse($fCie, [System.Globalization.CultureInfo]::GetCultureInfo('es-PE')) } catch { $d = $null } }
        if ($null -ne $d -and $d.Date -lt $hoy.Date) { $estado = 'EXPIRADA' }
    }
    if ($null -ne $prev -and [string]$prev.estadoPublicacion -eq 'PUBLICADA') { $estado = 'PUBLICADA' }

    # ficha Bumeran: validacion y salario estructurado
    $validacion = 'validada'
    $fuenteSal = ''
    if ($id -ne '' -and $fichasBum.ContainsKey($id)) {
        $fb = $fichasBum[$id]
        if ($fb.validacion -and [string]$fb.validacion.estado -ne '') { $validacion = [string]$fb.validacion.estado }
        if ($fb.salario -and $fb.salario.fuente_salario) { $fuenteSal = [string]$fb.salario.fuente_salario }
        if ($fb.salario -and $fb.salario.especificado) {
            $salMin = $fb.salario.min; $salMax = $fb.salario.max
            $salarioTxt = [string]$fb.salario.texto_original
            if ($salarioTxt -eq '' -or $salarioTxt -eq 'A convenir') { $salarioTxt = 'No especificado' }
        }
    }

    $encolado = (Get-Date).ToString('o')
    if ($null -ne $prev -and [string]$prev.encoladoEn -ne '') { $encolado = [string]$prev.encoladoEn }

    $reg = [pscustomobject]@{
        clave = $clave
        id = $(if ($id -ne '') { $id } else { 'gen-' + (Hash-Texto $f.Name).Substring(0, 8) })
        archivo = $f.Name
        titulo = $titulo
        empresa = $empresa
        sector = $sector
        fuente = $fuente
        url = $url
        urlNormalizada = $urlNorm
        ubicacion = $ubi
        modalidad = $modal
        fechaPublicacion = $fPub
        fechaCierre = $fCie
        salario = [pscustomobject]@{
            min = $salMin; max = $salMax; moneda = 'PEN'
            texto = $salarioTxt; fuenteSalario = $fuenteSal
            especificado = ($salarioTxt -ne 'No especificado')
        }
        descripcion = $(if ($desc.Length -gt 600) { $desc.Substring(0, 600) } else { $desc })
        validacion = $validacion
        estadoPublicacion = $estado
        encoladoEn = $encolado
        actualizadoEn = (Get-Date).ToString('o')
    }

    $cola[$clave] = $reg
    if ($null -ne $prev) { $actualizadas++ }
    else {
        switch ($estado) {
            'HISTORICA' { $historicas++ }
            'EXPIRADA'  { $expiradas++ }
            'PUBLICADA' { }
            default     { $nuevas++ }
        }
    }
}

# ------------------------------------------------------------------ rechazadas
$rechEspejo = 0
if (Test-Path $RutaRechBum) {
    $existentes = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if (Test-Path $RutaRech) {
        foreach ($l in [IO.File]::ReadAllLines($RutaRech)) { $p = $l -split '\|'; if ($p.Count -ge 4) { [void]$existentes.Add(($p[2].Trim() + '|' + $p[3].Trim())) } }
    }
    foreach ($l in [IO.File]::ReadAllLines($RutaRechBum)) {
        $l = $l.Trim(); if ($l -eq '') { continue }
        $p = $l -split '\|'
        if ($p.Count -ge 4) {
            $k = ($p[2].Trim() + '|' + $p[3].Trim())
            if (-not $existentes.Contains($k)) {
                [IO.File]::AppendAllText($RutaRech, ($l + "`r`n"), $utf8)
                [void]$existentes.Add($k); $rechEspejo++
            }
        }
    }
}

# ------------------------------------------------------------------ salida
$lineas = New-Object System.Collections.Generic.List[string]
foreach ($k in ($cola.Keys | Sort-Object)) { $lineas.Add(($cola[$k] | ConvertTo-Json -Compress -Depth 6)) }
[IO.File]::WriteAllLines($RutaCola, [string[]]$lineas, $utf8)

$porEstado = @{}
foreach ($r in $cola.Values) { $e = [string]$r.estadoPublicacion; $porEstado[$e] = 1 + $(if ($porEstado.ContainsKey($e)) { $porEstado[$e] } else { 0 }) }

Log ("cola guardada: " + $RutaCola + "  (" + $cola.Count + " ofertas)")
Log ("esta corrida -> nuevas: " + $nuevas + " | historicas: " + $historicas + " | expiradas: " + $expiradas + " | repetidas de corrida previa: " + $actualizadas + " | duplicadas: " + $duplicadas + " | ya publicadas: " + $publicadasCnt)
foreach ($e in ($porEstado.Keys | Sort-Object)) { Log ("  estado " + $e + ": " + $porEstado[$e]) }
if ($rechEspejo -gt 0) { Log ("rechazadas nuevas reflejadas: " + $rechEspejo + " -> " + $RutaRech) }
exit 0
