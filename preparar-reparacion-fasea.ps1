# preparar-reparacion-fasea.ps1 - SOLO LECTURA de Blogger (escribe en la cola local).
# Genera entradas accion=CORREGIR con estado=PENDIENTE en cola-correcciones.jsonl
# para reparar publicaciones antiguas en lote:
#   1) categoria no canonica  -> reetiqueta con lib\categoria.ps1
#   2) Ubicacion vacia        -> rellena desde fuentes\*.txt (UBICACION/CIUDAD/REGION)
#   3) Ciudad vacia           -> rellena desde fuentes\*.txt
# Nada se escribe en Blogger aqui. Aplicar con:
#   .\aplicar-correcciones.ps1                (simulacion)
#   .\aplicar-correcciones.ps1 -Aplicar       (escrituras reales, con caps)
#
# Salida: entradas nuevas en datos\publicados\cola-correcciones.jsonl
#         reporte\reparacion-fasea-<fecha>.txt (resumen)

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$MaxPosts = 0
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $BaseDir 'lib\categoria.ps1')

$DirPub = Join-Path $BaseDir 'datos\publicados'
$DirFue = Join-Path $BaseDir 'fuentes'
$DirRep = Join-Path $BaseDir 'reporte'
$RutaCola = Join-Path $DirPub 'cola-correcciones.jsonl'
if (-not (Test-Path $DirRep)) { New-Item -ItemType Directory -Path $DirRep -Force | Out-Null }
if (-not (Test-Path $RutaCola)) { Write-Host 'no existe la cola; aborta'; exit 1 }

function Nor([string]$s) {
    $x = [string]$s
    $x = $x.ToLowerInvariant()
    $x = $x.Normalize([Text.NormalizationForm]::FormD)
    $x = [regex]::Replace($x, '[\u0300-\u036f]', '')
    $x = [regex]::Replace($x, '\s+', ' ')
    return $x.Trim()
}
function NUrl([string]$u) {
    $x = ([string]$u).Trim().ToLowerInvariant()
    $x = $x -replace '^https?://', ''
    $x = $x -replace '^www\.', ''
    return $x.TrimEnd('/')
}
function Campo([string]$html, [string]$etiqueta) {
    $m = [regex]::Match($html, '<strong>' + [regex]::Escape($etiqueta) + ':\s*</strong>\s*([^<]*)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}
function Sin-Etiqueta([string]$html, [string]$etiqueta) {
    return (-not [regex]::IsMatch($html, '<strong>' + [regex]::Escape($etiqueta) + ':\s*</strong>'))
}
function Cambiar-Campo([string]$html, [string]$etiqueta, [string]$valor) {
    $patron = '(<strong>' + [regex]::Escape($etiqueta) + ':\s*</strong>\s*)([^<]*)'
    $v = $valor
    return [regex]::Replace($html, $patron, { param($m) $m.Groups[1].Value + $v })
}
function Texto-Visible([string]$html) {
    $t = $html
    $t = [regex]::Replace($t, '(?is)<style.*?</style>', ' ')
    $t = [regex]::Replace($t, '(?is)<script.*?</script>', ' ')
    $t = [regex]::Replace($t, '<[^>]+>', ' ')
    return [System.Net.WebUtility]::HtmlDecode($t)
}

# ------------------------------------------------------------------ fuentes
Write-Host 'indexando fuentes...'
$mapUrlFuentes = @{}
foreach ($f in (Get-ChildItem (Join-Path $DirFue '*.txt'))) {
    $u = [IO.File]::ReadLines($f.FullName) | Select-Object -First 1
    if ($u -like 'URL: *') {
        $k = NUrl ($u.Substring(5))
        if ($k -ne '' -and -not $mapUrlFuentes.ContainsKey($k)) { $mapUrlFuentes[$k] = $f.FullName }
    }
}
Write-Host ('fuentes indexadas: ' + $mapUrlFuentes.Count)

function Resolver-Fuente([string]$archivo, [string]$fuente) {
    if ($archivo -like 'oportunidad-laboral-*') {
        $slug = $archivo -replace '-entrada\.html$', ''
        $f = Join-Path $DirFue ($slug + '.txt')
        if (Test-Path -LiteralPath $f) { return $f }
    }
    if ($fuente -ne '') {
        $k = NUrl $fuente
        if ($mapUrlFuentes.ContainsKey($k)) { return $mapUrlFuentes[$k] }
    }
    return ''
}
function Leer-Fuente([string]$path) {
    $o = [pscustomobject]@{ CONTRATO=''; CIUDAD=''; REGION=''; UBICACION=''; ok=$false }
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $o }
    foreach ($l in [IO.File]::ReadAllLines($path)) {
        if ($l -match '^CONTRATO:\s*(.*)$')    { $o.CONTRATO = $Matches[1].Trim() }
        elseif ($l -match '^CIUDAD:\s*(.*)$')   { $o.CIUDAD   = $Matches[1].Trim() }
        elseif ($l -match '^REGION:\s*(.*)$')   { $o.REGION   = $Matches[1].Trim() }
        elseif ($l -match '^UBICACION:\s*(.*)$'){ $o.UBICACION= $Matches[1].Trim() }
    }
    $o.ok = $true
    return $o
}

# ------------------------------------------------------------------ cola actual
$pendientesActuales = @{}
$nCola = 0
foreach ($l in [IO.File]::ReadAllLines($RutaCola)) {
    $l = $l.Trim(); if ($l -eq '') { continue }
    try { $o = $l | ConvertFrom-Json; $nCola++; if ([string]$o.estado -eq 'PENDIENTE') { $pendientesActuales[[string]$o.id] = $true } } catch { }
}
Write-Host ('cola actual: ' + $nCola + ' entradas, pendientes=' + $pendientesActuales.Count)

$bak = $RutaCola + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item -LiteralPath $RutaCola -Destination $bak
Write-Host ('respaldo: ' + (Split-Path -Leaf $bak))

# ------------------------------------------------------------------ inventario
$inv = Get-ChildItem (Join-Path $DirPub 'inventario-*.jsonl') | Sort-Object Name -Descending | Select-Object -First 1
Write-Host ('inventario: ' + $inv.Name)

$nuevas = New-Object System.Collections.Generic.List[string]
$cont = @{ cat=0; ub=0; ciu=0; sinFuente=0; sinCampo=0; yaPendiente=0; sinId=0; sinCambio=0; procesados=0 }

function Encolar([string]$id, [string]$titulo, [string]$url, [string]$contenido, [string[]]$motivos) {
    $e = [ordered]@{
        id = $id
        url = $url
        titulo = $titulo
        accion = 'CORREGIR'
        contenidoNuevo = $contenido
        motivo = ('FASE-A: ' + ($motivos -join ', '))
        estado = 'PENDIENTE'
        prioridad = 0
        fechaEncolada = (Get-Date).ToString('o')
    }
    $script:nuevas.Add((($e | ConvertTo-Json -Compress -Depth 4)))
}

foreach ($line in [IO.File]::ReadAllLines($inv.FullName)) {
    if ($line.Trim() -eq '') { continue }
    $o = $line | ConvertFrom-Json
    if (@($o.etiquetas) -notcontains 'Empleo') { continue }
    $cont.procesados++
    if ($MaxPosts -gt 0 -and $nuevas.Count -ge $MaxPosts) { break }

    $id = [string]$o.id
    if ($id -eq '') { $cont.sinId++; continue }
    if ($pendientesActuales.ContainsKey($id)) { $cont.yaPendiente++; continue }

    $html = [string]$o.contenido
    $titulo = [string]$o.titulo
    $fuenteUrl = [string]$o.fuente
    $archivo = [string]$o.archivoLocal
    $cambios = 0
    $motivos = @()

    # --- 1) categoria canonica -------------------------------------------
    $mCat = [regex]::Match($html, '(<div class="empleo-categoria">)([^<]*)(</div>)')
    if ($mCat.Success) {
        $catVieja = $mCat.Groups[2].Value.Trim()
        if (-not (Es-CategoriaCanonica $catVieja)) {
            $sinDiv = $html.Substring(0, $mCat.Index) + $mCat.Groups[1].Value + $mCat.Groups[3].Value + $html.Substring($mCat.Index + $mCat.Length)
            $catNueva = Obtener-CategoriaExacta $titulo (Texto-Visible $sinDiv)
            if ((Es-CategoriaCanonica $catNueva) -and ($catNueva -ne $catVieja)) {
                $html = $html.Substring(0, $mCat.Index) + $mCat.Groups[1].Value + $catNueva + $mCat.Groups[3].Value + $html.Substring($mCat.Index + $mCat.Length)
                $cambios++; $motivos += ('cat:' + $catVieja + '->' + $catNueva)
                $cont.cat++
            }
        }
    }

    # --- 2) ubicacion / ciudad desde fuentes -----------------------------
    $ubi = Campo $html 'Ubicación'
    $ciu = Campo $html 'Ciudad'
    $ubiVacia = ($ubi -eq '' -or $ubi -match '^(No especificado|No especificada)$')
    $ciuVacia = ($ciu -eq '' -or $ciu -match '^No especificad')

    if ($ubiVacia -or $ciuVacia) {
        $fu = Leer-Fuente (Resolver-Fuente $archivo $fuenteUrl)
        if ($fu.ok) {
            if ($ubiVacia) {
                $nuevoUbi = ''
                if ($fu.UBICACION -ne '' -and -not ($fu.UBICACION -match '^(No especificado|No especificada)$')) { $nuevoUbi = $fu.UBICACION }
                elseif ($fu.CIUDAD -ne '' -and -not ($fu.CIUDAD -match '^No especificad')) {
                    $nuevoUbi = $fu.CIUDAD
                    if ($fu.REGION -ne '' -and (Nor $fu.REGION) -ne (Nor $fu.CIUDAD)) { $nuevoUbi += ', ' + $fu.REGION }
                }
                if ($nuevoUbi -ne '') {
                    if (Sin-Etiqueta $html 'Ubicación') { $cont.sinCampo++ }
                    else {
                        $html = Cambiar-Campo $html 'Ubicación' $nuevoUbi
                        $cambios++; $motivos += ('ub:' + $nuevoUbi)
                        $cont.ub++
                    }
                } else { $cont.sinFuente++ }
            }
            if ($ciuVacia -and $fu.CIUDAD -ne '' -and -not ($fu.CIUDAD -match '^No especificad')) {
                if (Sin-Etiqueta $html 'Ciudad') { $cont.sinCampo++ }
                else {
                    $html = Cambiar-Campo $html 'Ciudad' $fu.CIUDAD
                    $cambios++; $motivos += ('ciu:' + $fu.CIUDAD)
                    $cont.ciu++
                }
            }
        } else { $cont.sinFuente++ }
    }

    if ($cambios -eq 0) { $cont.sinCambio++; continue }
    Encolar $id $titulo ([string]$o.url) $html $motivos
}

# ------------------------------------------------------------------ salida
if ($nuevas.Count -gt 0) {
    [IO.File]::AppendAllLines($RutaCola, $nuevas, $utf8)
}

$fecha = Get-Date -Format 'yyyyMMdd'
$rep = Join-Path $DirRep ("reparacion-fasea-{0}.txt" -f $fecha)
$lines = @(
    'PREPARACION REPARACION FASE A - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'),
    'inventario: ' + $inv.Name,
    'procesados (Empleo): ' + $cont.procesados,
    'encolados: ' + $nuevas.Count,
    '  categoria corregida : ' + $cont.cat,
    '  ubicacion rellenada : ' + $cont.ub,
    '  ciudad rellenada    : ' + $cont.ciu,
    'omitidos:',
    '  sin id              : ' + $cont.sinId,
    '  ya pendiente en cola: ' + $cont.yaPendiente,
    '  sin fuente local    : ' + $cont.sinFuente,
    '  campo ausente en el : ' + $cont.sinCampo,
    '  sin cambio posible  : ' + $cont.sinCambio,
    '',
    'cola: ' + $RutaCola,
    'respaldo: ' + $bak
)
[IO.File]::WriteAllLines($rep, [string[]]$lines, $utf8)

Write-Host ''
Write-Host '== RESUMEN PREPARACION FASE A =='
foreach ($l in $lines) { Write-Host ('  ' + $l) }
Write-Host ('reporte: ' + $rep)
exit 0
