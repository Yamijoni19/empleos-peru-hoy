# obtener-bumeran.ps1 - captura del SECTOR PRIVADO desde BUMERAN (fuente unica)
#
# Reemplaza a obtener-urls-privado.ps1 (BuscoJobs/Computrabajo) para las ofertas
# NUEVAS. Los historicos de BuscoJobs NO se tocan ni se reprocesan.
#
# USO (PowerShell):
#   .\obtener-bumeran.ps1                     # 10 ofertas nuevas del sitemap
#   .\obtener-bumeran.ps1 -MaxOfertas 50      # mas ofertas
#   .\obtener-bumeran.ps1 -MaxOfertas 0       # TODO el sitemap (cuidado)
#   .\ obtener-bumeran.ps1 -Urls "https://www.bumeran.com.pe/empleos/xxx-123.html,..."
#   .\obtener-bumeran.ps1 -PausaSeg 0.5       # ritmo de descarga
#   .\obtener-bumeran.ps1 -ReintentarRechazadas
#
# SALIDA (carpeta bumeran\):
#   historial-urls.txt     memoria incremental de URLs ya procesadas
#   indice.json            deduplicacion por ID/URL normalizada
#   normalizado\<id>.json  oferta valida (datos normalizados, sector=privado)
#   capturas\<ts>.json     bruto capturado (auditoria)
#   rechazadas.txt         RECHAZADA | fecha | url | motivo
#
# REGLAS:
#   - valida que sea una OFERTA LABORAL INDIVIDUAL antes de guardar
#   - salario: si hay monto real NUNCA se escribe "A convenir"; sin monto = "No especificado"
#   - nunca publica en Blogger ni llama a ninguna API de Google
#
# Sale 0 = OK, 1 = error de captura.

param(
    [int]$MaxOfertas = 10,
    [double]$PausaSeg = 1,
    [string[]]$Urls = @(),
    [switch]$ReintentarRechazadas,
    [switch]$SoloDiagnostico,
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Stop'
$Urls = @($Urls | ForEach-Object { ([string]$_) -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Sitio   = 'https://www.bumeran.com.pe'
$Sitemap = $Sitio + '/sitemap_avisos_bum.xml'
# La ficha de Bumeran es una SPA: con UA normal solo devuelve el shell (sin JobPosting).
$Ua = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'

$DirBum      = Join-Path $BaseDir 'bumeran'
$DirCapturas = Join-Path $DirBum 'capturas'
$DirNorm     = Join-Path $DirBum 'normalizado'
$HistPath    = Join-Path $DirBum 'historial-urls.txt'
$IdxPath     = Join-Path $DirBum 'indice.json'
$RechPath    = Join-Path $DirBum 'rechazadas.txt'
$LogPath     = Join-Path $BaseDir ('reporte\bumeran-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($d in @($DirBum, $DirCapturas, $DirNorm, (Join-Path $BaseDir 'reporte'))) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($LogPath, ($l + "`r`n"), $utf8) } catch { }
    Write-Host $l
}
function Rechazar([string]$url, [string]$motivo) {
    $l = "RECHAZADA | {0} | {1} | {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $url, $motivo
    [IO.File]::AppendAllText($RechPath, ($l + "`r`n"), $utf8)
    Log ("RECHAZADA: " + $motivo + " <- " + $url)
}
function Descargar([string]$u) {
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = $Ua
    $b = $wc.DownloadData($u)
    $wc.Dispose()
    return [Text.Encoding]::UTF8.GetString($b)
}
function Limpio([string]$t) {
    $s = [Net.WebUtility]::HtmlDecode([string]$t)
    $s = $s -replace '(?i)</(p|div|li|h[1-6]|br)>', ' '
    $s = $s -replace '<br\s*/?>', ' '
    $s = $s -replace '<[^>]+>', ' '
    $s = ($s -replace '\s+', ' ').Trim()
    return $s
}

# ============================================================ 1) URL individual
function Es-Url-Individual([string]$u) {
    if ($u -notmatch ('^' + [regex]::Escape($Sitio) + '/')) { return 'dominio distinto de bumeran' }
    if ($u -match '\?') { return 'URL con parametros (busqueda, filtros o categoria)' }
    if ($u -match '#') { return 'URL con ancla' }
    if ($u -notmatch '/empleos/[^/]+\.html$') { return 'no es la URL de una oferta individual (.html)' }
    if ($u -match '(?i)/(empresas?|empresa/|noticias?|blog|salarios|preguntas|ayuda|login|registro)(/|$)') { return 'pagina de empresa/contenido, no de oferta' }
    return ''
}
function Clave-De-Url([string]$u) {
    # 1) ID de la oferta (numero final de la URL)  2) URL normalizada  3) hash
    $limpia = ([string]$u).Trim().ToLower()
    $limpia = [regex]::Replace($limpia, '[?#].*$', '')
    $limpia = [regex]::Replace($limpia, '/+$', '')
    $m = [regex]::Match($limpia, '(\d+)\.html$')
    if ($m.Success -and $m.Groups[1].Value.Length -ge 5) { return ('id:' + $m.Groups[1].Value) }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $h = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($limpia)))) -replace '-', ''
        return ('url:' + $h.Substring(0, 32))
    } finally { $sha.Dispose() }
}

# ============================================================ 2) salario
function Convertir-Monto([string]$s) {
    $t = ([string]$s).Trim() -replace '[^\d\.,]', ''
    if ($t -eq '') { return $null }
    # 1.450 o 1.450,50 -> miles con punto
    if ($t -match '^\d{1,3}(\.\d{3})+(,\d{1,2})?$') { $t = ($t -replace '\.', '') -replace ',', '.' }
    # 1,450 o 1,450.50 -> miles con coma
    elseif ($t -match '^\d{1,3}(,\d{3})+(\.\d{1,2})?$') { $t = ($t -replace ',', '') }
    # 2500,50 -> decimal con coma
    elseif ($t -match '^\d+,\d{1,2}$' -and $t.Length -le 6) { $t = $t -replace ',', '.' }
    else { $t = $t -replace '[^\d]', '' }
    if ($t -eq '') { return $null }
    $v = $null
    if (-not [double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { return $null }
    if ($v -lt 100 -or $v -gt 100000) { return $null }   # fuera de rango razonable mensual
    return [double]$v
}

function Buscar-Montos([string]$texto) {
    # devuelve lista de @{v; txt}
    $res = @()
    if (-not $texto) { return $res }
    $patrones = @(
        'S/\s*\.?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{3,6})',
        '(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{3,6})\s*soles',
        '(?:sueldo|salario|remuneraci[oó]n)[^0-9S]{0,20}(\d{3,6})',
        '(\d{3,6})\s*\+\s*EPS'
    )
    foreach ($p in $patrones) {
        foreach ($m in [regex]::Matches($texto, '(?i)' + $p)) {
            $v = Convertir-Monto $m.Groups[1].Value
            if ($null -ne $v) {
                $res += @{ v = $v; txt = $m.Value.Trim() }
            }
        }
    }
    return $res
}

function Extraer-Salario([string]$ldJson, [string]$html, [string]$titulo, [string]$descripcion) {
    $r = [pscustomobject]@{
        min = $null; max = $null; moneda = 'PEN'; especificado = $false
        texto_original = 'No especificado'; fuente_salario = ''
    }
    $vistos = @()

    # 1) JSON-LD JobPosting / baseSalary
    try {
        $ld = $ldJson | ConvertFrom-Json
        $bs = $ld.baseSalary
        if ($bs) {
            $val = $bs.value
            if ($val -is [string] -or $val -is [double] -or $val -is [int]) {
                $v = Convertir-Monto ([string]$val)
                if ($null -ne $v) { $r.min = $v; $r.max = $v; $r.especificado = $true; $r.texto_original = ('S/ ' + $v.ToString('N0')); $r.fuente_salario = 'jsonld' ; $vistos += $v }
            } elseif ($val) {
                $mn = $null; $mx = $null
                if ($val.minValue) { $mn = Convertir-Monto ([string]$val.minValue) }
                if ($val.maxValue) { $mx = Convertir-Monto ([string]$val.maxValue) }
                if ($null -eq $mn -and $val.value) { $mn = Convertir-Monto ([string]$val.value) }
                if ($null -ne $mn -and $null -ne $mx) { $r.min=$mn; $r.max=$mx; $r.especificado=$true; $r.texto_original=('S/ ' + $mn.ToString('N0') + ' - S/ ' + $mx.ToString('N0')); $r.fuente_salario='jsonld'; $vistos += $mn }
                elseif ($null -ne $mn) { $r.min=$mn; $r.max=$mn; $r.especificado=$true; $r.texto_original=('S/ ' + $mn.ToString('N0')); $r.fuente_salario='jsonld'; $vistos += $mn }
            }
        }
    } catch { }

    # 2) campos estructurados del HTML (JSON embebido de la SPA)
    if (-not $r.especificado) {
        foreach ($p in @('"(?:salary|sueldo|salario)"\s*:\s*"([^"]{1,40})"', '"(?:salary|sueldo|salario)"\s*:\s*(\d{3,6})')) {
            foreach ($m in [regex]::Matches($html, '(?i)' + $p)) {
                $v = Convertir-Monto $m.Groups[1].Value
                if ($null -ne $v) { $r.min=$v; $r.max=$v; $r.especificado=$true; $r.texto_original=('S/ ' + $v.ToString('N0')); $r.fuente_salario='campo-estructurado'; $vistos += $v; break }
            }
            if ($r.especificado) { break }
        }
    }

    # 3) HTML visible: etiqueta con dos puntos ("Salario: S/ 1,450")
    if (-not $r.especificado) {
        $mL = [regex]::Match($html, '(?is)(salario|sueldo|remuneraci[oó]n)(?:\s*(?:mensual|nominal|base))?\s*[:\-]?\s*(?:<[^>]+>\s*){0,5}(S/\s*\.?\s*\d[\d.,]*|\d[\d.,]{2,6}\s*soles)')
        if ($mL.Success) {
            $v = Convertir-Monto ($mL.Groups[2].Value -replace '(?i)soles', '')
            if ($null -ne $v) { $r.min=$v; $r.max=$v; $r.especificado=$true; $r.texto_original=$mL.Value.Trim(); $r.fuente_salario='html'; $vistos += $v }
        }
    }

    # 4) titulo   5) descripcion
    foreach ($par in @(@('titulo', $titulo), @('descripcion', $descripcion))) {
        if ($r.especificado) { break }
        $montos = @(Buscar-Montos $par[1])
        if ($montos.Count -gt 0) {
            $r.min = $montos[0].v; $r.max = $montos[0].v
            $r.especificado = $true; $r.texto_original = $montos[0].txt; $r.fuente_salario = $par[0]
            $vistos += $montos[0].v
        }
    }

    # 6) regex general sobre todo el documento
    if (-not $r.especificado) {
        $montos = @(Buscar-Montos ($html -replace '<[^>]+>', ' '))
        if ($montos.Count -gt 0) {
            $r.min = $montos[0].v; $r.max = $montos[0].v
            $r.especificado = $true; $r.texto_original = $montos[0].txt; $r.fuente_salario = 'regex'
            $vistos += $montos[0].v
        }
    }

    # rangos explicitos sobre el texto ya detectado ("S/ 2,500 - S/ 3,500", "hasta S/ 3,500")
    if ($r.especificado -and $r.texto_original -ne 'No especificado') {
        $txt = $titulo + ' ' + $descripcion + ' ' + $r.texto_original
        $mR = [regex]::Match($txt, '(?i)S/\s*\.?\s*(\d[\d.,]{2,8})\s*(?:-|a|hasta)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
        if ($mR.Success) {
            $mn = Convertir-Monto $mR.Groups[1].Value; $mx = Convertir-Monto $mR.Groups[2].Value
            if ($null -ne $mn -and $null -ne $mx -and $mx -ge $mn) { $r.min=$mn; $r.max=$mx; $r.texto_original=$mR.Value.Trim(); $r.fuente_salario='rango' }
        } else {
            $mH = [regex]::Match($txt, '(?i)(hasta|tope de)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
            $mM = [regex]::Match($txt, '(?i)(m[aá]s de|desde|desde solo)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
            if ($mH.Success) { $mx = Convertir-Monto $mH.Groups[2].Value; if ($null -ne $mx) { $r.min=$null; $r.max=$mx; $r.texto_original=$mH.Value.Trim(); $r.fuente_salario='hasta' } }
            elseif ($mM.Success) { $mn = Convertir-Monto $mM.Groups[2].Value; if ($null -ne $mn) { $r.min=$mn; $r.max=$null; $r.texto_original=$mM.Value.Trim(); $r.fuente_salario='desde' } }
        }
    }

    if (-not $r.especificado) {
        $r.min = $null; $r.max = $null
        $r.texto_original = 'No especificado'
        $r.fuente_salario = ''
    }
    return $r
}

# ============================================================ 3) validacion de oferta
$RxGenerico = @(
    '^(?:gu[ií]a|consejo|noticia|beca|curso|capacitaci[oó]n|evento|plantilla|publicidad|bolet[ií]n)\b',
    '^(?:c[oó]mo |qu[eé] es |errores|frases|preguntas)',
    '^(?:empleos|trabajos|ofertas|vacantes)\b',
    '^(?:buscador|categor[ií]a|listado|resultados|p[aá]gina\s*\d)',
    '^\d+\s*(?:empleos|ofertas|vacantes|puestos)',
    '(?:empleos|trabajos|vacantes)\s+en\s+(?:lima|arequipa|trujillo|per[uú]|piura|cusco)\b',
    '^(?:todas las|ver m[aá]s|las mejores)\s+(?:ofertas|vacantes|convocatorias)'
)

function Validar-Oferta([pscustomobject]$o) {
    $senales = @()
    $motivos = @()

    $t = [string]$o.titulo
    $e = [string]$o.empresa
    $d = [string]$o.descripcion
    $req = @($o.requisitos).Count
    $fn = @($o.funciones).Count

    foreach ($rx in $RxGenerico) {
        if ($t -match $rx) { $motivos += ('titulo de listado/articulo: "' + $t.Substring(0, [Math]::Min(60, $t.Length)) + '"'); break }
    }
    if ($t.Length -lt 6) { $motivos += 'titulo vacio o demasiado corto' }
    if ($e -eq '') { $motivos += 'sin empresa/entidad' }
    if ($d.Length -lt 80) { $motivos += ('descripcion insuficiente (' + $d.Length + ' caracteres)') }
    if ($d -match '(?i)^(p[aá]gina no encontrada|error 404|no se encontr[oó])') { $motivos += 'pagina vacia o inexistente' }

    $largoContenido = $d.Length + (@($o.funciones) -join ' ').Length + (@($o.requisitos) -join ' ').Length
    if ($t.Length -ge 6 -and $e -ne '' -and $largoContenido -ge 200) { $senales += 'titulo+empresa+contenido' }
    if ($t.Length -ge 6) { $senales += 'puesto/titulo' }
    if ($e -ne '') { $senales += 'empresa' }
    if ($d.Length -ge 80) { $senales += 'descripcion/funciones' }
    if ($req -gt 0) { $senales += 'requisitos' }
    if ($fn -gt 0) { $senales += 'funciones' }
    if ([string]$o.ubicacion -ne '') { $senales += 'ubicacion' }
    if ([string]$o.modalidad -ne '' -or [string]$o.contrato -ne '') { $senales += 'modalidad' }
    if ([string]$o.fecha_publicacion -ne '' -or [string]$o.fecha_cierre -ne '') { $senales += 'fecha' }
    if ([string]$o.url -ne '') { $senales += 'url individual' }
    if ($o.salario.especificado) { $senales += 'salario' }

    if ($motivos.Count -gt 0) { return @{ ok = $false; motivos = $motivos; senales = $senales } }
    if ($t -eq '') { return @{ ok = $false; motivos = @('sin titulo') ; senales = $senales } }
    if ($senales.Count -lt 4) { return @{ ok = $false; motivos = @('senales insuficientes de oferta laboral (' + $senales.Count + ' de 8)'); senales = $senales } }
    if ($senales -notcontains 'titulo+empresa+contenido') { return @{ ok = $false; motivos = @('falta combinacion titulo+empresa+contenido'); senales = $senales } }
    return @{ ok = $true; motivos = @(); senales = $senales }
}

# ============================================================ 4) fuentes de URLs
$historial = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $HistPath) {
    foreach ($l in [IO.File]::ReadAllLines($HistPath)) { $l = $l.Trim(); if ($l -ne '') { [void]$historial.Add($l) } }
}
$rechazadas = @{}
if ($ReintentarRechazadas -and (Test-Path $RechPath)) {
    foreach ($l in [IO.File]::ReadAllLines($RechPath)) {
        $p = $l -split '\|'
        if ($p.Count -ge 3) { $u = $p[2].Trim(); if ($u) { $rechazadas[$u] = $true } }
    }
}
$indice = @{}
if (Test-Path $IdxPath) {
    try {
        $ix = Get-Content $IdxPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $ix.PSObject.Properties) { $indice[$p.Name] = $p.Value }
    } catch { Log "AVISO: indice ilegible, se reconstruye" }
}

$candidatas = @()
if ($Urls.Count -gt 0) {
    $candidatas = @($Urls | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
} else {
    Log ("Bumeran: descargando sitemap " + $Sitemap)
    try { $xml = Descargar $Sitemap }
    catch { Log ("ERROR sitemap: " + $_.Exception.Message); exit 1 }
    $vistos = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($m in [regex]::Matches($xml, '(?s)<url>(.*?)</url>')) {
        $ml = [regex]::Match($m.Groups[1].Value, '<loc>([^<]+)</loc>')
        if (-not $ml.Success) { continue }
        $u = [Net.WebUtility]::HtmlDecode($ml.Groups[1].Value).Trim()
        if ($u -notmatch ('^' + [regex]::Escape($Sitio) + '/empleos/[^/]+\.html$')) { continue }
        if (-not $vistos.Add($u)) { continue }
        $candidatas += $u
        if ($MaxOfertas -gt 0 -and $candidatas.Count -ge ($MaxOfertas * 10)) { break }
    }
    Log ("Bumeran sitemap: " + $candidatas.Count + " URLs individuales candidatas")
}

# incremental: solo las que no estan en el historial
$pendientes = @($candidatas | Where-Object {
        $u = $_
        -not $historial.Contains($u) -and (-not $ReintentarRechazadas -or -not $rechazadas.ContainsKey($u))
    })
if ($MaxOfertas -gt 0 -and $pendientes.Count -gt $MaxOfertas) { $pendientes = $pendientes[0..($MaxOfertas - 1)] }
Log ("historial=" + $historial.Count + " | por descargar=" + $pendientes.Count)
if ($pendientes.Count -eq 0) { Log 'Bumeran: sin URLs nuevas'; exit 0 }

if ($SoloDiagnostico) {
    Log ("-SoloDiagnostico: solo se lista lo pendiente, no se descarga nada")
    foreach ($u in $pendientes) { Write-Host ("  " + $u) }
    exit 0
}

# ============================================================ 5) descarga + parseo
$capturas = @()
$validas = 0
$rechazos = 0
$n = 0
foreach ($u in $pendientes) {
    $n++
    $mMotivo = Es-Url-Individual $u
    if ($mMotivo -ne '') { Rechazar $u $mMotivo; $rechazos++; [void]$historial.Add($u); continue }

    $html = $null
    $ok = $false
    $falta = ''
    for ($i = 1; $i -le 2; $i++) {
        try { $html = Descargar $u; $ok = $true; break }
        catch {
            $ex = $_.Exception
            while ($ex -ne $null) {
                if ($ex -is [Net.WebException] -and $ex.Response -ne $null) {
                    $st = [int]$ex.Response.StatusCode
                    if ($st -eq 404 -or $st -eq 410) { $falta = ('pagina inexistente (' + $st + ')'); break }
                }
                $ex = $ex.InnerException
            }
            if ($falta -ne '') { break }
            Log ("reintento " + $i + " " + $u + ": " + $_.Exception.Message)
            Start-Sleep -Seconds (2 * $i)
        }
    }
    if ($falta -ne '') { Rechazar $u $falta; $rechazos++; [void]$historial.Add($u); continue }
    if (-not $ok) { Log ("ERROR descarga " + $u); continue }

    # --- JobPosting
    $ld = $null; $ldJson = ''
    foreach ($m in [regex]::Matches($html, '(?is)<script[^>]*application/ld\+json[^>]*>([\s\S]*?)</script>')) {
        try {
            $o2 = $m.Groups[1].Value.Trim() | ConvertFrom-Json
            if ($o2 -is [array]) { $o2 = @($o2 | Where-Object { $_.'@type' -eq 'JobPosting' }) | Select-Object -First 1 }
            if ($o2 -and $o2.'@type' -eq 'JobPosting') { $ld = $o2; $ldJson = $m.Groups[1].Value.Trim(); break }
        } catch { }
    }
    if (-not $ld) {
        Rechazar $u 'sin JSON-LD JobPosting (listado, categoria, shell de SPA o extraccion rota)'
        $rechazos++; [void]$historial.Add($u); continue
    }

    $titulo = ''
    if ($ld.title) { $titulo = ([string]$ld.title -replace '\s+', ' ').Trim() }
    $empresa = ''
    if ($ld.hiringOrganization -and $ld.hiringOrganization.name) { $empresa = ([string]$ld.hiringOrganization.name -replace '\s+', ' ').Trim() }

    $ciudad=''; $region=''; $pais=''
    if ($ld.jobLocation -and $ld.jobLocation.address) {
        $a = $ld.jobLocation.address
        if ($a.addressLocality) { $ciudad = [string]$a.addressLocality }
        if ($a.addressRegion) { $region = [string]$a.addressRegion }
        if ($a.addressCountry) { $pais = [string]$a.addressCountry }
    }
    $ubicacion = ''
    if ($region -and $ciudad -and $region -ne $ciudad) { $ubicacion = $region + ' - ' + $ciudad }
    elseif ($ciudad) { $ubicacion = $ciudad }
    elseif ($region) { $ubicacion = $region }
    elseif ($pais) { $ubicacion = $pais }

    $descripcion = ''
    if ($ld.description) { $descripcion = (Limpio ([string]$ld.description)) }

    # secciones (requisitos/funciones) desde el JobPosting y desde el HTML visible
    $requisitos = @(); $funciones = @(); $beneficios = @()
    foreach ($sec in @($ld.qualifications, $ld.responsibilities, $ld.skills, $ld.experienceRequirements)) {
        if ($sec) { $requisitos += (Limpio ([string]$sec)) }
    }
    foreach ($m in [regex]::Matches($html, '(?is)<p>\s*<strong>\s*([^<]{2,60}?)\s*:\s*</strong>\s*</p>\s*(?:<ul>|<p>)([\s\S]*?)(?:</ul>|</p>)')) {
        $cab = ([Net.WebUtility]::HtmlDecode($m.Groups[1].Value)).Trim().ToLower()
        $items = @()
        if ($m.Value -match '(?is)<ul>') {
            foreach ($li in [regex]::Matches($m.Groups[2].Value, '(?is)<li>([\s\S]*?)</li>')) {
                $v = (Limpio $li.Groups[1].Value).Trim(); if ($v -ne '') { $items += $v }
            }
        } else { $v = (Limpio $m.Groups[2].Value).Trim(); if ($v -ne '') { $items = @($v) } }
        if ($items.Count -eq 0) { continue }
        if ($cab -match 'requisit|perfil|experiencia|formaci|estudio|conocimiento|competenc') { $requisitos += $items }
        elseif ($cab -match 'funcion|actividad|responsab|tarea|descripci|puesto') { $funciones += $items }
        elseif ($cab -match 'beneficio') { $beneficios += $items }
    }
    $requisitos = @($requisitos | Where-Object { $_ -ne '' } | Select-Object -Unique)
    $funciones   = @($funciones   | Where-Object { $_ -ne '' } | Select-Object -Unique)
    $beneficios  = @($beneficios  | Where-Object { $_ -ne '' } | Select-Object -Unique)

    $modalidad = ''
    if ($ld.jobLocationType) { $modalidad = [string]$ld.jobLocationType }   # TELECOMMUTE
    if (-not $modalidad -and $descripcion -match '(?i)(trabajo remoto|100%\s*remoto|modalidad remota|esquema remoto)') { $modalidad = 'REMOTE' }
    $contrato = ''
    if ($ld.employmentType) { $contrato = [string]$ld.employmentType }

    $fPub = ''; $fCie = ''
    if ($ld.datePosted)   { $fPub = ([datetime]$ld.datePosted).ToString('yyyy-MM-dd') }
    if ($ld.validThrough) { $fCie = ([datetime]$ld.validThrough).ToString('yyyy-MM-dd') }

    $salario = Extraer-Salario $ldJson $html $titulo $descripcion

    $oferta = [pscustomobject]@{
        id                 = ''
        clave              = (Clave-De-Url $u)
        sector             = 'privado'
        fuente             = [pscustomobject]@{ id = 'bumeran'; nombre = 'Bumeran Peru'; urlOrigen = $u; capturadoEn = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') }
        titulo             = $titulo
        empresa            = $empresa
        ubicacion          = $ubicacion
        ciudad             = $ciudad
        region             = $region
        modalidad          = $modalidad
        contrato           = $contrato
        salario            = $salario
        descripcion        = $descripcion
        requisitos         = $requisitos
        funciones          = $funciones
        beneficios         = $beneficios
        fecha_publicacion  = $fPub
        fecha_cierre       = $fCie
        url                = $u
        url_postulacion    = $u
    }

    # --- deduplicacion
    if ($indice.ContainsKey($oferta.clave)) {
        Log ("DUPLICADA (ya capturada como " + [string]$indice[$oferta.clave] + "): " + $u)
        [void]$historial.Add($u)
        continue
    }

    $v = Validar-Oferta $oferta
    $oferta | Add-Member -NotePropertyName 'validacion' -NotePropertyValue ([pscustomobject]@{
            estado = $(if ($v.ok) { 'VALIDADA' } else { 'RECHAZADA' })
            senales = @($v.senales); motivos = @($v.motivos)
        })
    if (-not $v.ok) {
        Rechazar $u (($v.motivos) -join ' / ')
        $rechazos++; [void]$historial.Add($u); continue
    }

    # identidad estable: id:bumeran-<id de la URL>
    $idNum = ''
    $mId = [regex]::Match($u, '(\d+)\.html$')
    if ($mId.Success -and $mId.Groups[1].Value.Length -ge 5) { $idNum = $mId.Groups[1].Value }
    $slugBase = [regex]::Replace($titulo.ToLower(), '[^a-z0-9]+', '-').Trim('-')
    if ($slugBase.Length -gt 60) { $slugBase = $slugBase.Substring(0, 60).Trim('-') }
    if ($idNum -ne '') { $oferta.id = 'bumeran-' + $idNum }
    else { $oferta.id = 'bumeran-' + ($oferta.clave -replace '^[a-z]+:', '').Substring(0, 8) }

    $rutaNorm = Join-Path $DirNorm ($oferta.id + '.json')
    if (Test-Path $rutaNorm) { Log ("DUPLICADA (ficha existente): " + $oferta.id); [void]$historial.Add($u); continue }

    [IO.File]::WriteAllText($rutaNorm, ($oferta | ConvertTo-Json -Depth 8), $utf8)
    $indice[$oferta.clave] = $oferta.id
    [void]$historial.Add($u)
    $capturas += $oferta
    $validas++

    $sal = 'No especificado'
    if ($salario.especificado) {
        $txtMin = '?'
        $txtMax = '?'
        if ($null -ne $salario.min) { $txtMin = ([double]$salario.min).ToString('N0') }
        if ($null -ne $salario.max) { $txtMax = ([double]$salario.max).ToString('N0') }
        $sal = 'S/ ' + $txtMin
        if ($txtMax -ne $txtMin) { $sal = $sal + ' - S/ ' + $txtMax }
        $sal = $sal + ' [' + $salario.fuente_salario + ']'
    }
    Log ("OK " + $n + "/" + $pendientes.Count + " | " + $titulo + " | " + $empresa + " | " + $ubicacion + " | " + $sal)
    if ($PausaSeg -gt 0) { Start-Sleep -Milliseconds ([int]($PausaSeg * 1000)) }
}

# ============================================================ 6) salidas
if ($capturas.Count -gt 0) {
    $rutaCap = Join-Path $DirCapturas (('captura-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
    [IO.File]::WriteAllText($rutaCap, ($capturas | ConvertTo-Json -Depth 8), $utf8)
    Log ("capturas guardadas: " + $rutaCap)
}
[IO.File]::WriteAllLines($HistPath, @($historial), $utf8)
$obj = [ordered]@{}
foreach ($k in ($indice.Keys | Sort-Object)) { $obj[$k] = $indice[$k] }
[IO.File]::WriteAllText($IdxPath, (($obj | ConvertTo-Json -Depth 3)), $utf8)

$totNorm = @().Count
if (Test-Path $DirNorm) { $totNorm = (Get-ChildItem $DirNorm -Filter '*.json' -File).Count }
Log ("RESUMEN Bumeran: validadas=" + $validas + " rechazadas=" + $rechazos + " | fichas en normalizado=" + $totNorm + " | indice=" + $indice.Count)
Write-Host ""
Write-Host ("== RESUMEN BUMERAN ==  validadas: " + $validas + " | rechazadas: " + $rechazos + " | fichas: " + $totNorm)
Write-Host ("  carpeta: " + $DirBum)
exit 0
