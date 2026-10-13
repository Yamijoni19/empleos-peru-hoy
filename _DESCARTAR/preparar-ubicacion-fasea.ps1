# preparar-ubicacion-fasea.ps1 - SOLO LECTURA de Blogger (escribe en la cola local).
# Onda 2 de reparacion: repara Ubicacion y Ciudad de posts Empleo.
#   1) valor desde fuentes\*.txt (UBICACION/CIUDAD/REGION)      -> fuente
#   2) si no hay fuente, se infiere del titulo de la entidad
#      (departamento/ciudad en la parte antes del ':')          -> entidad
#   3) si la etiqueta <strong>Ubicacion/Ciudad:</strong> falta,
#      se INSERTA el parrafo antes de Salario (plantilla minima)
# Re-aplica tambien la categoria canonica (el inventario quedo viejo
# tras la onda 1) para que el PUT no revierta esas correcciones.
# Nada se escribe en Blogger aqui. Aplicar con:
#   .\aplicar-correcciones.ps1                (simulacion)
#   .\aplicar-correcciones.ps1 -Aplicar       (escrituras reales, con caps)
#
# Salida: entradas nuevas en datos\publicados\cola-correcciones.jsonl
#         reporte\ubicacion-fasea-<fecha>.txt (resumen)

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$MaxPosts = 0
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
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

# ------------------------------------------------------- mapas del tema
Write-Host 'leyendo mapas del tema...'
$listaDep = @(); $listaCiudad = @(); $mapCiudad = @{}
try {
    $tt = [IO.File]::ReadAllText((Join-Path $BaseDir 'Bloque-Tema-Blogger.txt'), [Text.Encoding]::UTF8)
    $mD = [regex]::Match($tt, '(?s)var departamentosPeru = \[(.*?)\];')
    if ($mD.Success) { $listaDep = @([regex]::Matches($mD.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }
    $mC = [regex]::Match($tt, '(?s)var ciudadesPeru = \[(.*?)\];')
    if ($mC.Success) { $listaCiudad = @([regex]::Matches($mC.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }
    $mM = [regex]::Match($tt, '(?s)var ciudadADepartamento = \{(.*?)\};')
    if ($mM.Success) {
        foreach ($kv in [regex]::Matches($mM.Groups[1].Value, '"([^"]+)"\s*:\s*"([^"]+)"')) {
            $mapCiudad[[string]$kv.Groups[1].Value] = [string]$kv.Groups[2].Value
        }
    }
} catch { Write-Host ('  AVISO: no se pudieron leer los mapas: ' + $_.Exception.Message) }
Write-Host ('  departamentos=' + $listaDep.Count + ' ciudades=' + $listaCiudad.Count + ' mapa=' + $mapCiudad.Count)

function Tiene-Frase([string]$textoNorm, [string]$frase) {
    $f = (Nor $frase)
    if ($f -eq '') { return $false }
    $e = [regex]::Escape($f)
    return [regex]::IsMatch($textoNorm, '(^|[^a-z0-9])' + $e + '([^a-z0-9]|$)')
}
function Inferir-Ubicacion([string]$titulo) {
    $pn = [string]$titulo
    $i = $pn.IndexOf(':')
    if ($i -gt 0) { $pn = $pn.Substring(0, $i) }
    foreach ($zona in @((Nor $pn), (Nor $titulo))) {
        if ($zona -eq '') { continue }
        foreach ($d in $listaDep) { if (Tiene-Frase $zona $d) { return @{ valor = ($d + ', Perú'); ciudad = '' } } }
        foreach ($c in $listaCiudad) { if (Tiene-Frase $zona $c) { return @{ valor = ($c + ', Perú'); ciudad = $c } } }
    }
    return $null
}

# --------------------------------------------------------------- fuentes
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
$cont = @{ cat=0; ubFte=0; ubEnt=0; ubIns=0; ciuFte=0; ciuEnt=0; ciuIns=0; sinValor=0; sinAncla=0; yaPendiente=0; sinId=0; sinCambio=0; procesados=0 }
$muestras = New-Object System.Collections.Generic.List[string]

function Encolar([string]$id, [string]$titulo, [string]$url, [string]$contenido, [string[]]$motivos) {
    $e = [ordered]@{
        id = $id
        url = $url
        titulo = $titulo
        accion = 'CORREGIR'
        contenidoNuevo = $contenido
        motivo = ('FASE-A-UB: ' + ($motivos -join ', '))
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
    $origUbi = ''; $nuevoUbi = ''

    # --- 1) categoria canonica (inventario viejo tras la onda 1) -------
    # se aplica EN SILENCIO al contenido nuevo: la onda 1 ya corrigio eso en
    # vivo; aqui solo evita que el PUT de ubicacion lo revierta.
    $mCat = [regex]::Match($html, '(<div class="empleo-categoria">)([^<]*)(</div>)')
    if ($mCat.Success) {
        $catVieja = $mCat.Groups[2].Value.Trim()
        if (-not (Es-CategoriaCanonica $catVieja)) {
            $sinDiv = $html.Substring(0, $mCat.Index) + $mCat.Groups[1].Value + $mCat.Groups[3].Value + $html.Substring($mCat.Index + $mCat.Length)
            $catNueva = Obtener-CategoriaExacta $titulo (Texto-Visible $sinDiv)
            if ((Es-CategoriaCanonica $catNueva) -and ($catNueva -ne $catVieja)) {
                $html = $html.Substring(0, $mCat.Index) + $mCat.Groups[1].Value + $catNueva + $mCat.Groups[3].Value + $html.Substring($mCat.Index + $mCat.Length)
            }
        }
    }

    # --- 2) ubicacion / ciudad: fuente > entidad -----------------------
    $ubi = Campo $html 'Ubicación'
    $ciu = Campo $html 'Ciudad'
    $ubiVacia = ($ubi -eq '' -or $ubi -match '^(No especificado|No especificada)$')
    $ciuVacia = ($ciu -eq '' -or $ciu -match '^No especificad')

    if ($ubiVacia -or $ciuVacia) {
        $fu = Leer-Fuente (Resolver-Fuente $archivo $fuenteUrl)
        $nuevoUbi = ''; $origUbi = ''
        $nuevoCiu = ''; $origCiu = ''

        if ($fu.ok) {
            if ($fu.UBICACION -ne '' -and -not ($fu.UBICACION -match '^(No especificado|No especificada)$')) { $nuevoUbi = $fu.UBICACION; $origUbi = 'fuente' }
            elseif ($fu.CIUDAD -ne '' -and -not ($fu.CIUDAD -match '^No especificad')) {
                $nuevoUbi = $fu.CIUDAD
                if ($fu.REGION -ne '' -and (Nor $fu.REGION) -ne (Nor $fu.CIUDAD)) { $nuevoUbi += ', ' + $fu.REGION }
                $origUbi = 'fuente'
            }
            if ($fu.CIUDAD -ne '' -and -not ($fu.CIUDAD -match '^No especificad')) { $nuevoCiu = $fu.CIUDAD; $origCiu = 'fuente' }
        }
        if ($nuevoUbi -eq '' -or ($ciuVacia -and $nuevoCiu -eq '')) {
            $inf = Inferir-Ubicacion $titulo
            if ($null -ne $inf) {
                if ($nuevoUbi -eq '') { $nuevoUbi = $inf.valor; $origUbi = 'entidad' }
                if ($ciuVacia -and $nuevoCiu -eq '' -and $inf.ciudad -ne '') { $nuevoCiu = $inf.ciudad; $origCiu = 'entidad' }
            }
        }

        $parrafos = New-Object System.Collections.Generic.List[string]
        if ($ubiVacia -and $nuevoUbi -ne '') {
            if (Sin-Etiqueta $html 'Ubicación') {
                $parrafos.Add('<p><strong>Ubicación:</strong> ' + $nuevoUbi + '</p>')
                $cont.ubIns++
            } else {
                $html = Cambiar-Campo $html 'Ubicación' $nuevoUbi
                $cambios++; $motivos += ('ub-' + $origUbi + ':' + $nuevoUbi)
                if ($origUbi -eq 'fuente') { $cont.ubFte++ } else { $cont.ubEnt++ }
            }
        }
        if ($ciuVacia -and $nuevoCiu -ne '') {
            if (Sin-Etiqueta $html 'Ciudad') {
                $parrafos.Add('<p><strong>Ciudad:</strong> ' + $nuevoCiu + '</p>')
                $cont.ciuIns++
            } else {
                $html = Cambiar-Campo $html 'Ciudad' $nuevoCiu
                $cambios++; $motivos += ('ciu-' + $origCiu + ':' + $nuevoCiu)
                if ($origCiu -eq 'fuente') { $cont.ciuFte++ } else { $cont.ciuEnt++ }
            }
        }

        if ($parrafos.Count -gt 0) {
            # orden de la plantilla: Ubicacion, Ciudad, ... Salario
            $html2 = ''
            $iAncla = $html.IndexOf('<p><strong>Salario:</strong>')
            if ($iAncla -lt 0) { $iAncla = $html.IndexOf('<p><strong>Fecha publicaci') }
            if ($iAncla -lt 0) { $iAncla = $html.IndexOf('<p><strong>Tipo contratante:</strong>') }
            if ($iAncla -ge 0) {
                $bloque = ($parrafos -join "`n    ")
                $html2 = $html.Substring(0, $iAncla) + $bloque + "`n    " + $html.Substring($iAncla)
            } elseif ($parrafos.Count -eq 1 -and $parrafos[0].IndexOf('Ciudad:') -ge 0) {
                # solo Ciudad y ya existe el parrafo de Ubicacion: insertar tras el
                $mU = [regex]::Match($html, '<p><strong>Ubicación:</strong>[^<]*</p>')
                if ($mU.Success) { $html2 = $html.Substring(0, $mU.Index + $mU.Length) + "`n    " + $parrafos[0] + $html.Substring($mU.Index + $mU.Length) }
            }
            if ($html2 -ne '') { $html = $html2; $cambios++; $motivos += ('ins:' + ($parrafos.Count)) }
            else { $cont.sinAncla++ }
        }

        if ($nuevoUbi -eq '' -and $nuevoCiu -eq '') { $cont.sinValor++ }
    }

    if ($cambios -eq 0) { $cont.sinCambio++; continue }
    Encolar $id $titulo ([string]$o.url) $html $motivos
    if ($origUbi -eq 'entidad' -and $muestras.Count -lt 12) {
        $muestras.Add(($titulo.Substring(0, [Math]::Min(55, $titulo.Length)) + '  =>  ' + $nuevoUbi))
    }
}

# ------------------------------------------------------------------ salida
if ($nuevas.Count -gt 0) {
    [IO.File]::AppendAllLines($RutaCola, $nuevas, $utf8)
}

$fecha = Get-Date -Format 'yyyyMMdd'
$rep = Join-Path $DirRep ("ubicacion-fasea-{0}.txt" -f $fecha)
$lines = @(
    'PREPARACION UBICACION FASE A - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'),
    'inventario: ' + $inv.Name,
    'procesados (Empleo): ' + $cont.procesados,
    'encolados: ' + $nuevas.Count,
    '  ubicacion rellenada (fuente)  : ' + $cont.ubFte,
    '  ubicacion rellenada (entidad) : ' + $cont.ubEnt,
    '  ubicacion INSERTADA           : ' + $cont.ubIns,
    '  ciudad rellenada (fuente)     : ' + $cont.ciuFte,
    '  ciudad rellenada (entidad)    : ' + $cont.ciuEnt,
    '  ciudad INSERTADA              : ' + $cont.ciuIns,
    '  categoria re-canonica         : ' + $cont.cat,
    'omitidos:',
    '  sin id              : ' + $cont.sinId,
    '  ya pendiente en cola: ' + $cont.yaPendiente,
    '  sin valor posible   : ' + $cont.sinValor,
    '  sin ancla de insertar: ' + $cont.sinAncla,
    '  sin cambio posible  : ' + $cont.sinCambio,
    '',
    'muestra de relleno por entidad (titulo => valor):'
) + @($muestras) + @(
    '',
    'cola: ' + $RutaCola,
    'respaldo: ' + $bak
)
[IO.File]::WriteAllLines($rep, [string[]]$lines, $utf8)

Write-Host ''
Write-Host '== RESUMEN UBICACION FASE A =='
foreach ($l in $lines) { Write-Host ('  ' + $l) }
Write-Host ('reporte: ' + $rep)
exit 0
