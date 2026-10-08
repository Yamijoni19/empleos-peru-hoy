# validar-entrada.ps1 — valida una entrada de empleo ANTES de pegarla en Blogger.
#
# USO (PowerShell):
#   .\validar-entrada.ps1 -Archivo "entrada.html"
#   .\validar-entrada.ps1 -Archivo "entrada.html" -Fuente "https://www.convocatoriasdetrabajo.com/....html"
#   .\validar-entrada.ps1 -Archivo "entrada.html" -Calidad    # puerta Fase A
#
# Con -Fuente también comprueba que TODOS los enlaces (href) de la entrada
# existan COPIADOS LITERALMENTE en la publicación original.
# Con -Calidad añade la puerta de calidad Fase A: categoria canonica (7 del
# tema), glosario de salario/vacantes/fechas, sin enums crudos (FULL_TIME...),
# li <=200, parrafos <=5 oraciones, orden de secciones nuevas y anti-copia
# (error >=35%, aviso >=20% — estos dos ultimos solo con -Fuente legible).
# Devuelve exit code 0 = TODO OK, 1 = hay errores.

param(
    [Parameter(Mandatory = $true)][string]$Archivo,
    [string]$Fuente = "",
    [switch]$Calidad
)

$ErrorActionPreference = "Stop"
$raizLib = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $raizLib 'lib\categoria.ps1')
. (Join-Path $raizLib 'lib\reescritor.ps1')
$errores = New-Object System.Collections.Generic.List[string]
$avisos  = New-Object System.Collections.Generic.List[string]

function Err($m)  { $script:errores.Add($m) }
function Aviso($m) { $script:avisos.Add($m) }

# texto plano (sin etiquetas, sin tildes ni signos) para comparar similitud
function Solo-Texto([string]$t) {
    $s = [string]$t
    $s = $s -replace '<[^>]+>', ' '
    $s = $s -replace '&[a-z]+;', ' '
    $s = $s.ToLowerInvariant()
    $s = $s -replace '[^a-z0-9\s]', ' '
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

if (-not (Test-Path -LiteralPath $Archivo)) { Write-Host "ERROR: no existe el archivo $Archivo"; exit 1 }
$html = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Archivo), [System.Text.Encoding]::UTF8)
$body = $html -replace '<!--[\s\S]*?-->', ''   # sin comentarios

# tipo de entrada: Estado (bloque oculto) vs Privado (plantilla data-only)
$esEstado = [regex]::IsMatch($body, '<strong>Tipo contratante:</strong>\s*Estado\b')

Write-Host "== VALIDANDO: $Archivo =="

# 1. marcadores sin rellenar
if ($body -match '@@[A-Z0-9_]+@@') {
    $m = [regex]::Match($body, '@@[A-Z0-9_]+@@'); Err ("quedan marcadores sin rellenar: " + $m.Value)
}

# 2. sin CSS/JS inline (se exceptua el bloque fix-parpadeo conocido de la plantilla)
$chk2 = $body -replace '(?s)<style>/\*fix-parpadeo[^<]*</style>', ''
if ($chk2 -match '<style|<script|style="') { Err "la entrada contiene <style>, <script> o style= (prohibido)" }

# 2b. sin artefactos de citas de la IA
if ($body -match ':contentReference\s*\[' -or $body -match 'oaicite\s*\[' -or $body -match '\[citation\]') {
    Err "queda un artefacto de cita de la IA en el texto (:contentReference / oaicite / [citation])"
}

# 3. estructura base
$iInd = $body.IndexOf('<div class="empleo-individual">')
if ($iInd -lt 0) { Err "falta <div class=`"empleo-individual`">"; Write-Host ""; $errores | ForEach-Object { Write-Host "  ERROR: $_" }; exit 1 }
$iOculto = $body.IndexOf('<div class="empleo-datos-ocultos">')
if ($iOculto -lt 0) {
    # el bloque oculto es obligatorio en Estado; la plantilla Privado no lo trae
    if ($esEstado -or $body.IndexOf('<strong>Tipo contratante:</strong>') -lt 0) {
        Err "falta el bloque oculto .empleo-datos-ocultos"
    }
}
elseif ($iOculto -lt $iInd) { Err "el bloque oculto esta fuera de .empleo-individual" }
elseif ((($body.Substring($iInd, $iOculto - $iInd)) -replace '\s+', '') -ne '<divclass="empleo-individual">') {
    Err "el bloque oculto NO es el PRIMER hijo de .empleo-individual"
}

# 4. los 18 campos del bloque oculto
$campos = @("Fuente","Categoría","Empresa","Ubicación","Ciudad","Modalidad","Salario","Contrato",
            "Vacantes","Dirigido a","Estudios","Experiencia","Jornada","Fecha de publicación",
            "Fecha de cierre","Tipo contratante","Tipo de contrato Estado","Tipo de entidad")
if ($iOculto -ge 0) {
    $finOculto = $body.IndexOf("</div>", $iOculto)
    $oculto = $body.Substring($iOculto, $finOculto - $iOculto)
    foreach ($c in $campos) { if ($oculto.IndexOf("<strong>${c}:</strong>") -lt 0) { Err ("bloque oculto sin campo: " + $c) } }

    # 5. "No especificado" visible (permitido solo dentro de los recuadros de la ficha)
    $visible = $body.Substring($finOculto)
    $sinFicha = $visible -replace '<div class="empleo-info-value">[\s\S]*?</div>', ''
    $sinFicha = $sinFicha -replace '<div class="empleo-anuncio">[\s\S]*?</div>', ''
    if ($sinFicha.IndexOf("No especificado") -ge 0) {
        $p = $sinFicha.IndexOf("No especificado")
        $ctx = $sinFicha.Substring([Math]::Max(0, $p - 90), [Math]::Min(160, $sinFicha.Length - [Math]::Max(0, $p - 90)))
        Err ("'No especificado' visible fuera de los 4 recuadros: ..." + ($ctx -replace '\s+', ' '))
    }
}

# 6. ficha: exactamente 4 recuadros con sus etiquetas
$nCards = ([regex]::Matches($body, 'class="empleo-info-card"')).Count
if ($nCards -ne 4) { Err ("la ficha debe tener 4 recuadros; tiene " + $nCards) }
$labelsFicha = @("Vacantes","Contrato","Dirigido a","Ubicación")   # Estado
if (-not $esEstado) { $labelsFicha = @("Ubicación","Modalidad","Contrato","Salario") }  # Privado
foreach ($l in $labelsFicha) {
    if ($body.IndexOf('<div class="empleo-info-label">' + $l + '</div>') -lt 0) { Err ("falta el recuadro de la ficha: " + $l) }
}

# 7. secciones obligatorias (Estado usa sus 7 titulos; Privado, los de su plantilla)
if ($esEstado) {
    $seccionesObl = @("<h2>Resumen de la convocatoria</h2>","<h2>Perfil y funciones del puesto</h2>",
                      "<h2>Lo que ofrece esta convocatoria</h2>","<h2>Pasos para postular</h2>",
                      "<h2>Bases y anexos oficiales</h2>","<h2>Consejos antes de postular</h2>",
                      "<h2>Resultados y siguientes pasos</h2>")
} elseif ($body.IndexOf("<h2>Información de la oferta</h2>") -ge 0) {
    # plantilla data-only vigente. Funciones/Requisitos/Beneficios pueden no
    # existir si la fuente no trae ese contenido (se omiten en vez de texto generico)
    $seccionesObl = @("<h2>Descripción del puesto</h2>",
                      "<h2>Información de la oferta</h2>","<h2>Información de la empresa</h2>")
    foreach ($sOpt in @("<h2>Funciones</h2>","<h2>Requisitos</h2>","<h2>Beneficios</h2>")) {
        if ($body.IndexOf($sOpt) -lt 0) { Aviso ("seccion omitida (sin contenido real): " + $sOpt) }
    }
} else {
    # entradas Privado antiguas
    $seccionesObl = @("<h2>Requisitos</h2>","<h2>Condiciones del contrato</h2>","<h2>¿Cómo postular?</h2>",
                      "<h2>Descargar bases</h2>","<h2>Recomendaciones para postular</h2>")
}
foreach ($s in $seccionesObl) {
    if ($body.IndexOf($s) -lt 0) { Err ("falta la seccion: " + $s) }
}
if ($esEstado) {
    $iRes = $body.IndexOf("<h2>Resumen de la convocatoria</h2>")
    if ($iRes -ge 0) {
        $mRes = [regex]::Match($body.Substring($iRes), '<p>([\s\S]*?)</p>')
        $txtRes = ""
        if ($mRes.Success) { $txtRes = ((($mRes.Groups[1].Value -replace '<[^>]+>', ' ') -replace '\s+', ' ').Trim()) }
        if ($txtRes.Length -lt 60) {
            Err "Resumen de la convocatoria vacio o muy corto: se espera un parrafo (min. 60 caracteres) escrito con tus palabras"
        }
        $iPrim = $body.IndexOf('<div class="empleo-seccion">')
        if ($iPrim -ge 0 -and $iRes -gt $iPrim) {
            $entre = $body.Substring($iPrim, $iRes - $iPrim)
            if ($entre.IndexOf('<h2>') -ge 0) { Aviso "el Resumen de la convocatoria deberia ser la PRIMERA seccion de la entrada" }
        }
    }
}

# 8. banner de vigencia (solo Estado lo lleva en su plantilla)
if (-not ($body -match 'class="empleo-vigencia[^"]*">')) {
    if ($esEstado) { Err "falta el banner .empleo-vigencia" }
} elseif (-not ($body -match 'class="empleo-vigencia[^"]*">CONVOCATORIA (VIGENTE|FINALIZADA)\.')) {
    Err "el banner de vigencia no usa una de las 2 cadenas exactas"
}
if ($body.IndexOf('id="ofertasRelacionadas"') -lt 0) { Err "falta #ofertasRelacionadas" }

# 9. UN SOLO boton, texto fijo, y sin enlaces en la seccion de postulacion
$nBoton = ([regex]::Matches($body, 'class="empleo-boton"')).Count
if ($nBoton -ne 1) { Err ("debe haber UN SOLO boton .empleo-boton; hay " + $nBoton) }
$mBoton = [regex]::Match($body, '<a[^>]*class="empleo-boton"[^>]*>([\s\S]*?)</a>')
if ($mBoton.Success) {
    $txt = ($mBoton.Groups[1].Value -replace '<[^>]+>','' -replace '\s+',' ').Trim()
    $okTxt = ($txt -eq "POSTULA AQUÍ") -or ($txt -match '^POSTULAR EN \S')   # Estado / Privado
    if (-not $okTxt) { Err ("texto del boton debe ser 'POSTULA AQUÍ' (o 'POSTULAR EN <portal>' en Privado); es [" + $txt + "]") }
}
$iComo = $body.IndexOf("<h2>Pasos para postular</h2>")
if ($iComo -lt 0) { $iComo = $body.IndexOf("<h2>¿Cómo postular?</h2>") }
if ($iComo -ge 0) {
    $sig = $body.IndexOf("<div class=`"empleo-anuncio`">", $iComo)
    if ($sig -lt 0) { $sig = $body.IndexOf("<div class=`"empleo-postular`">", $iComo) }
    if ($sig -lt 0) { $sig = $body.Length }
    $sec = $body.Substring($iComo, $sig - $iComo)
    if ($sec.IndexOf("<a ") -ge 0 -or $sec.IndexOf("<a`n") -ge 0) { Err "en la seccion de postulacion (Pasos para postular / ¿Cómo postular?) NO debe haber ningun <a>" }
}
foreach ($t in @("Ver publicación oficial","Ver convocatoria oficial","Ir a la convocatoria oficial")) {
    if ($body.ToLower().IndexOf($t.ToLower()) -ge 0) { Err ("texto de boton duplicado/confuso: '" + $t + "'") }
}

# 10. la cabecera no debe mostrar la línea de Fuente (solo en Estado; Privado sí la lleva)
$mCab = [regex]::Match($body, '<div class="empleo-cabecera">[\s\S]*?</div>\s*<p class="empleo-vigencia"')
if ($esEstado -and $mCab.Success -and $mCab.Value.IndexOf("empleo-fuente") -ge 0) { Err "la cabecera todavía muestra la línea de Fuente (.empleo-fuente)" }

# 11. metadatos de Blogger (en comentarios o al final)
if ($html.IndexOf("ETIQUETA_BLOGGER") -lt 0) { Aviso "no encontré ETIQUETA_BLOGGER (debe ser: Empleo)" }
elseif ($html.IndexOf("ETIQUETA_BLOGGER = Estado") -ge 0 -or $html.IndexOf("ETIQUETA_BLOGGER=Estado") -ge 0) { Err "la etiqueta no puede ser 'Estado'; debe ser 'Empleo'" }
$mTb = [regex]::Match($html, 'TITULO_BLOGGER = ([^\r\n]*?) -->')
if (-not $mTb.Success) { Err "no encontré TITULO_BLOGGER (debe ser: ENTIDAD: Puesto)" }
else {
    $tv = $mTb.Groups[1].Value.Trim()
    if ($tv -eq '' -or $tv -match '^[:\s\p{P}]+$') { Err "TITULO_BLOGGER vacío o sin contenido: [$tv]" }
    elseif ($esEstado -and $tv -notmatch ':') { Err "TITULO_BLOGGER del Estado debe ser 'ENTIDAD: Puesto': [$tv]" }
}
$mH1v = [regex]::Match($body, '<h1[^>]*>([\s\S]*?)</h1>')
if (-not $mH1v.Success) { Err "no encontré el <h1> del puesto" }
elseif ($mH1v.Groups[1].Value.Trim() -eq '') { Err "<h1> vacío (título no extraído de la fuente)" }

# 12. hrefs: protocolo correcto + (opcional) comparación literal contra la fuente
$hrefs = @()
foreach ($m in [regex]::Matches($body, 'href="([^"]*)"')) { $hrefs += $m.Groups[1].Value }
if ($hrefs.Count -eq 0) { Err "la entrada no tiene ningún enlace" }
foreach ($h in $hrefs) {
    if ($h -notmatch '^https?://') { Err "href sin protocolo: [$h]" }
    elseif ($h -match '\s') { Err "href con espacios: [$h]" }
    elseif ($h -eq "#" -or $h -eq "") { Err "href vacío o '#'" }
}
$relacionados = $body.IndexOf('id="ofertasRelacionadas"')

# 12b. enlaces repetidos dentro de "Bases y anexos oficiales"
$iBases = $body.IndexOf('<h2>Bases y anexos oficiales</h2>')
if ($iBases -lt 0) { $iBases = $body.IndexOf('<h2>Descargar bases</h2>') }
$fBases = -1
if ($iBases -ge 0) {
    $fBases = $body.IndexOf('<div class="empleo-seccion">', $iBases + 5)
    if ($fBases -lt 0) { $fBases = $body.Length }
    $segB = $body.Substring($iBases, $fBases - $iBases)
    $vistosB = @{}
    foreach ($mLi in [regex]::Matches($segB, '<li>[\s\S]*?</li>')) {
        $mH = [regex]::Match($mLi.Value, 'href="([^"]+)"')
        if ($mH.Success) {
            $u = $mH.Groups[1].Value
            if ($vistosB.ContainsKey($u)) { Err ("enlace repetido en 'Bases y anexos oficiales': " + $u) }
            else { $vistosB[$u] = $true }
        }
    }
}

# 15. PUERTA DE CALIDAD (Fase A, solo con -Calidad)
if ($Calidad) {
    Write-Host "== PUERTA DE CALIDAD (-Calidad) =="

    # 15a. categoria canonica (las 7 del tema, con tildes)
    $mCat = [regex]::Match($body, '<div class="empleo-categoria">([^<]*)</div>')
    if ($mCat.Success) {
        $catVal = $mCat.Groups[1].Value.Trim()
        if ($catVal -eq '') { Err "la categoria (.empleo-categoria) esta vacia" }
        elseif (-not (Es-CategoriaCanonica $catVal)) { Err ("categoria no canonica: [$catVal] — debe ser una de las 7 del tema") }
    } else { Aviso "no encontre <div class=\"empleo-categoria\">" }

    # 15b. glosario de salario: todas las apariciones visibles y del bloque oculto
    $salVals = @()
    foreach ($mS in [regex]::Matches($body, '<div class="empleo-salario-header">\s*([^<]+?)\s*</div>')) { $salVals += $mS.Groups[1].Value.Trim() }
    foreach ($mS in [regex]::Matches($body, '<strong>Salario:</strong>\s*([^<]*)</p>'))          { $salVals += $mS.Groups[1].Value.Trim() }
    foreach ($mS in [regex]::Matches($body, '<div class="empleo-info-label">Salario</div>\s*<div class="empleo-info-value">([^<]*)</div>')) { $salVals += $mS.Groups[1].Value.Trim() }
    foreach ($v in $salVals) {
        if ($v -eq '') { continue }
        if ($v -notmatch '^(No especificado|A convenir|Negociable|S/ \d{1,3}(,\d{3})*( - S/ \d{1,3}(,\d{3})*)?( por hora)?)$') {
            Err ("salario fuera del glosario: [$v] (formato: 'S/ 1,800' | rango | 'por hora' | No especificado | A convenir | Negociable)")
        }
    }

    # 15c. vacantes: 1..99 o No especificado
    $vacVals = @()
    foreach ($mV in [regex]::Matches($body, '<strong>Vacantes:</strong>\s*([^<]*)</p>')) { $vacVals += $mV.Groups[1].Value.Trim() }
    foreach ($mV in [regex]::Matches($body, '<div class="empleo-info-label">Vacantes</div>\s*<div class="empleo-info-value">([^<]*)</div>')) { $vacVals += $mV.Groups[1].Value.Trim() }
    foreach ($v in $vacVals) {
        if ($v -eq '') { continue }
        if ($v -notmatch '^([1-9][0-9]?|No especificado)$') { Err ("vacantes fuera del glosario: [$v] (esperado 1..99 o 'No especificado')") }
    }

    # 15d. fechas: dd/MM/yyyy o No especificado
    foreach ($mF in [regex]::Matches($body, '<strong>Fecha[^<]*:</strong>\s*([^<]*)</p>')) {
        $v = $mF.Groups[1].Value.Trim()
        if ($v -eq '') { continue }
        if ($v -notmatch '^(\d{2}/\d{2}/\d{4}|No especificado)$') { Err ("fecha fuera del glosario: [$v] (esperado dd/MM/yyyy o 'No especificado')") }
    }

    # 15e. sin enums crudos de la fuente (FULL_TIME, TELECOMMUTE, ...) en el
    #      texto visible (dentro de etiquetas; los href no cuentan)
    $textoVis = [regex]::Replace($body, '<[^>]+>', ' ')
    foreach ($mE in [regex]::Matches($textoVis, '\b[A-Z]{3,}_[A-Z][A-Z_]{1,}\b')) {
        Err ("enum crudo de la fuente filtrado al HTML: [" + $mE.Value + "] (debe ir por el glosario)")
    }

    # 15f. jornada/contrato/modalidad: sin enums y sin textos largos
    foreach ($mJ in [regex]::Matches($body, '<strong>(Jornada|Contrato|Modalidad):</strong>\s*([^<]*)</p>')) {
        $v = $mJ.Groups[2].Value.Trim()
        if ($v -ne '' -and $v.Length -gt 60) { Err ($mJ.Groups[1].Value + " demasiado largo (>60): [" + $v + "]") }
    }

    # 15g. bullets <= 200 caracteres y parrafos <= 5 oraciones
    foreach ($mLi in [regex]::Matches($body, '<li>([^<]*)</li>')) {
        if ($mLi.Groups[1].Value.Length -gt 200) {
            Err ("bullet >200 caracteres: ..." + $mLi.Groups[1].Value.Substring(0, 80))
        }
    }
    foreach ($mP in [regex]::Matches($body, '<p[^>]*>([\s\S]*?)</p>')) {
        $tP = (([regex]::Replace($mP.Groups[1].Value, '<[^>]+>', ' ')) -replace '\s+', ' ').Trim()
        if ($tP.Length -lt 120) { continue }
        $nOr = @($tP -split '(?<=[.!?])\s+').Count
        if ($nOr -gt 5) { Err ("parrafo con $nOr oraciones (max 5): ..." + $tP.Substring(0, 70)) }
    }

    # 15h. orden de secciones nuevas (solo entradas de la plantilla data-only)
    if ((-not $esEstado) -and $body.IndexOf('<h2>Información de la oferta</h2>') -ge 0) {
        $ordenSecc = @('Descripción del puesto', 'Funciones', 'Requisitos', 'Beneficios',
                       '¿Por qué postular?', '¿Cómo postular?',
                       'Información de la oferta', 'Información de la empresa',
                       'Consejos antes de postular')
        $ultPos = -1
        foreach ($s in $ordenSecc) {
            $iS = $body.IndexOf('<h2>' + $s + '</h2>')
            if ($iS -lt 0) {
                if ($s -eq '¿Por qué postular?') { Err "falta la seccion obligatoria: ¿Por qué postular?" }
                elseif ($s -eq 'Consejos antes de postular') { Err "falta la seccion: Consejos antes de postular" }
                elseif ($s -in @('Funciones', 'Requisitos', 'Beneficios', '¿Cómo postular?')) { Aviso ("seccion omitida (sin contenido): " + $s) }
                # 'Descripción' / 'Info oferta' / 'Info empresa': la regla base 7 ya las exige
                continue
            }
            if ($ultPos -ge 0 -and $iS -lt $ultPos) { Err ("seccion fuera de orden: " + $s) }
            $ultPos = $iS
        }
    }
}

if ($Fuente -ne "") {
    Write-Host "  leyendo la publicación original..."
    try {
        $src = (Invoke-WebRequest -Uri $Fuente -UseBasicParsing -TimeoutSec 45 -Headers @{ "User-Agent" = "Mozilla/5.0" }).Content
    } catch {
        Write-Host "  AVISO: no pude leer la fuente ($($_.Exception.Message)) — se omite la comparación de enlaces"
        $src = $null
    }
    if ($src) {
        foreach ($h in $hrefs) {
            if ($src.IndexOf($h) -lt 0) {
                Err ("href NO existe en la publicación original (¿inventado o acortado?): " + $h)
            }
        }

        # 13. ORIGINALIDAD: avisa si la entrada repite texto de la publicación (aviso, no error)
        $wSrc = (Solo-Texto $src) -split ' ' | Where-Object { $_ -ne '' }
        $setSrc = New-Object 'System.Collections.Generic.HashSet[string]'
        if ($wSrc.Count -ge 6) {
            for ($i = 0; $i -le $wSrc.Count - 6; $i++) { [void]$setSrc.Add(($wSrc[$i..($i + 5)] -join ' ')) }
        }
        $copiados = 0
        foreach ($mp in [regex]::Matches($body, '<(?:p|li)[^>]*>([\s\S]*?)</(?:p|li)>')) {
            $txt = Solo-Texto $mp.Groups[1].Value
            $w = @($txt -split ' ' | Where-Object { $_ -ne '' })
            if ($w.Count -lt 15) { continue }
            $total = 0; $ok = 0
            for ($i = 0; $i -le $w.Count - 6; $i++) {
                $total++
                if ($setSrc.Contains(($w[$i..($i + 5)] -join ' '))) { $ok++ }
            }
            if ($total -gt 0 -and (($ok / $total) -ge 0.6)) {
                $copiados++
                if ($copiados -le 3) {
                    Aviso ("texto casi idéntico a la publicación original (" + [int][Math]::Round(($ok / $total) * 100) + "%): ..." + $txt.Substring(0, [Math]::Min(70, $txt.Length)))
                }
            }
        }
        if ($copiados -gt 3) {
            Aviso ("hay $copiados párrafos casi idénticos a la fuente; parafrasea el texto para que la entrada sea original")
        }

        # 13b. anti-copia Fase A (solo con -Calidad): error >=35%, aviso >=20%
        if ($Calidad) {
            $copErr = @(Parrafos-Copiados -Html $body -Fuente $src -Umbral 0.35)
            foreach ($cc in $copErr) {
                $tC = (([string]$cc.texto) -replace '\s+', ' ').Trim()
                Err ("parrafo copiado >=35% de la fuente: ..." + $tC.Substring(0, [Math]::Min(70, $tC.Length)))
            }
            $copAv = @(Parrafos-Copiados -Html $body -Fuente $src -Umbral 0.20)
            foreach ($cc in $copAv) {
                if ([double]$cc.pct -lt 0.35) {
                    $tC = (([string]$cc.texto) -replace '\s+', ' ').Trim()
                    Aviso ("parrafo casi copiado (" + [int][Math]::Round([double]$cc.pct * 100) + "%): ..." + $tC.Substring(0, [Math]::Min(70, $tC.Length)))
                }
            }
        }

        # 14. la publicación trae varios documentos con enlace: la lista de Bases debe traerlos
        $docs = New-Object System.Collections.Generic.List[string]
        foreach ($ma in [regex]::Matches($src, '<a[^>]+href="(https?://[^"]+)"[^>]*>([\s\S]*?)</a>')) {
            $t = Solo-Texto $ma.Groups[2].Value
            if ($t -eq '') { continue }
            if ($t -match 'descarga|bases|cronograma|anexo|ficha|declaraci') {
                $u = $ma.Groups[1].Value
                if (-not $docs.Contains($u)) { $docs.Add($u) }
            }
        }
        $enLista = 0
        if ($iBases -ge 0) {
            foreach ($mLi in [regex]::Matches($segB, '<li>[\s\S]*?</li>')) {
                if ([regex]::IsMatch($mLi.Value, 'href="[^"]+"')) { $enLista++ }
            }
        }
        if ($docs.Count -ge 2 -and $enLista -lt $docs.Count) {
            Aviso ("la publicación trae " + $docs.Count + " enlaces de documentos y la lista 'Bases y anexos' solo tiene " + $enLista + ". Revisa: " + (($docs | Select-Object -First 3) -join "  |  "))
        }
    }
}

# ---- resultado ----
Write-Host ""
if ($avisos.Count -gt 0) { $avisos | ForEach-Object { Write-Host "  AVISO : $_" } }
if ($errores.Count -gt 0) {
    $errores | ForEach-Object { Write-Host "  ERROR : $_" }
    Write-Host ""
    Write-Host "RESULTADO: $($errores.Count) error(es). NO pegues esta entrada en Blogger todavía."
    exit 1
}
Write-Host "RESULTADO: OK — entrada válida (enlaces: $($hrefs.Count))."
exit 0
