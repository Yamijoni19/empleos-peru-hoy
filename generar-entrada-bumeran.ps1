# generar-entrada-bumeran.ps1 - genera la entrada HTML en salida\ a partir de
# las fichas normalizadas de obtener-bumeran.ps1 (bumeran\normalizado\*.json).
#
# USO:
#   .\generar-entrada-bumeran.ps1                 # genera todas las pendientes
#   .\generar-entrada-bumeran.ps1 -Maximo 5       # solo 5
#   .\generar-entrada-bumeran.ps1 -Repasar        # regenera aunque exista
#
# REGLAS:
#   - SIEMPRE valida con validar-entrada.ps1 -Calidad antes de guardar.
#   - Si la validacion falla o hay copia >=35% de la fuente: la entrada se
#     guarda en datos\revision\ y se registra en datos\cola\rechazadas.txt
#     (NUNCA se descarta en silencio, nunca queda en salida\).
#   - Salario: si hay monto real se muestra; si no: "No especificado"
#     (NUNCA "A convenir").
#   - Categoria/salario/jornada/etc: formas canonicas de lib\ (Fase A).
#   - Idempotente: no regenera lo ya generado (deduplicacion por id).

param(
    [int]$Maximo = 0,
    [switch]$Repasar,
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$DirNorm     = Join-Path $BaseDir 'bumeran\normalizado'
$DirSalida   = Join-Path $BaseDir 'salida'
$DirValid    = Join-Path $BaseDir 'datos\cola'
$RutaRech    = Join-Path $DirValid 'rechazadas.txt'
$Plantilla   = Join-Path $BaseDir 'plantilla-oferta-data.html'
$Validador   = Join-Path $BaseDir 'validar-entrada.ps1'
$LogPath     = Join-Path $BaseDir ('reporte\bumeran-entradas-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($d in @($DirSalida, $DirValid, (Join-Path $BaseDir 'reporte'))) { New-Item -ItemType Directory -Path $d -Force  }

# librerias Fase A: categoria canonica, glosario de campos, anti-copia
. (Join-Path $BaseDir 'lib\categoria.ps1')
. (Join-Path $BaseDir 'lib\estandar.ps1')
. (Join-Path $BaseDir 'lib\reescritor.ps1')

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($LogPath, ($l + "`r`n"), $utf8) } catch { }
    Write-Host $l
}
function Guardar-Revision([string]$nombreHtml, [string]$html, [string]$url, [string]$motivo) {
    # decision Fase A: toda entrada que no pasa la puerta de calidad se guarda
    # en datos\revision\ (para repararla a mano o descartarla despues)
    $dirRev = Join-Path $BaseDir 'datos\revision'
    if (-not (Test-Path $dirRev)) { New-Item -ItemType Directory -Path $dirRev -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $dirRev $nombreHtml), $html, $utf8)
    [IO.File]::AppendAllText($RutaRech, ("RECHAZADA | {0} | {1} | {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $url, $motivo) + "`r`n", $utf8)
    Log ("REVISION -> datos\revision\" + $nombreHtml + " | " + $motivo)
}
function Escapar([string]$t) {
    $s = [string]$t
    $s = $s -replace '&', '&amp;'
    $s = $s -replace '<', '&lt;'
    $s = $s -replace '>', '&gt;'
    return $s
}
function Limpiar([string]$t) {
    $s = ([string]$t) -replace '\s+', ' '
    return $s.Trim()
}
function Slug([string]$t) {
    $s = $t.ToLower()
    $s = $s -replace '[^a-z0-9\s-]', ' '
    $s = ($s -replace '\s+', '-').Trim('-')
    $s = $s -replace '-{2,}', '-'
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60).Trim('-') }
    if ($s -eq '') { $s = 'oferta' }
    return $s
}
function Quita-Vacio([string]$html, [string]$ph) {
    # quita el <li>/<p> que quedaria con el placeholder vacio
    $html = [regex]::Replace($html, '(?is)\s*<li>\s*' + [regex]::Escape($ph) + '\s*</li>', '')
    $html = [regex]::Replace($html, '(?is)\s*<p>\s*' + [regex]::Escape($ph) + '\s*</p>', '')
    return $html
}
function Quita-Seccion([string]$html, [string]$titulo) {
    # quita la seccion completa <div class="empleo-seccion"> cuando no hay contenido real
    return [regex]::Replace($html, '(?s)\s*<div class="empleo-seccion">\s*<h2>\s*' + [regex]::Escape($titulo) + '\s*</h2>.*?</div>', '')
}

if (-not (Test-Path $Plantilla)) { Write-Host ("ERROR: falta la plantilla " + $Plantilla); exit 1 }
if (-not (Test-Path $DirNorm)) { Write-Host ("ERROR: no existe " + $DirNorm); exit 1 }

$fichas = @(Get-ChildItem $DirNorm -Filter '*.json' -File | Sort-Object LastWriteTime)
if ($fichas.Count -eq 0) { Write-Host 'Bumeran: no hay fichas normalizadas.'; exit 0 }

$hechas = 0
$omitidas = 0
$rechazadas = 0
$revisiones = 0
$n = 0
foreach ($fi in $fichas) {
    $n++
    if ($Maximo -gt 0 -and $hechas -ge $Maximo) { break }
    try { $o = Get-Content $fi.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { Log ("ficha ilegible: " + $fi.Name); continue }

    $idNum = ([string]$o.id) -replace '^bumeran-', ''
    $nombre = 'bum-' + $idNum + '-' + (Slug $o.titulo) + '-entrada.html'
    $ruta = Join-Path $DirSalida $nombre
    if ((Test-Path $ruta) -and -not $Repasar) { $omitidas++; continue }

    # ---------------------------------------------------------------- salario
    $salTxt = 'No especificado'
    $salMin = $null; $salMax = $null
    if ($o.salario -and $o.salario.especificado) {
        $salTxt = [string]$o.salario.texto_original
        if ($o.salario.min -ne $null) { try { $salMin = [double]$o.salario.min } catch { } }
        if ($o.salario.max -ne $null) { try { $salMax = [double]$o.salario.max } catch { } }
    }
    if ($null -ne $salMin -and $null -ne $salMax -and $salMax -ge $salMin) {
        $salTxt = Est-Salario -Min $salMin -Max $salMax
    } elseif ($null -ne $salMin -and ($salTxt -eq '' -or $salTxt -eq 'No especificado')) {
        $salTxt = Est-Salario -Min $salMin
    } elseif ($salTxt -ne '' -and $salTxt -ne 'No especificado') {
        $salTxt = Est-Salario -Texto $salTxt
    } else {
        $salTxt = 'No especificado'
    }
    if ($salTxt -eq '' -or $salTxt -eq 'A convenir') { $salTxt = 'No especificado' }

    # ---------------------------------------------------------------- campos
    $titulo  = Limpiar $o.titulo
    $empresa = Limpiar $o.empresa
    if ($empresa -eq '') { $empresa = 'No especificado' }
    $ubi     = Est-Ubicacion (Limpiar $o.ubicacion)
    $ciudad  = Est-Ciudad ([string]$o.ciudad)
    if ($ciudad -eq 'No especificado') { $ciudad = Est-Ciudad (Limpiar $o.ubicacion) }
    $modal   = Est-Modalidad ([string]$o.modalidad)
    $contrato = switch ([string]$o.contrato) {
        'FULL_TIME' { 'Full-time' }
        'PART_TIME' { 'Part-time' }
        'TEMPORARY' { 'Temporal' }
        'CONTRACT'  { 'Por contrato' }
        'INTERN'    { 'Prácticas' }
        'VOLUNTEER' { 'Voluntariado' }
        default     { Est-Contrato ([string]$o.contrato) }
    }
    if ([string]::IsNullOrWhiteSpace([string]$contrato)) { $contrato = 'No especificado' }
    $fPub = Est-Fecha ([string]$o.fecha_publicacion)
    $fCie = Est-Fecha ([string]$o.fecha_cierre)

    # ---------------------------------------------------------------- resumen propio (no copiar literal)
    $exp = Limpiar $o.experiencia; if ($exp -eq '') { $exp = 'No especificado' }
    $jor = Est-Jornada ([string]$o.jornada)
    $vca = Est-Vacantes ([string]$o.vacantes)
    $est = Limpiar $o.estudios;   if ($est -eq '') { $est = 'No especificado' }
    $area = Limpiar $o.area;      if ($area -eq '') { $area = 'No especificado' }
    $niv  = Limpiar $o.nivel;     if ($niv -eq '')  { $niv = 'No especificado' }
    $turno = Limpiar $o.turno;    if ($turno -eq '') { $turno = 'No especificado' }
    $horario = Limpiar $o.horario; if ($horario -eq '') { $horario = 'No especificado' }

    $resumen1 = 'Se busca ' + $titulo + ' para ' + $(if ($empresa -ne 'No especificado') { $empresa } else { 'una empresa confidencial' }) + ' en ' + $ubi + '.'
    $detalles = @()
    if ($modal -ne 'No especificado') { $detalles += 'Modalidad: ' + $modal }
    if ($jor -ne 'No especificado')  { $detalles += 'Jornada: ' + $jor }
    if ($contrato -ne 'No especificado') { $detalles += 'Contrato: ' + $contrato }
    if ($exp -ne 'No especificado')  { $detalles += 'Experiencia: ' + $exp }
    if ($est -ne 'No especificado')  { $detalles += 'Estudios: ' + $est }
    if ($turno -ne 'No especificado') { $detalles += 'Turno: ' + $turno }
    if ($horario -ne 'No especificado') { $detalles += 'Horario: ' + $horario }

    $p1 = $resumen1
    $p2 = ''
    if ($detalles.Count -gt 0) { $p2 = ($detalles -join '. ') + '.' }
    if ($p2 -eq '') { $p2 = 'Los interesados aplican directamente en Bumeran a través del enlace de esta publicación.' }

    $funciones = @(); foreach ($x in @($o.funciones)) { $x = Limpiar $x; if ($x -ne '' -and $x -ne 'No especificado') { $funciones += $x } }
    $requisitos = @(); foreach ($x in @($o.requisitos)) { $x = Limpiar $x; if ($x -ne '' -and $x -ne 'No especificado' -and $funciones -notcontains $x) { $requisitos += $x } }
     $beneficios = @(); foreach ($x in @($o.beneficios)) { $x = Limpiar $x; if ($x -ne '' -and $x -ne 'No especificado' -and $x -notmatch 'Sueldo|Salario|Remuneraci[o&]n') { $beneficios += $x } }

    # ---------------------------------------------------------------- categoria canonica (Fase A)
    $categoria = Obtener-CategoriaExacta -Titulo $titulo -Texto ((@($o.funciones) + @($o.requisitos)) -join ' ')

    # ---------------------------------------------------------------- plantilla
    $html = [IO.File]::ReadAllText($Plantilla, [Text.Encoding]::UTF8)
    $map = @{
        '@@FUENTE@@'            = 'BUMERAN'
        '@@CATEGORIA@@'         = $categoria
        '@@TITULO@@'            = $titulo
        '@@EMPRESA@@'           = $empresa
        '@@SALARIO_HEADER@@'    = $salTxt
        '@@UBICACION@@'         = $ubi
        '@@CIUDAD@@'            = $ciudad
        '@@MODALIDAD@@'         = $modal
        '@@CONTRATO@@'          = $contrato
        '@@SALARIO@@'           = $salTxt
        '@@DIRIGIDO_A@@'        = 'No especificado'
        '@@COMO_POSTULAR@@'     = 'Completa el formulario de postulación con tus datos, adjunta tu CV en PDF y envía la solicitud con el botón de esta publicación; el proceso lo gestiona directamente Bumeran.'
        '@@DESCRIPCION_P1@@'    = $(if ($p1 -eq '') { '' } else { $p1 })
        '@@DESCRIPCION_P2@@'    = $(if ($p2 -eq '') { '' } else { $p2 })
        '@@VACANTES@@'          = $vca
        '@@JORNADA@@'           = $jor
        '@@CONTRATO2@@'         = $contrato
        '@@MODALIDAD2@@'        = $modal
        '@@EXPERIENCIA@@'       = $exp
        '@@ESTUDIOS@@'          = $est
        '@@SALARIO2@@'          = $salTxt
        '@@FECHA_PUBLICACION@@' = $fPub
        '@@FECHA_CIERRE@@'      = $fCie
        '@@AREA@@'              = $area
        '@@NIVEL@@'             = $niv
        '@@TURNO@@'             = $turno
        '@@HORARIO@@'           = $horario
        '@@TIPO_CONTRATANTE@@'  = 'Privado'
        '@@TIPO_CONTRATO_ESTADO@@' = 'No especificado'
        '@@TIPO_ENTIDAD@@'      = 'Empresa privada'
        '@@EMPRESA2@@'          = $empresa
        '@@SECTOR@@'            = 'Privado'
        '@@TAMANO@@'            = 'No especificado'
        '@@UBICACION_EMPRESA@@' = $ubi
        '@@DESCRIPCION_EMPRESA@@' = 'No especificado'
        '@@URL_POSTULAR@@'      = [string]$o.url
        '@@PORTAL@@'            = 'BUMERAN'
    }
    for ($i = 1; $i -le 6; $i++) {
        $v = ''; if ($i -le $funciones.Count) { $v = $funciones[$i - 1] }
        if ($v -eq '') { $html = Quita-Vacio $html ('@@FUNCION' + $i + '@@') } else { $map['@@FUNCION' + $i + '@@'] = $v }
    }
    for ($i = 1; $i -le 6; $i++) {
        $v = ''; if ($i -le $requisitos.Count) { $v = $requisitos[$i - 1] }
        if ($v -eq '') { $html = Quita-Vacio $html ('@@REQUISITO' + $i + '@@') } else { $map['@@REQUISITO' + $i + '@@'] = $v }
    }
    for ($i = 1; $i -le 4; $i++) {
        $v = ''; if ($i -le $beneficios.Count) { $v = $beneficios[$i - 1] }
        if ($v -eq '') { $html = Quita-Vacio $html ('@@BENEFICIO' + $i + '@@') } else { $map['@@BENEFICIO' + $i + '@@'] = $v }
    }
    # "¿Por qué postular?": bullets SOLO con datos reales ya extraidos (Fase A)
    $porque = Est-Porque @{
        titulo = $titulo; empresa = $empresa; sector = [string]$o.sector
        ubicacion = $ubi; ciudad = $ciudad; modalidad = $modal
        salario = $salTxt; contrato = $contrato; jornada = $jor
        experiencia = $exp; beneficios = @($beneficios)
    }
    for ($i = 1; $i -le 4; $i++) {
        $v = ''; if ($i -le $porque.Count) { $v = [string]$porque[$i - 1] }
        if ($v -eq '') { $html = Quita-Vacio $html ('@@PORQUE' + $i + '@@') } else { $map['@@PORQUE' + $i + '@@'] = $v }
    }
    if ($p1 -eq '') { $html = Quita-Vacio $html '@@DESCRIPCION_P1@@' }
    if ($p2 -eq '') { $html = Quita-Vacio $html '@@DESCRIPCION_P2@@' }

    foreach ($k in $map.Keys) { $html = $html.Replace($k, (Escapar ([string]$map[$k]))) }
    $html = [regex]::Replace($html, '@@[A-Z0-9_]+@@', '')
    if ($funciones.Count -eq 0)  { $html = Quita-Seccion $html 'Funciones' }
    if ($requisitos.Count -eq 0) { $html = Quita-Seccion $html 'Requisitos' }
    if ($beneficios.Count -eq 0) { $html = Quita-Seccion $html 'Beneficios' }

    # 'No especificado' visible fuera de los 4 recuadros (regla 5 del validador):
    # se borran esas lineas de .empleo-destacado (oferta y empresa), la linea de
    # salario de la cabecera y la de empresa si esta vacia
    $html = [regex]::Replace($html, '(?s)<div class="empleo-destacado">.*?</div>', {
        param($bl)
        [regex]::Replace($bl.Value, '(?s)<p>\s*<strong>[^<]*:</strong>\s*No especificad[oa]\s*</p>', '')
    })
    if ($salTxt -eq 'No especificado') {
        $html = [regex]::Replace($html, '(?m)^\s*<div class="empleo-salario-header">[\s\S]*?</div>\r?\n?', '')
    }
    if ($empresa -eq 'No especificado') {
        $html = [regex]::Replace($html, '(?m)^\s*<div class="empleo-empresa">[\s\S]*?</div>\r?\n?', '')
    }

    $meta = "<!-- ETIQUETA_BLOGGER = Empleo`r`n     TITULO_BLOGGER = " + $titulo + " -->`r`n`r`n"
    $entrada = $meta + $html

    # ---------------------------------------------------------------- anti-copia (Fase A)
    # parrafos/bullets de 15+ palabras con >=35% de n-gramas identicos a la
    # ficha de origen: se reescriben hasta 3 veces; si aun asi persisten, la
    # entrada va a datos\revision\ en vez de salida\
    $fuenteAnti = [string]$o.descripcion_html
    if ($fuenteAnti -eq '') { $fuenteAnti = [string]$o.descripcion }
    $reintentos = 0
    while ($reintentos -lt 3) {
        $cop = @(Parrafos-Copiados -Html $entrada -Fuente $fuenteAnti -Umbral 0.35)
        if ($cop.Count -eq 0) { break }
        $reintentos++
        foreach ($c in $cop) {
            $tipo = 'p'; if ([string]$c.tipo -eq 'li') { $tipo = 'li' }
            $viejo = [string]$c.texto
            $nuevos = @(Reescribir-Copiado -texto $viejo -tipo $tipo -Fuente $fuenteAnti)
            $rep = ''
            if ($tipo -eq 'li') {
                # reemplazar el <li> COMPLETO: N fragmentos => N <li> hermanos
                # (nunca anidar <li> dentro de <li>)
                foreach ($nv in $nuevos) { $rep += '<li>' + $nv + '</li>' }
                if ($rep -eq '') { continue }
                $rx = '<li[^>]*>' + [regex]::Escape($viejo) + '</li>'
                if ([regex]::IsMatch($entrada, $rx)) {
                    $entrada = [regex]::Replace($entrada, $rx, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $rep })
                } else { continue }
            } else {
                # 1 trozo => mismo parrafo; N trozos => parrafos hermanos
                $rep = ($nuevos -join '</p><p>')
                if ($rep -eq '') { continue }
                if ($entrada.Contains($viejo)) { $entrada = $entrada.Replace($viejo, $rep) } else { continue }
            }
        }
    }
    if (@(Parrafos-Copiados -Html $entrada -Fuente $fuenteAnti -Umbral 0.35).Count -gt 0) {
        Guardar-Revision $nombre $entrada ([string]$o.url) 'anti-copia: parrafos con >=35% de n-gramas de la fuente'
        $revisiones++
        continue
    }

    # ---------------------------------------------------------------- validacion
    $rutaTmp = Join-Path $env:TEMP ('bum-' + $idNum + '-entrada.html')
    [IO.File]::WriteAllText($rutaTmp, $entrada, $utf8)
    $ok = $true
    $motivo = ''
    if (Test-Path $Validador) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $Validador -Archivo $rutaTmp -Calidad | Out-Null
        if ($LASTEXITCODE -ne 0) { $ok = $false; $motivo = 'no paso validar-entrada.ps1 -Calidad' }
    }
    if (-not $ok) {
        Remove-Item ($rutaTmp + '._keep') -ErrorAction SilentlyContinue
        Guardar-Revision $nombre $entrada ([string]$o.url) $motivo
        $revisiones++
        continue
    }
    Remove-Item ($rutaTmp + '._keep') -ErrorAction SilentlyContinue

    [IO.File]::WriteAllText($ruta, $entrada, $utf8)
    $hechas++
    Log ("ENTRADA " + $nombre + " | " + $titulo + " | " + $empresa + " | " + $salTxt)
}

Write-Host ''
Write-Host ("== RESUMEN ENTRADAS BUMERAN ==  generadas: " + $hechas + " | ya existian: " + $omitidas + " | a revision: " + $revisiones + " | rechazadas: " + $rechazadas)
Write-Host ("  carpeta: " + $DirSalida)
exit 0
