<#
  preparar-correcciones.ps1 - LOTE: clasifica los posts publicados (A/B/C) y
  arma la cola que ejecuta aplicar-correcciones.ps1.

  Lee el feed PUBLICO del blog (solo lectura), no escribe en Blogger.

  Clases pedidas en el informe:
    A = reconstruible  -> se corrige (accion CORREGIR)
    B = valida          -> se conserva (sin accion)
    C = excluida        -> se retira a borrador (accion RETIRAR)

  Reglas aplicadas (todas trazables, ninguna inventa datos):
    C1 articulo/guia rotulado como Empleo (no es oferta individual)
    C2 CTA no utilizable (CDT/sin destino) y sin URL oficial verificable
       (verificado: 12/12 paginas fuente CDT solo enlazan a bumeran, sin gob.pe)
    C3 sin ningun enlace de postulacion ni URL oficial
    C4 duplicado (titulo normalizado repetido): se conserva el mejor y se retiran los demas
    A1 enlace placeholder (href="URL1" ...) reparado con la URL utilizable de la
       propia publicacion (oficial si existe; si no, la CTA que si funciona)
    A2 salario con valor corrupto (S/ ., S/ 3, S/ 10000., A convenir...)
       -> se limpia si el numero es verificable; si no, "No especificado"
    B  el resto (incluye toda publicacion cuya CTA ya funciona: oferta individual,
       gob.pe, drive, formulario, buscojobs... jamas se retira por enlaces)

  USO:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\preparar-correcciones.ps1 -SoloAnalizar
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\preparar-correcciones.ps1
#>
param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [switch]$SoloAnalizar,
    [switch]$SinDuplicados,
    [switch]$SinSalario,
    [switch]$SinUrl,
    [int]$MaxPaginas = 60,
    [string]$Cache = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)

$DirDatos = Join-Path $BaseDir 'datos\publicados'
New-Item -ItemType Directory -Path $DirDatos -Force | Out-Null
$RutaLog    = Join-Path $DirDatos 'preparar.log'
$RutaCola   = Join-Path $DirDatos 'cola-correcciones.jsonl'
$fecha      = Get-Date -Format 'yyyyMMdd'
$RutaClasif = Join-Path $DirDatos ("clasificacion-lote-{0}.jsonl" -f $fecha)
$RutaResumen= Join-Path $DirDatos ("preparar-resumen-{0}.txt" -f $fecha)

# extraccion de salario compartida (Convertir-Monto valida formato y rango)
. (Join-Path $BaseDir 'lib\salario.ps1')

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($RutaLog, ($l + "`r`n"), $utf8) } catch { }
    Write-Host ("[preparar] " + $m)
}

# ------------------------------------------------------------------ utilidades
function Quitar-Acentos([string]$s) {
    if (-not $s) { return '' }
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($c in $n.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}
function Titulo-Norm([string]$t) {
    $s = Quitar-Acentos ([Net.WebUtility]::HtmlDecode([string]$t))
    $s = [regex]::Replace($s.ToLowerInvariant(), '[^a-z0-9]+', ' ')
    return $s.Trim()
}
function Host-De([string]$u) {
    if (-not $u) { return '' }
    if ($u -match '^https?://([^/?#]+)') { return $Matches[1].ToLower() }
    return ''
}
function Es-Oficial([string]$u) {
    if (-not $u) { return $false }
    return [bool]($u -match '(?i)^https?://([a-z0-9-]+\.)*gob\.pe(:\d+)?([/?#]|$)')
}
function Es-Cdt([string]$u) {
    if (-not $u) { return $false }
    $h = Host-De $u
    if (-not $h) { return $false }
    return [bool]($h -match '(^|\.)convocatoriasdetrabajo\.com$')
}
function Es-Placeholder([string]$u) {
    if (-not $u) { return $true }
    if ($u -match '^(https?://|mailto:|#|/)') { return $false }
    return $true        # URL1, URL2, javascript:, texto suelto...
}
function Reparar-Placeholders([string]$html, [string]$nuevaUrl) {
    # repara placeholders reales de anclas visibles; NO toca el href="' + url + '"
    # que vive dentro de bloques <script> embebidos en algunos posts
    $enc = [Net.WebUtility]::HtmlEncode($nuevaUrl)
    $h = [regex]::Replace($html, '(?is)href\s*=\s*"(URL\d+|)"', ('href="' + $enc + '"'))
    $h = [regex]::Replace($h, '(?is)(href\s*=\s*")www\.', '$1https://www.')
    return $h
}

# ------------------------------------------------------------------ 1) feed
function Escanear-Feed {
    param([int]$LimitePaginas)
    $out = New-Object System.Collections.ArrayList
    if ($Cache -and (Test-Path -LiteralPath $Cache)) {
        foreach ($c in (Get-Content -LiteralPath $Cache -Raw -Encoding UTF8 | ConvertFrom-Json)) {
            [void]$out.Add([pscustomobject]@{
                id = $c.id; titulo = $c.titulo; url = $c.url; publicado = $c.publicado; contenido = $c.contenido
            })
        }
        return $out
    }
    $base = "https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json&max-results=150"
    $start = 1; $pag = 0
    while ($true) {
        $pag++
        if ($pag -gt $LimitePaginas) { break }
        $url = $base + "&start-index=" + $start
        $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 120
        $j = $r.Content | ConvertFrom-Json
        $entries = $j.feed.entry
        if (-not $entries) { break }
        foreach ($e in $entries) {
            $html = ''; if ($e.content) { $html = [string]$e.content.'$t' }
            $titulo = ''; if ($e.title) { $titulo = [string]$e.title.'$t' }
            $uPost = ''
            foreach ($lnk in $e.link) { if ($lnk.rel -eq 'alternate') { $uPost = $lnk.href; break } }
            $id = ([string]$e.id.'$t') -replace '^.*post-', ''
            [void]$out.Add([pscustomobject]@{
                id = $id; titulo = $titulo; url = $uPost; contenido = $html
                publicado = $(if ($e.published) { [string]$e.published.'$t' } else { '' })
            })
        }
        if ($entries.Count -lt 150) { break }
        $start += 150
    }
    return $out
}

# ------------------------------------------------------------------ 2) salario
function Limpiar-Valor-Salario([string]$valor) {
    # devolver: @{ ok; valor; motivo }  (valor = texto definitivo para el post)
    $v = ([Net.WebUtility]::HtmlDecode([string]$valor)).Trim()
    $v = [regex]::Replace($v, '\s+', ' ')
    if ($v -eq '') { return @{ ok = $true; valor = 'No especificado'; motivo = 'sin valor de salario' } }
    if ($v -match '(?i)no especific') { return @{ ok = $false; valor = $v; motivo = '' } }   # ya correcto
    if ($v -match '(?i)a convenir|a definir|a acordar|a confirmar|a negociar') {
        return @{ ok = $true; valor = 'CONVENIR'; motivo = "dice 'A convenir'" }
    }
    $m = [regex]::Match($v, 'S/\s*([0-9][0-9.,]*)')
    if (-not $m.Success) {
        # sin prefijo S/ pero con numero: "1600.00", ".1,600.00"
        $m2 = [regex]::Match($v, '([0-9][0-9.,]+|\.[0-9][0-9.,]+)')
        if ($m2.Success) { $m = $m2 } else {
            return @{ ok = $true; valor = 'No especificado'; motivo = "valor no numerico ('$v')" }
        }
    }
    $num = $m.Groups[1].Value
    if ($num -eq '') { $num = $m.Groups[0].Value }
    $num = $num.Trim()
    $num = $num -replace '^\.(?=[0-9])', ''      # S/ .1,600.00 -> 1,600.00
    $num = $num -replace '[.,]+$', ''            # S/ 10000.    -> 10000
    if ($num -eq '') { return @{ ok = $true; valor = 'No especificado'; motivo = "valor vacio ('$v')" } }
    # Convertir-Monto (lib\salario.ps1) valida formato y rango 100..100000
    $valorNum = Convertir-Monto $num
    if ($null -eq $valorNum) { return @{ ok = $true; valor = 'No especificado'; motivo = "valor no verificable ('$num')" } }
    $nuevo = 'S/ ' + $num
    if ($nuevo -eq $v) { return @{ ok = $false; valor = $nuevo; motivo = '' } }   # ya estaba bien
    return @{ ok = $true; valor = $nuevo; motivo = "salario '$v' -> '$nuevo'" }
}

function Corregir-Salario([string]$html) {
    # devuelve @{ html; motivos; cambios }
    $htmlOriginal = $html
    $motivos = New-Object System.Collections.ArrayList
    $cambios = 0

    # a) cabecera de la tarjeta
    $mH = [regex]::Match($html, '(?is)(<div class="empleo-salario-header">)\s*([^<]*)')
    if ($mH.Success) {
        $actual = $mH.Groups[2].Value
        $r = Limpiar-Valor-Salario $actual
        if ($r.valor -eq 'CONVENIR') {
            # buscar un monto real cerca (misma regla que inspeccionar-publicados.ps1)
            $monto = ''
            $mC = [regex]::Match($html, '(?is)(salario|remuneraci[o\u00f3]n).{0,80}?A convenir')
            if ($mC.Success) {
                $mMonto = [regex]::Match($mC.Value, 'S/\s*([0-9][0-9.,]*)')
                if ($mMonto.Success) { $monto = $mMonto.Groups[1].Value.Trim() }
            }
            $nuevoValor = if ($monto -ne '') { 'S/ ' + $monto } else { 'No especificado' }
            $html = $html.Remove($mH.Groups[2].Index, $mH.Groups[2].Length).Insert($mH.Groups[2].Index, $nuevoValor)
            $cambios++
            [void]$motivos.Add($(if ($monto -ne '') { "'A convenir' -> S/ $monto (monto de la propia publicacion)" } else { "'A convenir' -> No especificado (sin monto verificable)" }))
        } elseif ($r.ok) {
            $html = $html.Remove($mH.Groups[2].Index, $mH.Groups[2].Length).Insert($mH.Groups[2].Index, $r.valor)
            $cambios++
            [void]$motivos.Add($r.motivo)
        }
    }

    # recalcular el valor vigente de la cabecera (ya corregido si toco)
    $mH2 = [regex]::Match($html, '(?is)<div class="empleo-salario-header">\s*([^<]*)')
    $valorVigente = if ($mH2.Success) { ([Net.WebUtility]::HtmlDecode($mH2.Groups[1].Value)).Trim() } else { '' }

    # b) campo <strong>Salario:</strong> X
    $mF = [regex]::Match($html, '(?is)(<strong>Salario:</strong>)\s*([^<]*)')
    if ($mF.Success) {
        $actual = ([Net.WebUtility]::HtmlDecode($mF.Groups[2].Value)).Trim()
        if ($valorVigente -ne '' -and $actual -ne $valorVigente -and $actual -notmatch '(?i)no especific') {
            $antes = $actual
            $html = $html.Remove($mF.Groups[2].Index, $mF.Groups[2].Length).Insert($mF.Groups[2].Index, $valorVigente)
            $cambios++
            [void]$motivos.Add("campo Salario: '$antes' -> '$valorVigente'")
        }
    }

    # c) frases de la descripcion: "remuneracion de S/ 3;"
    if ($valorVigente -ne '') {
        $patron = '(?is)(remuneraci[o\u00f3]n)(\s+de)?\s+S/\s*[0-9][0-9.,]*'
        $mD = [regex]::Match($html, $patron)
        if ($mD.Success) {
            $antes = ([Net.WebUtility]::HtmlDecode($mD.Value)).Trim()
            $reemplazo = if ($valorVigente -match '(?i)no especific') {
                $mD.Groups[1].Value + ' no especificada'
            } else {
                $mD.Groups[1].Value + $(if ($mD.Groups[2].Success -and $mD.Groups[2].Value) { $mD.Groups[2].Value } else { ' de' }) + ' ' + $valorVigente
            }
            if ($reemplazo -ne $mD.Value) {
                $html = $html.Remove($mD.Index, $mD.Length).Insert($mD.Index, $reemplazo)
                $cambios++
                [void]$motivos.Add("frase de descripcion: '$antes' -> '$reemplazo'")
            }
        }
    }

    if ($html -eq $htmlOriginal) { return @{ html = $html; motivos = @(); cambios = 0 } }
    return @{ html = $html; motivos = $motivos; cambios = $cambios }
}

# ------------------------------------------------------------------ 3) enlaces
function Analizar-Enlaces([string]$html) {
    $hrefs = @([regex]::Matches($html, '(?is)href\s*=\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
    $placeholders = @($hrefs | Where-Object { Es-Placeholder $_ })
    $http = @($hrefs | Where-Object { $_ -match '^https?://' })
    $oficiales = @($http | Where-Object { Es-Oficial $_ })
    $cdt = @($http | Where-Object { Es-Cdt $_ })
    # enlace principal (boton POSTULA) : el primero dentro de empleo-postular
    $cta = ''
    $mBloque = [regex]::Match($html, '(?is)<div class="empleo-postular">([\s\S]{0,1200}?)</div>\s*<div class="ofertas-relacionadas"')
    if (-not $mBloque.Success) { $mBloque = [regex]::Match($html, '(?is)<div class="empleo-postular">([\s\S]{0,1200})') }
    if ($mBloque.Success) {
        $mA = [regex]::Match($mBloque.Groups[1].Value, '(?is)<a[^>]*href\s*=\s*"([^"]+)"')
        if ($mA.Success) { $cta = $mA.Groups[1].Value }
    }
    if ($cta -eq '') {
        $mB = [regex]::Match($html, '(?is)class="empleo-boton"[^>]*href\s*=\s*"([^"]+)"')
        if ($mB.Success) { $cta = $mB.Groups[1].Value }
    }
    return @{
        hrefs        = $http
        placeholders = $placeholders
        oficiales    = $oficiales
        cdt          = $cdt
        cta          = $cta
        tieneHttp    = ($http.Count -gt 0)
    }
}

# ------------------------------------------------------------------ ejecucion
Log ("")
Log ("=== PREPARAR CORRECCIONES (" + $fecha + ") ===")
Log "  leyendo feed publico (solo lectura)..."
$sw = [Diagnostics.Stopwatch]::StartNew()
$posts = Escanear-Feed -LimitePaginas $MaxPaginas
Log ("  posts leidos: " + $posts.Count + "  (" + [math]::Round($sw.Elapsed.TotalSeconds,1) + " s)")

# ---------------------------------------------------------------- clasificacion
$resultados = New-Object System.Collections.ArrayList
$acciones = New-Object System.Collections.ArrayList

foreach ($p in $posts) {
    $html = [string]$p.contenido
    $titulo = [string]$p.titulo
    $clase = 'B'; $motivo = ''; $accion = 'CONSERVAR'; $contenidoNuevo = ''

    $estructura = $html -match 'empleo-individual'
    $esTituloArticulo = $titulo -match '(?i)^(c[oó]mo|que es|qu[eé] es|gu[ií]a|err[oó]res|beneficios|diferencia entre|expectativa salarial:|cts, essalud|10 consejos|consejos para)'
    $enlaces = Analizar-Enlaces $html

    # ---- C1: articulo/guia (no es oferta individual)
    if ((-not $estructura) -or $esTituloArticulo) {
        $clase = 'C'; $accion = 'RETIRAR'
        $motivo = $(if (-not $estructura) { 'no tiene estructura de oferta individual (articulo/guia)' } else { 'titulo de articulo, no de oferta individual' })
    }

    # ---- C2/C3/A1: enlaces
    # Regla de calidad: la publicacion SOLO se retira si la CTA no es utilizable
    # y no existe URL final verificable (oficial o la propia CTA) en la publicacion.
    if ($clase -eq 'B' -and -not $SinUrl) {
        $sinOficial = (-not $enlaces.oficiales -or $enlaces.oficiales.Count -eq 0)
        $hayPh = ($enlaces.placeholders.Count -gt 0)
        $cta = [string]$enlaces.cta
        $ctaUtil = ($cta -match '^https?://') -and (-not (Es-Cdt $cta))
        $nuevoHtml = ''

        if ($ctaUtil) {
            # la CTA ya lleva a un destino utilizable (oferta individual, gob.pe,
            # drive, formulario...): jamas se retira por enlaces; solo se reparan
            # placeholders reales de anclas visibles
            if ($hayPh) {
                $nuevaUrl = $(if ($sinOficial) { $cta } else { $enlaces.oficiales[0] })
                $nuevoHtml = Reparar-Placeholders $html $nuevaUrl
                if ($nuevoHtml -ne $html) {
                    $clase = 'A'; $accion = 'CORREGIR'
                    $contenidoNuevo = $nuevoHtml
                    $motivo = "enlace placeholder reparado con la " + $(if ($sinOficial) { "CTA utilizable de la publicacion" } else { "URL oficial de la publicacion" }) + " ($nuevaUrl)"
                }
            }
        } elseif (-not $sinOficial) {
            # CTA no utilizable (convocatoriasdetrabajo.com o sin destino) pero la
            # publicacion contiene URL oficial verificable: se sustituye todo lo roto
            $nuevaUrl = $enlaces.oficiales[0]
            $nuevoHtml = Reparar-Placeholders $html $nuevaUrl
            $nuevoHtml = [regex]::Replace($nuevoHtml, '(?is)(href\s*=\s*")[^"]*convocatoriasdetrabajo\.com[^"]*(")', ('$1' + [Net.WebUtility]::HtmlEncode($nuevaUrl) + '$2'))
            if ($nuevoHtml -ne $html) {
                $clase = 'A'; $accion = 'CORREGIR'
                $contenidoNuevo = $nuevoHtml
                $motivo = "CTA/enlace sin destino utilizable sustituido por la URL oficial de la publicacion ($nuevaUrl)"
            }
        } else {
            # CTA no utilizable y sin URL oficial verificable => se excluye
            $clase = 'C'; $accion = 'RETIRAR'
            $motivo = $(if ($cta -and (Es-Cdt $cta)) {
                "el boton POSTULA apunta a convocatoriasdetrabajo.com y la publicacion no contiene URL oficial verificable"
            } elseif (-not $cta -and -not $enlaces.tieneHttp) {
                'sin enlace de postulacion y sin URL oficial en la publicacion'
            } elseif (-not $cta) {
                'sin boton de postulacion utilizable y sin URL oficial verificable'
            } else {
                "sin URL final verificable en la publicacion (CTA no utilizable: $cta)"
            })
        }
    }

    # ---- A2: salario
    if (-not $SinSalario) {
        $rSal = $null
        if ($contenidoNuevo -ne '') { $rSal = Corregir-Salario $contenidoNuevo }
        else { $rSal = Corregir-Salario $html }
        if ($rSal.cambios -gt 0) {
            $contenidoNuevo = $rSal.html
            $listaMotivos = @($rSal.motivos) -join ' ; '
            if ($clase -eq 'B') { $clase = 'A'; $accion = 'CORREGIR' }
            $motivo = ($motivo + $(if ($motivo) { ' | ' } else { '' }) + 'salario: ' + $listaMotivos)
        }
    }

    [void]$resultados.Add([pscustomobject]@{
        id = $p.id; url = $p.url; titulo = $titulo; publicado = $p.publicado
        clase = $clase; accion = $accion; motivo = $motivo
        contenidoNuevo = $(if ($accion -eq 'CORREGIR') { $contenidoNuevo } else { '' })
        tituloNorm = (Titulo-Norm $titulo); len = $html.Length
        idConservado = ''
    })
}

# ---------------------------------------------------------------- C4 duplicados
if (-not $SinDuplicados) {
    $grupos = $resultados | Group-Object tituloNorm | Where-Object { $_.Count -gt 1 -and $_.Name -ne '' }
    foreach ($g in $grupos) {
        $miembros = @($g.Group)
        # se conserva el mejor: con estructura de oferta y mas contenido (calidad > antiguedad)
        $candidatos = @($miembros | Where-Object { $_.clase -ne 'C' })
        if ($candidatos.Count -eq 0) { $candidatos = $miembros }
        $conservado = ($candidatos | Sort-Object -Property @{Expression = 'len'; Descending = $true}, @{Expression = 'publicado'; Ascending = $false} | Select-Object -First 1)
        foreach ($m in $miembros) {
            if ($m.id -eq $conservado.id) { continue }
            if ($m.accion -eq 'RETIRAR') {
                # ya se retira por otra regla: anotar el duplicado igualmente
                $m.motivo = $m.motivo + ' | duplicado de ' + $conservado.id
                $m.idConservado = $conservado.id
            } else {
                $m.clase = 'C'; $m.accion = 'RETIRAR'
                $m.motivo = 'duplicado (titulo normalizado repetido) de ' + $conservado.id
                $m.idConservado = $conservado.id
                $m.contenidoNuevo = ''
            }
        }
    }
}

# ---------------------------------------------------------------- salidas
$porClase = $resultados | Group-Object clase | Sort-Object Name
$porAccion = $resultados | Where-Object { $_.accion -ne 'CONSERVAR' } | Group-Object accion | Sort-Object Name

Log ""
Log "--- CLASIFICACION (A reconstruible / B valida / C excluida) ---"
foreach ($g in $porClase) { Log ("  " + $g.Name + ": " + $g.Count) }
Log "--- ACCIONES propuestas ---"
foreach ($g in $porAccion) { Log ("  " + $g.Name + ": " + $g.Count) }
Log "--- motivos ---"
$resultados | Where-Object { $_.accion -ne 'CONSERVAR' } | ForEach-Object {
    $k = if ($_.motivo -match '^[^|]+') { ($_.motivo -split '\|')[0].Trim() } else { $_.motivo }
    $_ | Add-Member -NotePropertyName claveMotivo -NotePropertyValue $k -Force
}
$resultados | Where-Object { $_.accion -ne 'CONSERVAR' } | Group-Object claveMotivo | Sort-Object Count -Descending | ForEach-Object { Log ("  " + $_.Count.ToString().PadLeft(4) + "  " + $_.Name) }

# clasificacion completa (auditoria)
$lineas = New-Object System.Collections.Generic.List[string]
foreach ($r in $resultados) {
    $lineas.Add(([pscustomobject]@{
        id = $r.id; url = $r.url; titulo = $r.titulo; publicado = $r.publicado
        clase = $r.clase; accion = $r.accion; motivo = $r.motivo
        idConservado = $r.idConservado; lenContenido = $r.len
        fecha = (Get-Date).ToString('o')
    } | ConvertTo-Json -Compress -Depth 4))
}
[IO.File]::WriteAllLines($RutaClasif, [string[]]$lineas, $utf8)
Log ("  clasificacion -> " + $RutaClasif)

if ($SoloAnalizar) {
    Log ""
    Log "SOLO ANALIZAR: no se modifico ninguna cola."
    exit 0
}

# ---------------------------------------------------------------- cola
# Se conserva TODO lo ya registrado en la cola (retiros/correcciones de corridas
# anteriores) y solo se actualizan los ids que este lote vuelve a analizar.
$lineasPrevias = New-Object System.Collections.Generic.List[string]
$indicePrevio = @{}
if (Test-Path $RutaCola) {
    foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
        $l = $l.Trim(); if ($l -eq '') { continue }
        $lineasPrevias.Add($l)
        try {
            $o = $l | ConvertFrom-Json
            if ($o.id -and -not $indicePrevio.ContainsKey([string]$o.id)) { $indicePrevio[[string]$o.id] = ($lineasPrevias.Count - 1) }
        } catch { }
    }
}
$nuevos = 0; $actualizados = 0; $repetidos = 0
$reemplazos = @{}
$lineasNuevas = New-Object System.Collections.Generic.List[string]
foreach ($r in $resultados) {
    if ($r.accion -eq 'CONSERVAR') { continue }
    $nuevaLinea = ([pscustomobject]@{
        id = $r.id; accion = $r.accion; clase = $r.clase
        prioridad = $(if ($r.accion -eq 'RETIRAR') { 1 } else { 2 })
        titulo = $r.titulo; url = $r.url; motivo = $r.motivo
        idConservado = $r.idConservado
        tituloNuevo = ''
        contenidoNuevo = $(if ($r.accion -eq 'CORREGIR') { $r.contenidoNuevo } else { '' })
        fechaEncolada = (Get-Date).ToString('o')
        estado = 'PENDIENTE'
    } | ConvertTo-Json -Compress -Depth 5)
    if ($indicePrevio.ContainsKey($r.id)) {
        $previa = $null
        try { $previa = $lineasPrevias[$indicePrevio[$r.id]] | ConvertFrom-Json } catch { }
        if ($previa -and [string]$previa.estado -notin @('', 'PENDIENTE')) { $repetidos++; continue }
        $reemplazos[$indicePrevio[$r.id]] = $nuevaLinea
        $actualizados++
    } else {
        $lineasNuevas.Add($nuevaLinea)
        $nuevos++
    }
}
$salida = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $lineasPrevias.Count; $i++) {
    if ($reemplazos.ContainsKey($i)) { $salida.Add($reemplazos[$i]) } else { $salida.Add($lineasPrevias[$i]) }
}
foreach ($n in $lineasNuevas) { $salida.Add($n) }
[IO.File]::WriteAllLines($RutaCola, [string[]]$salida, $utf8)

$pendientes = 0
foreach ($l in $salida) { try { $o = $l | ConvertFrom-Json; if ([string]$o.estado -eq 'PENDIENTE') { $pendientes++ } } catch { } }
Log ""
Log ("  cola: " + $nuevos + " nueva(s), " + $actualizados + " actualizada(s), " + $repetidos + " ya aplicadas (se conservan)")
Log ("  cola total PENDIENTE: " + $pendientes + "  -> " + $RutaCola)
Log ("siguiente paso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aplicar-correcciones.ps1   (simulacion)")
Log ("                 powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\aplicar-correcciones.ps1 -Aplicar   (escrituras)")
