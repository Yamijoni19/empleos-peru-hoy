# diagnostico-publicados-fasea.ps1 - SOLO LECTURA.
# Cruza el inventario de posts publicados con las fuentes locales y simula la
# logica actual del tema (detectarDepartamento + clasificarTipoContratoEstado)
# para medir los errores reportados: ubicacion no especificada, departamento
# mal detectado (Ica y otros), tipo de contrato CAS/728/practicas y categoria
# no canonica.
#
# Salida: reporte\diagnostico-fasea-<fecha>.txt  (+ resumen en pantalla)
# NO escribe en Blogger ni modifica colas.

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $BaseDir 'lib\categoria.ps1')

$Tema     = Join-Path $BaseDir 'Bloque-Tema-Blogger.txt'
$Pub      = Join-Path $BaseDir 'publicaciones.txt'
$DirPub   = Join-Path $BaseDir 'datos\publicados'
$DirFue   = Join-Path $BaseDir 'fuentes'
$DirRep   = Join-Path $BaseDir 'reporte'
if (-not (Test-Path $DirRep)) { New-Item -ItemType Directory -Path $DirRep -Force | Out-Null }

# ---------------------------------------------------------------- tema (JS)
$tt = [IO.File]::ReadAllText($Tema, [Text.Encoding]::UTF8)
$mapCiudad = @{}
$mMap = [regex]::Match($tt, '(?s)var ciudadADepartamento\s*=\s*\{(.*?)\}')
foreach ($kv in [regex]::Matches($mMap.Groups[1].Value, '"([^"]+)"\s*:\s*"([^"]+)"')) {
    $mapCiudad[$kv.Groups[1].Value] = $kv.Groups[2].Value
}
$listaDep = @()
$mDep = [regex]::Match($tt, '(?s)var departamentosPeru\s*=\s*\[(.*?)\]')
foreach ($s in [regex]::Matches($mDep.Groups[1].Value, '"([^"]+)"')) { $listaDep += $s.Groups[1].Value }
Write-Host ("mapa ciudades=" + $mapCiudad.Count + " departamentos=" + $listaDep.Count)

function Nor([string]$s) {
    $x = [string]$s
    $x = $x.ToLowerInvariant()
    $x = $x.Normalize([Text.NormalizationForm]::FormD)
    $x = [regex]::Replace($x, '[\u0300-\u036f]', '')
    $x = [regex]::Replace($x, '\s+', ' ')
    return $x.Trim()
}

# detectarDepartamento TAL CUAL como el tema hoy (indexOf = subcadena)
function Dept-Actual([string]$ubi, [string]$ciu) {
    $texto = Nor $ubi; $ciudadNorm = Nor $ciu
    if ($mapCiudad.ContainsKey($ciudadNorm)) { return $mapCiudad[$ciudadNorm] }
    foreach ($d in $listaDep) { if ($ciudadNorm -eq (Nor $d)) { return $d } }
    foreach ($d in $listaDep) { if ($texto.IndexOf((Nor $d)) -ne -1) { return $d } }
    $f = $mapCiudad[$ciudadNorm]
    if ($f -and $texto.IndexOf((Nor $f)) -ne -1) { return $f }
    return 'No especificado'
}

# version corregida: coincidencia por palabra exacta en la ubicacion
function Dept-Corregido([string]$ubi, [string]$ciu) {
    $texto = Nor $ubi; $ciudadNorm = Nor $ciu
    if ($mapCiudad.ContainsKey($ciudadNorm)) { return $mapCiudad[$ciudadNorm] }
    foreach ($d in $listaDep) { if ($ciudadNorm -eq (Nor $d)) { return $d } }
    $toks = @(($texto -split '[^a-z0-9]+') | Where-Object { $_ -ne '' })
    foreach ($d in $listaDep) {
        if ($toks -contains (Nor $d)) { return $d }
    }
    $f = $mapCiudad[$ciudadNorm]
    if ($f -and ($toks -contains (Nor $f))) { return $f }
    return 'No especificado'
}

# clasificarTipoContratoEstado TAL CUAL como el tema hoy
function Clasif-Contrato([string]$valor) {
    $n = Nor $valor
    if (-not $n -or $n.StartsWith('no espec') -or $n -eq 'no aplica') { return 'No especificado' }
    if ($n.IndexOf('practic') -ne -1 -or $n.IndexOf('pasant') -ne -1) { return 'Practicas' }
    if ($n -match '\bcas\b' -or $n.IndexOf('contrato administrativo') -ne -1) { return 'CAS' }
    if ($n.IndexOf('728') -ne -1) { return '728' }
    if ($n.IndexOf('276') -ne -1) { return '276' }
    if ($n.IndexOf('servicio civil') -ne -1) { return 'Servicio Civil' }
    if ($n.IndexOf('locacion') -ne -1) { return 'Locacion' }
    if ($n.IndexOf('consultoria') -ne -1) { return 'Consultoria' }
    return 'Otro'
}

# ---------------------------------------------------------------- fuentes
function NUrl([string]$u) {
    $x = ([string]$u).Trim().ToLowerInvariant()
    $x = $x -replace '^https?://', ''
    $x = $x -replace '^www\.', ''
    return $x.TrimEnd('/')
}

$mapUrlFuentes = @{}   # url normalizada -> archivo fuente
foreach ($f in (Get-ChildItem (Join-Path $DirFue '*.txt'))) {
    $u = [IO.File]::ReadLines($f.FullName) | Select-Object -First 1
    if ($u -like 'URL: *') {
        $k = NUrl ($u.Substring(5))
        if ($k -ne '' -and -not $mapUrlFuentes.ContainsKey($k)) { $mapUrlFuentes[$k] = $f.FullName }
    }
}
Write-Host ("fuentes indexadas: " + $mapUrlFuentes.Count)

function Leer-Fuente([string]$path) {
    $o = [pscustomobject]@{ CONTRATO=''; CIUDAD=''; REGION=''; UBICACION=''; TITULO=''; ok=$false }
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $o }
    foreach ($l in [IO.File]::ReadAllLines($path)) {
        if ($l -match '^CONTRATO:\s*(.*)$')   { $o.CONTRATO = $Matches[1].Trim() }
        elseif ($l -match '^CIUDAD:\s*(.*)$')   { $o.CIUDAD   = $Matches[1].Trim() }
        elseif ($l -match '^REGION:\s*(.*)$')   { $o.REGION   = $Matches[1].Trim() }
        elseif ($l -match '^UBICACION:\s*(.*)$'){ $o.UBICACION= $Matches[1].Trim() }
        elseif ($l -match '^TITULO:\s*(.*)$')   { $o.TITULO   = $Matches[1].Trim() }
    }
    $o.ok = $true
    return $o
}

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

function Campo([string]$html, [string]$etiqueta) {
    $m = [regex]::Match($html, '<strong>' + [regex]::Escape($etiqueta) + ':\s*</strong>\s*([^<]*)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

# ---------------------------------------------------------------- inventario
$inv = Get-ChildItem (Join-Path $DirPub 'inventario-*.jsonl') | Sort-Object Name -Descending | Select-Object -First 1
Write-Host ("inventario: " + $inv.Name)

$est = @{ UB_VACIA=0; UB_VACIA_SIN_FUENTE=0; UB_DIFIERE_FUENTE=0; CIU_VACIA=0; CIUDAD_RARA=0; REGION_RARA=0; DEPT_MISMATCH=0; CT_VACIO_POST=0; CT_DIFIERE_FUENTE=0; CT_PRAC=0; CT_BAJA_CAS=0 }
$cat = @{ ESTADO=0; BUMERAN=0; OTRO=0 }
$ej = @{}; foreach ($k in (@($est.Keys) + @($cat.Keys | ForEach-Object { 'CAT_' + $_ }))) { $ej[$k] = New-Object System.Collections.Generic.List[string] }
$tot = 0; $nEmpleo = 0; $nEstado = 0; $nFuenteOk = 0

function Ejemp([string]$k, [string]$s) {
    if (-not $ej.ContainsKey($k)) { $ej[$k] = New-Object System.Collections.Generic.List[string] }
    if ($ej[$k].Count -lt 5) { $ej[$k].Add($s) }
}

foreach ($line in [IO.File]::ReadAllLines($inv.FullName)) {
    if ($line.Trim() -eq '') { continue }
    $o = $line | ConvertFrom-Json
    $tot++
    if (@($o.etiquetas) -notcontains 'Empleo') { continue }
    $nEmpleo++
    $archivo = [string]$o.archivoLocal
    $fuenteUrl = [string]$o.fuente
    $html = [string]$o.contenido

    $portal = 'ESTADO'
    if ($archivo -like 'bum-*' -or $fuenteUrl -like '*bumeran.com.pe*') { $portal = 'BUMERAN' }
    elseif ($fuenteUrl -like '*buscojobs*' -or $fuenteUrl -like '*computrabajo*' -or $fuenteUrl -like '*infojobs*') { $portal = 'OTRO' }

    # categoria canonica
    $mCat = [regex]::Match($html, '<div class="empleo-categoria">([^<]*)</div>')
    $catVal = if ($mCat.Success) { $mCat.Groups[1].Value.Trim() } else { '(sin div)' }
    if (-not (Es-CategoriaCanonica $catVal)) {
        $cat[$portal]++
        Ejemp ('CAT_' + $portal) ("[" + $catVal + "] " + [string]$o.titulo)
    }

    if ($portal -ne 'ESTADO') { continue }
    $nEstado++

    $ubi   = Campo $html 'Ubicación'
    $ciu   = Campo $html 'Ciudad'
    $ctRaw = Campo $html 'Tipo de contrato Estado'
    $ctFb  = Campo $html 'Contrato'
    $fu    = Leer-Fuente (Resolver-Fuente $archivo $fuenteUrl)
    if ($fu.ok) { $nFuenteOk++ }

    # ubicacion
    if ($ubi -eq '' -or $ubi -match '^(No especificado|No especificada)$') {
        $est.UB_VACIA++
        if ($fu.ok -and ($fu.UBICACION -ne '' -or $fu.CIUDAD -ne '')) { }
        else { $est.UB_VACIA_SIN_FUENTE++ }
        Ejemp 'UB_VACIA' ([string]$o.titulo + ' | post=[' + $ubi + '] fuente=[' + $fu.UBICACION + ']')
    } elseif ($fu.ok -and $fu.UBICACION -ne '' -and (Nor $ubi) -ne (Nor $fu.UBICACION)) {
        $est.UB_DIFIERE_FUENTE++
        Ejemp 'UB_DIFIERE_FUENTE' ([string]$o.titulo + ' | post=[' + $ubi + '] fuente=[' + $fu.UBICACION + ']')
    }

    # ciudad
    if ($ciu -eq '' -or $ciu -match '^No especificad') {
        $est.CIU_VACIA++
        Ejemp 'CIU_VACIA' ([string]$o.titulo + ' | ubi=[' + $ubi + '] fuenteCIUDAD=[' + $fu.CIUDAD + ']')
    }
    if ($fu.ok) {
        $r = Nor $fu.REGION; $c = Nor $fu.CIUDAD
        $esDep = $false; foreach ($d in $listaDep) { if ((Nor $d) -eq $r) { $esDep = $true; break } }
        if ($r -ne '' -and (-not $esDep) -and $mapCiudad.ContainsKey($r)) { $est.REGION_RARA++; Ejemp 'REGION_RARA' ([string]$o.titulo + ' | REGION=' + $fu.REGION + ' CIUDAD=' + $fu.CIUDAD) }
        $esDepC = $false; foreach ($d in $listaDep) { if ((Nor $d) -eq $c) { $esDepC = $true; break } }
        if ($c -ne '' -and $esDepC) { $est.CIUDAD_RARA++; Ejemp 'CIUDAD_RARA' ([string]$o.titulo + ' | REGION=' + $fu.REGION + ' CIUDAD=' + $fu.CIUDAD) }
    }

    # departamento: actual vs corregido
    $dA = Dept-Actual $ubi $ciu
    $dC = Dept-Corregido $ubi $ciu
    if ($dA -ne $dC) {
        $est.DEPT_MISMATCH++
        Ejemp 'DEPT_MISMATCH' ([string]$o.titulo + ' | ubi=[' + $ubi + '] ciu=[' + $ciu + '] actual=' + $dA + ' corregido=' + $dC)
    }

    # contrato
    $useRaw = $ctRaw; if ($useRaw -eq '') { $useRaw = $ctFb; if ($useRaw -ne '') { $est.CT_VACIO_POST++; Ejemp 'CT_VACIO_POST' ([string]$o.titulo + ' | tipoEstado vacio; usa Contrato=[' + $ctFb + ']') } }
    $cPost = Clasif-Contrato $useRaw
    if ($cPost -eq 'Practicas') { $est.CT_PRAC++; Ejemp 'CT_PRAC' ([string]$o.titulo + ' | TipoEstado=[' + $ctRaw + '] Contrato=[' + $ctFb + ']') }
    if ($cPost -eq 'Practicas' -and (Nor $ctFb) -match 'cas|728') { $est.CT_BAJA_CAS++; Ejemp 'CT_BAJA_CAS' ([string]$o.titulo + ' | TipoEstado=[' + $ctRaw + '] Contrato=[' + $ctFb + ']') }
    if ($fu.ok -and $fu.CONTRATO -ne '') {
        $cFu = Clasif-Contrato $fu.CONTRATO
        if ($cPost -ne $cFu -and -not ($cPost -eq 'Otro' -and $cFu -eq 'Otro')) {
            $est.CT_DIFIERE_FUENTE++
            Ejemp 'CT_DIFIERE_FUENTE' ([string]$o.titulo + ' | post=' + $cPost + ' ([' + $useRaw + ']) fuente=' + $cFu + ' ([' + $fu.CONTRATO + '])')
        }
    }
}

# ---------------------------------------------------------------- reporte
$fecha = Get-Date -Format 'yyyyMMdd'
$rep = Join-Path $DirRep ("diagnostico-fasea-{0}.txt" -f $fecha)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('DIAGNOSTICO FASE A - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$lines.Add('posts inventariados: ' + $tot + ' | empleo: ' + $nEmpleo + ' | estado: ' + $nEstado + ' | con fuente resuelta: ' + $nFuenteOk)
$lines.Add('')
$lines.Add('== ESTADO ==')
foreach ($k in ($est.Keys | Sort-Object)) { $lines.Add(('  {0,-22} {1}' -f $k, $est[$k])) }
$lines.Add('')
$lines.Add('== CATEGORIA NO CANONICA ==')
foreach ($k in ($cat.Keys | Sort-Object)) { $lines.Add(('  {0,-22} {1}' -f $k, $cat[$k])) }
$lines.Add('')
$lines.Add('== EJEMPLOS ==')
foreach ($k in ($ej.Keys | Sort-Object)) {
    if ($ej[$k].Count -gt 0) {
        $lines.Add('  [' + $k + ']')
        foreach ($s in $ej[$k]) { $lines.Add('    - ' + $s) }
    }
}
[IO.File]::WriteAllLines($rep, [string[]]$lines, $utf8)

Write-Host ''
Write-Host '== RESUMEN DIAGNOSTICO FASE A =='
Write-Host ('  posts inventariados: ' + $tot + ' | empleo: ' + $nEmpleo + ' | estado: ' + $nEstado + ' | con fuente: ' + $nFuenteOk)
foreach ($k in ($est.Keys | Sort-Object)) { Write-Host ('  ' + $k.PadRight(22) + $est[$k]) }
Write-Host '  -- categoria no canonica --'
foreach ($k in ($cat.Keys | Sort-Object)) { Write-Host ('  ' + $k.PadRight(22) + $cat[$k]) }
Write-Host ('reporte: ' + $rep)
exit 0
