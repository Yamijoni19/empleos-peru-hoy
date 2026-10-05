# inspeccionar-publicados.ps1 - INVENTARIO y CLASIFICACION de los posts YA publicados.
#
# Lee el feed publico del blog (solo lectura, sin API de Blogger), guarda copia
# local de seguridad del contenido y clasifica cada post:
#
#   A CORRECTO   B CORREGIBLE   C DUPLICADO   D NO ES OFERTA
#   E ROTO       F INFO DEFECTUOSA   G VENCIDO   H OTRO PROBLEMA
#
# Salidas en datos\publicados\:
#   inventario-<fecha>.jsonl      copia de seguridad (id, url, titulo, contenido, fecha)
#   clasificacion-<fecha>.jsonl   clase + motivo + accion propuesta
#   clasificacion-<fecha>.csv     resumen legible
#   cola-correcciones.jsonl       acciones PENDIENTES (aplicar-correcciones.ps1)
#
# Reglas: basura -> RETIRAR; duplicado inequivoco -> conservar el mejor y retirar
# el otro; roto -> RETIRAR (o CORREGIR con respaldo local); info defectuosa ->
# CORREGIR solo con propuesta de alta confianza; solo vencido -> CONSERVAR;
# incertidumbre -> CONSERVAR + registro.
#
# USO:
#   .\inspeccionar-publicados.ps1              # feed + clasifica
#   .\inspeccionar-publicados.ps1 -SoloLocal   # sin red (inventario local)
#   .\inspeccionar-publicados.ps1 -ConservarTodo   # no propone retiros

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [switch]$SoloLocal,
    [switch]$ConservarTodo,
    [int]$MaxPaginas = 40,
    [string]$BlogUrl = 'https://empleosperuhoy.blogspot.com'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$DirDatos  = Join-Path $BaseDir 'datos\publicados'
$DirSalida = Join-Path $BaseDir 'salida'
$RutaLogPub= Join-Path $BaseDir 'publicaciones.txt'
$RutaInvViejo = Join-Path $BaseDir '_inventario-posts.json'
New-Item -ItemType Directory -Path $DirDatos -Force | Out-Null

$fecha  = Get-Date -Format 'yyyyMMdd'
$RutaBackup = Join-Path $DirDatos ("inventario-{0}.jsonl" -f $fecha)
$RutaClasif = Join-Path $DirDatos ("clasificacion-{0}.jsonl" -f $fecha)
$RutaCsv    = Join-Path $DirDatos ("clasificacion-{0}.csv" -f $fecha)
$RutaCola   = Join-Path $DirDatos 'cola-correcciones.jsonl'
$RutaLog    = Join-Path $DirDatos 'inspeccion.log'

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($RutaLog, ($l + "`r`n"), $utf8) } catch { }
    Write-Host ("[inspeccion] " + $m)
}

# ---------------------------------------------------------------- utilidades
function Quitar-Acentos([string]$s) {
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
function Url-Norm([string]$u) {
    $s = ([string]$u).Trim().ToLowerInvariant()
    $s = [regex]::Replace($s, '[?#].*$', '')
    $s = [regex]::Replace($s, '/+$', '')
    return $s
}
function Texto-Plano([string]$html) {
    if (-not $html) { return '' }
    $s = [Net.WebUtility]::HtmlDecode($html)
    $s = [regex]::Replace($s, '(?is)<(script|style)[^>]*>.*?</\1>', ' ')
    $s = [regex]::Replace($s, '(?s)<[^>]+>', ' ')
    $s = [regex]::Replace($s, '\s+', ' ')
    return $s.Trim()
}
function Fecha-Cierre-De([string]$texto) {
    $m = [regex]::Match($texto, '(?is)fecha de cierre\s*:\s*([0-3]?\d[\/\-]\d{1,2}[\/\-]\d{2,4}|[0-4]?\d{1,2}\s+de\s+[a-z]+(?:\s+de\s+\d{4})?)')
    if (-not $m.Success) { return $null }
    $t = $m.Groups[1].Value.Trim()
    foreach ($fmt in @('yyyy-MM-dd', 'dd/MM/yyyy', 'd/M/yyyy', 'dd-MM-yyyy')) {
        try { return [datetime]::ParseExact($t, $fmt, [Globalization.CultureInfo]::InvariantCulture) } catch { }
    }
    try { return [datetime]::Parse($t, [Globalization.CultureInfo]::GetCultureInfo('es-PE')) } catch { }
    return $null
}
function Es-Mojibake([string]$s) { if (-not $s) { return $false }; return [bool]($s -match 'Ã.|Â.|â€') }

# mapa url-post -> archivo local (publicaciones.txt: fecha | titulo | url | archivo)
$mapUrlArchivo = @{}
if (Test-Path $RutaLogPub) {
    foreach ($l in [IO.File]::ReadAllLines($RutaLogPub)) {
        if ($l -match '\|\s*(https?://\S+?)\s*\|\s*([^|\s]+\.html)\s*$') {
            $u = Url-Norm $Matches[1]
            if (-not $mapUrlArchivo.ContainsKey($u)) { $mapUrlArchivo[$u] = $Matches[2] }
        }
    }
}
Log ("mapa url->archivo local: " + $mapUrlArchivo.Count + " publicaciones registradas")

# ---------------------------------------------------------------- 1) inventario
$posts = New-Object System.Collections.Generic.List[object]
$fuenteDato = 'feed publico (solo lectura)'
if (-not $SoloLocal) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ini = 1; $total = 0; $pag = 0
    while ($pag -lt $MaxPaginas) {
        $url = $BlogUrl + '/feeds/posts/default?alt=json&max-results=150&start-index=' + $ini
        $j = $null
        try { $j = Invoke-RestMethod -Uri $url -TimeoutSec 60 } catch {
            if ($pag -eq 0) { Log ("  AVISO: sin feed (" + $_.Exception.Message + "); se usa inventario local") }
            break
        }
        if ($pag -eq 0) { try { $total = [int]$j.feed.'openSearch$totalResults'.'$t' } catch { $total = 0 } }
        $entries = @(); if ($j -and $j.feed -and $j.feed.entry) { $entries = @($j.feed.entry) }
        if ($entries.Count -eq 0 -or $null -eq $entries[0]) { break }
        foreach ($x in $entries) {
            $id = ''; try { if ($x.id.'$t' -match 'post-(\d+)') { $id = $Matches[1] } } catch { }
            $tit = ''; try { $tit = ([Net.WebUtility]::HtmlDecode([string]$x.title.'$t')).Trim() } catch { }
            $cont = ''; try { $cont = [string]$x.content.'$t' } catch { }
            $pub = ''; try { $pub = [string]$x.published.'$t' } catch { }
            $urlPost = ''
            foreach ($ln in @($x.link)) { if ($ln.rel -eq 'alternate') { $urlPost = [string]$ln.href; break } }
            $etiq = @(); try { $etiq = @(@($x.category) | ForEach-Object { [string]$_.term }) } catch { }
            $posts.Add([pscustomobject]@{ id = $id; titulo = $tit; publicado = $pub; url = $urlPost; etiquetas = $etiq; contenido = $cont })
        }
        $ini += $entries.Count
        $pag++
        if ($total -gt 0 -and $ini -gt $total) { break }
        if ($entries.Count -lt 150) { break }
    }
    Log ("feed leido: " + $posts.Count + " posts (total reportado: " + $total + ", paginas: " + $pag + ")")
}
if ($posts.Count -eq 0) {
    $fuenteDato = 'inventario local _inventario-posts.json'
    if (-not (Test-Path $RutaInvViejo)) { Log "ERROR: no hay feed ni inventario local"; exit 1 }
    foreach ($o in @(Get-Content $RutaInvViejo -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $posts.Add([pscustomobject]@{
            id = [string]$o.id; titulo = [string]$o.title; publicado = [string]$o.published
            url = [string]$o.url; etiquetas = @(if ($o.labels) { $o.labels } else { @() }); contenido = ''
        })
    }
    Log ("inventario local cargado: " + $posts.Count + " posts (SIN contenido: solo metadatos)")
}

# ---------------------------------------------------------------- 2) enriquecer + copia de seguridad
$contLocal = 0
$enriquecidos = New-Object System.Collections.Generic.List[object]
foreach ($p in $posts) {
    $archivo = ''
    $uN = Url-Norm $p.url
    if ($mapUrlArchivo.ContainsKey($uN)) { $archivo = $mapUrlArchivo[$uN] }
    $contenido = [string]$p.contenido
    if ($contenido -eq '' -and $archivo -ne '') {
        $ruta = Join-Path $DirSalida $archivo
        if (Test-Path $ruta) { try { $contenido = [IO.File]::ReadAllText($ruta); $contLocal++ } catch { } }
    }
    $fuente = ''
    $mF = [regex]::Match($contenido, '(?is)<strong>\s*Fuente\s*:\s*</strong>\s*(?:<[^>]+>\s*)*(?:<a[^>]+href=")?(https?://[^\s"<>]+)')
    if ($mF.Success) { $fuente = $mF.Groups[1].Value.Trim() }
    if ($fuente -eq '') {
        foreach ($m in [regex]::Matches($contenido, '(?is)<a[^>]+href="(https?://[^"]+)"')) {
            $c = $m.Groups[1].Value
            if ($c -notmatch 'blogger\.com|blogspot\.com|google\.com|facebook\.com|twitter\.com|wa\.me|whatsapp') { $fuente = $c; break }
        }
    }
    $texto = Texto-Plano $contenido
    $enriquecidos.Add([pscustomobject]@{
        id = $p.id; titulo = $p.titulo; publicado = $p.publicado; url = $p.url
        etiquetas = $p.etiquetas; archivoLocal = $archivo; fuente = $fuente
        contenido = $contenido
        contenidoOrigen = $(if ($p.contenido) { 'feed' } else { $(if ($archivo) { 'salida-local' } else { '' }) })
        lenContenido = $contenido.Length; texto = $texto
    })
}

# copia de seguridad ANTES de proponer nada: id, url, titulo, contenido, fecha
$lineasBak = New-Object System.Collections.Generic.List[string]
foreach ($e in $enriquecidos) {
    $lineasBak.Add(([pscustomobject]@{
        id = $e.id; url = $e.url; titulo = $e.titulo; publicado = $e.publicado
        etiquetas = $e.etiquetas; archivoLocal = $e.archivoLocal; fuente = $e.fuente
        contenido = $e.contenido; contenidoOrigen = $e.contenidoOrigen
        respaldadoEn = (Get-Date).ToString('o')
    } | ConvertTo-Json -Compress -Depth 5))
}
[IO.File]::WriteAllLines($RutaBackup, [string[]]$lineasBak, $utf8)
Log ("copia de seguridad: " + $RutaBackup + "  (" + $lineasBak.Count + " posts con contenido)")

# ---------------------------------------------------------------- 3) clasificacion A-H
$rxSenales = [regex]'(?i)(descripci[oó]n del puesto|descripci[oó]n general|requisitos|funciones a desempe[nñ]ar|empresa\s*:|ubicaci[oó]n\s*:|fecha de publicaci[oó]n|fecha de cierre|postulante|remuneraci[oó]n|salario\s*:)'
$rxNoOferta = [regex]'(?i)^(becas?|cursos?|capacitaciones?|noticias?|art[ií]culos?|gu[ií]as?|plantillas?|bolet[ií]n|eventos?|presentaciones|listado|categor[ií]a|resultados?|buscador|p[aá]gina\s*\d+|empleos\s+en\s+|trabajos\s+en\s+|vacantes\s+en\s+|errores\s|consejos|tips\b|preguntas\s|frases\s|c[oó]mo\s|qu[eé]\s|renunci[eé]\s)'
$rxRotos = [regex]'(?i)^(error|404|p[aá]gina no encontrada|no encontrado)|error en el servidor remoto|solicitud incorrecta'
$rxMonto = [regex]'(?i)(S/\s*[\d.,]+(?:\s*-\s*S/\s*[\d.,]+)?|\d{3,6}\s*soles)'

$clasificados = New-Object System.Collections.Generic.List[object]
foreach ($e in $enriquecidos) {
    $tit = [string]$e.titulo; $titTrim = $tit.Trim(); $texto = [string]$e.texto
    $senales = @($rxSenales.Matches($texto)).Count
    $vencida = $null; if ($texto -ne '') { $vencida = Fecha-Cierre-De $texto }
    $vencidaPasada = ($null -ne $vencida -and $vencida.Date -lt (Get-Date).Date)
    $clase = ''; $motivo = ''; $prio = 9

    if ($e.contenido -eq '' -or $texto.Length -lt 120) {
        $clase = 'E'; $motivo = 'contenido vacio o incompleto (sin cuerpo legible)'; $prio = 3
    } elseif ($titTrim -eq '' -or $titTrim -match '^[^A-Za-zÀ-ÿ0-9]{1,5}$') {
        $clase = 'E'; $motivo = "titulo invalido: '" + $titTrim + "'"; $prio = 3
    } elseif ($titTrim -match '^(?i)(error|error\s*404|404|pagina no encontrada|no encontrado|error en el servidor)\s*[.!]?\s*$' -or ($texto.Length -gt 0 -and $rxRotos.IsMatch($texto.Substring(0, [Math]::Min(300, $texto.Length))))) {
        $clase = 'E'; $motivo = 'marca de error / pagina rota en el contenido'; $prio = 3
    } elseif ($rxNoOferta.IsMatch($titTrim)) {
        $clase = 'D'; $motivo = 'titulo de categoria/contenido, no de oferta individual'; $prio = 1
    } elseif ($senales -eq 0 -and (@($e.etiquetas) -notcontains 'Empleo')) {
        $clase = 'D'; $motivo = 'sin senales de oferta laboral y sin etiqueta Empleo'; $prio = 1
    } elseif ($senales -eq 0 -and [regex]::Matches($texto, 'https?://').Count -ge 5 -and $texto.Length -lt 900) {
        $clase = 'D'; $motivo = 'listado de enlaces, no una oferta individual'; $prio = 1
    } elseif (Es-Mojibake $titTrim) {
        $clase = 'F'; $motivo = 'titulo con caracteres rotos (mojibake)'; $prio = 6
    } elseif ([regex]::IsMatch($texto, '(?i)A convenir') -and $rxMonto.IsMatch($texto)) {
        $clase = 'F'; $motivo = "dice 'A convenir' pero el contenido trae un monto de salario"; $prio = 5
    } elseif (Es-Mojibake $texto) {
        $clase = 'B'; $motivo = 'texto con caracteres rotos (mojibake) en el contenido'; $prio = 6
    } elseif ($senales -gt 0 -and $senales -le 2 -and $texto.Length -lt 700) {
        $clase = 'B'; $motivo = 'oferta incompleta: pocas secciones (corregible con respaldo local)'; $prio = 6
    } elseif ($vencidaPasada) {
        $clase = 'G'; $motivo = 'fecha de cierre pasada (' + $vencida.ToString('yyyy-MM-dd') + ')'; $prio = 7
    } elseif ($e.contenidoOrigen -eq '' -and $e.archivoLocal -eq '') {
        $clase = 'H'; $motivo = 'sin respaldo local para verificar'; $prio = 8
    } else {
        $clase = 'A'; $motivo = 'oferta laboral individual completa'; $prio = 0
    }

    $emp = ''
    $i = $titTrim.IndexOf(':')
    if ($i -gt 0) { $emp = Titulo-Norm $titTrim.Substring(0, $i) }
    $clasificados.Add([pscustomobject]@{
        id = $e.id; titulo = $tit; publicado = $e.publicado; url = $e.url
        etiquetas = $e.etiquetas; archivoLocal = $e.archivoLocal; fuente = $e.fuente
        contenido = $e.contenido; texto = $texto; lenContenido = $e.lenContenido
        clase = $clase; motivo = $motivo; prioridad = $prio
        empresa = $emp; normTit = (Titulo-Norm $titTrim); normFuen = (Url-Norm $e.fuente)
        vencida = $(if ($vencida) { $vencida.ToString('yyyy-MM-dd') } else { '' })
        accion = 'CONSERVAR'; contenidoPropuesto = ''; tituloPropuesto = ''
        estado = 'CONSERVADO'; idConservado = ''
    })
}

# ---------------------------------------------------------------- 4) duplicados (C)
# clave 1: URL de la oferta de origen (si existe)  -> inequivoca
# clave 2: empresa + puesto (titulo normalizado)    -> ultima comprobacion
$grupos = @{}
foreach ($c in $clasificados) {
    if ($c.clase -in @('D', 'E')) { continue }
    # Solo es duplicado si el TITULO es igual y ademas comparten la MISMA URL de
    # origen (o ambos no traen URL). Una fuente compartida con titulos distintos
    # NO es duplicado: es una pagina/listado comun y retiraria ofertas validas.
    $clave = ''
    if ($c.normTit -eq '' -or $c.normTit.Length -lt 8) { continue }
    if ($c.normFuen -ne '' -and $c.normFuen -notmatch 'blogspot\.com$') { $clave = 'N:' + $c.normTit + '|' + $c.normFuen }
    elseif ($c.normFuen -eq '') { $clave = 'S:' + $c.normTit + '|' + $c.empresa }
    else { continue }
    if ($clave -eq '') { continue }
    if (-not $grupos.ContainsKey($clave)) { $grupos[$clave] = New-Object System.Collections.Generic.List[object] }
    $grupos[$clave].Add($c)
}
$dupsTotal = 0
foreach ($k in $grupos.Keys) {
    $g = $grupos[$k]
    if ($g.Count -lt 2) { continue }
    $ordenado = @($g | Sort-Object -Property @{ Expression = { -$_.lenContenido } }, @{ Expression = { $_.publicado } })
    $mejor = $ordenado[0]
    $dupsTotal += ($g.Count - 1)
    foreach ($x in $g) {
        if ($x.id -eq $mejor.id) {
            $x.motivo = $x.motivo + ' | duplicados conservados: ' + ($g.Count - 1)
            continue
        }
        $x.clase = 'C'; $x.prioridad = 2
        $x.motivo = 'duplicado de post ' + $mejor.id + ' (mismo origen o mismo titulo) se conserva el mejor: ' + $mejor.titulo
        $x.idConservado = $mejor.id
    }
}
Log ("duplicados detectados: " + $dupsTotal)

# ---------------------------------------------------------------- 5) propuestas de correccion + acciones
$propuestas = 0
foreach ($c in $clasificados) {
    # propuesta de contenido: respaldo local de alta confianza
    if ($c.archivoLocal -ne '') {
        $ruta = Join-Path $DirSalida $c.archivoLocal
        if (Test-Path $ruta) {
            try {
                $nuevo = [IO.File]::ReadAllText($ruta)
                $mt = [regex]::Match($nuevo, '(?s)TITULO_BLOGGER\s*=\s*(.+?)\s*-->')
                if ($nuevo.Length -gt 400 -and $mt.Success -and -not [regex]::IsMatch($nuevo, '(?i)A convenir')) {
                    $c.contenidoPropuesto = $nuevo
                    $c.tituloPropuesto = ([Net.WebUtility]::HtmlDecode($mt.Groups[1].Value)).Trim()
                    $propuestas++
                }
            } catch { }
        }
    }
    # correccion quirurgica de salario: solo con monto de alta confianza
    # (dentro del propio campo, en el titulo del empleador, o pegado al texto)
    if ($c.contenidoPropuesto -eq '' -and $c.clase -eq 'F') {
        $monto = ''
        $mC = [regex]::Match($c.contenido, '(?is)(salario|remuneraci[oó]n).{0,80}?A convenir')
        if ($mC.Success) { $m = $rxMonto.Match($mC.Value); if ($m.Success) { $monto = $m.Value.Trim() } }
        if ($monto -eq '') { $m = $rxMonto.Match($c.titulo); if ($m.Success) { $monto = $m.Value.Trim() } }
        if ($monto -eq '' -and $c.texto.Contains('A convenir')) {
            $iA = $c.texto.IndexOf('A convenir')
            $ini = [Math]::Max(0, $iA - 150)
            $vent = $c.texto.Substring($ini, [Math]::Min(300, $c.texto.Length - $ini))
            $m = $rxMonto.Match($vent)
            if ($m.Success) { $monto = $m.Value.Trim() }
        }
        if ($monto -ne '') {
            $nuevoCont = [regex]::Replace($c.contenido, '(?is)(salario|remuneraci[oó]n)(.{0,80}?)A convenir', { param($mm) $mm.Groups[1].Value + $mm.Groups[2].Value + $monto }, 1)
            if ($nuevoCont -ne $c.contenido) {
                $c.contenidoPropuesto = $nuevoCont
                $c.tituloPropuesto = $c.titulo
                $propuestas++
            }
        }
    }

    switch ($c.clase) {
        'D' { $c.accion = 'RETIRAR'; $c.estado = 'PENDIENTE' }
        'C' { $c.accion = 'RETIRAR'; $c.estado = 'PENDIENTE' }
        'E' { if ($c.contenidoPropuesto -ne '') { $c.accion = 'CORREGIR'; $c.estado = 'PENDIENTE' } else { $c.accion = 'RETIRAR'; $c.estado = 'PENDIENTE' } }
        'F' { if ($c.contenidoPropuesto -ne '') { $c.accion = 'CORREGIR'; $c.estado = 'PENDIENTE' } else { $c.accion = 'CONSERVAR'; $c.motivo = $c.motivo + ' | SIN propuesta: se conserva y se registra para revision' } }
        'B' { if ($c.contenidoPropuesto -ne '') { $c.accion = 'CORREGIR'; $c.estado = 'PENDIENTE' } else { $c.accion = 'CONSERVAR'; $c.motivo = $c.motivo + ' | SIN propuesta: se conserva y se registra para revision' } }
        default { $c.accion = 'CONSERVAR'; $c.estado = 'CONSERVADO' }
    }
    if ($ConservarTodo -and $c.accion -eq 'RETIRAR') {
        $c.accion = 'CONSERVAR'; $c.estado = 'CONSERVADO'
        $c.motivo = $c.motivo + ' | retiro desactivado (-ConservarTodo)'
    }
}

# ---------------------------------------------------------------- 6) salidas
# estado previo de la cola: no perder lo ya aplicado en corridas anteriores
$estadoPrevio = @{}
if (Test-Path $RutaCola) {
    foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
        $l = $l.Trim(); if ($l -eq '') { continue }
        try { $o = $l | ConvertFrom-Json; if ($o.id) { $estadoPrevio[[string]$o.id] = [pscustomobject]@{ estado = [string]$o.estado; accion = [string]$o.accion; aplicadaEn = [string]$o.aplicadaEn } } } catch { }
    }
}

$lineasClas = New-Object System.Collections.Generic.List[string]
$lineasCola = New-Object System.Collections.Generic.List[string]
$lineasCsv  = New-Object System.Collections.Generic.List[string]
$lineasCsv.Add('id;clase;accion;estado;prioridad;titulo;url;motivo')
$porClase = @{}; $porAccion = @{}; $pendientes = 0; $conservados = 0; $rePropuesta = 0

foreach ($c in ($clasificados | Sort-Object prioridad, id)) {
    $porClase[$c.clase] = 1 + $(if ($porClase.ContainsKey($c.clase)) { $porClase[$c.clase] } else { 0 })

    if ($estadoPrevio.ContainsKey($c.id) -and $estadoPrevio[$c.id].estado -notin @('', 'PENDIENTE')) {
        $c.estado = $estadoPrevio[$c.id].estado
    }

    if ($c.accion -ne 'CONSERVAR') {
        $porAccion[$c.accion] = 1 + $(if ($porAccion.ContainsKey($c.accion)) { $porAccion[$c.accion] } else { 0 })
    }
    if ($c.estado -eq 'PENDIENTE') {
        $pendientes++
        # la cola guarda solo lo necesario para ejecutar; el contenido original
        # completo vive en el inventario (respaldo), no aqui.
        $lineasCola.Add(([pscustomobject]@{
            id = $c.id; accion = $c.accion; clase = $c.clase; prioridad = $c.prioridad
            titulo = $c.titulo; url = $c.url; archivoLocal = $c.archivoLocal
            motivo = $c.motivo; idConservado = $c.idConservado
            tituloNuevo = $c.tituloPropuesto
            contenidoNuevo = $(if ($c.accion -eq 'CORREGIR') { $c.contenidoPropuesto } else { '' })
            fechaEncolada = (Get-Date).ToString('o')
            estado = 'PENDIENTE'
        } | ConvertTo-Json -Compress -Depth 4))
    }
    else { $conservados++ }
    if ($c.contenidoPropuesto -ne '') { $rePropuesta++ }

    $lineasClas.Add(([pscustomobject]@{
        id = $c.id; url = $c.url; titulo = $c.titulo; publicado = $c.publicado
        etiquetas = $c.etiquetas; archivoLocal = $c.archivoLocal; fuente = $c.fuente
        clase = $c.clase; motivo = $c.motivo; prioridad = $c.prioridad
        accion = $c.accion; estado = $c.estado; idConservado = $c.idConservado
        vencida = $c.vencida; lenContenido = $c.lenContenido
        tienePropuesta = ($c.contenidoPropuesto -ne ''); tituloPropuesto = $c.tituloPropuesto
    } | ConvertTo-Json -Compress -Depth 5))

    $lineasCsv.Add(('{0};{1};{2};{3};{4};"{5}";{6};"{7}"' -f
        $c.id, $c.clase, $c.accion, $c.estado, $c.prioridad,
        ($c.titulo -replace '"', "'"),
        $c.url,
        (($c.motivo -replace '"', "'") -replace '\s+', ' ')))
}

[IO.File]::WriteAllLines($RutaClasif, [string[]]$lineasClas, $utf8)
[IO.File]::WriteAllLines($RutaCsv,    [string[]]$lineasCsv,  $utf8)
[IO.File]::WriteAllLines($RutaCola,   [string[]]$lineasCola, $utf8)

Log ""
Log ("=== RESUMEN INSPECCION ===")
Log ("  fuente de datos : " + $fuenteDato)
Log ("  posts inspeccionados: " + $clasificados.Count)
foreach ($k in ($porClase.Keys | Sort-Object)) { Log ("  clase " + $k + ": " + $porClase[$k]) }
Log ("  acciones propuestas: " + $(if ($porAccion.Keys.Count -gt 0) { (@($porAccion.Keys | ForEach-Object { $_ + '=' + $porAccion[$_] }) -join ' | ') } else { 'ninguna' }))
Log ("  cola de correcciones PENDIENTE: " + $pendientes + "  -> " + $RutaCola)
Log ("  conservados (incluye incertidumbre): " + $conservados)
Log ("  con propuesta de contenido: " + $rePropuesta)
Log ("  clasificacion: " + $RutaClasif)
Log ("  csv          : " + $RutaCsv)
Log ("  respaldo     : " + $RutaBackup)
Write-Host ""
Write-Host "Nada se ha tocado en Blogger: esto es inventario local + cola preparada."
exit 0

