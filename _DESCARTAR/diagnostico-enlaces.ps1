# diagnostico-enlaces.ps1 -- analisis de enlaces del feed vivo (SOLO LECTURA)
# Verifica las reglas de clasificacion de preparar-correcciones.ps1 antes de aplicar nada.
# No llama a la API de Blogger ni modifica nada.
param([int]$MaxPaginas = 40, [string]$Cache = '', [string[]]$DebugIds = @())

$d = Split-Path -Parent $MyInvocation.MyCommand.Path

function Log([string]$m) {
    $ts = (Get-Date).ToString('HH:mm:ss')
    Write-Output "[$ts] $m"
}

function Host-De([string]$u) {
    if (-not $u) { return '' }
    if ($u -match '^https?://([^/?#]+)') { return $Matches[1].ToLower() }
    return ''
}
function Es-Oficial([string]$u) {
    if (-not $u) { return $false }
    return [bool]($u -match '(?i)^https?://([a-z0-9-]+\.)*gob\.pe([/?#]|$)')
}
function Es-Cdt([string]$u) {
    if (-not $u) { return $false }
    $h = Host-De $u
    if (-not $h) { return $false }
    return [bool]($h -match '(^|\.)convocatoriasdetrabajo\.com$')
}
function Es-Blogspot([string]$u) {
    if (-not $u) { return $false }
    $h = Host-De $u
    if (-not $h) { return $false }
    return [bool]($h -match '(^|\.)blogspot\.[a-z.]+$|(^|\.)blogger\.[a-z.]+$')
}
function Es-Placeholder([string]$u) {
    if (-not $u) { return $true }
    if ($u -match '^(https?://|mailto:|#|/)') { return $false }
    return $true
}
function Es-ExternoUtil([string]$u) {
    # enlace externo distinto de CDT/gob.pe/blogspot que SI puede ser URL final de la oferta
    if (-not $u) { return $false }
    if (-not ($u -match '^https?://')) { return $false }
    if (Es-Cdt $u) { return $false }
    if (Es-Oficial $u) { return $false }
    if (Es-Blogspot $u) { return $false }
    $h = Host-De $u
    if ($h -match '(^|\.)(google\.com|googleapis\.com|googledrive\.com|dropbox\.com|box\.com|onedrive\.live\.com|facebook\.com|fb\.com|twitter\.com|x\.com|instagram\.com|linkedin\.com|youtube\.com|youtu\.be|wa\.me|whatsapp\.com|t\.me|telegram\.me)$') { return $false }
    return $true
}
function Norm([string]$s) {
    if (-not $s) { return '' }
    $s = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
    }
    return ($sb.ToString().Normalize([Text.NormalizationForm]::FormC)).ToLower().Trim()
}
function Clasificar-Contratante([string]$valor) {
    $n = Norm $valor
    if ((-not $n) -or ($n -like 'no especific*')) { return 'NoEspecificado' }
    if (($n -match 'estado') -or ($n -match 'publico') -or ($n -match 'gobierno') -or
        ($n -match 'municipal') -or ($n -match 'region') -or ($n -match 'ministerio') -or
        ($n -match 'gob\.') -or ($n -match 'cas 728')) { return 'Estado' }
    if (($n -match 'privad') -or ($n -match 'empresa privada')) { return 'Privado' }
    return 'Otro'
}
function Analizar-Enlaces([string]$html) {
    $hrefs = @([regex]::Matches($html, '(?is)href\s*=\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
    $placeholders = @($hrefs | Where-Object { Es-Placeholder $_ })
    $http = @($hrefs | Where-Object { $_ -match '^https?://' })
    $oficiales = @($http | Where-Object { Es-Oficial $_ })
    $cdt = @($http | Where-Object { Es-Cdt $_ })
    $externos = @($http | Where-Object { (-not (Es-Cdt $_)) -and (-not (Es-Oficial $_)) -and (-not (Es-Blogspot $_)) })
    $cta = ''
    $origen = 'ninguno'
    $mBloque = [regex]::Match($html, '(?is)<div class="empleo-postular">([\s\S]{0,1200}?)</div>\s*<div class="ofertas-relacionadas"')
    if (-not $mBloque.Success) { $mBloque = [regex]::Match($html, '(?is)<div class="empleo-postular">([\s\S]{0,1200})') }
    if ($mBloque.Success) {
        $mA = [regex]::Match($mBloque.Groups[1].Value, '(?is)<a[^>]*href\s*=\s*"([^"]+)"')
        if ($mA.Success) { $cta = $mA.Groups[1].Value; $origen = 'bloque' }
    }
    if ($cta -eq '') {
        $mB = [regex]::Match($html, '(?is)class="empleo-boton"[^>]*href\s*=\s*"([^"]+)"')
        if ($mB.Success) { $cta = $mB.Groups[1].Value; $origen = 'fallback-boton' }
    }
    return @{
        hrefs        = $http
        placeholders = $placeholders
        oficiales    = $oficiales
        cdt          = $cdt
        externos     = $externos
        cta          = $cta
        origen       = $origen
        tieneHttp    = ($http.Count -gt 0)
    }
}

# ---------------------------------------------------------------- feed
$sw = [Diagnostics.Stopwatch]::StartNew()
$posts = New-Object System.Collections.ArrayList
if ($Cache -and (Test-Path -LiteralPath $Cache)) {
    foreach ($c in (Get-Content -LiteralPath $Cache -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        [void]$posts.Add([pscustomobject]@{ id = $c.id; titulo = $c.titulo; contenido = $c.contenido })
    }
    Log ('posts leidos del cache: ' + $posts.Count + '  (' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s)')
} else {
$base = 'https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json&max-results=150'
$start = 1; $pag = 0
while ($true) {
    $pag++
    if ($pag -gt $MaxPaginas) { break }
    $url = $base + '&start-index=' + $start
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 120
    $j = $r.Content | ConvertFrom-Json
    $entries = $j.feed.entry
    if (-not $entries) { break }
    foreach ($e in $entries) {
        $html = ''; if ($e.content) { $html = [string]$e.content.'$t' }
        $titulo = ''; if ($e.title) { $titulo = [string]$e.title.'$t' }
        $id = ([string]$e.id.'$t') -replace '^.*post-', ''
        [void]$posts.Add([pscustomobject]@{ id = $id; titulo = $titulo; contenido = $html })
    }
    if ($entries.Count -lt 150) { break }
    $start += 150
}
Log ('posts leidos: ' + $posts.Count + '  (' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s)')
}

# ---------------------------------------------------------------- analisis
$tot = @{}
function Inc([string]$k) { if (-not $script:tot.ContainsKey($k)) { $script:tot[$k] = 0 }; $script:tot[$k]++ }

$ctaXTipo = @{}      # "tipo|sector" -> n
$tablaRegla = @{}    # "accion|motivo-corto|sector" -> n  (regla actual de preparar)
$tablaPropuesta = @{}# "accion|motivo|sector" -> n        (regla propuesta)
$oficialHosts = @{}  # host de la URL oficial elegida
$extHostsProp = @{}  # host del externo util elegido
$ctaHosts = @{}      # host de CTAs externas utiles
$extHostsRetirar = @{}  # host de primer externo en RETIRAR-ctd sin oficial
$corregirCtd = 0
$sinCambioRegex = 0
$corregirProp = 0
$sinCambioProp = 0
$muestraRetirar = New-Object System.Collections.ArrayList

foreach ($p in $posts) {
    $html = [string]$p.contenido
    Inc 'total'
    $estructura = $html -match 'empleo-individual'
    if (-not $estructura) { continue }
    Inc 'estructura'
    $mTipo = [regex]::Match($html, '(?is)Tipo\s+(?:de\s+)?contratante\s*:\s*(?:</strong>)?\s*([^<\r\n]{1,60})')
    $sector = 'SinEtiqueta'
    if ($mTipo.Success) { $sector = Clasificar-Contratante $mTipo.Groups[1].Value }
    Inc ('sector:' + $sector)

    $enl = Analizar-Enlaces $html
    $sinOficial = ($enl.oficiales.Count -eq 0)
    $hayPh = ($enl.placeholders.Count -gt 0)


    $cta = [string]$enl.cta
    $ctaTipo = 'sin-cta'
    if ($cta -ne '') {
        if (Es-Cdt $cta) { $ctaTipo = 'ctd' }
        elseif (Es-Placeholder $cta) { $ctaTipo = 'cta-ph' }
        elseif ($cta -match '^https?://') {
            if (Es-Oficial $cta) { $ctaTipo = 'cta-gobpe' }
            elseif (Es-Blogspot $cta) { $ctaTipo = 'cta-blog' }
            else { $ctaTipo = 'cta-http-ext' }
        } else { $ctaTipo = 'cta-otro' }
    }
    $k = $ctaTipo + '|' + $sector
    if (-not $ctaXTipo.ContainsKey($k)) { $ctaXTipo[$k] = 0 }
    $ctaXTipo[$k]++

    Inc ('origen-cta:' + $enl.origen)
    if ($enl.cdt.Count -gt 0) {
        Inc 'ctd-en-algun-href'
        $fuera = @($enl.cdt | Where-Object { $_ -ne $cta })
        if ($fuera.Count -gt 0) { Inc 'ctd-tambien-fuera-de-la-cta' } else { Inc 'ctd-solo-en-la-cta' }
    }
    if ($enl.cta -match '^https?://' -and (Es-Oficial $enl.cta)) { Inc 'cta-gobpe-directa' }
    if ($enl.cta -match '^https?://' -and (-not (Es-Cdt $enl.cta)) -and (-not (Es-Oficial $enl.cta)) -and (-not (Es-Blogspot $enl.cta))) {
        Inc 'cta-externa-util'
        $hh = Host-De $enl.cta
        if (-not $ctaHosts.ContainsKey($hh)) { $ctaHosts[$hh] = 0 }
        $ctaHosts[$hh]++
    }

    $ctaUsable = ($enl.cta -match '^https?://') -and (-not (Es-Cdt $enl.cta)) -and (-not (Es-Placeholder $enl.cta))

    # ---- riesgos de las reglas actuales de preparar-correcciones.ps1
    if ($hayPh -and $ctaUsable) {
        Inc 'RIESGO1: placeholder en algun href pero CTA util (hoy: sin oficial => RETIRAR injusto)'
        if ($sinOficial) { Inc 'RIESGO1a: de esos, sin oficial (hoy RETIRAR)' }
    }
    if ($hayPh -and ($ctaTipo -eq 'ctd')) {
        Inc 'RIESGO2: placeholder presente y CTA=CDT (hoy solo arregla placeholders, deja CDT)'
    }

    # ---- simulacion exacta de la regla actual
    $accion = 'CONSERVAR'; $motivoCorto = 'B'
    if ($hayPh) {
        if ($sinOficial) { $accion = 'RETIRAR'; $motivoCorto = 'ph-sin-oficial' }
        else { $accion = 'CORREGIR'; $motivoCorto = 'ph->oficial' }
    } elseif ($enl.cta -and (Es-Cdt $enl.cta)) {
        if ($sinOficial) { $accion = 'RETIRAR'; $motivoCorto = 'ctd-sin-oficial' }
        else { $accion = 'CORREGIR'; $motivoCorto = 'ctd->oficial' }
    } elseif (-not $enl.tieneHttp) {
        $accion = 'RETIRAR'; $motivoCorto = 'sin-http'
    } else {
        $motivoCorto = 'cta-ok-o-sin-cambio'
    }
    $k2 = $accion + '|' + $motivoCorto + '|' + $sector
    if (-not $tablaRegla.ContainsKey($k2)) { $tablaRegla[$k2] = 0 }
    $tablaRegla[$k2]++

    # ---- simulacion de la regla PROPUESTA
    $extUtil = @($enl.externos | Where-Object { Es-ExternoUtil $_ })
    if ($ctaUsable) {
        if ($hayPh -and (-not $sinOficial)) { $pAccion = 'CORREGIR'; $pMotivo = 'cta-util+ph->oficial' }
        elseif ($hayPh) { $pAccion = 'CONSERVAR'; $pMotivo = 'cta-util+ph-sin-oficial' }
        else { $pAccion = 'CONSERVAR'; $pMotivo = 'cta-util' }
    } elseif (-not $sinOficial) {
        $pAccion = 'CORREGIR'
        $pMotivo = $(if ($enl.cdt.Count -gt 0 -or (Es-Cdt $cta)) { '->oficial' } else { 'ph->oficial' })
    } elseif ($extUtil.Count -gt 0) {
        $pAccion = 'CORREGIR'; $pMotivo = '->externo-util'
    } else {
        $pAccion = 'RETIRAR'; $pMotivo = 'sin-url-final-verificable'
    }
    $k3 = $pAccion + '|' + $pMotivo + '|' + $sector
    if (-not $tablaPropuesta.ContainsKey($k3)) { $tablaPropuesta[$k3] = 0 }
    $tablaPropuesta[$k3]++

    # ---- comprobacion: la sustitucion real cambia el HTML?
    if ($pAccion -eq 'CORREGIR') {
        $corregirProp++
        $nuevaUrl = ''
        if (-not $sinOficial) { $nuevaUrl = $enl.oficiales[0] }
        elseif ($extUtil.Count -gt 0) { $nuevaUrl = $extUtil[0] }
        if ($nuevaUrl -ne '') {
            $enc = [Net.WebUtility]::HtmlEncode($nuevaUrl)
            $h2 = $html
            $h2 = [regex]::Replace($h2, '(?is)(href\s*=\s*")([^"]*convocatoriasdetrabajo[^"]*)(")', ('$1' + $enc + '$3'))
            $h2 = [regex]::Replace($h2, '(?is)(href\s*=\s*")(URL\d+|)(")', ('$1' + $enc + '$3'))
            $h2 = [regex]::Replace($h2, '(?is)(<div class="empleo-postular">[\s\S]{0,1200}?<a[^>]*href\s*=\s*")[^"]*(")', ('$1' + $enc + '$2'))
            if ($h2 -eq $html) { $sinCambioProp++ }
            $hh = Host-De $nuevaUrl
            if ($sinOficial) {
                if (-not $extHostsProp.ContainsKey($hh)) { $extHostsProp[$hh] = 0 }
                $extHostsProp[$hh]++
            } else {
                if (-not $oficialHosts.ContainsKey($hh)) { $oficialHosts[$hh] = 0 }
                $oficialHosts[$hh]++
            }
        }
    }

    # ---- verificaciones de la correccion CTD -> oficial
    if ($motivoCorto -eq 'ctd->oficial') {
        $corregirCtd++
        $nuevaUrl = $enl.oficiales[0]
        $h2 = [regex]::Replace($html, '(?is)(class="empleo-boton"[^>]*href\s*=\s*")[^"]*(")', ('$1' + [Net.WebUtility]::HtmlEncode($nuevaUrl) + '$2'))
        if ($h2 -eq $html) { $sinCambioRegex++ }
        $hh = Host-De $nuevaUrl
        if (-not $oficialHosts.ContainsKey($hh)) { $oficialHosts[$hh] = 0 }
        $oficialHosts[$hh]++
    }

    # ---- RETIRAR-ctd: hay enlace externo no-gobpe que podria ser la URL final?
    if ($motivoCorto -eq 'ctd-sin-oficial') {
        if ($enl.externos.Count -gt 0) {
            Inc 'RETIRAR-ctd pero tiene enlace externo no-gobpe (revisar: posible URL final)'
            $hh = Host-De $enl.externos[0]
            if (-not $extHostsRetirar.ContainsKey($hh)) { $extHostsRetirar[$hh] = 0 }
            $extHostsRetirar[$hh]++
            if ($muestraRetirar.Count -lt 8) {
                [void]$muestraRetirar.Add([pscustomobject]@{
                    id = $p.id; sector = $sector; cta = $cta; externo = $enl.externos[0]
                    titulo = $p.titulo.Substring(0, [Math]::Min(60, $p.titulo.Length))
                })
            }
        } else {
            Inc 'RETIRAR-ctd sin ningun enlace externo distinto del CDT'
        }
    }
    if ($motivoCorto -eq 'ph-sin-oficial' -and $ctaUsable) {
        if ($muestraRetirar.Count -lt 16) {
            [void]$muestraRetirar.Add([pscustomobject]@{
                id = $p.id; sector = $sector; cta = $cta; externo = '(cta-util)'
                titulo = $p.titulo.Substring(0, [Math]::Min(60, $p.titulo.Length))
            })
        }
    }
}

# ---------------------------------------------------------------- salida
$out = New-Object System.Text.StringBuilder
function Line([string]$s) { [void]$script:out.AppendLine($s) }

Line '=== DIAGNOSTICO DE ENLACES ==='
Line ''
Line '-- totales --'
foreach ($k in ($tot.Keys | Sort-Object)) { Line ('  ' + $k + ': ' + $tot[$k]) }
Line ''
Line '-- tipo de CTA x sector (solo posts con estructura de oferta) --'
foreach ($k in ($ctaXTipo.Keys | Sort-Object)) { Line ('  ' + $k + ': ' + $ctaXTipo[$k]) }
Line ''
Line '-- regla ACTUAL (preparar-correcciones.ps1 hoy): accion | motivo | sector --'
foreach ($k in ($tablaRegla.Keys | Sort-Object)) { Line ('  ' + $k + ': ' + $tablaRegla[$k]) }
Line ''
Line '-- regla PROPUESTA: accion | motivo | sector --'
foreach ($k in ($tablaPropuesta.Keys | Sort-Object)) { Line ('  ' + $k + ': ' + $tablaPropuesta[$k]) }
Line ''
Line ('-- propuesta CORREGIR: ' + $corregirProp + '  (reemplazo NO cambia el HTML: ' + $sinCambioProp + ') --')
Line '  hosts de la URL final elegida (oficial/externo) top 15:'
foreach ($e in ($oficialHosts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
    Line ('    ' + ('{0,5}' -f $e.Value) + '  ' + $e.Key + '   (oficial)')
}
foreach ($e in ($extHostsProp.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
    Line ('    ' + ('{0,5}' -f $e.Value) + '  ' + $e.Key + '   (externo)')
}
Line ''
if ($ctaHosts.Count -gt 0) {
    Line '-- hosts de CTA externa util (top 15) --'
    foreach ($e in ($ctaHosts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
        Line ('    ' + ('{0,5}' -f $e.Value) + '  ' + $e.Key)
    }
    Line ''
}
Line ('-- regla VIEJA ctd->oficial (solo comparacion): ' + $corregirCtd + '  (regex empleo-boton sin efecto: ' + $sinCambioRegex + ') --')
if ($extHostsRetirar.Count -gt 0) {
    Line '-- RETIRAR-ctd que aun asi tienen enlace externo no-gobpe: hosts (top 15) --'
    foreach ($e in ($extHostsRetirar.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
        Line ('    ' + ('{0,5}' -f $e.Value) + '  ' + $e.Key)
    }
    Line ''
}
if ($muestraRetirar.Count -gt 0) {
    Line '-- muestra de posibles RETIRAR problematicos --'
    foreach ($m in $muestraRetirar) {
        Line ('    ' + $m.id + ' [' + $m.sector + '] cta=' + $m.cta + ' ext=' + $m.externo + ' :: ' + $m.titulo)
    }
}

$txt = $out.ToString()
$dest = Join-Path $env:TEMP 'opencode\diag\diagnostico-enlaces.txt'
if (-not (Test-Path (Split-Path -Parent $dest))) { New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null }
Set-Content -LiteralPath $dest -Value $txt -Encoding UTF8
Write-Output $txt
Log ('guardado en ' + $dest)
