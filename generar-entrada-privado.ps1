# generar-entrada-privado.ps1 - genera el HTML de una oferta del SECTOR PRIVADO
# (BuscoJobs / Computrabajo) a partir de su URL.
#
# USO (PowerShell):
#   .\generar-entrada-privado.ps1 -Url "https://www.buscojobs.pe/...."
#
# Baja la pagina, extrae los datos REALES (JSON-LD JobPosting + secciones del
# texto), rellena plantilla-oferta-data.html, valida con validar-entrada.ps1 y
# guarda fuentes\ + salida\. Sin portapapeles por defecto en lote (-SinPortapapeles).
#
# Devuelve exit code:
#   0 = OK (HTML guardado) | 0 = fuera de la ventana | 0 = repetida en otro portal
#   1 = error

param(
    [string]$Url = "",
    [int]$DiasMax = 4,
    [switch]$SinParafrasear,
    [switch]$SinPortapapeles
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
# librerias Fase A: DEBEN cargarse antes de definir Parafrasear-Texto local
. (Join-Path $raiz 'lib\categoria.ps1')
. (Join-Path $raiz 'lib\estandar.ps1')
. (Join-Path $raiz 'lib\reescritor.ps1')
$hoy  = Get-Date

try {

if ($Url.Trim() -eq "") { $Url = (Read-Host " URL de la publicacion").Trim() }
if ($Url -notmatch '^https?://') { Write-Host "ERROR: la URL debe empezar por http:// o https://"; exit 1 }

$portal = ""
if ($Url -match 'buscojobs\.pe')     { $portal = "BUSCOJOBS" }
elseif ($Url -match 'computrabajo\.com') { $portal = "COMPUTRABAJO" }
else { Write-Host "ERROR: portal no soportado (solo BuscoJobs o Computrabajo): $Url"; exit 1 }

# ------------------------------------------------------------------ descargar
Write-Host "== DESCARGANDO =="
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
$bytes = $null
for ($intento = 1; ; $intento++) {
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = $ua
    $wc.Headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    $wc.Headers['Accept-Language'] = 'es-PE,es;q=0.9'
    $wc.Headers['Accept-Encoding'] = 'identity'
    if ($portal -eq 'BUSCOJOBS') { $wc.Headers['Referer'] = 'https://www.buscojobs.pe/' }
    else { $wc.Headers['Referer'] = 'https://pe.computrabajo.com/' }
    try {
        $bytes = $wc.DownloadData($Url)
        break
    } catch {
        $ex = $_.Exception
        while ($ex -and -not $ex.Response) { $ex = $ex.InnerException }
        $cod = 0
        if ($ex -and $ex.Response) { $cod = [int]$ex.Response.StatusCode }
        if (($cod -eq 405 -or $cod -eq 403) -and $intento -lt 4) {
            $espera = 90 * $intento
            Write-Host ("  HTTP " + $cod + " - rate limit, espero " + $espera + "s (intento " + $intento + "/3)")
            Start-Sleep -Seconds $espera
        } else { throw }
    }
}
$src   = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host ("  HTTP OK - " + $bytes.Length + " bytes")

# ------------------------------------------------------------------ JSON-LD
$ld = $null
foreach ($m in [regex]::Matches($src, '(?is)<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>')) {
    try {
        $o = $m.Groups[1].Value.Trim() | ConvertFrom-Json
        if ($o.'@type' -eq 'JobPosting') { $ld = $o; break }
        if ($o.'@graph') {
            foreach ($g in @($o.'@graph')) {
                if ($g.'@type' -eq 'JobPosting') { $ld = $g; break }
            }
            if ($ld) { break }
        }
    } catch { }
}
if (-not $ld) { Write-Host "ERROR: la pagina no trae JSON-LD JobPosting"; exit 1 }

# ------------------------------------------------------------------ utilidades
function Limpio([string]$t) {
    $s = [string]$t
    $s = $s -replace '(?i)<br\s*/?>', ' '
    $s = $s -replace '<[^>]+>', ' '
    $s = [Net.WebUtility]::HtmlDecode($s)
    # etiquetas creadas por decodificar entidades y etiquetas cortadas sin '>' por
    # ventanas truncadas (ej. <a href="/cdn-cgi/..." cortado a mitad)
    $s = $s -replace '<[a-zA-Z/!][^>]*>', ' '
    $s = $s -replace '<[a-zA-Z/!][^>]*$', ' '
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}
function Sin-Acentos([string]$s) {
    $x = [string]$s
    $x = $x.ToLower()
    $x = $x.Normalize([Text.NormalizationForm]::FormD)
    $x = [regex]::Replace($x, '[\u0300-\u036f]', '')
    return $x
}
function Fecha-Date([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $t = $s.Trim()
    if ($t.Length -ge 10) {
        try { return [datetime]::ParseExact($t.Substring(0,10), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { }
    }
    try { return [datetime]::Parse($t, [Globalization.CultureInfo]::InvariantCulture) } catch { return $null }
}

# --------------------------------------------------------------- parafraseo
$mapPara = @{
  'apoyar en'='brindar apoyo en';        'colaborar en'='prestar colaboracion en'
  'colaborar con'='prestar colaboracion con'; 'participar en'='tomar parte en'
  'llevar a cabo'='ejecutar';            'realizar'='efectuar'
  'elaborar'='preparar';                 'mantener'='conservar'
  'supervisar'='vigilar';                'verificar'='comprobar'
  'revisar'='examinar';                  'organizar'='coordinar'
  'atender'='asistir';                   'brindar'='ofrecer'
  'aplicar'='emplear';                   'controlar'='supervisar'
  'registrar'='asentar';                 'generar'='producir'
  'identificar'='detectar';              'evaluar'='valorar'
  'analizar'='estudiar';                 'orientar'='asesorar'
  'capacitar'='formar';                  'utilizar'='emplear'
  'usar'='emplear';                      'obtener'='conseguir'
  'definir'='establecer';                'determinar'='fijar'
  'crear'='elaborar';                    'enviar'='remitir'
  'recibir'='recepcionar';               'presentar'='entregar'
  'así como'='y también';                'a través de'='mediante'
  'por medio de'='mediante';             'con el fin de'='para'
  'con el objetivo de'='para';           'con el propósito de'='para'
  'con la finalidad de'='para';          'a fin de'='para'
  'en el marco de'='dentro de';          'con respecto a'='sobre'
  'con base en'='según';                 'de conformidad con'='según'
  'en relación con'='respecto a';        'de manera'='de forma'
  'de forma'='de manera';                'posterior a'='después de'
  'previo a'='antes de';                 'dicho'='este'
  'dicha'='esta';                        'dichos'='estos'
  'dichas'='estas';                      'actualmente'='en la actualidad'
  'posteriormente'='luego';              'previamente'='antes'
  'principalmente'='sobre todo';         'especialmente'='en particular'
  'también'='asimismo';                  'diferentes'='distintos'
  'documentos'='archivos';               'reuniones'='sesiones'
  'informes'='reportes';                 'reportes'='informes'
  'solicitudes'='peticiones';            'tareas'='labores'
  'actividades'='tareas';                'elaboración'='creación'
  'necesario'='requerido';               'necesarios'='requeridos'
  'importante'='relevante';              'emitida'='enviada'
  'emitidas'='enviadas';                 'emitido'='enviado'
  'emitidos'='enviados'
}
$rxPara = [regex]::new('(?i)\b(' + (($mapPara.Keys | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b')

function Parafrasear-Texto([string]$texto) {
    if ([string]::IsNullOrWhiteSpace($texto)) { return $texto }
    if ($SinParafrasear) { return $texto }
    if ($texto -match '(?i)no especificado') { return $texto }
    if ($texto -match '^https?://') { return $texto }
    $n = @(($texto -split '\s+') | Where-Object { $_ -ne '' }).Count
    if ($n -lt 15) { return $texto }
    $t = $texto
    $t = $rxPara.Replace($t, {
        param($mm)
        $rep = $mapPara[$mm.Value]
        if ($null -eq $rep) { return $mm.Value }
        if ([char]::IsUpper($mm.Value[0])) { $rep = $rep.Substring(0,1).ToUpper() + $rep.Substring(1) }
        return $rep
    })
    $trozos = [regex]::Split($t, '(?<!\w\.)\.(?=\s+[A-ZÁÉÍÓÚÑ])')
    if ($trozos.Count -gt 1) {
        $conectores = @('Además, ', 'Asimismo, ', 'De igual forma, ')
        $sal = $trozos[0]
        for ($k = 1; $k -lt $trozos.Count; $k++) {
            $seg = $trozos[$k]
            if ($seg -match '^[A-ZÁÉÍÓÚÑ]' -and $seg -notmatch '^[A-Z]{2,}') { $seg = $seg.Substring(0,1).ToLower() + $seg.Substring(1) }
            $sal += '. ' + $conectores[(($k - 1) % 3)] + $seg
        }
        $t = $sal
    }
    return $t
}

# ------------------------------------------------------------------ ventana
$fPub = ""; $fCie = ""
if ($ld.datePosted)   { $fPub = [string]$ld.datePosted }
if ($ld.validThrough) { $fCie = [string]$ld.validThrough }
$dp = Fecha-Date $fPub
if ($dp -ne $null -and $dp.Date -lt $hoy.Date.AddDays(-$DiasMax)) {
    Write-Host ("RESULTADO: OK - fuera de la ventana (publicada " + $dp.ToString('dd/MM/yyyy') + "); no se genera.")
    exit 0
}

# ------------------------------------------------------------------ titulo
$titulo = ""
$m = [regex]::Match($src, '(?is)<h1[^>]*>([\s\S]*?)</h1>')
if ($m.Success) { $titulo = (Limpio $m.Groups[1].Value) }
if ($titulo -eq "" -and $ld.title) { $titulo = ([string]$ld.title).Trim() }
if ($titulo -eq "") {
    $m = [regex]::Match($src, '(?is)<h1[^>]*>([\s\S]*?)</h1>')
    if ($m.Success) { $titulo = (Limpio $m.Groups[1].Value) }
}
if ($titulo -eq "") {
    $m = [regex]::Match($src, '(?is)<title[^>]*>([\s\S]*?)</title>')
    if ($m.Success) { $titulo = ((Limpio $m.Groups[1].Value) -split '\s+[-|]\s+')[0] }
}
if ($titulo -eq "") { Write-Host "ERROR: no pude extraer el titulo de la oferta"; exit 1 }

# ------------------------------------------------------------------ descripcion -> lineas
$d = [string]$ld.description
$d = $d -replace '(?i)</p>', "`n"
$d = $d -replace '(?i)<br\s*/?>', "`n"
$d = $d -replace '(?i)</li>', "`n"
$d = $d -replace '(?i)<li[^>]*>', '- '
$d = $d -replace '<[^>]+>', ' '
$d = [Net.WebUtility]::HtmlDecode($d)
$lineas = New-Object System.Collections.Generic.List[string]
foreach ($ln in ($d -split "`n")) {
    $t = ($ln -replace '\s+', ' ').Trim()
    $t = $t -replace '^[•·o\-–—]+\s*', ''
    if ($t -ne '') { $lineas.Add($t) }
}
if ($lineas.Count -eq 0) { Write-Host "ERROR: la descripcion del JSON-LD esta vacia"; exit 1 }

# ------------------------------------------------------- secciones del texto
$hdrSet = @{
  'funcion'='funcs'; 'funciones'='funcs'; 'funciones principales'='funcs'
  'responsabilidades'='funcs'; 'actividades'='funcs'; 'mis funciones'='funcs'
  'funciones del puesto'='funcs'
  'requisito'='reqs'; 'requisitos'='reqs'; 'perfil'='reqs'; 'requerimientos'='reqs'
  'que buscamos'='reqs'; 'competencias'='reqs'; 'estudios requeridos'='reqs'
  'perfil del candidato'='reqs'; 'requisitos minimos'='reqs'
  'ofrecemos'='bens'; 'que ofrecemos'='bens'; 'beneficio'='bens'; 'beneficios'='bens'
  'condiciones labores'='bens'; 'condiciones laborales'='bens'
  'lo que ofrecemos'='bens'; 'te ofrecemos'='bens'
  'sobre nosotros'='empresaSec'; 'sobre la empresa'='empresaSec'
  'la empresa'='empresaSec'
  'resumen del puesto'='intro'; 'resumen'='intro'; 'descripcion del puesto'='intro'
  'sobre la vacante'='intro'; 'descripcion'='intro'; 'puesto'='intro'
}
$hdrCampo = @{
  'tipo de puesto'='tipoPuesto'; 'tipo de contrato'='tipoPuesto'
  'lugar de trabajo'='lugar'; 'modalidad'='modalidad'
  'salario'='salarioPagina'; 'salario nominal'='salarioPagina'
  'vacantes'='vacantes'; 'jornada'='jornada'
  'experiencia'='experiencia'
  'estudios'='estudios'; 'formacion academica'='estudios'; 'formacion'='estudios'
  'sector'='sector'; 'ubicacion'='ubicacionPagina'
  'area'='area'; 'nivel'='nivel'; 'turno'='turno'; 'horario'='horario'
  'dirigido a'='dirigidoA'; 'publico objetivo'='dirigidoA'; 'perfil dirigido'='dirigidoA'
}
$funcs = New-Object System.Collections.Generic.List[string]
$reqs  = New-Object System.Collections.Generic.List[string]
$bens  = New-Object System.Collections.Generic.List[string]
$empresaSec = New-Object System.Collections.Generic.List[string]
$intro = New-Object System.Collections.Generic.List[string]
$campoValor = @{}
$actual = 'intro'
foreach ($ln in $lineas) {
    $norm = Sin-Acentos $ln
    $hd = $null; $val = ''
    if ($norm -match '^([a-z /]+?)\s*:\s*(.+)$') { $hd = $Matches[1].Trim(); $val = $Matches[2].Trim() }
    elseif ($norm -match '^([a-z /]+?)\s*:\s*$') { $hd = $Matches[1].Trim() }
    $procesado = $false
    if ($hd -and $hdrSet.ContainsKey($hd)) {
        $tipo = $hdrSet[$hd]
        if ($val -ne '') {
            if ($tipo -eq 'funcs') { $funcs.Add($val) }
            elseif ($tipo -eq 'reqs') { $reqs.Add($val) }
            elseif ($tipo -eq 'bens') { $bens.Add($val) }
            elseif ($tipo -eq 'empresaSec') { $empresaSec.Add($val) }
            else { $intro.Add($val) }
        }
        $actual = $tipo
        $procesado = $true
    }
    elseif ($hd -and $hdrCampo.ContainsKey($hd)) {
        if ($val -ne '' -and -not $campoValor.ContainsKey($hd)) { $campoValor[$hd] = $val }
        $actual = 'campo:' + $hd
        $procesado = $true
    }
    if (-not $procesado) {
        if ($actual -eq 'funcs') { $funcs.Add($ln) }
        elseif ($actual -eq 'reqs') { $reqs.Add($ln) }
        elseif ($actual -eq 'bens') { $bens.Add($ln) }
        elseif ($actual -eq 'empresaSec') { $empresaSec.Add($ln) }
        elseif ($actual -eq 'intro') { $intro.Add($ln) }
        elseif ($actual -like 'campo:*') {
            $c = $actual.Substring(6)
            if (-not $campoValor.ContainsKey($c)) { $campoValor[$c] = $ln }
        }
    }
}
function Campo([string[]]$nombres) {
    foreach ($n in $nombres) { if ($campoValor.ContainsKey($n)) { return [string]$campoValor[$n] } }
    return ''
}

# ------------------------------------------------------------------ empresa
$empresa = ""
if ($ld.hiringOrganization -and $ld.hiringOrganization.name) {
    $empresa = ([string]$ld.hiringOrganization.name).Trim()
}
$generico = @('empresas','empresa','ver empresas','empleos','inicio','ingresar','iniciar sesion','registrarse')
if ($empresa -eq "" -and $portal -eq 'BUSCOJOBS') {
    foreach ($mm in [regex]::Matches($src, '(?is)<a[^>]+href="[^"]*buscojobs\.pe/empres[^"]*"[^>]*>([\s\S]{0,150}?)</a>')) {
        $c = (Limpio $mm.Groups[1].Value).Trim()
        if ($c.Length -ge 4 -and $c.Length -le 70 -and ($generico -notcontains (Sin-Acentos $c))) { $empresa = $c; break }
    }
}
if ($empresa -eq "" -and $intro.Count -gt 0) {
    $m = [regex]::Match($intro[0], '(?i)^(.{3,80}?)\s+(?:busca|requiere|contrata|necesita|queremos|estamos en busca|buscamos)')
    if ($m.Success) { $empresa = $m.Groups[1].Value.Trim().TrimEnd(',').Trim() }
}
if ($empresa -eq "" -and $intro.Count -gt 0) {
    $m = [regex]::Match($intro[0], '(?i)^en\s+([A-Z\xC1\xC9\xCD\xD3\xDA\xD1][^.,;]{2,70})')
    if ($m.Success) { $empresa = $m.Groups[1].Value.Trim() }
}
if ($empresa -eq "" -and $intro.Count -gt 0) {
    $m = [regex]::Match($intro[0], '^[A-Z][^.,;]{2,70}?(?:S\.?\s?A\.?\s?C\.?|S\.?\s?A\.?|E\.?\s?I\.?\s?R\.?\s?L\.?|S\.?\s?R\.?\s?L\.?)\.?')
    if ($m.Success) { $empresa = $m.Value.Trim() }
}
$empresa = ($empresa -replace '\s+', ' ').Trim()
if ($empresa.Length -lt 4) { $empresa = "" }

# ------------------------------------------------------------------ ubicacion
$ciudad = ""; $region = ""; $pais = ""
$jl = $null
if ($ld.jobLocation) { $jl = @($ld.jobLocation)[0] }
if ($jl -and $jl.address) {
    $a = $jl.address
    if ($a.addressLocality) { $ciudad = ([string]$a.addressLocality).Trim() }
    if ($a.addressRegion)   { $region = ([string]$a.addressRegion).Trim() }
    if ($a.addressCountry)  { $pais   = ([string]$a.addressCountry).Trim() }
}
$paisTxt = "Perú"
if ($pais -ne "" -and $pais -notin @('PE','Peru','Perú','PER')) { $paisTxt = $pais }
$ubi = "No especificado"
$partes = @()
if ($ciudad -ne "") { $partes += $ciudad }
if ($region -ne "" -and $region -ne $ciudad) { $partes += $region }
if ($partes.Count -gt 0) { $ubi = ($partes -join ', ') + ', ' + $paisTxt }
$ubi = Est-Ubicacion $ubi

# ------------------------------------------------------------------ salario
$salario = "No especificado"
if ($ld.baseSalary) {
    $bs = $ld.baseSalary
    $n = $null; $nMin = $null; $nMax = $null; $unit = ""
    $val = $null
    if ($bs.value -is [System.Management.Automation.PSCustomObject]) {
        $val = $bs.value
        if ($bs.value.unitText) { $unit = ([string]$bs.value.unitText).ToUpper() }
        if ($bs.value.value -ne $null -and [string]$bs.value.value -ne '') {
            try { $n = [double]::Parse([string]$bs.value.value, [Globalization.CultureInfo]::InvariantCulture) } catch { $n = $null }
        }
        if ($bs.value.minValue -ne $null -and [string]$bs.value.minValue -ne '') {
            try { $nMin = [double]::Parse([string]$bs.value.minValue, [Globalization.CultureInfo]::InvariantCulture) } catch { $nMin = $null }
        }
        if ($bs.value.maxValue -ne $null -and [string]$bs.value.maxValue -ne '') {
            try { $nMax = [double]::Parse([string]$bs.value.maxValue, [Globalization.CultureInfo]::InvariantCulture) } catch { $nMax = $null }
        }
    } else {
        $val = $bs.value
        if ($bs.unitText) { $unit = ([string]$bs.unitText).ToUpper() }
        if ($val -ne $null -and [string]$val -ne '') {
            try { $n = [double]::Parse([string]$val, [Globalization.CultureInfo]::InvariantCulture) } catch { $n = $null }
        }
    }
    if ($bs.unitText -and $unit -eq "") { $unit = ([string]$bs.unitText).ToUpper() }
    $fmtN = { param($v) ([decimal]$v).ToString('#,0', [Globalization.CultureInfo]::InvariantCulture) }
    if ($n -ne $null -and $n -gt 0) {
        $salario = 'S/ ' + (& $fmtN $n)
    } elseif ($nMin -ne $null -and $nMax -ne $null -and $nMin -gt 0 -and $nMax -gt 0) {
        $salario = 'S/ ' + (& $fmtN $nMin) + ' a S/ ' + (& $fmtN $nMax)
    } elseif ($nMin -ne $null -and $nMin -gt 0) {
        $salario = 'S/ ' + (& $fmtN $nMin)
    }
    if ($salario -ne "No especificado" -and $unit -match 'HOUR') { $salario = $salario + ' por hora' }
}
$salarioPagina = Campo @('salario','salario nominal')
if ($salario -eq "No especificado" -and $salarioPagina -ne "") {
    $sp = ([Net.WebUtility]::HtmlDecode($salarioPagina) -replace '[•·]', '').Trim()
    $mS = [regex]::Match($sp, '(?i)S/\s*\.?\s*([\d.,]+)')
    if ($mS.Success -and $mS.Groups[1].Value -notmatch '^0+([.,]0+)?$') { $salario = 'S/ ' + $mS.Groups[1].Value }
    elseif ($mS.Success -eq $false -and $sp.Length -gt 2 -and $sp.Length -le 40) { $salario = $sp }
}
if ($salario -eq "No especificado") {
    # busqueda ETIQUETADA en la pagina (con dos puntos); jamas un S/ suelto del sidebar
    $mS = [regex]::Match($src, '(?i)Salario(?:\s+Nominal)?\s*:\s*(?:<[^>]+>\s*){0,4}([^<\n]{1,40})')
    if ($mS.Success) {
        $sv = ([Net.WebUtility]::HtmlDecode($mS.Groups[1].Value) -replace '[•·]', '').Trim()
        $mNum = [regex]::Match($sv, '(?i)S/\s*\.?\s*([\d.,]+)')
        if ($mNum.Success -and $mNum.Groups[1].Value -notmatch '^0+([.,]0+)?$') { $salario = 'S/ ' + $mNum.Groups[1].Value }
        elseif ($mNum.Success -eq $false -and $sv.Length -ge 3 -and $sv.Length -le 40 -and $sv -notmatch '^0+([.,]0+)?$') { $salario = $sv }
    }
}
# forma canonica del glosario (Fase A): 'S/ 1,800' | rango | 'por hora' | catalogo
$salario = Est-Salario -Texto $salario

# ------------------------------------------------------------------ contrato
$contrato = "No especificado"
$et = ""
if ($ld.employmentType) { $et = ([string]$ld.employmentType).Trim().ToUpper() }
switch ($et) {
    'FULL_TIME'  { $contrato = 'Full-time' }
    'PART_TIME'  { $contrato = 'Part-time' }
    'TEMPORARY'  { $contrato = 'Temporal' }
    'CONTRACT'   { $contrato = 'Por contrato' }
    'INTERN'     { $contrato = 'Pasantía' }
    'VOLUNTEER'  { $contrato = 'Voluntariado' }
}
if ($contrato -eq "No especificado") {
    $ct = (Campo @('tipoPuesto')).Trim()
    if ($ct.Length -gt 2 -and $ct.Length -le 40) { $contrato = Est-Contrato $ct }
}

# ------------------------------------------------------------------ modalidad
$modalidad = "No especificado"
foreach ($cand in @((Campo @('modalidad')), (Campo @('lugar')))) {
    if ($cand -eq '') { continue }
    if ($cand -match '(?i)presencial')      { $modalidad = 'Presencial'; break }
    if ($cand -match '(?i)remoto|teletrabajo|home\s*office') { $modalidad = 'Remoto'; break }
    if ($cand -match '(?i)h[ií]brido')      { $modalidad = 'Híbrido'; break }
}
if ($modalidad -eq "No especificado") {
    if ($d -match '(?i)modalidad\s+(?:de\s+trabajo\s+)?(presencial|remoto|h[ií]brido)') { $modalidad = (Get-Culture).TextInfo.ToTitleCase($Matches[1].ToLower()) }
    elseif ($d -match '(?i)(?:esquema|modalidad)\s*:\s*(presencial|remoto|h[ií]brido)') { $modalidad = (Get-Culture).TextInfo.ToTitleCase($Matches[1].ToLower()) }
}
if ($modalidad -eq "No especificado") {
    $mMo = [regex]::Match($src, '(?i)Modalidad(?:\s+de\s+trabajo)?\s*:\s*(?:<[^>]+>\s*){0,4}(presencial|remoto|h[ií]brido)')
    if ($mMo.Success) { $modalidad = (Get-Culture).TextInfo.ToTitleCase($mMo.Groups[1].Value.ToLower()) }
}
if ($modalidad -match '(?i)^h[ií]brido$') { $modalidad = 'Híbrido' }
$modalidad = Est-Modalidad $modalidad

# ------------------------------------------------------------------ vacantes / jornada / experiencia / estudios
$vacantes = "No especificado"
$mv = Campo @('vacantes')
if ($mv -ne "") {
    $mV = [regex]::Match($mv, '\d+')
    if ($mV.Success -and [int]$mV.Value -gt 0) { $vacantes = $mV.Value }
}
if ($vacantes -eq "No especificado") {
    $mV = [regex]::Match($d, '(?i)\b(\d{1,3})\s*(?:vacantes?|puestos?|plazas?)\b')
    if ($mV.Success -and [int]$mV.Value -gt 0) { $vacantes = $mV.Value }
}
if ($vacantes -eq "No especificado" -and $ld.totalJobOpenings) {
    try { if ([int]$ld.totalJobOpenings -gt 0) { $vacantes = [string]([int]$ld.totalJobOpenings) } } catch { }
}
$vacantes = Est-Vacantes $vacantes

$jornada = "No especificado"
$mJ = Campo @('jornada')
if ($mJ.Length -gt 1 -and $mJ.Length -le 60) { $jornada = $mJ }
if ($jornada -eq "No especificado" -and $ld.workHours) {
    $wh = ([string]$ld.workHours).Trim()
    if ($wh.Length -gt 1 -and $wh.Length -le 60) { $jornada = $wh }
}
if ($jornada -eq "No especificado") {
    $mJ2 = [regex]::Match($src, '(?is)Jornada\s*:\s*(?:<[^>]+>\s*){0,4}([^<\n]{2,60})')
    if ($mJ2.Success) { $j2 = (Limpio $mJ2.Groups[1].Value); if ($j2.Length -ge 2 -and $j2.Length -le 60) { $jornada = $j2 } }
}
$jornada = Est-Jornada $jornada

$experiencia = "No especificado"
$mEx = Campo @('experiencia')
if ($mEx.Length -gt 1 -and $mEx.Length -le 160) { $experiencia = $mEx }
if ($experiencia -eq "No especificado" -and $ld.experienceRequirements) {
    $xr = ""
    if ($ld.experienceRequirements -is [System.Management.Automation.PSCustomObject]) {
        if ($ld.experienceRequirements.description) { $xr = [string]$ld.experienceRequirements.description }
    } else { $xr = [string]$ld.experienceRequirements }
    $xr = ($xr -replace '<[^>]+>', ' ').Trim()
    if ($xr.Length -gt 1 -and $xr.Length -le 160) { $experiencia = $xr }
}
$experiencia = Parafrasear-Texto $experiencia

$estudios = "No especificado"
$mEs = Campo @('estudios','formacion academica','formacion')
if ($mEs.Length -gt 1 -and $mEs.Length -le 160) { $estudios = $mEs }
if ($estudios -eq "No especificado" -and $ld.educationRequirements) {
    $cat = ""
    if ($ld.educationRequirements -is [System.Management.Automation.PSCustomObject]) {
        if ($ld.educationRequirements.credentialCategory) { $cat = [string]$ld.educationRequirements.credentialCategory }
    } else { $cat = [string]$ld.educationRequirements }
    if ($cat -ne "") {
        $mapEduc = @{
          'high school'='Secundaria completa'; 'secondary school'='Secundaria completa'
          'bachelor degree'='Título profesional'; 'associate degree'='Técnico universitario'
          'vocational'='Formación técnica'; 'some college'='Estudios universitarios en curso'
          'master'='Maestría'; 'doctoral'='Doctorado'; 'professional degree'='Título profesional'
        }
        $catL = Sin-Acentos $cat
        if ($mapEduc.ContainsKey($catL)) { $estudios = $mapEduc[$catL] }
        elseif ($cat.Length -le 80) { $estudios = $cat }
    }
}
$estudios = Parafrasear-Texto $estudios

# ------------------------------------------------------------------ fechas
$fPubTxt = ""
if ($dp -ne $null) { $fPubTxt = $dp.ToString('dd/MM/yyyy') }
if ($fPubTxt -eq "") { $fPubTxt = $hoy.ToString('dd/MM/yyyy') }
$fCieTxt = ""
$dc = Fecha-Date $fCie
if ($dc -ne $null) { $fCieTxt = $dc.ToString('dd/MM/yyyy') }

# ------------------------------------------------------------------ categoria
# Fase A: clasificador canonico compartido (lib\categoria.ps1). Debe resolver
# el bug "Analista Contable" -> Otros/Ingenieria (ahora -> Administración y Finanzas).
$industry = ""
if ($ld.industry) { $industry = ((@($ld.industry) | ForEach-Object { [string]$_ }) -join ', ') }
$skills = ""
if ($ld.skills) { $skills = ([string]$ld.skills) }
$categoria = Obtener-CategoriaExacta -Titulo $titulo -Texto ($industry + " " + $skills + " " + (($intro | Select-Object -First 4) -join ' '))

# ------------------------------------------------------------------ empresa: resto de campos
$sector = "No especificado"
$secCampo = Campo @('sector')
if ($secCampo.Length -gt 2 -and $secCampo.Length -le 60) { $sector = $secCampo }
elseif ($industry -ne "") { $sector = $industry }

$tamano = "No especificado"
$mT = [regex]::Match($src, '(?i)(\d[\d.,]*\s*(?:-|a|–)\s*\d[\d.,]*\s*empleados|\d[\d.,]*\s*\+?\s*empleados)')
if ($mT.Success) { $tamano = (($mT.Value -replace '\s+', ' ').Trim()) }

$ubiEmp = "No especificado"
if ($ld.hiringOrganization -and $ld.hiringOrganization.address) {
    $aE = $ld.hiringOrganization.address
    $pe = @()
    if ($aE.addressLocality) { $pe += ([string]$aE.addressLocality).Trim() }
    if ($aE.addressRegion -and $aE.addressRegion -ne $aE.addressLocality) { $pe += ([string]$aE.addressRegion).Trim() }
    if ($pe.Count -gt 0) { $ubiEmp = ($pe -join ', ') + ', ' + $paisTxt }
}

$descEmp = "No especificado"
if ($empresaSec.Count -gt 0) {
    foreach ($ln in $empresaSec) { if ($ln.Length -ge 40) { $descEmp = $ln; break } }
}
$descEmp = Parafrasear-Texto $descEmp

# ------------------------------------------------------------------ textos propios
# p1 y p2: parrafos de 1 a 3 frases REALES (sin texto generico de relleno)
$usadas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$fr1 = New-Object System.Collections.Generic.List[string]
foreach ($ln in (@($intro) + @($funcs))) {
    if ($ln.Length -lt 40 -or $ln -match ':\s*$') { continue }
    if (-not $usadas.Add($ln)) { continue }
    $fr1.Add($ln)
    if ($fr1.Count -ge 3) { break }
}
if ($fr1.Count -eq 0) {
    foreach ($ln in $lineas) {
        $cand = ($ln -replace ':\s*$', '').Trim()
        if ($cand.Length -ge 20) { $fr1.Add($cand); break }
    }
}
$p1 = ($fr1 -join ' ')

$fr2 = New-Object System.Collections.Generic.List[string]
foreach ($ln in (@($empresaSec) + @($intro) + @($funcs) + @($reqs) + @($bens))) {
    if ($ln.Length -lt 40 -or $ln -match ':\s*$') { continue }
    if (-not $usadas.Add($ln)) { continue }
    $fr2.Add($ln)
    if ($fr2.Count -ge 3) { break }
}
$p2 = ($fr2 -join ' ')
$p1 = Parafrasear-Texto $p1
$p2 = Parafrasear-Texto $p2

# ------------------------------------------------------------------ URL_POSTULAR
$urlPostular = ""
$m = [regex]::Match($src, '(?is)<link[^>]+rel="canonical"[^>]+href="([^"]+)"')
if (-not $m.Success) { $m = [regex]::Match($src, '(?is)<link[^>]+href="([^"]+)"[^>]+rel="canonical"') }
if ($m.Success -and $src.Contains($m.Groups[1].Value)) { $urlPostular = $m.Groups[1].Value }
if ($urlPostular -eq "") {
    $m = [regex]::Match($src, '"UrlOferta"\s*:\s*"(https?://[^"]+)"')
    if ($m.Success -and $src.Contains($m.Groups[1].Value)) { $urlPostular = $m.Groups[1].Value }
}
if ($urlPostular -eq "") {
    $u0 = $Url -replace '#.*$', ''
    if ($src.Contains($u0)) { $urlPostular = $u0 }
}
if ($urlPostular -eq "" -and $src.Contains($Url)) { $urlPostular = $Url }
if ($urlPostular -eq "") { Write-Host "ERROR: no encuentro la URL de la oferta dentro de la propia pagina (no puedo fijar URL_POSTULAR)"; exit 1 }

# ------------------------------------------------------------------ clave antirepeticion (BuscoJobs vs Computrabajo)
$stopClave = @('de','del','la','el','los','las','en','y','a','con','para','por','un','una','que','se','al','su','sus','o','u','the','of','and','is','for')
function NClave([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $t = Sin-Acentos $s
    $t = $t -replace '[^a-z0-9]+', ' '
    $toks = @($t -split ' ' | Where-Object { $_ -ne '' -and ($stopClave -notcontains $_) })
    $toks = @($toks | Sort-Object)
    return ($toks -join ' ')
}
$clave = (NClave $titulo) + '|' + (NClave $empresa) + '|' + (NClave $ciudad)
$clavesPath = Join-Path $raiz 'historial-claves.txt'
$claves = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $clavesPath) {
    foreach ($l in [IO.File]::ReadAllLines($clavesPath)) { $l = $l.Trim(); if ($l -ne '') { [void]$claves.Add($l) } }
}
if ($claves.Contains($clave)) {
    Write-Host "RESULTADO: OK - repetida en otro portal (misma clave); no se genera."
    exit 0
}

# ------------------------------------------------------------------ template
$plantilla = Join-Path $raiz 'plantilla-oferta-data.html'
if (-not (Test-Path -LiteralPath $plantilla)) { Write-Host "ERROR: falta $plantilla"; exit 1 }
$html = [System.IO.File]::ReadAllText($plantilla, [System.Text.Encoding]::UTF8)

# sin frase real para P1: se elimina el parrafo completo (nada de relleno)
if ($p1 -eq '') { $html = [regex]::Replace($html, '(?s)\s*<p>\s*@@DESCRIPCION_P1@@\s*</p>', '') }
# sin frase real para P2: se elimina el parrafo completo (nada de relleno)
if ($p2 -eq '') { $html = [regex]::Replace($html, '(?s)\s*<p>\s*@@DESCRIPCION_P2@@\s*</p>', '') }
# sin descripcion de empresa: se elimina ese parrafo (evita 'No especificado' multilinea)
if ($descEmp -eq 'No especificado') { $html = [regex]::Replace($html, '(?s)\s*<p>\s*<strong>Descripci(?:ó|o)n:</strong>\s*@@DESCRIPCION_EMPRESA@@\s*</p>', '') }

function Rellenar-UL([string]$h, [string]$tituloH2, [System.Collections.Generic.List[string]]$items, [int]$max) {
    $usados = New-Object System.Collections.Generic.List[string]
    foreach ($it in $items) { if ($usados.Count -ge $max) { break }; $usados.Add($it) }
    if ($usados.Count -eq 0) {
        # sin contenido real: se elimina la seccion entera (nada de texto generico)
        $rx = '(?s)<div class="empleo-seccion">\s*<h2>' + [regex]::Escape($tituloH2) + '</h2>\s*<ul>[\s\S]*?</ul>\s*</div>\s*'
        $nuevo = [regex]::Replace($h, $rx, '')
        if ($nuevo -eq $h) { $nuevo = [regex]::Replace($h, '(?s)<h2>' + [regex]::Escape($tituloH2) + '</h2>\s*<ul>[\s\S]*?</ul>\s*', '') }
        return $nuevo
    }
    $lis = ''
    foreach ($it in $usados) { $lis += '    <li>' + $it + '</li>' + "`n" }
    $nuevo = [regex]::Replace($h, '(?s)(<h2>' + [regex]::Escape($tituloH2) + '</h2>\s*<ul>)[\s\S]*?(</ul>)', {
        param($mm) $mm.Groups[1].Value + "`n" + $lis + '  ' + $mm.Groups[2].Value
    })
    if ($nuevo -eq $h) { Write-Host ("  AVISO: no se encontro la lista <ul> de '" + $tituloH2 + "'") }
    return $nuevo
}
$html = Rellenar-UL $html 'Funciones'    $funcs 10
$html = Rellenar-UL $html 'Requisitos'   $reqs  8
$html = Rellenar-UL $html 'Beneficios'   $bens  6

$empresaOut = $empresa
if ($empresaOut -eq "") {
    $empresaOut = 'No especificada'
    $html = [regex]::Replace($html, '(?m)^\s*<div class="empleo-empresa">[\s\S]*?</div>\r?\n', '')
}

# campos extra del bloque oculto (Fase A): si la pagina no los trae o son
# basura larga => 'No especificado' (las lineas del destacado se auto-borran)
function Campo-Corto([string[]]$nombres, [int]$max = 60) {
    $v = (Campo $nombres)
    $v = ($v -replace '\s+', ' ').Trim()
    if ($v.Length -gt $max) { $v = '' }
    return $v
}
$dirTxt  = Campo-Corto @('dirigido a', 'publico objetivo', 'perfil dirigido')
$areaTxt = Campo-Corto @('area')
$nivTxt  = Campo-Corto @('nivel')
$turnoTxt = Campo-Corto @('turno')
$horTxt  = Campo-Corto @('horario')

$map = @{
 '@@FUENTE@@'              = $portal
 '@@CATEGORIA@@'            = $categoria
 '@@TITULO@@'               = $titulo
 '@@EMPRESA@@'              = $empresaOut
 '@@EMPRESA2@@'             = $empresaOut
 '@@SALARIO_HEADER@@'       = $salario
 '@@SALARIO@@'              = $salario
 '@@SALARIO2@@'             = $salario
 '@@UBICACION@@'            = $ubi
 '@@CIUDAD@@'               = $(if ($ciudad -ne '') { $ciudad } else { 'No especificado' })
 '@@MODALIDAD@@'            = $modalidad
 '@@MODALIDAD2@@'           = $modalidad
 '@@CONTRATO@@'             = $contrato
 '@@CONTRATO2@@'            = $contrato
 '@@DESCRIPCION_P1@@'       = $p1
 '@@DESCRIPCION_P2@@'       = $p2
 '@@VACANTES@@'             = $vacantes
 '@@JORNADA@@'              = $jornada
 '@@EXPERIENCIA@@'          = $experiencia
 '@@ESTUDIOS@@'             = $estudios
 '@@DIRIGIDO_A@@'           = $(if ($dirTxt -ne '') { $dirTxt } else { 'No especificado' })
 '@@AREA@@'                 = $(if ($areaTxt -ne '') { $areaTxt } else { 'No especificado' })
 '@@NIVEL@@'                = $(if ($nivTxt -ne '') { $nivTxt } else { 'No especificado' })
 '@@TURNO@@'                = $(if ($turnoTxt -ne '') { $turnoTxt } else { 'No especificado' })
 '@@HORARIO@@'              = $(if ($horTxt -ne '') { $horTxt } else { 'No especificado' })
 '@@FECHA_PUBLICACION@@'    = $fPubTxt
 '@@FECHA_CIERRE@@'         = $(if ($fCieTxt -ne "") { $fCieTxt } else { 'No especificado' })
 '@@TIPO_CONTRATANTE@@'     = 'Privado'
 '@@TIPO_CONTRATO_ESTADO@@' = 'No aplica'
 '@@TIPO_ENTIDAD@@'         = 'No aplica'
 '@@SECTOR@@'               = $sector
 '@@TAMANO@@'               = $tamano
 '@@UBICACION_EMPRESA@@'    = $ubiEmp
 '@@DESCRIPCION_EMPRESA@@'  = $descEmp
 '@@URL_POSTULAR@@'         = $urlPostular
 '@@PORTAL@@'               = $portal
 '@@COMO_POSTULAR@@'        = "Completa el formulario de postulación en $portal con tus datos, adjunta tu CV en PDF y envía tu solicitud; el proceso se gestiona directamente en el portal de origen."
}

# "¿Por qué postular?" (Fase A): bullets SOLO con datos reales ya extraidos
$porque = Est-Porque @{
    titulo = $titulo; empresa = $empresaOut; sector = $sector
    ubicacion = $ubi; ciudad = $(if ($ciudad -ne '') { $ciudad } else { 'No especificado' })
    modalidad = $modalidad; salario = $salario; contrato = $contrato
    jornada = $jornada; experiencia = $experiencia; beneficios = @($bens)
}
function Quita-Vacio([string]$h, [string]$ph) {
    $h = [regex]::Replace($h, '(?is)\s*<li>\s*' + [regex]::Escape($ph) + '\s*</li>', '')
    $h = [regex]::Replace($h, '(?is)\s*<p>\s*' + [regex]::Escape($ph) + '\s*</p>', '')
    return $h
}
for ($i = 1; $i -le 4; $i++) {
    $v = ''; if ($i -le $porque.Count) { $v = [string]$porque[$i - 1] }
    if ($v -eq '') { $html = Quita-Vacio $html ('@@PORQUE' + $i + '@@') } else { $map['@@PORQUE' + $i + '@@'] = $v }
}

foreach ($k in $map.Keys) { $html = $html.Replace($k, [string]$map[$k]) }

# "No especificado" fuera de los 4 recuadros: se borra ese <p> dentro de .empleo-destacado
$html = [regex]::Replace($html, '(?s)<div class="empleo-destacado">.*?</div>', {
    param($bl)
    return [regex]::Replace($bl.Value, '(?m)^[ \t]*<p><strong>[^<]*:</strong>\s*No especificad[oa]\s*</p>[ \t]*\r?\n?', '')
})

# sin salario: se borra la linea de salario de la cabecera (no puede quedar
# "No especificado" visible fuera de los 4 recuadros)
if ($salario -eq "No especificado") {
    $html = [regex]::Replace($html, '(?m)^\s*<div class="empleo-salario-header">[\s\S]*?</div>\r?\n?', '')
}

$meta = "<!-- ETIQUETA_BLOGGER = Empleo`n     TITULO_BLOGGER = " + $titulo + " -->`n`n"
$html = $meta + $html

$pend = [regex]::Matches($html, '@@[A-Z0-9_]+@@')
if ($pend.Count -gt 0) {
    $lista = ($pend | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ', '
    Write-Host "ERROR: marcadores sin rellenar: $lista"
    exit 1
}

# ------------------------------------------------------------------ filtro de calidad
# si la pagina quedaria muy delgada (<180 palabras de contenido visible)
# no se genera: mejor una oferta menos que una entrada sin valor
$txtCal = [regex]::Replace($html, '(?s)<script[\s\S]*?</script>', ' ')
$txtCal = [regex]::Replace($txtCal, '<[^>]+>', ' ')
$palCal = @(($txtCal -split '\s+') | Where-Object { $_ -ne '' }).Count
if ($palCal -lt 180) {
    Write-Host "RESULTADO: OK - contenido insuficiente ($palCal palabras); no se genera."
    exit 0
}

# ------------------------------------------------------------------ guardar
$seg = ""
try { $segs = ([Uri]$Url).Segments; $seg = $segs[$segs.Count - 1] } catch { }
$slug = ($seg -replace '\.html$', '')
$slug = Sin-Acentos $slug
$slug = ($slug -replace '[^a-z0-9\-]', '').Trim('-')
$pref = $(if ($portal -eq 'BUSCOJOBS') { 'bj-' } else { 'ct-' })
$slug = $pref + $slug
if ($slug.Length -gt 70) {
    # truncado: hash corto de la URL para que titulos largos similares no
    # colisionen en el mismo archivo
    $md5 = [Security.Cryptography.MD5]::Create()
    $h = ([BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($Url)))).Substring(0, 5).Replace('-', '').ToLower()
    $slug = $slug.Substring(0, 64).Trim('-') + '-' + $h
}
if ($slug.Length -le $pref.Length) { $slug = $pref + (Get-Date -Format 'yyyyMMdd-HHmmss') }

# ------------------------------------------------------------------ anti-copia (Fase A)
# parrafos de 15+ palabras con >=35% de n-gramas identicos a la pagina de
# origen: se reescriben hasta 3 veces; si persisten, a datos\revision\
$reintentos = 0
while ($reintentos -lt 3) {
    $cop = @(Parrafos-Copiados -Html $html -Fuente $src -Umbral 0.35)
    if ($cop.Count -eq 0) { break }
    $reintentos++
    foreach ($c in $cop) {
        $tipo = 'p'; if ([string]$c.tipo -eq 'li') { $tipo = 'li' }
        $viejo = [string]$c.texto
        $nuevos = @(Reescribir-Copiado -texto $viejo -tipo $tipo -Fuente $src)
        $rep = ''
        if ($tipo -eq 'li') {
            # reemplazar el <li> COMPLETO: N fragmentos => N <li> hermanos
            # (nunca anidar <li> dentro de <li>)
            foreach ($nv in $nuevos) { $rep += '<li>' + $nv + '</li>' }
            if ($rep -eq '') { continue }
            $rx = '<li[^>]*>' + [regex]::Escape($viejo) + '</li>'
            if ([regex]::IsMatch($html, $rx)) {
                $html = [regex]::Replace($html, $rx, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $rep })
            } else { continue }
        } else {
            # 1 trozo => mismo parrafo; N trozos => parrafos hermanos
            $rep = ($nuevos -join '</p><p>')
            if ($rep -eq '') { continue }
            if ($html.Contains($viejo)) { $html = $html.Replace($viejo, $rep) } else { continue }
        }
    }
}
if (@(Parrafos-Copiados -Html $html -Fuente $src -Umbral 0.35).Count -gt 0) {
    $dirRev = Join-Path $raiz 'datos\revision'
    if (-not (Test-Path -LiteralPath $dirRev)) { New-Item -ItemType Directory -Path $dirRev -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dirRev ($slug + '-entrada.html')), $html, [System.Text.UTF8Encoding]::new($false))
    Write-Host "RESULTADO: REVISION - hay parrafos con >=35% de la fuente; entrada guardada en datos\revision\."
    exit 0
}

$dirF = Join-Path $raiz 'fuentes'
$dirS = Join-Path $raiz 'salida'
if (-not (Test-Path -LiteralPath $dirF)) { New-Item -ItemType Directory -Path $dirF | Out-Null }
if (-not (Test-Path -LiteralPath $dirS)) { New-Item -ItemType Directory -Path $dirS | Out-Null }

$fuenteTxt = @(
  "URL: $Url",
  "Portal: $portal",
  "Descargado: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')",
  "",
  "TITULO: $titulo",
  "EMPRESA: $empresa",
  "CATEGORIA: $categoria",
  "SALARIO: $salario",
  "CONTRATO: $contrato",
  "MODALIDAD: $modalidad",
  "CIUDAD: $ciudad",
  "REGION: $region",
  "UBICACION: $ubi",
  "VACANTES: $vacantes",
  "JORNADA: $jornada",
  "EXPERIENCIA: $experiencia",
  "ESTUDIOS: $estudios",
  "SECTOR: $sector",
  "TAMANO: $tamano",
  "UBICACION EMPRESA: $ubiEmp",
  "FECHA PUBLICACION: $fPubTxt",
  "FECHA CIERRE: $fCieTxt",
  "URL POSTULAR: $urlPostular",
  "INDUSTRY: $industry",
  ("FUNCIONES: " + $funcs.Count),
  ("REQUISITOS: " + $reqs.Count),
  ("BENEFICIOS: " + $bens.Count),
  "",
  "TEXTO DESCRIPCION 1: $p1",
  "TEXTO DESCRIPCION 2: $p2"
)
$pathF = Join-Path $dirF ($slug + '.txt')
[System.IO.File]::WriteAllText($pathF, ($fuenteTxt -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

$pathS = Join-Path $dirS ($slug + '-entrada.html')
[System.IO.File]::WriteAllText($pathS, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "== GUARDADO =="
Write-Host ("  fuente : " + $pathF)
Write-Host ("  entrada: " + $pathS)

# ------------------------------------------------------------------ validar
Write-Host ""
$validar = Join-Path $raiz 'validar-entrada.ps1'
# BuscoJobs bloquea la descarga del validador (403) - se omite -Fuente para no
# duplicar peticiones; Computrabajo si la permite y se compara enlaces.
if ($portal -eq 'BUSCOJOBS') { & powershell -NoProfile -ExecutionPolicy Bypass -File $validar -Archivo $pathS -Calidad }
else { & powershell -NoProfile -ExecutionPolicy Bypass -File $validar -Archivo $pathS -Fuente $Url -Calidad }
$rc = $LASTEXITCODE

Write-Host ""
if ($rc -ne 0) {
    # decision Fase A: nunca dejar una entrada fallida en salida\ - va a datos\revision\
    $dirRev = Join-Path $raiz 'datos\revision'
    if (-not (Test-Path -LiteralPath $dirRev)) { New-Item -ItemType Directory -Path $dirRev -Force | Out-Null }
    Move-Item -LiteralPath $pathS -Destination (Join-Path $dirRev ($slug + '-entrada.html')) -Force
    if (Test-Path -LiteralPath $pathF) { Remove-Item -LiteralPath $pathF -Force }
    Write-Host "RESULTADO: REVISION - no paso validar-entrada.ps1 -Calidad; entrada movida a datos\revision\."
    exit 0
}

# verificacion rapida de datos contra la fuente
$fallos = @()
$cuerpo = [System.IO.File]::ReadAllText($pathS, [System.Text.Encoding]::UTF8)
if ($empresa -ne "" -and $cuerpo.IndexOf($empresa) -lt 0) { $fallos += "empresa ($empresa)" }
if ($ciudad -ne "" -and $cuerpo.IndexOf($ciudad) -lt 0)     { $fallos += "ciudad ($ciudad)" }
if ($salario -ne "No especificado" -and $cuerpo.IndexOf($salario) -lt 0) { $fallos += "salario ($salario)" }
if ($fCieTxt -ne "" -and $cuerpo.IndexOf($fCieTxt) -lt 0)    { $fallos += "fecha de cierre ($fCieTxt)" }
if ($fallos.Count -gt 0) {
    $dirRev = Join-Path $raiz 'datos\revision'
    if (-not (Test-Path -LiteralPath $dirRev)) { New-Item -ItemType Directory -Path $dirRev -Force | Out-Null }
    Move-Item -LiteralPath $pathS -Destination (Join-Path $dirRev ($slug + '-entrada.html')) -Force
    if (Test-Path -LiteralPath $pathF) { Remove-Item -LiteralPath $pathF -Force }
    Write-Host ("RESULTADO: REVISION - datos faltantes en el HTML (" + ($fallos -join ', ') + "); entrada movida a datos\revision\.")
    exit 0
}

# clave registrada solo tras validacion OK
if ($claves.Add($clave)) { [IO.File]::AppendAllText($clavesPath, $clave + "`n", (New-Object System.Text.UTF8Encoding($false))) }

if (-not $SinPortapapeles) { Set-Clipboard -Value $html }

Write-Host "RESUMEN DE LA ENTRADA"
Write-Host ("  " + $vacantes + " vacantes | " + $salario + " | " + $ubi + " | " + $contrato + " | " + $modalidad + " | cierra " + $(if ($fCieTxt -ne "") { $fCieTxt } else { 'No especificado' }))
Write-Host ("  categoria: " + $categoria + " | empresa: " + $empresaOut)
Write-Host ("  publicada: " + $fPubTxt + " | postular: " + $urlPostular)
Write-Host ("  funciones: " + $funcs.Count + " | requisitos: " + $reqs.Count + " | beneficios: " + $bens.Count)
Write-Host ""
if ($SinPortapapeles) {
    Write-Host "RESULTADO: OK - HTML generado (portapapeles intacto)."
} else {
    Write-Host "RESULTADO: OK - HTML copiado al portapapeles. Ve a Blogger y pega (Ctrl+V)."
}
exit 0

} catch {
    Write-Host ("ERROR: " + $_.Exception.Message)
    exit 1
}
