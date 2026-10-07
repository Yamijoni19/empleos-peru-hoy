# generar-entrada-bumeran.ps1 - genera la entrada HTML en salida\ a partir de
# las fichas normalizadas de obtener-bumeran.ps1 (bumeran\normalizado\*.json).
#
# USO:
#   .\generar-entrada-bumeran.ps1                 # genera todas las pendientes
#   .\generar-entrada-bumeran.ps1 -Maximo 5       # solo 5
#   .\generar-entrada-bumeran.ps1 -Repasar        # regenera aunque exista
#
# REGLAS:
#   - SIEMPRE valida con validar-entrada.ps1 antes de guardar.
#   - Si la validacion falla: no se guarda la entrada y se registra
#     RECHAZADA | fecha | URL | motivo  en datos\cola\rechazadas.txt.
#   - Salario: si hay monto real se muestra; si no: "No especificado"
#     (NUNCA "A convenir").
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

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($LogPath, ($l + "`r`n"), $utf8) } catch { }
    Write-Host $l
}
function Rechazar([string]$url, [string]$motivo) {
    [IO.File]::AppendAllText($RutaRech, ("RECHAZADA | {0} | {1} | {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $url, $motivo) + "`r`n", $utf8)
    Log ("RECHAZADA: " + $motivo)
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
function Categoria-De([string]$t, [string]$e) {
    $x = ($t + ' ' + $e).ToLower()
    if ($x -match 'administrativ|contabl|contable|tesorer|cobranz|facturac|auxiliar') { return 'Administracion y Finanzas' }
    if ($x -match 'recursos humanos|rrhh|seleccion|\brh\b') { return 'Recursos Humanos' }
    if ($x -match 'desarroll|software|programad|sistem|data|devops|backend|frontend|tecnolog|soporte tecnico|informatic') { return 'Tecnologia' }
    if ($x -match 'ventas|comercial|asesor|ejecutivo de cuenta|vendedor|promotor|telemarketing') { return 'Ventas' }
    if ($x -match 'marketing|disen|graphic|community|publicid|comunicacion') { return 'Marketing y Diseno' }
    if ($x -match 'salud|enfermer|medic|odontolog|farmac|nutricion|laboratorio|kinesi') { return 'Salud' }
    if ($x -match 'abogad|legal|juridic|compliance') { return 'Legal' }
    if ($x -match 'ingenier|industrial|produccion|calidad|mantenimiento|civil|mecanic|electric') { return 'Ingenieria' }
    if ($x -match 'operador|operario|conductor|almacen|logistic|distribuc|repartidor|deposito') { return 'Operaciones y Logistica' }
    if ($x -match 'call center|atencion al cliente|servicio al cliente|recepcion|cajero|caja') { return 'Atencion al Cliente' }
    if ($x -match 'docente|profesor|educativ|instructor|capacitador') { return 'Educacion' }
    if ($x -match 'limpieza|vigilanc|seguridad|aseo|conserje') { return 'Servicios Generales' }
    if ($x -match 'hotel|restaurante|cocin|mesero|hostel|turismo') { return 'Hoteleria y Gastronomia' }
    return 'Otros'
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
    if ($o.salario -and $o.salario.especificado) {
        $salTxt = [string]$o.salario.texto_original
        if ($salTxt -eq '') {
            $mn = $o.salario.min; $mx = $o.salario.max
            if ($null -ne $mn -and $null -ne $mx -and [double]$mn -ne [double]$mx) { $salTxt = ('S/ {0} - S/ {1}' -f ([double]$mn).ToString('N0'), ([double]$mx).ToString('N0')) }
            elseif ($null -ne $mn) { $salTxt = ('S/ ' + ([double]$mn).ToString('N0')) }
        }
    }
    if ($salTxt -eq '' -or $salTxt -eq 'A convenir') { $salTxt = 'No especificado' }

    # ---------------------------------------------------------------- campos
    $titulo  = Limpiar $o.titulo
    $empresa = Limpiar $o.empresa
    if ($empresa -eq '') { $empresa = 'No especificado' }
    $ubi     = Limpiar $o.ubicacion
    if ($ubi -eq '') { $ubi = 'No especificado' } else { $ubi = $ubi + ', Peru' }
    $modal   = 'No especificado'
    if ([string]$o.modalidad -eq 'TELECOMMUTE') { $modal = 'Remoto' }
    elseif ([string]$o.modalidad -ne '') { $modal = [string]$o.modalidad }
    $contrato = Limpiar $o.contrato
    if ($contrato -eq '') { $contrato = 'No especificado' }
    $fPub = [string]$o.fecha_publicacion; if ($fPub -eq '') { $fPub = 'No especificado' } else { try { $fPub = ([datetime]$fPub).ToString('dd/MM/yyyy') } catch { } }
    $fCie = [string]$o.fecha_cierre;     if ($fCie -eq '') { $fCie = 'No especificado' } else { try { $fCie = ([datetime]$fCie).ToString('dd/MM/yyyy') } catch { } }

    # ---------------------------------------------------------------- resumen propio (no copiar literal)
    $exp = Limpiar $o.experiencia; if ($exp -eq '') { $exp = 'No especificado' }
    $jor = Limpiar $o.jornada;    if ($jor -eq '') { $jor = 'No especificado' }
    $vca = Limpiar $o.vacantes;   if ($vca -eq '') { $vca = 'No especificado' }
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

    # ---------------------------------------------------------------- plantilla
    $html = [IO.File]::ReadAllText($Plantilla, [Text.Encoding]::UTF8)
    $map = @{
        '@@FUENTE@@'            = 'BUMERAN'
        '@@CATEGORIA@@'         = (Categoria-De $titulo $empresa)
        '@@TITULO@@'            = $titulo
        '@@EMPRESA@@'           = $empresa
        '@@SALARIO_HEADER@@'    = $salTxt
        '@@UBICACION@@'         = $ubi
        '@@MODALIDAD@@'         = $modal
        '@@CONTRATO@@'          = $contrato
        '@@SALARIO@@'           = $salTxt
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
    if ($p1 -eq '') { $html = Quita-Vacio $html '@@DESCRIPCION_P1@@' }
    if ($p2 -eq '') { $html = Quita-Vacio $html '@@DESCRIPCION_P2@@' }

    foreach ($k in $map.Keys) { $html = $html.Replace($k, (Escapar ([string]$map[$k]))) }
    $html = [regex]::Replace($html, '@@[A-Z0-9_]+@@', '')
    if ($funciones.Count -eq 0)  { $html = Quita-Seccion $html 'Funciones' }
    if ($requisitos.Count -eq 0) { $html = Quita-Seccion $html 'Requisitos' }
    if ($beneficios.Count -eq 0) { $html = Quita-Seccion $html 'Beneficios' }

    $meta = "<!-- ETIQUETA_BLOGGER = Empleo`r`n     TITULO_BLOGGER = " + $titulo + " -->`r`n`r`n"
    $entrada = $meta + $html

    # ---------------------------------------------------------------- validacion
    $rutaTmp = Join-Path $env:TEMP ('bum-' + $idNum + '-entrada.html')
    [IO.File]::WriteAllText($rutaTmp, $entrada, $utf8)
    $ok = $true
    $motivo = ''
    if (Test-Path $Validador) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $Validador -Archivo $rutaTmp | Out-Null
        if ($LASTEXITCODE -ne 0) { $ok = $false; $motivo = 'no paso validar-entrada.ps1' }
    }
    if (-not $ok) {
        Remove-Item ($rutaTmp + '._keep') -ErrorAction SilentlyContinue
        Rechazar ([string]$o.url) $motivo
        $rechazadas++
        continue
    }
    Remove-Item ($rutaTmp + '._keep') -ErrorAction SilentlyContinue

    [IO.File]::WriteAllText($ruta, $entrada, $utf8)
    $hechas++
    Log ("ENTRADA " + $nombre + " | " + $titulo + " | " + $empresa + " | " + $salTxt)
}

Write-Host ''
Write-Host ("== RESUMEN ENTRADAS BUMERAN ==  generadas: " + $hechas + " | ya existian: " + $omitidas + " | rechazadas: " + $rechazadas)
Write-Host ("  carpeta: " + $DirSalida)
exit 0
