# generar-entrada.ps1 - genera el HTML de una entrada de empleo a partir de una URL.
#
# USO (PowerShell):
#   .\generar-entrada.ps1 -Url "https://www.convocatoriasdetrabajo.com/....html"
#
# Baja la pagina, extrae los datos REALES (JSON-LD + campos del HTML),
# rellena la plantilla del Estado, valida con validar-entrada.ps1 y,
# si todo esta OK, copia el HTML al portapapeles.
#
# Devuelve exit code 0 = OK (HTML en el portapapeles), 1 = hay errores.

param(
    [string]$Url = "",
    [string]$Tipo = "",
    [switch]$SinParafrasear,
    [switch]$SinPortapapeles
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$hoy  = Get-Date

try {

if ($Url.Trim() -eq "") { $Url = (Read-Host " URL de la publicacion").Trim() }
if ($Url -notmatch '^https?://') { Write-Host "ERROR: la URL debe empezar por http:// o https://"; exit 1 }

Write-Host "== DESCARGANDO =="
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
$wc = New-Object System.Net.WebClient
$wc.Headers['User-Agent'] = $ua
$bytes = $wc.DownloadData($Url)
$src   = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host ("  HTTP OK - " + $bytes.Length + " bytes")

# ------------------------------------------------------------------ JSON-LD
$ld = $null
foreach ($m in [regex]::Matches($src, '(?s)<script type="application/ld\+json">(.*?)</script>')) {
    try {
        $o = $m.Groups[1].Value.Trim() | ConvertFrom-Json
        if ($o.'@type' -eq 'JobPosting') { $ld = $o; break }
    } catch { }
}

$titulo      = ""
$entidad     = ""
$ciudad      = ""
$region      = ""
$contrato    = ""
$salarioJson = ""
$fPub        = ""
$fCie        = ""
if ($ld) {
    if ($ld.title)               { $titulo      = [string]$ld.title }
    if ($ld.hiringOrganization)   { $entidad     = [string]$ld.hiringOrganization.name }
    if ($ld.jobLocation) {
        $a = $ld.jobLocation.address
        if ($a.addressLocality) { $ciudad = [string]$a.addressLocality }
        if ($a.addressRegion)   { $region = [string]$a.addressRegion }
    }
    if ($ld.employmentType)      { $contrato    = [string]$ld.employmentType }
    if ($ld.baseSalary)          { $salarioJson = [string]$ld.baseSalary.value.value }
    if ($ld.datePosted)          { $fPub        = [string]$ld.datePosted }
    if ($ld.validThrough)        { $fCie        = [string]$ld.validThrough }
}

# ------------------------------------------------------------------ HTML
function Limpio([string]$t) {
    $s = [string]$t
    $s = $s -replace '<[^>]+>', ' '
    $s = $s -replace '&nbsp;', ' '
    $s = $s -replace '&amp;', '&'
    $s = [regex]::Replace($s, '&#(\d+);', { param($m) [string][char][int]$m.Groups[1].Value })
    # etiquetas creadas por decodificar entidades y etiquetas cortadas sin '>' por
    # ventanas truncadas (ej. <a href="/cdn-cgi/..." cortado a mitad)
    $s = $s -replace '<[a-zA-Z/!][^>]*>', ' '
    $s = $s -replace '<[a-zA-Z/!][^>]*$', ' '
    $s = $s -replace '&[a-z]+;', ' '
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

# ------------------------------------------------- fallbacks sin JSON-LD
# CT dejo de emitir el JobPosting en algunas paginas (solo quedan WebSite,
# Organization y NewsArticle): sin ld.title ni ld.hiringOrganization el
# titulo y la entidad quedaban vacios => "TITULO_BLOGGER = :". Se recuperan
# del <h1> y del breadcrumb "Convocatorias X" (clase "current").
if ($titulo -eq "") {
    $mh1 = [regex]::Match($src, '(?is)<h1[^>]*>([\s\S]*?)</h1>')
    if ($mh1.Success) {
        $titulo = (Limpio $mh1.Groups[1].Value) -replace '\s*[-|]\s*Convocatoria\s+.*$', ''
        $titulo = $titulo.Trim()
    }
}
if ($entidad -eq "") {
    $mbc = [regex]::Match($src, '(?is)<a[^>]+class="current"[^>]*>([\s\S]*?)</a>')
    if (-not $mbc.Success) { $mbc = [regex]::Match($src, '(?is)title="Convocatorias?\s+([^"]+)"') }
    if ($mbc.Success) { $entidad = (Limpio $mbc.Groups[1].Value) }
}
if ($titulo -eq "" -or $entidad -eq "") {
    Write-Host "ERROR: no pude extraer TITULO/ENTIDAD de la publicacion (sin JSON-LD JobPosting y sin <h1>/breadcrumb utiles)"
    exit 1
}

# --------------------------------------------------------------- parafraseo
# Cambia palabras y conectores de los textos LARGOS copiados de la fuente
# (mismas ideas, otras palabras) para que la entrada no quede calco.
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

function Parafrasear([string]$texto) {
    if ([string]::IsNullOrWhiteSpace($texto)) { return $texto }
    if ($SinParafrasear) { return $texto }
    if ($texto -match '(?i)no especificado') { return $texto }
    if ($texto -match '^https?://') { return $texto }
    $n = @(($texto -split '\s+') | Where-Object { $_ -ne '' }).Count
    if ($n -lt 15) { return $texto }          # los textos cortos no generan avisos

    $t = $texto

    # 1) sinonimos y arranques de frase (pasada unica, sin re-scan)
    $t = $rxPara.Replace($t, {
        param($mm)
        $rep = $mapPara[$mm.Value]
        if ($null -eq $rep) { return $mm.Value }
        if ([char]::IsUpper($mm.Value[0])) { $rep = $rep.Substring(0,1).ToUpper() + $rep.Substring(1) }
        return $rep
    })

    # 2) conectores entre oraciones (evita "a.m."/"p.m.")
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

    # 3) articulos en enumeraciones (sustantivos)
    $t = [regex]::Replace($t, ',\s+(?=[a-záéíóúñ]+(?:ción|sión|ión|dad|tud)\b)', ', la ')
    $t = [regex]::Replace($t, '\sy\s+(?=[a-záéíóúñ]+(?:ción|sión|ión|dad|tud)\s+de\b)', ' y la ')
    $t = [regex]::Replace($t, '\sy\s+(?=(?:control|registro|seguimiento|apoyo|desarrollo|almacenamiento|procesamiento|reconocimiento|mantenimiento)\b)', ' y el ')

    return $t
}

# vacantes: 1) tarjeta "N plaza(s)"  2) "Nro de vacantes: N"  3) "Numero de vacantes: N"
$vacantes = "No especificado"
$vals = @()
$m1 = [regex]::Match($src, '(\d+)\s*plaza\(s\)')
if ($m1.Success) { $vals += ,@("tarjeta", $m1.Groups[1].Value) }
$m2 = [regex]::Match($src, 'Nro de vacantes:\s*(?:<[^>]+>\s*)*(\d+)')
if ($m2.Success) { $vals += ,@("resumen", $m2.Groups[1].Value) }
$m3 = [regex]::Match($src, '(?i)N(?:&#250;|&uacute;|ú|u)mero de vacantes:\s*(?:<[^>]+>\s*)*(\d+)')
if ($m3.Success) { $vals += ,@("requisitos", $m3.Groups[1].Value) }
$unicos = @($vals | ForEach-Object { $_[1] } | Sort-Object -Unique)
if ($vals.Count -gt 0) {
    $vacantes = $vals[0][1]                      # precedencia: tarjeta > resumen > requisitos
    if ($unicos.Count -gt 1) {
        $detalle = ($vals | ForEach-Object { $_[0] + "=" + $_[1] }) -join ", "
        Write-Host ("  AVISO: la fuente se contradice (" + $detalle + ") -> se usa " + $vacantes)
    }
}

# salario
$salario = "No especificado"
$ms = [regex]::Match($src, '(?is)Remuneraci(?:&#243;|&oacute;|ó|o)n:\s*(?:<[^>]+>\s*)*S/\s*([\d.,]+)')
if (-not $ms.Success) { $ms = [regex]::Match($src, 'S/\s*([\d.,]{3,})') }
if ($ms.Success)     { $salario = "S/ " + $ms.Groups[1].Value }
elseif ($salarioJson -ne "") { $salario = "S/ " + $salarioJson }
$salarioHeader = $salario

# segmentos de texto
$segReq = ""
$iReq = $src.IndexOf('Requisitos para el puesto')
if ($iReq -ge 0) { $segReq = Limpio ($src.Substring($iReq, [Math]::Min(3000, $src.Length - $iReq))) }

$estudios = "No especificado"
$mEst = [regex]::Match($segReq, '(?i)Formaci(?:&oacute;|ó|o)n Acad(?:&eacute;|é|e)mica:\s*(.+?)(?=\s+Experiencia:|\s+Cursos y/o programas|\s+Nota:|$)')
if ($mEst.Success) { $estudios = $mEst.Groups[1].Value.Trim() }
$estudios = Parafrasear $estudios

$experiencia = "No especificado"
$mExp = [regex]::Match($segReq, '(?i)\s+Experiencia:\s*(.+?)(?=\s+Cursos y/o programas|\s+Nota:|$)')
if ($mExp.Success) { $experiencia = $mExp.Groups[1].Value.Trim() }
$experiencia = Parafrasear $experiencia

$dirigido = "No especificado"
$mDir = [regex]::Match($src, '(?is)Dirigido\s+a:\s*(?:<[^>]+>\s*)*([^<]{3,200})')
if (-not $mDir.Success) { $mDir = [regex]::Match($src, '(?is)A\s+qui(?:&eacute;|é|e)n\s+(?:va\s+)?dirigido[^<]{0,40}:\s*(?:<[^>]+>\s*)*([^<]{3,200})') }
if (-not $mDir.Success) { $mDir = [regex]::Match($src, '(?is)Pueden\s+postular\s*:\s*(?:<[^>]+>\s*)*([^<]{3,200})') }
if ($mDir.Success) {
    $d = (Limpio $mDir.Groups[1].Value).Trim()
    if ($d -ne "" -and $d -ne "No especificado") { $dirigido = $d }
}
if ($dirigido -eq "No especificado") {
    # la publicacion no trae "Dirigido a": se arma con datos REALES de la fuente
    if ($estudios -ne "" -and $estudios -ne "No especificado") { $dirigido = "Profesionales con $estudios" }
    else { $dirigido = "Quienes cumplan los requisitos y el perfil de las bases oficiales" }
}

$jornada = "No especificado"
$mJor = [regex]::Match($src, '(?is)Jornada\s*:\s*(?:<[^>]+>\s*)*([^<]{2,80})')
if ($mJor.Success) { $jornada = (Limpio $mJor.Groups[1].Value) }

$modalidad = "No especificado"
$mMod = [regex]::Match($src, '(?is)Modalidad(?:\s+de\s+trabajo)?\s*:\s*(?:<[^>]+>\s*)*([^<]{2,80})')
if ($mMod.Success) { $modalidad = (Limpio $mMod.Groups[1].Value) }

$lugarPrest = ""
$mLug = [regex]::Match($src, '(?is)Lugar de prestaci(?:&#243;|&oacute;|ó|o)n del servicio:\s*(?:<[^>]+>\s*)*([^<]{2,120})')
if ($mLug.Success) { $lugarPrest = (Limpio $mLug.Groups[1].Value) }

$plazo = "No especificado"
$segComo = ""
$iComo = $src.IndexOf('C&#243;mo postular?')
if ($iComo -lt 0) { $iComo = $src.IndexOf('C&oacute;mo postular?') }
if ($iComo -lt 0) { $iComo = $src.IndexOf([char]0xF3 + 'mo postular?') }
if ($iComo -lt 0) { $iComo = $src.IndexOf('mo postular?') }
if ($iComo -ge 0) {
    $segComo = Limpio ($src.Substring($iComo, [Math]::Min(1200, $src.Length - $iComo)))
    $mPl = [regex]::Match($segComo, '(?i)Plazo para postular:\s*(.+?)(?=\s*(?:¿|&iquest;)?\s*C(?:ó|o)mo postular|\s+PUBLICIDAD|$)')
    if ($mPl.Success) { $plazo = $mPl.Groups[1].Value.Trim() }
}

$comoPostular = ""
$mCP = [regex]::Match($segComo, '(?i)C(?:&oacute;|ó|o)mo postular\?:\s*(.+?)(?=\s+PUBLICIDAD|$)')
if ($mCP.Success) { $comoPostular = $mCP.Groups[1].Value.Trim() }
if ($comoPostular -eq "") { $comoPostular = "segun las bases oficiales de la convocatoria" }
$comoPostular = Parafrasear $comoPostular

# enlaces oficiales de la publicacion (bases, cronograma, anexos, ficha, etc.)
$redes = '(?i)facebook|twitter|t\.me|linkedin|instagram|whatsapp|youtube|eepurl|mailchimp|google\.com/search|doubleclick|googlesyndication|googleadservices|adservice|pagead2|outbrain'
$enlaces = New-Object System.Collections.Generic.List[object]
$seenU = @{}
foreach ($m in [regex]::Matches($src, '(?is)<a[^>]+href="(https?://[^"]+)"[^>]*>([\s\S]{0,400}?)</a>')) {
    $u = (($m.Groups[1].Value.Trim() -split '\s+')[0]).Trim()
    $t = (Limpio $m.Groups[2].Value).Trim()
    if ($u -eq "" -or $t -eq "") { continue }
    if ($u -eq $Url) { continue }
    if ($u -match $redes) { continue }
    if ($seenU.ContainsKey($u)) { continue }
    if ($t -notmatch '(?i)descarga|bases|cronograma|anexo|ficha|declaraci|formulario|instructivo|convocatoria completa|ver aqu|constancia') { continue }
    $seenU[$u] = $true
    $enlaces.Add(@{ href = $u; texto = $t })
    if ($enlaces.Count -ge 3) { break }
}
$urlBases = $Url
if ($enlaces.Count -gt 0) { $urlBases = $enlaces[0].href }

# enlace de postulacion: el portal oficial de la publicacion (nunca la propia pagina)
$urlPostular = ""
foreach ($m in [regex]::Matches($src, '(?is)<a[^>]+href="(https?://[^"]+)"[^>]*>([\s\S]{0,300}?)</a>')) {
    $u = (($m.Groups[1].Value.Trim() -split '\s+')[0]).Trim()
    $t = (Limpio $m.Groups[2].Value).Trim()
    if ($u -eq "" -or $u -eq $Url -or $u -match $redes) { continue }
    if ($t -match '(?i)postula\s*(aqu|ah)|inscripci|reg[ií]strate|formulario de postulaci|aplicar') { $urlPostular = $u; break }
}
if ($urlPostular -eq "" -and $enlaces.Count -gt 0) { $urlPostular = $enlaces[0].href }
if ($urlPostular -eq "") { $urlPostular = $Url }

# fechas
function FechaEs([string]$s, [string]$formato) {
    try { return ([datetime]::ParseExact($s.Trim(), $formato, [Globalization.CultureInfo]::InvariantCulture)).ToString('dd/MM/yyyy') } catch { return "" }
}
$fPubTxt = ""
if ($fPub -ne "") { $fPubTxt = FechaEs $fPub 'yyyy-MM-dd HH:mm:ss' }
if ($fPubTxt -eq "" -and $fPub -ne "") { $fPubTxt = FechaEs $fPub 'yyyy-MM-dd' }
$fCieTxt = ""
if ($fCie -ne "") { $fCieTxt = FechaEs $fCie 'yyyy-MM-dd HH:mm:ss' }
if ($fCieTxt -eq "" -and $fCie -ne "") { $fCieTxt = FechaEs $fCie 'yyyy-MM-dd' }
if ($fPubTxt -eq "") { $fPubTxt = $hoy.ToString('dd/MM/yyyy') }

$cierreFecha = $null
if ($fCieTxt -ne "") { try { $cierreFecha = [datetime]::ParseExact($fCieTxt, 'dd/MM/yyyy', $null) } catch { } }
$vigencia = "CONVOCATORIA FINALIZADA."
if ($cierreFecha -eq $null -or $cierreFecha -ge $hoy.Date) { $vigencia = "CONVOCATORIA VIGENTE." }

# tipo de contratante
if ($Tipo -eq "") {
    $publico = @('CAS','728','276','Servicio Civil','Locaci','Consultor')
    $Tipo = "estado"
    foreach ($p in $publico) { if ($contrato -like "*$p*") { $Tipo = "estado"; break } }
    if ($contrato -ne "" -and ($publico -notcontains $contrato) -and ($contrato -notmatch 'CAS|728|276|Servicio Civil|Locaci|Consultor')) { $Tipo = "privado" }
}
$Tipo = $Tipo.ToLower()
if ($Tipo -ne "estado") {
    Write-Host "ERROR: por ahora solo genero entradas del ESTADO (JSON-LD con CAS/728/276/Servicio Civil)."
    Write-Host "       Para portales privados usa aun la IA con el instructivo + la fuente."
    exit 1
}

# categoria (mapeo por palabras clave, portado del tema)
function Sin-Acentos([string]$s) {
    $x = [string]$s
    $x = $x.ToLower()
    $x = $x.Normalize([Text.NormalizationForm]::FormD)
    $x = [regex]::Replace($x, '[\u0300-\u036f]', '')
    return $x
}
function Obtener-Categoria([string]$texto) {
    $t = Sin-Acentos $texto
    if ($t -match 'salud|farmac|medic|enfermer|odontolog|paciente|hospital|clinica|laboratorio') { return 'Salud' }
    if ($t -match 'abogad|legal|juridic|derecho|notari') { return 'Derecho' }
    if ($t -match 'ingenier|construccion|topograf|mina|electric|mecanic|ambiental|industrial|sistema|software|telecomunic|arquitect') { return 'Ingenieria' }
    if ($t -match 'venta|comercial|marketing|cliente|publicidad|negocio|emprend|atencion al cliente') { return 'Ventas y Servicios' }
    if ($t -match 'administr|contabil|finanz|recur.?humanos|rrhh|tesorer|almacen|logistic|compras|banco|contador|gestion') { return 'Administracion y Finanzas' }
    if ($t -match 'docente|profesor|educacion|instituto|colegio|escolar|pedagog|tutor') { return 'Educacion' }
    return 'Otros'
}
$categoria = Obtener-Categoria ($titulo + " " + $estudios + " " + $dirigido)

# ------------------------------------------------------------------ textos propios
$puesto = $titulo
$puesto = $puesto -replace '(?i)^CAS\s*N[&ordm;°º]?\s*[0-9A-Za-z\-]+:\s*', ''
if ($entidad -ne "") {
    # si el titulo viene del <h1> ("UGEL X requiere ..."), el puesto no debe
    # repetir la entidad ni el verbo: "UGEL X: Ingeniero y ..." en vez de
    # "UGEL X: UGEL X requiere Ingeniero y ..."
    $puesto = $puesto -replace ('(?i)^\s*' + [regex]::Escape($entidad) + '\s+(?:requiere|solicita|busca|convoca|necesita|invita(?:\s+a)?)\s+'), ''
}
$puesto = $puesto.Trim()
if ($puesto -eq "") { $puesto = $titulo }

$ubi = "No especificado"
if ($ciudad -ne "") {
    $ubi = $ciudad
    if ($region -ne "" -and $region -ne $ciudad) { $ubi = $ciudad + ", " + $region }
    $ubi = $ubi + ", Perú"
} elseif ($region -ne "") { $ubi = $region + ", Perú" }

$resumen = ""
if ($vacantes -ne "No especificado") {
    $vacTxt = $(if ($vacantes -eq "1") { "1 vacante" } else { "$vacantes vacantes" })
    $resumen = "$entidad convoca $vacTxt para el puesto $puesto"
} else {
    $resumen = "$entidad convoca para el puesto $puesto"
}
if ($ubi -ne "No especificado") { $resumen += " en $ubi" }
if ($salario -ne "No especificado") { $resumen += ", con una remuneración de $salario" }
if ($fCieTxt -ne "") { $resumen += "; el plazo para postular vence el $fCieTxt" }
$resumen += ". La postulación se rige por las bases oficiales de la convocatoria."

$descP1 = "$entidad busca $puesto"
if ($lugarPrest -ne "") { $descP1 += ", con lugar de prestación del servicio en $lugarPrest" }
$estudiosTxt = ($estudios -replace '[\.\s]+$', '')
$expTxt      = ($experiencia -replace '[\.\s]+$', '')
if ($estudios -ne "" -and $estudios -ne "No especificado") { $descP1 += ". La formación académica que se exige es: $estudiosTxt" }
if ($experiencia -ne "" -and $experiencia -ne "No especificado") { $descP1 += ". En experiencia se pide: $expTxt" }
if ($dirigido -ne "" -and $dirigido -ne "No especificado") { $descP1 += ". Esta oportunidad es para: $dirigido" }
$descP1 += "."

$descP2 = ""
if ($plazo -ne "" -and $plazo -ne "No especificado") { $descP2 = "El plazo para postular es: $plazo. " }
$descP2 += "La postulación se realiza así: $comoPostular"
$descP2 += ". Antes de postular, descarga las bases oficiales de la sección siguiente y revisa el cronograma completo."

$puesto = ($puesto.Trim() -replace '^(?i:para)\s+(?=\p{Lu})', '').Trim()
$tituloBlog = "${entidad}: $puesto"

# ------------------------------------------------------------------ plantilla
$plantilla = Join-Path $raiz "plantilla-convocatoria-estado.html"
if (-not (Test-Path -LiteralPath $plantilla)) { Write-Host "ERROR: falta $plantilla"; exit 1 }
$html = [System.IO.File]::ReadAllText($plantilla, [System.Text.Encoding]::UTF8)

# 1) funciones/actividades reales de la publicacion (si no hay, se borra el bloque p + ul)
$funciones = New-Object System.Collections.Generic.List[string]
$mFn = [regex]::Match($src, '(?is)(?:Actividades|Funciones)\s*:\s*(?:</span>\s*)?<ul>([\s\S]*?)</ul>')
if ($mFn.Success) {
    foreach ($mLi in [regex]::Matches($mFn.Groups[1].Value, '(?is)<li>([\s\S]*?)</li>')) {
        $ft = (Limpio $mLi.Groups[1].Value).Trim()
        if ($ft -ne "") { $ft = Parafrasear $ft; $funciones.Add($ft); if ($funciones.Count -ge 6) { break } }
    }
}
$bloqueFnOk = $false
if ($funciones.Count -gt 0) {
    $lisF = (($funciones | ForEach-Object { '    <li>' + ([string]$_) + '</li>' }) -join "`n")
    $nuevoFn = [regex]::Replace($html, '(?s)(<p><strong>Funciones principales:</strong></p>\s*(?:<!--[\s\S]*?-->\s*)?<ul>)[\s\S]*?(</ul>)', {
        param($mm) $mm.Groups[1].Value + "`n" + $lisF + "`n  </ul>"
    })
    if ($nuevoFn -ne $html) { $html = $nuevoFn; $bloqueFnOk = $true }
}
if (-not $bloqueFnOk) {
    $html = [regex]::Replace($html, '(?s)\s*<p><strong>Funciones principales:</strong></p>\s*(<!--[\s\S]*?-->\s*)?<ul>[\s\S]*?</ul>', '')
}

# 2) relleno de marcadores
$map = @{
 '@@FUENTE@@'             = $Url
 '@@CATEGORIA@@'           = $categoria
 '@@EMPRESA@@'             = $entidad
 '@@UBICACION@@'           = $ubi
 '@@CIUDAD@@'              = $(if ($ciudad -ne "") { $ciudad } else { "No especificado" })
 '@@MODALIDAD@@'           = $modalidad
 '@@SALARIO@@'             = $salario
 '@@SALARIO_HEADER@@'      = $salarioHeader
 '@@CONTRATO@@'            = $(if ($contrato -ne "") { $contrato } else { "No especificado" })
 '@@VACANTES@@'            = $vacantes
 '@@DIRIGIDO_A@@'          = $dirigido
 '@@ESTUDIOS@@'            = $estudios
 '@@EXPERIENCIA@@'         = $experiencia
 '@@JORNADA@@'             = $jornada
 '@@FECHA_PUBLICACION@@'   = $fPubTxt
 '@@FECHA_CIERRE@@'        = $(if ($fCieTxt -ne "") { $fCieTxt } else { "No especificado" })
 '@@TIPO_CONTRATANTE@@'    = 'Estado'
 '@@TIPO_CONTRATO_ESTADO@@'= $(if ($contrato -ne "") { $contrato } else { "No especificado" })
 '@@TIPO_ENTIDAD@@'        = 'Otra entidad'
 '@@TITULO@@'              = $titulo
 '@@VIGENCIA@@'            = $vigencia
 '@@RESUMEN@@'             = $resumen
 '@@DESCRIPCION_P1@@'      = $descP1
 '@@DESCRIPCION_P2@@'      = $descP2
 '@@URL_BASES@@'           = $urlBases
 '@@URL_POSTULAR@@'        = $urlPostular
 '@@URL_ORIGEN@@'          = $Url
}
foreach ($k in $map.Keys) { $html = $html.Replace($k, [string]$map[$k]) }

# 2b) lista de documentos oficiales: un <li> por enlace (maximo 3, hrefs distintos)
if ($enlaces.Count -gt 0) {
    $lis = (($enlaces | ForEach-Object {
        $tx = ([string]$_.texto) -replace '&', '&amp;'
        '    <li><a href="' + [string]$_.href + '" target="_blank" rel="noopener noreferrer">' + $tx + '</a></li>'
    }) -join "`n")
    $nuevo = [regex]::Replace($html, '(?s)(<h2>(?:Bases y anexos oficiales|Descargar bases)</h2>[\s\S]*?<ul>)[\s\S]*?(</ul>)', {
        param($mm) $mm.Groups[1].Value + "`n" + $lis + "`n  " + $mm.Groups[2].Value
    })
    if ($nuevo -ne $html) { $html = $nuevo }
    else { Write-Host "  AVISO: no se encontro la lista <ul> de 'Bases y anexos oficiales' en la plantilla" }
}

# 3) "No especificado" solo en los 4 recuadros: se borran esos <p> dentro de .empleo-destacado
$html = [regex]::Replace($html, '(?s)<div class="empleo-destacado">.*?</div>', {
    param($bl)
    return [regex]::Replace($bl.Value, '(?m)^[ \t]*<p><strong>[^<]*:</strong>\s*No especificad[oa]\s*</p>[ \t]*\r?\n?', '')
})

# 3b) sin salario: se borra la linea de salario de la cabecera (no puede quedar
#     "No especificado" visible fuera de los 4 recuadros)
if ($salario -eq "No especificado") {
    $html = [regex]::Replace($html, '(?m)^\s*<div class="empleo-salario-header">[\s\S]*?</div>\r?\n?', '')
}

# 4) metadatos de Blogger (etiqueta y titulo del post)
$meta = "<!-- ETIQUETA_BLOGGER = Empleo`n     TITULO_BLOGGER = " + $tituloBlog + " -->`n`n"
$html = $meta + $html

# 5) ningun marcador sin rellenar
$pend = [regex]::Matches($html, '@@[A-Z0-9_]+@@')
if ($pend.Count -gt 0) {
    $lista = ($pend | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ", "
    Write-Host "ERROR: marcadores sin rellenar: $lista"
    exit 1
}

# ------------------------------------------------------------------ guardar
$slug = ([Uri]$Url).Segments[-1] -replace '\.html$', ''
$slug = Sin-Acentos $slug
$slug = ($slug -replace '[^a-z0-9\-]', '').Trim('-')
if ($slug.Length -gt 70) {
    # truncado: se anade hash corto de la URL para que titulos largos similares
    # no colisionen en el mismo archivo
    $md5 = [Security.Cryptography.MD5]::Create()
    $h = ([BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($Url)))).Substring(0, 5).Replace('-', '').ToLower()
    $slug = $slug.Substring(0, 64).Trim('-') + '-' + $h
}
if ($slug -eq "") { $slug = "entrada-" + (Get-Date -Format 'yyyyMMdd-HHmmss') }

$dirF = Join-Path $raiz "fuentes"
$dirS = Join-Path $raiz "salida"
if (-not (Test-Path -LiteralPath $dirF)) { New-Item -ItemType Directory -Path $dirF | Out-Null }
if (-not (Test-Path -LiteralPath $dirS)) { New-Item -ItemType Directory -Path $dirS | Out-Null }

$fuenteTxt = @(
  "URL: $Url",
  "Descargado: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')",
  "",
  "TITULO: $titulo",
  "ENTIDAD: $entidad",
  "VACANTES: $vacantes" + $(if ($vals.Count -gt 0 -and $unicos.Count -gt 1) { "  (fuente contradice: " + (($vals | ForEach-Object { $_[0] + "=" + $_[1] }) -join ", ") + ")" } else { "" }),
  "SALARIO: $salario",
  "CONTRATO: $contrato",
  "CIUDAD: $ciudad",
  "REGION: $region",
  "UBICACION: $ubi",
  "ESTUDIOS: $estudios",
  "EXPERIENCIA: $experiencia",
  "DIRIGIDO A: $dirigido",
  "FUNCIONES: " + $funciones.Count,
  "JORNADA: $jornada",
  "MODALIDAD: $modalidad",
  "LUGAR DE PRESTACION: $lugarPrest",
  "PLAZO: $plazo",
  "COMO POSTULAR: $comoPostular",
  "FECHA PUBLICACION: $fPubTxt",
  "FECHA CIERRE: $fCieTxt",
  "BASES: $urlBases",
  "URL POSTULAR: $urlPostular",
  "ENLACES: " + $(if ($enlaces.Count -gt 0) { ($enlaces | ForEach-Object { $_.href + "  (" + $_.texto + ")" }) -join " | " } else { "(ninguno)" }),
  "",
  "TEXTO RESUMEN: $resumen",
  "TEXTO DESCRIPCION 1: $descP1",
  "TEXTO DESCRIPCION 2: $descP2"
)
$pathF = Join-Path $dirF ($slug + ".txt")
[System.IO.File]::WriteAllText($pathF, ($fuenteTxt -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

$pathS = Join-Path $dirS ($slug + "-entrada.html")
[System.IO.File]::WriteAllText($pathS, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "== GUARDADO =="
Write-Host "  fuente : $pathF"
Write-Host "  entrada: $pathS"

# ------------------------------------------------------------------ validar
Write-Host ""
$validar = Join-Path $raiz "validar-entrada.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $validar -Archivo $pathS -Fuente $Url
$rc = $LASTEXITCODE

Write-Host ""
if ($rc -ne 0) {
    Write-Host "RESULTADO: NO se copio nada al portapapeles. Corrige los errores de arriba."
    exit 1
}

# verificacion rapida contra la fuente
$fallos = @()
$cuerpo = [System.IO.File]::ReadAllText($pathS, [System.Text.Encoding]::UTF8)
if ($vacantes -ne "No especificado" -and $cuerpo -notmatch [regex]::Escape($vacantes)) { $fallos += "vacantes ($vacantes)" }
if ($salario -ne "No especificado" -and $cuerpo -notmatch [regex]::Escape(($salario -replace '\s',''))) { if ($cuerpo -notmatch [regex]::Escape($salario)) { $fallos += "salario ($salario)" } }
if ($ciudad -ne "" -and $cuerpo -notmatch [regex]::Escape($ciudad)) { $fallos += "ciudad ($ciudad)" }
if ($fCieTxt -ne "" -and $cuerpo -notmatch [regex]::Escape($fCieTxt)) { $fallos += "fecha de cierre ($fCieTxt)" }
if ($entidad -ne "" -and $cuerpo -notmatch [regex]::Escape($entidad)) { $fallos += "entidad ($entidad)" }
if ($fallos.Count -gt 0) {
    Write-Host ("ERROR: el HTML generado no contiene estos datos de la fuente: " + ($fallos -join ", "))
    exit 1
}

if (-not $SinPortapapeles) { Set-Clipboard -Value $html }

Write-Host "RESUMEN DE LA ENTRADA"
Write-Host ("  " + $vacantes + " " + $(if ($vacantes -eq "1") { "vacante" } else { "vacantes" }) + " | " + $salario + " | " + $ubi + " | " + $contrato + " | cierra " + $(if ($fCieTxt -ne "") { $fCieTxt } else { "No especificado" }))
Write-Host ("  categoria: " + $categoria + " | vigencia: " + $vigencia)
Write-Host ("  dirigido: " + $dirigido)
Write-Host ("  postular: " + $urlPostular)
Write-Host ("  enlaces de documentos: " + $(if ($enlaces.Count -gt 0) { $enlaces.Count } else { 0 }))
Write-Host ("  funciones: " + $funciones.Count)
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
