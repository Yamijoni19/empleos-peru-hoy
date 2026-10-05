# corregir-entrada.ps1 — arregla AUTOMATICAMENTE una entrada de empleo
# generada por la IA antes de pegarla en Blogger.
#
# USO (PowerShell):
#   .\corregir-entrada.ps1 -Archivo "entrada.html"
#   .\corregir-entrada.ps1 -Archivo "entrada.html" -Fuente "https://www.convocatoriasdetrabajo.com/....html"
#
# Qué arregla SOLO:
#   - bloque oculto como PRIMER hijo + campos que falten (en "No especificado")
#     [solo Estado; la plantilla Privado no lleva bloque oculto y se respeta]
#   - cabecera con la categoría real (la línea de Fuente se quita SOLO en Estado;
#     en Privado esa línea es parte de su cabecera)
#   - ficha reconstruida con los 4 recuadros de cada plantilla
#     (Estado: Vacantes/Contrato/Dirigido a/Ubicación | Privado: Ubicación/Modalidad/Contrato/Salario)
#   - "No especificado" visible fuera del bloque oculto/la ficha (borra la línea/<li>)
#   - UN SOLO botón con texto exacto POSTULA AQUÍ en la caja final
#   - <a> dentro de "Pasos para postular"/"¿Cómo postular?" (los quita) y textos prohibidos
#   - <style>/<script>/style=  y marcadores @@URL_*@@ (con -Fuente)
#   - secciones que falten (en Estado: renombra los titulos viejos a los 7
#     propios de la plantilla y anade las que falten), banner de vigencia,
#     #ofertasRelacionadas, metadatos ETIQUETA_BLOGGER / TITULO_BLOGGER
#   - CON -FUENTE: repara cada href con una URL que sí existe copiada
#     literalmente en la publicación original (o cae a la URL de origen)
#
# Genera <nombre>-corregido.html y después ejecuta validar-entrada.ps1.
# exit 0 = listo para pegar en Blogger.  exit 1 = quedan errores manuales.

param(
    [Parameter(Mandatory = $true)][string]$Archivo,
    [string]$Fuente = "",
    [string]$Salida = ""
)

$ErrorActionPreference = "Stop"
$cambios = New-Object System.Collections.Generic.List[string]
$avisos = New-Object System.Collections.Generic.List[string]

function Cambio($m) { [void]$script:cambios.Add($m) }
function Aviso($m)  { [void]$script:avisos.Add($m) }

if (-not (Test-Path -LiteralPath $Archivo)) {
    Write-Host "ERROR: no existe el archivo $Archivo"
    exit 1
}
$ruta = (Resolve-Path -LiteralPath $Archivo).Path
$html = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)

# ---------------- helpers ----------------

function Fin-Div([string]$h, [int]$ini) {
    $depth = 0
    $i = $ini
    while ($i -lt $h.Length) {
        $nd = $h.IndexOf("<div", $i)
        $nc = $h.IndexOf("</div>", $i)
        if ($nc -lt 0) { return -1 }
        if ($nd -ge 0 -and $nd -lt $nc) { $depth++; $i = $nd + 4 }
        else {
            $depth--
            $i = $nc + 6
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

function Buscar-Div {
    param([string]$h, [string]$marca, [int]$desde = 0)
    $i = $h.IndexOf($marca, $desde)
    if ($i -lt 0) { return $null }
    $f = Fin-Div $h $i
    if ($f -lt 0) { return $null }
    return @{ Inicio = $i; Fin = $f }
}

function Campo-Oculto([string]$bloque, [string]$campo) {
    $m = [regex]::Match($bloque, '<p><strong>' + [regex]::Escape($campo) + ':</strong>([\s\S]*?)</p>')
    if (-not $m.Success) { return "" }
    return (($m.Groups[1].Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
}

function Quipos($v) {
    if ([string]::IsNullOrWhiteSpace($v)) { return $false }
    if ($v -match '^No especificad[oa]$') { return $false }
    if ($v -match '^No aplica$') { return $false }
    return $true
}

function Primer-Texto([string]$h, [string]$patron) {
    $m = [regex]::Match($h, $patron)
    if (-not $m.Success) { return "" }
    return (($m.Groups[1].Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
}

# ---------------- 0. comentarios (se guardan los metadatos) ----------------

$metas = New-Object System.Collections.Generic.List[string]
$mc = [regex]::Match($html, '<!--[\s\S]*?-->')
while ($mc.Success) {
    if ($mc.Value -match 'ETIQUETA_BLOGGER|TITULO_BLOGGER|TIPO_CONTRATANTE_BLOGGER|TIPO_ENTIDAD_BLOGGER|URL_ORIGEN|URL_POSTULAR|URL_BASES') {
        [void]$metas.Add($mc.Value)
    }
    $mc = $mc.NextMatch()
}
$trabajo = [regex]::Replace($html, '<!--[\s\S]*?-->', '')

# ---------------- 1. localizar la entrada ----------------

$iInd = $trabajo.IndexOf('<div class="empleo-individual">')
if ($iInd -lt 0) {
    Write-Host "ERROR: la entrada no tiene <div class=`"empleo-individual`">. Si es una entrada Privado, usa plantilla-oferta-data.html y valida con validar-entrada.ps1."
    exit 1
}
$fInd = Fin-Div $trabajo $iInd
if ($fInd -lt 0) { Write-Host "ERROR: estructura de divs rota en la entrada."; exit 1 }
$cuerpo = $trabajo.Substring($iInd, $fInd - $iInd)

# tipo de entrada: Estado (bloque oculto) vs Privado (plantilla data-only)
$esEstado = [regex]::IsMatch($cuerpo, '<strong>Tipo contratante:</strong>\s*Estado\b')
$esPrivado = (-not $esEstado) -and [regex]::IsMatch($cuerpo, '<strong>Tipo contratante:</strong>\s*Privado\b')

# ---------------- 1b. artefactos de citas de la IA + enlaces repetidos en Bases ---------

$antes1b = $cuerpo
$cuerpo = [regex]::Replace($cuerpo, '\s*:contentReference\s*\[[^\]]*\]\s*\{[^}]*\}', '')
$cuerpo = [regex]::Replace($cuerpo, '\s*oaicite\s*\[[^\]]*\]\s*\{[^}]*\}', '')
$cuerpo = [regex]::Replace($cuerpo, '\s*\[citation\]', '')
$cuerpo = [regex]::Replace($cuerpo, '\s*【[^】]*】', '')
if ($cuerpo -ne $antes1b) { Cambio "artefactos de citas de la IA eliminados (:contentReference / oaicite / [citation])" }

$iB = $cuerpo.IndexOf('<h2>Bases y anexos oficiales</h2>')
if ($iB -lt 0) { $iB = $cuerpo.IndexOf('<h2>Descargar bases</h2>') }
if ($iB -ge 0) {
    $fB = $cuerpo.IndexOf('<div class="empleo-seccion">', $iB + 5)
    if ($fB -lt 0) { $fB = $cuerpo.Length }
    $seg = $cuerpo.Substring($iB, $fB - $iB)
    $vistos = @{}
    $borrar = @()
    foreach ($mLi in [regex]::Matches($seg, '<li>[\s\S]*?</li>')) {
        $mH = [regex]::Match($mLi.Value, 'href="([^"]+)"')
        if (-not $mH.Success) { continue }
        $u = $mH.Groups[1].Value
        if ($vistos.ContainsKey($u)) { $borrar += @{ I = $mLi.Index; L = $mLi.Length; U = $u } }
        else { $vistos[$u] = $true }
    }
    foreach ($b in ($borrar | Sort-Object -Property I -Descending)) {
        $seg = $seg.Remove($b.I, $b.L)
        Cambio ("enlace repetido en 'Bases y anexos oficiales' eliminado: " + $b.U)
    }
    if ($borrar.Count -gt 0) { $cuerpo = $cuerpo.Remove($iB, $fB - $iB).Insert($iB, $seg) }
}

# 1c. si no pasaron -Fuente, se usa la URL de 'Fuente' del bloque oculto
if ($Fuente -eq "") {
    $mF = [regex]::Match($cuerpo, '<strong>Fuente:</strong>\s*(https?://[^\s<]+)')
    if ($mF.Success) {
        $Fuente = $mF.Groups[1].Value.Trim()
        Aviso ("sin -Fuente: uso la URL del bloque oculto 'Fuente': " + $Fuente)
    }
}

# ---------------- 2. bloque oculto: primer hijo + 18 campos ----------------

$occ = Buscar-Div $cuerpo '<div class="empleo-datos-ocultos">'
$oculto = ""
if (-not $occ) {
    if (-not $esPrivado) {
        Write-Host "ERROR: falta el bloque oculto .empleo-datos-ocultos. No puedo inventar los 18 datos: pide la salida de nuevo a la IA."
        exit 1
    }
    Aviso "entrada Privado (sin bloque oculto): se omiten los pasos de datos ocultos"
} else {
$oculto = $cuerpo.Substring($occ.Inicio, $occ.Fin - $occ.Inicio)
$campos = @("Fuente","Categoría","Empresa","Ubicación","Ciudad","Modalidad","Salario","Contrato",
            "Vacantes","Dirigido a","Estudios","Experiencia","Jornada","Fecha de publicación",
            "Fecha de cierre","Tipo contratante","Tipo de contrato Estado","Tipo de entidad")
$faltan = @()
foreach ($c in $campos) {
    if ($oculto.IndexOf("<strong>${c}:</strong>") -lt 0) { $faltan += $c }
}
foreach ($c in $faltan) {
    $cierra = $oculto.LastIndexOf("</div>")
    $oculto = $oculto.Substring(0, $cierra) + '  <p><strong>' + $c + ':</strong> No especificado</p>' + "`n" + $oculto.Substring($cierra)
    Cambio ("campo oculto faltante añadido como 'No especificado': " + $c)
}
$tagInd = '<div class="empleo-individual">'
$yaPrimero = (($cuerpo.Substring(0, $occ.Inicio)) -replace '\s+', '') -eq ($tagInd -replace '\s+', '')
if (-not $yaPrimero) {
    $cuerpo = $cuerpo.Remove($occ.Inicio, $occ.Fin - $occ.Inicio)
    $iTag = $cuerpo.IndexOf($tagInd)
    $cuerpo = $cuerpo.Insert($iTag + $tagInd.Length, "`n`n" + $oculto + "`n`n")
    Cambio "bloque oculto movido a la PRIMER posición de .empleo-individual"
    $occ = Buscar-Div $cuerpo '<div class="empleo-datos-ocultos">'
    $oculto = $cuerpo.Substring($occ.Inicio, $occ.Fin - $occ.Inicio)
} elseif ($faltan.Count -gt 0) {
    $cuerpo = $cuerpo.Remove($occ.Inicio, $occ.Fin - $occ.Inicio).Insert($occ.Inicio, $oculto)
    $occ = Buscar-Div $cuerpo '<div class="empleo-datos-ocultos">'
    $oculto = $cuerpo.Substring($occ.Inicio, $occ.Fin - $occ.Inicio)
}
}

# ---------------- 3. cabecera: sin Fuente + con categoría ----------------

$cab = Buscar-Div $cuerpo '<div class="empleo-cabecera">'
if ($cab) {
    $bloqueCab = $cuerpo.Substring($cab.Inicio, $cab.Fin - $cab.Inicio)
    if (-not $esPrivado) {   # en Privado la cabecera SÍ lleva la línea de Fuente
        $nuevoCab = [regex]::Replace($bloqueCab, '<div class="empleo-fuente">[\s\S]*?</div>', '')
        if ($nuevoCab -ne $bloqueCab) {
            Cambio "línea de Fuente eliminada de la cabecera"
            $bloqueCab = $nuevoCab
        }
    }
    if ($bloqueCab.IndexOf('<div class="empleo-categoria">') -lt 0) {
        $cat = Campo-Oculto $oculto "Categoría"
        if (-not (Quipos $cat)) { $cat = "Otros" }
        $marcaCab = '<div class="empleo-cabecera">'
        $pCab = $bloqueCab.IndexOf($marcaCab) + $marcaCab.Length
        $bloqueCab = $bloqueCab.Insert($pCab, "`n`n  <div class=`"empleo-categoria`">" + $cat + "</div>`n")
        Cambio ("categoría añadida a la cabecera: " + $cat)
    }
    $cuerpo = $cuerpo.Substring(0, $cab.Inicio) + $bloqueCab + $cuerpo.Substring($cab.Fin)
    $cab = Buscar-Div $cuerpo '<div class="empleo-cabecera">'
}

# quitar la línea de Fuente también si aparece en otro sitio de la entrada (solo Estado)
if (-not $esPrivado -and $cuerpo.IndexOf('<div class="empleo-fuente">') -ge 0) {
    $cuerpo = [regex]::Replace($cuerpo, '<div class="empleo-fuente">[\s\S]*?</div>', '')
    Cambio "línea de Fuente (.empleo-fuente) eliminada"
}

# ---------------- 4. ficha: SIEMPRE los 4 recuadros ----------------

$cv = @{}
foreach ($m in [regex]::Matches($cuerpo, '<div class="empleo-info-label">([^<]*)</div>\s*<div class="empleo-info-value">([\s\S]*?)</div>')) {
    $cv[$m.Groups[1].Value.Trim()] = $m.Groups[2].Value.Trim()
}
$labelsFicha = @("Vacantes","Contrato","Dirigido a","Ubicación")   # Estado
$mapaCampos = @{
    "Vacantes"   = "Vacantes"
    "Contrato"   = "Tipo de contrato Estado"
    "Dirigido a" = "Dirigido a"
    "Ubicación"  = "Ubicación"
}
if ($esPrivado) {   # la ficha Privado trae otros 4 recuadros
    $labelsFicha = @("Ubicación","Modalidad","Contrato","Salario")
    $mapaCampos = @{
        "Ubicación" = "Ubicación"
        "Modalidad" = "Modalidad"
        "Contrato"  = "Contrato"
        "Salario"   = "Salario"
    }
}
$ficha = "`n"
foreach ($l in $labelsFicha) {
    $v = ""
    if ($cv.ContainsKey($l)) { $v = $cv[$l] }
    if (-not (Quipos $v)) { $v = Campo-Oculto $oculto $mapaCampos[$l] }
    if (-not (Quipos $v)) { $v = "No especificado" }
    $ficha += '  <div class="empleo-info-card">' + "`n" +
              '    <div class="empleo-info-label">' + $l + '</div>' + "`n" +
              '    <div class="empleo-info-value">' + $v + '</div>' + "`n" +
              '  </div>' + "`n"
}
$nuevoInfo = '<div class="empleo-info">' + $ficha + '</div>'
$inf = Buscar-Div $cuerpo '<div class="empleo-info">'
if ($inf) {
    $viejoInfo = $cuerpo.Substring($inf.Inicio, $inf.Fin - $inf.Inicio)
    $nCards = ([regex]::Matches($viejoInfo, 'class="empleo-info-card"')).Count
    $labels = @()
    foreach ($m in [regex]::Matches($viejoInfo, '<div class="empleo-info-label">([^<]*)</div>')) { $labels += $m.Groups[1].Value.Trim() }
    $ordenOk = ($labels -join "|") -eq ($labelsFicha -join "|")
    if ($nCards -ne 4 -or -not $ordenOk) {
        $cuerpo = $cuerpo.Substring(0, $inf.Inicio) + $nuevoInfo + $cuerpo.Substring($inf.Fin)
        Cambio ("ficha reconstruida con los 4 recuadros (tenía " + $nCards + ")")
    }
} else {
    $donde = $cab
    if (-not $donde) { $donde = $occ }
    $cuerpo = $cuerpo.Insert($donde.Fin, "`n`n" + $nuevoInfo + "`n")
    Cambio "ficha creada con los 4 recuadros"
}

# ---------------- 5. "No especificado" visible fuera de sitio ----------------

$occ2 = Buscar-Div $cuerpo '<div class="empleo-datos-ocultos">'
$finOculto2 = 0
if ($occ2) { $finOculto2 = $occ2.Fin }   # Privado: no hay bloque oculto
$cabe = $cuerpo.Substring(0, $finOculto2)
$resto = $cuerpo.Substring($finOculto2)
foreach ($t in @('p', 'li')) {
    $patron = '<' + $t + '\b[^>]*>(?:(?!</' + $t + '>)[\s\S])*?No especificad[oa](?:(?!</' + $t + '>)[\s\S])*?</' + $t + '>'
    $n = ([regex]::Matches($resto, $patron)).Count
    if ($n -gt 0) {
        $resto = [regex]::Replace($resto, $patron, '')
        Cambio ("fuera de sitio: borradas " + $n + " línea(s)/ítem(s) con 'No especificado' en <" + $t + ">")
    }
}
$cuerpo = $cabe + $resto

# ---------------- 6. <style>/<script>/style= ----------------

if ([regex]::IsMatch($cuerpo, '<script[\s\S]*?</script>')) {
    $cuerpo = [regex]::Replace($cuerpo, '<script[\s\S]*?</script>', '')
    Cambio "<script> eliminado de la entrada"
}
if ([regex]::IsMatch($cuerpo, '<style[\s\S]*?</style>')) {
    $cuerpo = [regex]::Replace($cuerpo, '<style[\s\S]*?</style>', '')
    Cambio "<style> eliminado de la entrada"
}
if ([regex]::IsMatch($cuerpo, '\s+style="[^"]*"')) {
    $cuerpo = [regex]::Replace($cuerpo, '\s+style="[^"]*"', '')
    Cambio "atributos style= eliminados"
}

# ---------------- 7. marcadores de URL ----------------

if ($Fuente -ne "") {
    foreach ($mk in @('@@URL_ORIGEN@@', '@@URL_POSTULAR@@', '@@URL_BASES@@')) {
        if ($cuerpo.IndexOf($mk) -ge 0) {
            $cuerpo = $cuerpo.Replace($mk, $Fuente)
            Cambio ("marcador " + $mk + " sustituido por la URL de origen")
        }
    }
}

# ---------------- 8. anclas: UN solo botón, texto exacto ----------------

$pb = Buscar-Div $cuerpo '<div class="empleo-postular">'
$rangoPost = $null
if ($pb) { $rangoPost = @($pb.Inicio, $pb.Fin) }

$anclas = [regex]::Matches($cuerpo, '<a\b[^>]*>[\s\S]*?</a>')
$ops = @()
$btnValido = $false
$hrefBoton = ""
$nSobrantes = 0

foreach ($a in $anclas) {
    $cls = ""
    if ($a.Value -match 'class="([^"]*)"') { $cls = $Matches[1] }
    $href = ""
    if ($a.Value -match 'href="([^"]*)"') { $href = $Matches[1] }
    $texto = (($a.Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
    $dentroPost = ($rangoPost -and $a.Index -ge $rangoPost[0] -and $a.Index -lt $rangoPost[1])
    $esBoton = $cls -match 'empleo-boton|empleo-enlace-oficial'

    if ($dentroPost) {
        if (-not $btnValido) {
            $btnOk = ($cls -match '(^|\s)empleo-boton(\s|$)') -and (Quipos $href) -and
                     (($texto -eq "POSTULA AQUÍ") -or ($texto -match '^POSTULAR EN \S'))
            if ($btnOk) {
                $btnValido = $true
                $hrefBoton = $href
                continue
            }
            if (Quipos $href) { $hrefBoton = $href }
            $nSobrantes++
            $ops += @{ I = $a.Index; F = $a.Index + $a.Value.Length; T = "" }
        } else {
            $nSobrantes++
            $ops += @{ I = $a.Index; F = $a.Index + $a.Value.Length; T = "" }
        }
    } elseif ($esBoton) {
        if ((-not (Quipos $hrefBoton)) -and (Quipos $href)) { $hrefBoton = $href }
        $nSobrantes++
        $ops += @{ I = $a.Index; F = $a.Index + $a.Value.Length; T = "" }
    }
}

$opsOrden = $ops | Sort-Object -Property I -Descending
foreach ($o in $opsOrden) {
    $cuerpo = $cuerpo.Remove($o.I, ($o.F - $o.I)).Insert($o.I, $o.T)
}
if ($nSobrantes -gt 0) { Cambio ("botones/enlaces sobrantes eliminados: " + $nSobrantes + " (queda UNO solo)") }

if (-not (Quipos $hrefBoton)) {
    $iBases = $cuerpo.IndexOf('<h2>Bases y anexos oficiales</h2>')
    if ($iBases -lt 0) { $iBases = $cuerpo.IndexOf('<h2>Descargar bases</h2>') }
    if ($iBases -ge 0) {
        $mB = [regex]::Match($cuerpo.Substring($iBases), 'href="([^"]+)"')
        if ($mB.Success) { $hrefBoton = $mB.Groups[1].Value }
    }
}
if (-not (Quipos $hrefBoton)) {
    $mP = [regex]::Match($cuerpo, 'href="(https?://[^"]+)"')
    if ($mP.Success) { $hrefBoton = $mP.Groups[1].Value }
}
if (-not (Quipos $hrefBoton) -and $Fuente -ne "") { $hrefBoton = $Fuente }

$textoBoton = "POSTULA AQUÍ"
$titCaja = "¿Te interesa esta convocatoria?"
$avisoCaja = "Antes de postular revisa las bases y el cronograma oficiales."
if ($esPrivado) {   # en Privado el botón dice POSTULAR EN <portal>
    $textoBoton = "POSTULAR EN EL PORTAL"
    if ($hrefBoton -match '^https?://([^/]+)') {
        $textoBoton = "POSTULAR EN " + (($Matches[1] -replace '^www\.', '') -replace '\..*$', '').ToUpper()
    }
    $titCaja = "¿Te interesa esta oferta?"
    $avisoCaja = "La postulación se realiza directamente en la plataforma de origen."
}
$botonCanonico = '<a class="empleo-boton" href="' + $hrefBoton + '" target="_blank" rel="noopener noreferrer">' + $textoBoton + '</a>'

if (-not $btnValido) {
    $pb = Buscar-Div $cuerpo '<div class="empleo-postular">'
    if ($pb) {
        $bloquePost = $cuerpo.Substring($pb.Inicio, $pb.Fin - $pb.Inicio)
        $marcaPost = '<div class="empleo-postular">'
        $pPost = $bloquePost.IndexOf($marcaPost) + $marcaPost.Length
        $bloquePost = $bloquePost.Insert($pPost, "`n  " + $botonCanonico + "`n")
        $cuerpo = $cuerpo.Substring(0, $pb.Inicio) + $bloquePost + $cuerpo.Substring($pb.Fin)
        Cambio ("botón añadido en la caja final: " + $textoBoton)
    } else {
        $caja = "`n<div class=`"empleo-postular`">`n  <h2>" + $titCaja + "</h2>`n  " + $botonCanonico +
                "`n  <div class=`"empleo-aviso`">" + $avisoCaja + "</div>`n</div>`n"
        $iRel = $cuerpo.IndexOf('<div class="ofertas-relacionadas">')
        if ($iRel -ge 0) { $cuerpo = $cuerpo.Insert($iRel, $caja) }
        else { $cuerpo = $cuerpo.Insert($cuerpo.LastIndexOf("</div>"), $caja) }
        Cambio "caja final creada con el botón POSTULA AQUÍ"
    }
}

# ---------------- 9. nada de <a> en la seccion de postulacion ----------------

$iComo = $cuerpo.IndexOf('<h2>Pasos para postular</h2>')
if ($iComo -lt 0) { $iComo = $cuerpo.IndexOf('<h2>¿Cómo postular?</h2>') }
if ($iComo -ge 0) {
    $finSec = $cuerpo.IndexOf('<div class="empleo-anuncio">', $iComo)
    if ($finSec -lt 0) { $finSec = $cuerpo.IndexOf('<div class="empleo-seccion">', $iComo) }
    if ($finSec -lt 0) { $finSec = $cuerpo.IndexOf('<div class="empleo-postular">', $iComo) }
    if ($finSec -lt 0) { $finSec = $cuerpo.Length }
    $sec = $cuerpo.Substring($iComo, $finSec - $iComo)
    $orig = $sec
    # primero quitar enlaces de acción (POSTULA/VER...), luego dejar el texto de los demás
    $sec = [regex]::Replace($sec, '<a\b[^>]*>(?:(?!</a>)[\s\S])*?(POSTULA|VER |Ir a|Ver |publicación oficial|convocatoria oficial)(?:(?!</a>)[\s\S])*?</a>', '')
    $sec = [regex]::Replace($sec, '<a\b[^>]*>([\s\S]*?)</a>', '$1')
    if ($sec -ne $orig) {
        $cuerpo = $cuerpo.Substring(0, $iComo) + $sec + $cuerpo.Substring($finSec)
        Cambio "en la seccion de postulacion no queda ningun <a>"
    }
}

# ---------------- 10. textos de botón prohibidos ----------------

foreach ($t in @("Ver publicación oficial", "Ver convocatoria oficial", "Ir a la convocatoria oficial")) {
    foreach ($tag in @('p', 'li')) {
        $patron = '<' + $tag + '\b[^>]*>(?:(?!</' + $tag + '>)[\s\S])*?' + [regex]::Escape($t) + '(?:(?!</' + $tag + '>)[\s\S])*?</' + $tag + '>'
        if ([regex]::IsMatch($cuerpo, $patron)) {
            $cuerpo = [regex]::Replace($cuerpo, $patron, '')
            Cambio ("texto prohibido eliminado (<" + $tag + ">): " + $t)
        }
    }
}

# ---------------- 11. secciones que falten ----------------

function Bloque-Destacado([string[]]$lineas) {
    if ($lineas.Count -eq 0) { return "" }
    $s = '  <div class="empleo-destacado">' + "`n"
    foreach ($l in $lineas) { $s += '    <p><strong>' + $l + '</strong></p>' + "`n" }
    $s += '  </div>' + "`n"
    return $s
}

function Linea-Dato([string]$etiqueta, [string]$valor) {
    if (-not (Quipos $valor)) { return $null }
    return ($etiqueta + ': ' + $valor)
}

$lineasReq = @()
foreach ($x in @(@("Estudios", (Campo-Oculto $oculto "Estudios")),
                 @("Experiencia", (Campo-Oculto $oculto "Experiencia")),
                 @("Jornada", (Campo-Oculto $oculto "Jornada")),
                 @("Dirigido a", (Campo-Oculto $oculto "Dirigido a")))) {
    $l = Linea-Dato $x[0] $x[1]
    if ($l) { $lineasReq += $l }
}

$lineasCond = @()
foreach ($x in @(@("Remuneración", (Campo-Oculto $oculto "Salario")),
                 @("Entidad", (Campo-Oculto $oculto "Empresa")),
                 @("Ubicación", (Campo-Oculto $oculto "Ubicación")),
                 @("Modalidad", (Campo-Oculto $oculto "Modalidad")),
                 @("Fecha de publicación", (Campo-Oculto $oculto "Fecha de publicación")),
                 @("Fecha de cierre", (Campo-Oculto $oculto "Fecha de cierre")))) {
    $l = Linea-Dato $x[0] $x[1]
    if ($l) { $lineasCond += $l }
}

$esEstado = [regex]::IsMatch($cuerpo, '<strong>Tipo contratante:</strong>\s*Estado\b')

# Estado: los 5 titulos viejos pasan a los 7 titulos propios de la plantilla
if ($esEstado) {
    $mapaTitulos = @(
        @('<h2>Requisitos</h2>', '<h2>Perfil y funciones del puesto</h2>'),
        @('<h2>Condiciones del contrato</h2>', '<h2>Lo que ofrece esta convocatoria</h2>'),
        @('<h2>¿Cómo postular?</h2>', '<h2>Pasos para postular</h2>'),
        @('<h2>Descargar bases</h2>', '<h2>Bases y anexos oficiales</h2>'),
        @('<h2>Recomendaciones para postular</h2>', '<h2>Consejos antes de postular</h2>')
    )
    $nRen = 0
    foreach ($m in $mapaTitulos) {
        if ($cuerpo.IndexOf($m[0]) -ge 0) { $cuerpo = $cuerpo.Replace($m[0], $m[1]); $nRen++ }
    }
    if ($nRen -gt 0) { Cambio ("titulos de seccion actualizados a la estructura de Estado: " + $nRen) }
}

$esPlantillaPrivNueva = $cuerpo.IndexOf('<h2>Información de la oferta</h2>') -ge 0

$faltanSec = @()

# Estado: el Resumen va como PRIMERA seccion (frase armada con los datos reales)
if ($esEstado -and $cuerpo.IndexOf('<h2>Resumen de la convocatoria</h2>') -lt 0) {
    $empresaR = Campo-Oculto $oculto "Empresa"
    $vacR = Campo-Oculto $oculto "Vacantes"
    $cierreR = Campo-Oculto $oculto "Fecha de cierre"
    $dirigidoR = Campo-Oculto $oculto "Dirigido a"
    if (Quipos $empresaR) { $fraseR = $empresaR + ' publica esta convocatoria' } else { $fraseR = 'Esta convocatoria' }
    if (Quipos $vacR) {
        if ($vacR -match '^\d+$' -and [int]$vacR -eq 1) { $fraseR += ' con 1 vacante' }
        else { $fraseR += ' con ' + $vacR + ' vacantes' }
    }
    if (Quipos $dirigidoR) { $fraseR += ' para ' + $dirigidoR }
    if (Quipos $cierreR) { $fraseR += '; las postulaciones cierran el ' + $cierreR + '.' } else { $fraseR += '.' }
    $fraseR += ' Revisa el perfil, lo que ofrece y los pasos para postular: el detalle oficial esta en las bases.'
    $secRes = ('<div class="empleo-seccion">' + "`n" + '  <h2>Resumen de la convocatoria</h2>' + "`n" +
               '  <p>' + $fraseR + '</p>' + "`n" + '</div>' + "`n" + "`n")
    $iPrimSec = $cuerpo.IndexOf('<div class="empleo-seccion">')
    if ($iPrimSec -ge 0) {
        $cuerpo = $cuerpo.Insert($iPrimSec, $secRes)
        Cambio "seccion 'Resumen de la convocatoria' anadida como primera seccion"
    } else { $faltanSec += $secRes }
}

if ($esEstado) {
    if ($cuerpo.IndexOf('<h2>Perfil y funciones del puesto</h2>') -lt 0) {
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Perfil y funciones del puesto</h2>" + "`n" +
            (Bloque-Destacado $lineasReq) +
            '  <p><strong>Funciones principales:</strong></p>' + "`n" +
            '  <p>Consulta en las bases oficiales la lista completa de funciones del puesto.</p>' + "`n" +
            '</div>' + "`n")
    }
    if ($cuerpo.IndexOf('<h2>Lo que ofrece esta convocatoria</h2>') -lt 0) {
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Lo que ofrece esta convocatoria</h2>" + "`n" +
            (Bloque-Destacado $lineasCond) + '</div>' + "`n")
    }
    if ($cuerpo.IndexOf('<h2>Pasos para postular</h2>') -lt 0) {
        $cierre = Campo-Oculto $oculto "Fecha de cierre"
        $lin = @()
        if (Quipos $cierre) { $lin += ('Fecha límite: ' + $cierre) }
        $pasosOl = ('  <ol>' + "`n" +
            '    <li>Lee completas las bases: requisitos, cronograma, anexos y formularios.</li>' + "`n" +
            '    <li>Reúne y digitaliza tus documentos antes de la fecha límite.</li>' + "`n" +
            '    <li>Ingresa al medio oficial de postulación que indican las bases (el enlace directo está en el botón de la caja final).</li>' + "`n" +
            '    <li>Completa el formulario y adjunta los archivos en el orden que piden las bases.</li>' + "`n" +
            '    <li>Guarda la constancia de postulación y revisa la página de la entidad por cambios de cronograma.</li>' + "`n" +
            '  </ol>' + "`n")
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Pasos para postular</h2>" + "`n" +
            (Bloque-Destacado $lin) +
            '  <p>Postulación según el procedimiento descrito en las bases y el cronograma oficiales.</p>' + "`n" +
            $pasosOl + '</div>' + "`n")
    }
    if ($cuerpo.IndexOf('<h2>Bases y anexos oficiales</h2>') -lt 0) {
        $urlBases = $hrefBoton
        if (-not (Quipos $urlBases) -and $Fuente -ne "") { $urlBases = $Fuente }
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Bases y anexos oficiales</h2>" + "`n  <ul>" + "`n    <li>" + "`n" +
            '      <a href="' + $urlBases + '" target="_blank" rel="noopener noreferrer">' + "`n" +
            '        Bases, cronograma y anexos en la convocatoria oficial' + "`n      </a>" + "`n    </li>`n  </ul>`n</div>`n")
    }
    if ($cuerpo.IndexOf('<h2>Consejos antes de postular</h2>') -lt 0) {
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Consejos antes de postular</h2>" + "`n  <ul>" + "`n" +
            '    <li>Comprueba en las bases que cumples cada requisito antes de llenar el formulario: un solo requisito sin cubrir basta para quedar fuera.</li>' + "`n" +
            '    <li>Digitaliza cada documento en un archivo claro y con el formato que piden las bases; así evitas rechazos por archivos ilegibles.</li>' + "`n" +
            '    <li>Postula únicamente por el canal y dentro del plazo que fija el cronograma oficial: otra vía no es válida.</li>' + "`n" +
            '    <li>Sigue la página de la entidad: ahí aparecen fe de erratas, cambios de cronograma o la suspensión de un proceso.</li>' + "`n  </ul>`n</div>`n")
    }
    if ($cuerpo.IndexOf('<h2>Resultados y siguientes pasos</h2>') -lt 0) {
        $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Resultados y siguientes pasos</h2>" + "`n" +
            '  <p>Cada etapa se resuelve según el cronograma que publican las bases; la entidad indica allí las fechas y el medio de publicación de cada resultado.</p>' + "`n" +
            '  <p>Si no quedas seleccionado, revisa los requisitos del puesto y vuelve a intentarlo: los procesos del Estado se abren de forma periódica.</p>' + "`n" +
            '</div>' + "`n")
    }
}
# Privado: la plantilla vigente ya trae sus 6 secciones; solo se repara la estructura antigua
elseif (-not $esPlantillaPrivNueva) {
if ($cuerpo.IndexOf('<h2>Requisitos</h2>') -lt 0) {
    $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Requisitos</h2>" + "`n" +
        (Bloque-Destacado $lineasReq) + '</div>' + "`n")
}
if ($cuerpo.IndexOf('<h2>Condiciones del contrato</h2>') -lt 0) {
    $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Condiciones del contrato</h2>" + "`n" +
        (Bloque-Destacado $lineasCond) + '</div>' + "`n")
}
if ($cuerpo.IndexOf('<h2>¿Cómo postular?</h2>') -lt 0) {
    $cierre = Campo-Oculto $oculto "Fecha de cierre"
    $lin = @()
    if (Quipos $cierre) { $lin += ('Fechas para postular: ' + $cierre) }
    $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>¿Cómo postular?</h2>" + "`n" +
        (Bloque-Destacado $lin) + '  <p>Postulación según las bases y el cronograma oficiales de la convocatoria.</p>' + "`n" +
        '</div>' + "`n")
}
if ($cuerpo.IndexOf('<h2>Descargar bases</h2>') -lt 0) {
    $urlBases = $hrefBoton
    if (-not (Quipos $urlBases) -and $Fuente -ne "") { $urlBases = $Fuente }
    $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Descargar bases</h2>" + "`n  <ul>" + "`n    <li>" + "`n" +
        '      <a href="' + $urlBases + '" target="_blank" rel="noopener noreferrer">' + "`n" +
        '        Bases, cronograma y anexos en la convocatoria oficial' + "`n      </a>" + "`n    </li>`n  </ul>`n</div>`n")
}
if ($cuerpo.IndexOf('<h2>Recomendaciones para postular</h2>') -lt 0) {
    $faltanSec += ('<div class="empleo-seccion">' + "`n  <h2>Recomendaciones para postular</h2>" + "`n  <ul>" + "`n" +
        '    <li>Revisa a detalle cada punto de las bases: requisitos, cronograma, anexos, formularios y el orden en que se presenta la documentación.</li>' + "`n" +
        '    <li>Postula solo por los medios y en las fechas que indican las bases. Cualquier otro medio puede ser motivo de descarte.</li>' + "`n" +
        '    <li>Estate atento a la página de la entidad para verificar reprogramaciones, suspensiones, fe de erratas o cancelaciones del proceso.</li>' + "`n" +
        '    <li>Los resultados de cada etapa se publican en la página oficial de la entidad.</li>' + "`n  </ul>`n</div>`n")
}
}
if ($faltanSec.Count -gt 0) {
    $bloqueSec = ($faltanSec -join "`n")
    $iPost = $cuerpo.IndexOf('<div class="empleo-postular">')
    $iRel2 = $cuerpo.IndexOf('<div class="ofertas-relacionadas">')
    if ($iPost -ge 0) { $cuerpo = $cuerpo.Insert($iPost, $bloqueSec) }
    elseif ($iRel2 -ge 0) { $cuerpo = $cuerpo.Insert($iRel2, $bloqueSec) }
    else { $cuerpo = $cuerpo.Insert($cuerpo.LastIndexOf("</div>"), $bloqueSec) }
    Cambio ("secciones añadidas: " + $faltanSec.Count)
}

# ---------------- 12. banner de vigencia ----------------

function Fecha-Pasada([string]$texto) {
    if ($texto -match '(\d{2})/(\d{1,2})/(\d{4})') {
        try {
            $d = Get-Date -Year ([int]$Matches[3]) -Month ([int]$Matches[2]) -Day ([int]$Matches[1])
            if ($d -lt (Get-Date).Date) { return $true }
        } catch { }
    }
    return $false
}
$cierreTxt = Campo-Oculto $oculto "Fecha de cierre"
$estadoVig = "CONVOCATORIA VIGENTE."
if (Fecha-Pasada $cierreTxt) { $estadoVig = "CONVOCATORIA FINALIZADA." }

$mVig = [regex]::Match($cuerpo, '<p class="empleo-vigencia[^"]*">[\s\S]*?</p>')
if (-not $mVig.Success) {
    if ($esEstado) {   # la plantilla Privado no lleva banner de vigencia
        $nuevoVig = '<p class="empleo-vigencia">' + $estadoVig + '</p>'
        if ($cab) { $cuerpo = $cuerpo.Insert($cab.Fin, "`n`n" + $nuevoVig + "`n") }
        elseif ($occ) { $cuerpo = $cuerpo.Insert($occ.Fin, "`n`n" + $nuevoVig + "`n") }
        Cambio ("banner de vigencia creado: " + $estadoVig)
    }
} elseif ($mVig.Value -notmatch 'class="empleo-vigencia[^"]*">CONVOCATORIA (VIGENTE|FINALIZADA)\.') {
    $nuevoVig = '<p class="empleo-vigencia">' + $estadoVig + '</p>'
    $cuerpo = $cuerpo.Remove($mVig.Index, $mVig.Value.Length).Insert($mVig.Index, $nuevoVig)
    Cambio ("banner de vigencia normalizado: " + $estadoVig)
}

# ---------------- 13. bloques relacionados ----------------

if ($cuerpo.IndexOf('id="ofertasRelacionadas"') -lt 0) {
    $rel = "`n<div class=`"ofertas-relacionadas`">`n  <h2>Convocatorias relacionadas</h2>" +
           "`n  <div id=`"ofertasRelacionadas`" class=`"relacionados-grid`"></div>`n</div>`n"
    $cuerpo = $cuerpo.Insert($cuerpo.LastIndexOf("</div>"), $rel)
    Cambio "bloque #ofertasRelacionadas añadido"
}

$resultado = $trabajo.Substring(0, $iInd) + $cuerpo + $trabajo.Substring($fInd)

# se reponen ANTES de revisar los metadatos, para no duplicarlos
if ($metas.Count -gt 0) { $resultado = ($metas -join "`n") + "`n" + $resultado }

# ---------------- 14. metadatos de Blogger ----------------

$tituloH1 = Primer-Texto $resultado '<h1>([\s\S]*?)</h1>'
$empresaH1 = Campo-Oculto $oculto "Empresa"
$tituloBlogger = ""
if (Quipos $empresaH1) { $tituloBlogger = $empresaH1 + ": " + $tituloH1 }
else { $tituloBlogger = $tituloH1 }

if ($resultado.IndexOf("ETIQUETA_BLOGGER") -lt 0) {
    $resultado = "<!-- ETIQUETA_BLOGGER = Empleo -->`n" + $resultado
    Cambio "metadato añadido: ETIQUETA_BLOGGER = Empleo"
} elseif ($resultado.IndexOf("ETIQUETA_BLOGGER = Estado") -ge 0 -or $resultado.IndexOf("ETIQUETA_BLOGGER=Estado") -ge 0) {
    $resultado = [regex]::Replace($resultado, 'ETIQUETA_BLOGGER\s*=\s*Estado', 'ETIQUETA_BLOGGER = Empleo')
    Cambio "ETIQUETA_BLOGGER corregida de Estado a Empleo"
}
if ($resultado.IndexOf("TITULO_BLOGGER") -lt 0 -and (Quipos $tituloBlogger)) {
    $resultado = "<!-- TITULO_BLOGGER = " + $tituloBlogger + " -->`n" + $resultado
    Cambio ("metadato añadido: TITULO_BLOGGER = " + $tituloBlogger)
}

# ---------------- 15. reparar href con la publicación original ----------------

function Normalizar-U([string]$u) {
    $s = ([string]$u).ToLower()
    $s = $s -replace '^https?://', ''
    $s = $s -replace '^www\.', ''
    $s = $s -replace '#.*$', ''
    $s = $s -replace '\?.*$', ''
    $s = $s -replace '/$', ''
    return $s
}

function Puntaje-U([string]$entrada, [string]$cand, [string]$contexto) {
    $a = Normalizar-U $entrada
    $b = Normalizar-U $cand
    if ($a -eq "" -or $b -eq "") { return 0 }
    if ($a -eq $b) { return 100 }
    $s = 0
    if ($b.StartsWith($a) -or $a.StartsWith($b) -or $b.IndexOf($a) -ge 0 -or $a.IndexOf($b) -ge 0) { $s += 60 }
    $da = ($a -split '/')[0]
    $db = ($b -split '/')[0]
    if ($da -eq $db) { $s += 25 }
    elseif ($db.IndexOf($da) -ge 0 -or $da.IndexOf($db) -ge 0) { $s += 15 }
    $ra = ($a -replace '^[^/]+', '')
    $rb = ($b -replace '^[^/]+', '')
    if ($ra -and $rb -and $ra -eq $rb) { $s += 15 }
    if ($contexto -eq "postular" -and $b -match 'postul|sisma|seleccion|seleccion|registro|login|plataforma|modul|inscri|portal|auth') { $s += 15 }
    if ($contexto -eq "bases" -and $b -match 'base|anexo|cronograma|\.pdf|document|descarg|resoluc|convocatoria|anexo') { $s += 15 }
    return $s
}

if ($Fuente -ne "") {
    Write-Host "  leyendo la publicación original para reparar los enlaces..."
    $src = $null
    try {
        $src = (Invoke-WebRequest -Uri $Fuente -UseBasicParsing -TimeoutSec 45 -Headers @{ "User-Agent" = "Mozilla/5.0" }).Content
    } catch {
        Aviso ("no pude leer la fuente (" + $_.Exception.Message + ") — los enlaces quedan como estaban")
    }
    if ($src) {
        $cand = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($src, 'href\s*=\s*"([^"]+)"')) {
            $u = $m.Groups[1].Value
            if ($u -match '^https?://' -and $src.IndexOf($u) -ge 0) { [void]$cand.Add($u) }
        }
        foreach ($m in [regex]::Matches($src, 'https?://[^\s"''<>]+')) {
            $u = $m.Value -replace '[\.,;\)\]]+$', ''
            if ($u.Length -gt 12 -and $src.IndexOf($u) -ge 0) { [void]$cand.Add($u) }
        }
        if ($src.IndexOf($Fuente) -ge 0) { [void]$cand.Add($Fuente) }
        Aviso ("candidatos de enlace en la fuente: " + $cand.Count)

        $iPost2 = $resultado.IndexOf('<div class="empleo-postular">')
        $fPost2 = -1
        if ($iPost2 -ge 0) { $fPost2 = Fin-Div $resultado $iPost2 }
        $iBases2 = $resultado.IndexOf('<h2>Bases y anexos oficiales</h2>')
        if ($iBases2 -lt 0) { $iBases2 = $resultado.IndexOf('<h2>Descargar bases</h2>') }
        $fBases2 = -1
        if ($iBases2 -ge 0) {
            $fBases2 = $resultado.IndexOf('<div class="empleo-seccion">', $iBases2 + 5)
            if ($fBases2 -lt 0) { $fBases2 = $resultado.Length }
        }

        $hrefs = [regex]::Matches($resultado, 'href="([^"]*)"')
        $reemp = @()
        foreach ($h in $hrefs) {
            $u = $h.Groups[1].Value
            if (-not ($u -match '^https?://')) { continue }
            if ($src.IndexOf($u) -ge 0) { continue }
            $pos = $h.Index
            $ctx = "otro"
            if ($iPost2 -ge 0 -and $fPost2 -gt $pos -and $pos -gt $iPost2) { $ctx = "postular" }
            elseif ($iBases2 -ge 0 -and $fBases2 -gt $pos -and $pos -gt $iBases2) { $ctx = "bases" }

            $mejor = ""
            $mejorS = 0
            foreach ($c in $cand) {
                $s = Puntaje-U $u $c $ctx
                if ($s -gt $mejorS) { $mejorS = $s; $mejor = $c }
            }
            if ($mejorS -ge 40 -and $mejor -ne "") {
                $reemp += @{ I = $h.Index; L = $h.Value.Length; Vieja = $u; Nueva = $mejor }
            } elseif ($src.IndexOf($Fuente) -ge 0) {
                $reemp += @{ I = $h.Index; L = $h.Value.Length; Vieja = $u; Nueva = $Fuente }
            } else {
                Aviso ("sin candidato fiable para: " + $u)
            }
        }
        foreach ($r in ($reemp | Sort-Object -Property I -Descending)) {
            $viejoAttr = 'href="' + $r.Vieja + '"'
            $nuevoAttr = 'href="' + $r.Nueva + '"'
            $resultado = $resultado.Remove($r.I, $r.L).Insert($r.I, $nuevoAttr)
            Cambio ("enlace reparado: " + $r.Vieja + "  ->  " + $r.Nueva)
        }

        # 15b. Bases: quitar hrefs repetidos (p. ej. los que la reparación dejó iguales)
        #      y completar la lista con los documentos que la IA dejó fuera.
        #      Las posiciones se recalculan SIEMPRE sobre $resultado ya reparado.
        $iBases2 = $resultado.IndexOf('<h2>Bases y anexos oficiales</h2>')
        if ($iBases2 -lt 0) { $iBases2 = $resultado.IndexOf('<h2>Descargar bases</h2>') }
        $fBases2 = -1
        if ($iBases2 -ge 0) {
            $fBases2 = $resultado.IndexOf('<div class="empleo-seccion">', $iBases2 + 5)
            if ($fBases2 -lt 0) { $fBases2 = $resultado.Length }

            $segB2 = $resultado.Substring($iBases2, $fBases2 - $iBases2)
            $vistos2 = @{}
            $sobra2 = @()
            foreach ($mLi in [regex]::Matches($segB2, '<li>[\s\S]*?</li>')) {
                $mH = [regex]::Match($mLi.Value, 'href="([^"]+)"')
                if (-not $mH.Success) { continue }
                $u = $mH.Groups[1].Value
                if ($vistos2.ContainsKey($u)) { $sobra2 += @{ I = $mLi.Index; L = $mLi.Length; U = $u } }
                else { $vistos2[$u] = $true }
            }
            foreach ($b in ($sobra2 | Sort-Object -Property I -Descending)) {
                $segB2 = $segB2.Remove($b.I, $b.L)
                Cambio ("enlace repetido en 'Bases y anexos oficiales' eliminado: " + $b.U)
            }

            $hay = @()
            foreach ($mH in [regex]::Matches($segB2, 'href="([^"]+)"')) { $hay += $mH.Groups[1].Value }
            $nItems = ([regex]::Matches($segB2, '<li>[\s\S]*?</li>')).Count
            if ($nItems -lt 3) {
                $nuevas = @()
                $titulos = @()
                foreach ($ma in [regex]::Matches($src, '<a[^>]+href="(https?://[^"]+)"[^>]*>([\s\S]*?)</a>')) {
                    if ($nItems + $nuevas.Count -ge 3) { break }
                    $u = $ma.Groups[1].Value
                    if ($hay -contains $u -or $nuevas -contains $u) { continue }
                    $t = (($ma.Groups[2].Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()
                    if ($t -eq '') { continue }
                    if ($t -notmatch 'descarga|bases|cronograma|anexo|ficha|declaraci') { continue }
                    $t = $t -replace '(?i)^\s*(descarga aqu[ií]|descarga|bajar|baja|ver)\s+', ''
                    $t = $t.Trim()
                    if ($t -eq '') { $t = "Documento oficial de la convocatoria" }
                    $nuevas += $u
                    $titulos += $t
                }
                if ($nuevas.Count -gt 0) {
                    $nuevosLi = ""
                    for ($k = 0; $k -lt $nuevas.Count; $k++) {
                        $nuevosLi += "`n    <li>`n      <a`n        href=`"" + $nuevas[$k] + "`"`n        target=`"_blank`"`n        rel=`"noopener noreferrer`"`n      >`n        " + $titulos[$k] + "`n      </a>`n    </li>"
                    }
                    $iCierre = $segB2.LastIndexOf('</ul>')
                    if ($iCierre -gt 0) {
                        $segB2 = $segB2.Insert($iCierre, $nuevosLi)
                        for ($k = 0; $k -lt $nuevas.Count; $k++) {
                            Cambio ("documento añadido a 'Bases y anexos oficiales': " + $titulos[$k] + "  ->  " + $nuevas[$k])
                        }
                    }
                }
            }

            # UNA sola reescritura de la sección (las posiciones no se tocan antes)
            if ($segB2 -ne $resultado.Substring($iBases2, $fBases2 - $iBases2)) {
                $resultado = $resultado.Remove($iBases2, $fBases2 - $iBases2).Insert($iBases2, $segB2)
            }
        }
    }
}

# ---------------- 16. escribir + validar ----------------

if ($Salida -eq "") {
    $dir = Split-Path -Parent $ruta
    $base = [System.IO.Path]::GetFileNameWithoutExtension($ruta)
    $Salida = Join-Path $dir ($base + "-corregido.html")
}
[System.IO.File]::WriteAllText($Salida, $resultado, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "== CORRIGIENDO: $Archivo =="
if ($avisos.Count -gt 0) { $avisos | ForEach-Object { Write-Host "  AVISO : $_" } }
if ($cambios.Count -gt 0) {
    $cambios | ForEach-Object { Write-Host "  FIX   : $_" }
} else {
    Write-Host "  FIX   : nada que corregir"
}
Write-Host ""
Write-Host "Guardado en: $Salida"
Write-Host ""

$validador = Join-Path $PSScriptRoot "validar-entrada.ps1"
if (-not (Test-Path -LiteralPath $validador)) {
    Write-Host "AVISO: no encuentro validar-entrada.ps1 junto a este script."
    exit 1
}
if ($Fuente -ne "") {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validador -Archivo $Salida -Fuente $Fuente
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validador -Archivo $Salida
}
$rc = $LASTEXITCODE
Write-Host ""
if ($rc -eq 0) {
    $copiado = $false
    try {
        Set-Clipboard -Value $resultado
        $copiado = $true
    } catch {
        $copiado = $false
    }
    if ($copiado) {
        Write-Host "CORRECCION OK — HTML copiado al PORTAPAPELES: en Blogger solo pega (Ctrl+V)."
        Write-Host "  (también guardado en: $Salida)"
    } else {
        Write-Host "CORRECCION OK — pega $Salida en Blogger."
    }
} else {
    Write-Host "QUEDAN ERRORES — revisa la lista de arriba y corrige esos puntos a mano."
}
exit $rc
