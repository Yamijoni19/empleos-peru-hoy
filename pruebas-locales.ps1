# pruebas-locales.ps1 - BATERIA DE PRUEBAS LOCALES (sin escrituras reales).
#
# USO:
#   .\pruebas-locales.ps1              # todas
#   .\pruebas-locales.ps1 -Rapidas     # omite las que usan red (blogger/feed)
#
# Reglas de la bateria:
#   - NUNCA hace POST/PUT/PATCH/DELETE contra Blogger.
#   - NO modifica publicaciones.txt, historico-bloqueado.txt ni los XML.
#   - Las pruebas que tocan archivos usan carpetas temporales o respaldan/restauran.
#   - Sale con 0 si todo pasa, 1 si algo falla.

param(
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [switch]$Rapidas
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:OK = 0; $script:FAL = 0; $script:Bloque = ''

function Bloque([string]$n) { $script:Bloque = $n; Write-Host ""; Write-Host ("-- " + $n) -ForegroundColor Cyan }
function Pass([string]$n) { $script:OK++; Write-Host ("  [PASS] " + $n) -ForegroundColor Green }
function Fail([string]$n, [string]$d) { $script:FAL++; Write-Host ("  [FAIL] " + $n + " -> " + $d) -ForegroundColor Red }
function Check([string]$n, [bool]$c, [string]$d = '') { if ($c) { Pass $n } else { Fail $n $d } }
function Run([string]$file, [string[]]$arg = @()) {
    $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $file @arg 2>&1
    return @{ Codigo = $LASTEXITCODE; Texto = (($o | ForEach-Object { $_.ToString() }) -join "`n") }
}
function Temp([string]$n) {
    $d = Join-Path $env:TEMP ("empleos-prueba-" + $n)
    if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
}
function Hash([string]$p) { if (Test-Path $p) { return (Get-FileHash $p -Algorithm SHA256).Hash } return '(no existe)' }

$RutaPub   = Join-Path $BaseDir 'publicaciones.txt'
$HashPub   = Hash $RutaPub

$Git = $null
$gc = Get-Command git -ErrorAction SilentlyContinue
if ($gc) { $Git = $gc.Source } else {
    foreach ($cand in @("$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")) {
        if (Test-Path $cand) { $Git = $cand; break }
    }
}
Write-Host ("PRUEBAS LOCALES - " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ("  base: " + $BaseDir)
if ($Rapidas) { Write-Host "  modo: RAPIDAS (sin red)" }

# =============================================================== T01 sintaxis
Bloque 'T01 sintaxis y BOM'
$ps1 = @(Get-ChildItem $BaseDir -Filter '*.ps1' -File) + @(Get-ChildItem (Join-Path $BaseDir 'lib') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$malos = @(); $sinBom = @()
foreach ($f in $ps1) {
    $errs = $null; $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$toks, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) { $malos += ($f.Name + ": " + $errs[0].Message) }
    $b = [IO.File]::ReadAllBytes($f.FullName)
    if ($b.Length -lt 3 -or $b[0] -ne 0xEF -or $b[1] -ne 0xBB -or $b[2] -ne 0xBF) { $sinBom += $f.Name }
}
Check ("todos los .ps1 parsean (" + $ps1.Count + " archivos)") ($malos.Count -eq 0) ($malos -join ' | ')
Check 'todos los .ps1 tienen BOM UTF-8' ($sinBom.Count -eq 0) ($sinBom -join ', ')

# =============================================================== T02 config
Bloque 'T02 configuracion central'
$RutaCfg = Join-Path $BaseDir 'config\publicacion.json'
Check 'existe config\publicacion.json' (Test-Path $RutaCfg) $RutaCfg
$cfg = Get-Content $RutaCfg -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($k in @('modo', 'maxPorCorrida', 'topeAbsoluto', 'frecuenciaScheduler', 'permitirBackfill', 'publicacion', 'backfill', 'cooldown429', 'scheduler', 'cola', 'anomalia', 'correcciones')) {
    Check ("llave '" + $k + "' presente") ($null -ne $cfg.PSObject.Properties[$k]) ''
}
Check 'publicacion.activada = false (por defecto)' ([bool]$cfg.publicacion.activada -eq $false) ("valor: " + $cfg.publicacion.activada)
Check 'correcciones.activadas = false (por defecto)' ([bool]$cfg.correcciones.activadas -eq $false) ("valor: " + $cfg.correcciones.activadas)
Check 'topeAbsoluto > 0' ([int]$cfg.topeAbsoluto -gt 0) ''
Check 'cooldown429.minutos >= 60' ([int]$cfg.cooldown429.minutos -ge 60) ''
Check 'no existe config\ejecucion.json (modo unico)' (-not (Test-Path (Join-Path $BaseDir 'config\ejecucion.json'))) ''

# =============================================================== T03 gate
Bloque 'T03 gate: publicacion desactivada = 0 escrituras'
$r = Run (Join-Path $BaseDir 'publicar-blogger.ps1')
Check 'sale con 0 y anuncia PUBLICACION DESACTIVADA' ($r.Codigo -eq 0 -and $r.Texto -match 'PUBLICACION DESACTIVADA') ("codigo=" + $r.Codigo)
Check 'publicaciones.txt intacto' ((Hash $RutaPub) -eq $HashPub) ''
Check 'sin POST/PUT/PATCH/DELETE reales en la salida' ($r.Texto -notmatch '(?i)\b(POST|PUT|PATCH|DELETE)\b.+\b(200|created|updated)') ''

# =============================================================== T04 simulador
Bloque 'T04 simulador Blogger (0 POST reales)'
if ($Rapidas) { Pass 'omitida con -Rapidas' } else {
    $r = Run (Join-Path $BaseDir 'publicar-blogger.ps1') @('-Simular', '-Ultimas', '3')
    Check 'simulacion sale 0' ($r.Codigo -eq 0) ("codigo=" + $r.Codigo)
    Check 'la salida dice SIMULACION y 0 POST reales' ($r.Texto -match 'SIMULACION' -and $r.Texto -match '0 POST reales') ($r.Texto.Substring([Math]::Max(0, $r.Texto.Length - 300)))
    Check 'publicaciones.txt intacto' ((Hash $RutaPub) -eq $HashPub) ''
    Check 'cola-actual.json marca simulacion (publicadas=0)' ((Get-Content (Join-Path $BaseDir 'datos\cola\cola-actual.json') -Raw -Encoding UTF8) -match '"publicadas"\s*:\s*0') ''
}

# =============================================================== T05 colas reales
Bloque 'T05 estado de las colas reales'
$hist = @(Get-Content (Join-Path $BaseDir 'datos\cola\historico-bloqueado.txt') -Encoding UTF8 | Where-Object { $_.Trim() })
Check ('baseline historico = 4.114 (' + $hist.Count + ')') ($hist.Count -eq 4114) ("obtenido " + $hist.Count)
$pub = @(Get-Content $RutaPub -Encoding UTF8 | Where-Object { $_.Trim() })
Check ('publicaciones.txt = 4.233 lineas (' + $pub.Count + ')') ($pub.Count -eq 4233) ("obtenido " + $pub.Count)
$cola = @(Get-Content (Join-Path $BaseDir 'datos\cola\cola-comun.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
Check ('cola comun >= 4.138 (' + $cola.Count + ')') ($cola.Count -ge 4138) ("obtenido " + $cola.Count)
$dup = @($cola | Where-Object { [string]$_.estadoPublicacion -eq 'DUP' })
Check 'sin estado DUP encolado' ($dup.Count -eq 0) ($dup.Count.ToString())
$bum = @($cola | Where-Object { [string]$_.fuente -eq 'bumeran' })
Check ('bumeran privado = solo bumeran (' + $bum.Count + ')') ($bum.Count -ge 20) ($bum.Count.ToString())
Check 'ningun estado desconocido' (@($cola | Where-Object { [string]$_.estadoPublicacion -notin @('HISTORICA', 'NUEVA', 'EXPIRADA', 'PUBLICADA', 'ACTUALIZADA', 'CORRECCION', 'SIMULADA', 'DIFERIDA') }).Count -eq 0) ''

# =============================================================== T06 salario
Bloque 'T06 lib\salario.ps1 (extraccion de salario)'
. (Join-Path $BaseDir 'lib\salario.ps1')
$s1 = Extraer-Salario '' '' 'Operario de produccion' ''
Check 'sin datos -> No especificado' ($s1.especificado -eq $false -and $s1.texto_original -eq 'No especificado') ($s1.texto_original)
$s2 = Extraer-Salario '' '<strong>Salario:</strong> S/ 1,450' 'Auxiliar' ''
Check 'label Salario con monto -> 1450' ($s2.especificado -and $s2.min -eq 1450 -and $s2.max -eq 1450) ("min=" + $s2.min)
$s3 = Extraer-Salario '' '<strong>Salario:</strong> S/ 2,500' 'Operario - S/ 2,500 - S/ 3,500' ''
Check 'rango en el titulo -> 2500..3500' ($s3.especificado -and $s3.min -eq 2500 -and $s3.max -eq 3500 -and $s3.fuente_salario -eq 'rango') ("min=" + $s3.min + " max=" + $s3.max + " fuente=" + $s3.fuente_salario)
$s4 = Extraer-Salario '' '<strong>Salario:</strong> A convenir' 'Oferta' 'sin monto en ningun lado'
Check "'A convenir' sin monto -> No especificado" ($s4.texto_original -eq 'No especificado') ($s4.texto_original)
Check 'Convertir-Monto 1.450 -> 1450' ((Convertir-Monto 'S/ 1.450') -eq 1450) ''
Check 'Convertir-Monto basura -> null' ($null -eq (Convertir-Monto 'A convenir')) ''
Check 'Convertir-Monto 50 (muy bajo) -> null' ($null -eq (Convertir-Monto 'S/ 50')) ''
$m = @(Buscar-Montos 'sueldo desde S/ 1,800 hasta S/ 2,200')
Check 'Buscar-Montos encuentra los dos montos' ($m.Count -ge 2) ($m.Count.ToString())

# =============================================================== T07 validacion
Bloque 'T07 validar-entrada.ps1'
$salidas = @(Get-ChildItem (Join-Path $BaseDir 'salida') -Filter '*-entrada.html' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
if ($salidas.Count -ge 1) {
    $malas = @()
    foreach ($f in $salidas) {
        $r = Run (Join-Path $BaseDir 'validar-entrada.ps1') @('-Archivo', $f.FullName)
        if ($r.Codigo -ne 0) { $malas += ($f.Name + ': ' + (($r.Texto -split "`n" | Where-Object { $_ -match 'ERROR' } | Select-Object -First 1) -join '')) }
    }
    Check ('las ' + $salidas.Count + ' entradas recientes validan OK') ($malas.Count -eq 0) ($malas -join ' | ')
} else { Fail 'no hay entradas en salida\ para validar' '' }
$tdir = Temp 'validar'
$malo = Join-Path $tdir 'malo.html'
[IO.File]::WriteAllText($malo, '<div class="empleo-individual">quedan @@MARCADOR@@ sin rellenar</div>', $utf8)
$r2 = Run (Join-Path $BaseDir 'validar-entrada.ps1') @('-Archivo', $malo)
Check 'entrada con marcador sin rellenar -> exit 1' ($r2.Codigo -eq 1) ("codigo=" + $r2.Codigo)

# =============================================================== T08 dedup
Bloque 'T08 deduplicacion y estados (encolar -BaseDir sobre fixtures)'
$tdir = Temp 'encolar'
New-Item -ItemType Directory -Path (Join-Path $tdir 'salida') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tdir 'datos\cola') -Force | Out-Null
function New-Oferta([string]$ruta, [string]$titulo, [string]$url, [string]$cierre) {
    $h = @"
<html><head><title>x</title></head><body>
<!-- TITULO_BLOGGER = $titulo -->
<div class="empleo-empresa">Empresa SAC</div>
<strong>Fuente:</strong> $url
<strong>Fecha cierre:</strong> $cierre
</body></html>
"@
    [IO.File]::WriteAllText($ruta, $h, $utf8)
}
New-Oferta (Join-Path $tdir 'salida\ct-111111-entrada.html')   'Oferta uno'   'https://convocatoriasdetrabajo.com/oferta-uno.html' '2099-12-31'
New-Oferta (Join-Path $tdir 'salida\ct-222222-entrada.html')   'Oferta dos'   'https://convocatoriasdetrabajo.com/oferta-dos.html' '2020-01-01'
New-Oferta (Join-Path $tdir 'salida\oferta-de-empleo-id-abc123-entrada.html')        'Oferta tres' 'https://convocatoriasdetrabajo.com/oferta-tres.html' '2099-12-31'
New-Oferta (Join-Path $tdir 'salida\oferta-de-empleo-dup-id-abc123-entrada.html')    'Oferta tres (duplicada)' 'https://convocatoriasdetrabajo.com/oferta-tres-bis.html' '2099-12-31'
[IO.File]::WriteAllText((Join-Path $tdir 'datos\cola\historico-bloqueado.txt'), "ct-111111-entrada.html`r`n", $utf8)
$r = Run (Join-Path $BaseDir 'encolar-ofertas.ps1') @('-BaseDir', $tdir)
Check 'encolar sale 0' ($r.Codigo -eq 0) ("codigo=" + $r.Codigo)
Check 'detecta 1 duplicado de corrida' ($r.Texto -match 'duplicadas: 1') ($r.Texto)
$fc = Join-Path $tdir 'datos\cola\cola-comun.jsonl'
if (Test-Path $fc) {
    $fx = @(Get-Content $fc -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    Check 'la cola fixture tiene 3 ofertas (1 dup fuera)' ($fx.Count -eq 3) ($fx.Count.ToString())
    $est = @{}
    foreach ($e in $fx) { $est[[string]$e.estadoPublicacion] = $true }
    Check 'ct-111111 -> HISTORICA' ($est.ContainsKey('HISTORICA')) (($fx | ForEach-Object { $_.archivo + '=' + $_.estadoPublicacion }) -join ', ')
    Check 'ct-222222 (cierre 2020) -> EXPIRADA' ($est.ContainsKey('EXPIRADA')) ''
    Check 'oferta nueva -> NUEVA' ($est.ContainsKey('NUEVA')) ''
} else { Fail 'no se genero cola-comun.jsonl en el fixture' '' }

# =============================================================== T09 candados
Bloque 'T09 candados de aplicar-correcciones.ps1 (0 escrituras)'
function New-FixCorr([string]$nombre, [bool]$actPublic, [bool]$actCorr, [bool]$cooldown) {
    $d = Temp $nombre
    New-Item -ItemType Directory -Path (Join-Path $d 'config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $d 'datos\publicados') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $d 'datos\cola') -Force | Out-Null
    $c = @{ modo = 'local'; maxPorCorrida = 5; topeAbsoluto = 100
            publicacion = @{ activada = $actPublic }
            correcciones = @{ activadas = $actCorr; maxPorCorrida = 10; pausaMs = 10 }
            cooldown429 = @{ minutos = 240 } }
    [IO.File]::WriteAllText((Join-Path $d 'config\publicacion.json'), ($c | ConvertTo-Json -Depth 5), $utf8)
    $item = @{ id = '999000111'; accion = 'RETIRAR'; clase = 'D'; prioridad = 1; titulo = 'Oferta falsa'
               url = 'https://ejemplo.com/x'; archivoLocal = ''; motivo = 'prueba'
               idConservado = ''; tituloNuevo = ''; contenidoNuevo = ''; fechaEncolada = (Get-Date).ToString('o'); estado = 'PENDIENTE' }
    [IO.File]::WriteAllText((Join-Path $d 'datos\publicados\cola-correcciones.jsonl'), (($item | ConvertTo-Json -Compress) + "`r`n"), $utf8)
    if ($cooldown) {
        $h = @{ activo = $true; hasta = (Get-Date).AddMinutes(90).ToString('o'); motivo = 'prueba' }
        [IO.File]::WriteAllText((Join-Path $d 'datos\cola\cooldown-429.json'), ($h | ConvertTo-Json), $utf8)
    }
    return $d
}
$aplicar = Join-Path $BaseDir 'aplicar-correcciones.ps1'
$fA = New-FixCorr 'corr-activada-off' $false $false $false
$rA = Run $aplicar @('-Aplicar', '-BaseDir', $fA)
Check 'candado 1: publicacion.activada=false cancela' ($rA.Codigo -eq 0 -and $rA.Texto -match 'CANCELADO: publicacion\.activada') ("codigo=" + $rA.Codigo)
Check 'sin escrituras (registro no creado)' (-not (Test-Path (Join-Path $fA 'datos\publicados\registro-historico.txt'))) ''
$fB = New-FixCorr 'corr-correcciones-off' $true $false $false
$rB = Run $aplicar @('-Aplicar', '-BaseDir', $fB)
Check 'candado 2: correcciones.activadas=false cancela' ($rB.Codigo -eq 0 -and $rB.Texto -match 'CANCELADO: correcciones\.activadas') ("codigo=" + $rB.Codigo)
$fC = New-FixCorr 'corr-cooldown' $true $true $true
$rC = Run $aplicar @('-Aplicar', '-BaseDir', $fC)
Check 'candado 3: cooldown 429 activo cancela' ($rC.Codigo -eq 0 -and $rC.Texto -match 'CANCELADO: cooldown 429') ("codigo=" + $rC.Codigo)
Check 'cola de correcciones intacta tras candados' ((Get-Content (Join-Path $fA 'datos\publicados\cola-correcciones.jsonl') -Raw -Encoding UTF8) -match '"estado":"PENDIENTE"') ''

# =============================================================== T10 tope
Bloque 'T10 tope absoluto (maxPorCorrida nunca supera topeAbsoluto)'
$fD = New-FixCorr 'corr-tope' $false $false $false
$cj = Get-Content (Join-Path $fD 'config\publicacion.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cj.correcciones.maxPorCorrida = 500; $cj.topeAbsoluto = 100
[IO.File]::WriteAllText((Join-Path $fD 'config\publicacion.json'), ($cj | ConvertTo-Json -Depth 5), $utf8)
$rD = Run $aplicar @('-BaseDir', $fD)
Check 'la simulacion recorta a 100 (topeAbsoluto)' ($rD.Texto -match 'se procesarian hasta 100') ($rD.Texto)
Check 'y no intenta escribir' ($rD.Texto -match 'SIMULACION OK') ''

# =============================================================== T11 inspeccion
Bloque 'T11 inspeccion de posts publicados (cola preparada)'
$DirPub = Join-Path $BaseDir 'datos\publicados'
$inv = @(Get-ChildItem $DirPub -Filter 'inventario-*.jsonl' -ErrorAction SilentlyContinue)
Check 'existe inventario de respaldo' ($inv.Count -ge 1) ''
if ($inv.Count -ge 1) {
    $nInv = @([IO.File]::ReadAllLines(($inv | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName) | Where-Object { $_.Trim() }).Count
    Check ('inventario con posts completos (' + $nInv + ')') ($nInv -gt 2000) ($nInv.ToString())
}
$cc = Join-Path $DirPub 'cola-correcciones.jsonl'
Check 'existe cola-correcciones.jsonl' (Test-Path $cc) ''
if (Test-Path $cc) {
    $items = @(Get-Content $cc -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    $pend = @($items | Where-Object { [string]$_.estado -eq 'PENDIENTE' })
    Check ('cola con pendientes (' + $pend.Count + ')') ($pend.Count -gt 0 -and $pend.Count -lt 200) ($pend.Count.ToString())
    Check 'nada aplicado todavia (sin estado HECHA/RETIRADA)' (@($items | Where-Object { [string]$_.estado -in @('RETIRADA', 'CORREGIDA') }).Count -eq 0) ''
    $acc = @($pend | Group-Object accion | ForEach-Object { $_.Name + '=' + $_.Count })
    Check ('acciones razonables: ' + ($acc -join ', ')) (@($pend | Where-Object { [string]$_.accion -notin @('RETIRAR', 'CORREGIR') }).Count -eq 0) ''
    Check 'RETIRAR no masivo (< 100)' (@($pend | Where-Object { [string]$_.accion -eq 'RETIRAR' }).Count -lt 100) ''
}
$cl = @(Get-ChildItem $DirPub -Filter 'clasificacion-*.jsonl' -ErrorAction SilentlyContinue)
Check 'existe clasificacion' ($cl.Count -ge 1) ''
Check 'sin registro-historico (nada se ha tocado en Blogger)' (-not (Test-Path (Join-Path $DirPub 'registro-historico.txt'))) ''

# =============================================================== T12 simulacion correcciones
Bloque 'T12 aplicar-correcciones en SIMULACION (0 escrituras)'
$hashColaAntes = Hash $cc
$rE = Run $aplicar @()
Check 'simulacion sale 0' ($rE.Codigo -eq 0) ("codigo=" + $rE.Codigo)
Check 'anuncia SIMULACION OK' ($rE.Texto -match 'SIMULACION OK') ''
Check 'cola de correcciones intacta' ((Hash $cc) -eq $hashColaAntes) ''
Check 'no crea registro-historico en simulacion' (-not (Test-Path (Join-Path $DirPub 'registro-historico.txt'))) ''

# =============================================================== T13 anomalia
Bloque 'T13 anomalia: maxPorCorrida > topeAbsoluto -> exit 2'
$RutaSnap = Join-Path $BaseDir 'datos\cola\cola-actual.json'
$RutaAlert = Join-Path $BaseDir 'datos\cola\alertas.txt'
$bakDir = Temp 'bak'
$snapBak = Join-Path $bakDir 'cola-actual.json'; $alertBak = Join-Path $bakDir 'alertas.txt'
if (Test-Path $RutaSnap)  { Copy-Item $RutaSnap $snapBak -Force }
if (Test-Path $RutaAlert) { Copy-Item $RutaAlert $alertBak -Force }
if ($Rapidas) { Pass 'omitida con -Rapidas' } else {
    $rF = Run (Join-Path $BaseDir 'publicar-blogger.ps1') @('-Simular', '-MaxPorCorrida', '500')
    Check 'anomalia -> exit 2' ($rF.Codigo -eq 2) ("codigo=" + $rF.Codigo)
    Check 'muestra COLA DETENIDA' ($rF.Texto -match 'COLA DETENIDA') ''
    Check 'sin publicar (0 POST)' ($rF.Texto -notmatch 'POST /feeds/posts') ''
}
if (Test-Path $snapBak)  { Copy-Item $snapBak $RutaSnap -Force } elseif (Test-Path $RutaSnap) { Remove-Item $RutaSnap -Force }
if (Test-Path $alertBak) { Copy-Item $alertBak $RutaAlert -Force } elseif (Test-Path $RutaAlert) { Remove-Item $RutaAlert -Force }

# =============================================================== T14 flujo
Bloque 'T14 flujo-principal en modo -Simular (con red)'
if ($Rapidas) { Pass 'omitida con -Rapidas' } else {
    $rG = Run (Join-Path $BaseDir 'flujo-principal.ps1') @('-Simular', '-MaxBumeran', '3', '-MaxEstado', '3')
    Check 'flujo simulado sale 0' ($rG.Codigo -eq 0) ("codigo=" + $rG.Codigo)
    Check 'publicaciones.txt intacto' ((Hash $RutaPub) -eq $HashPub) ''
    Check 'cola-actual sigue marcando simulacion' ((Get-Content $RutaSnap -Raw -Encoding UTF8) -match '"publicadas"\s*:\s*0') ''
}

# =============================================================== T15 cloud
Bloque 'T15 automatizacion en la nube y guardas'
$wf = Join-Path $BaseDir '.github\workflows\pipeline.yml'
Check 'existe .github/workflows/pipeline.yml' (Test-Path $wf) ''
if (Test-Path $wf) {
    $t = [IO.File]::ReadAllText($wf)
    foreach ($k in @('workflow_dispatch', 'maxPorCorrida', 'simular', 'if: always()', '-Nube', 'BLOGGER_CREDENTIALS_B64', 'BLOGGER_TOKEN_B64', 'concurrency', 'contents: write')) {
        Check ("workflow contiene '" + $k + "'") ($t.Contains($k)) ''
    }
    Check 'workflow no tiene secretos embebidos' ($t -notmatch '(?i)(ya2\.|1//|AIza[0-9A-Za-z_\-]{30,})') ''
}
foreach ($cmd in @('diario-estado.cmd', 'diario-privado.cmd')) {
    $p = Join-Path $BaseDir $cmd
    if (Test-Path $p) {
        $t = [IO.File]::ReadAllText($p)
        Check ($cmd + ' lee config\publicacion.json (modo)') ($t -match 'publicacion\.json') ''
        Check ($cmd + ' tiene guarda de modo nube') ($t -match 'nube|nube') ''
    } else { Fail ($cmd + ' no existe') '' }
}
$gi = Join-Path $BaseDir '.gitignore'
if (Test-Path $gi) {
    $t = [IO.File]::ReadAllText($gi)
    foreach ($k in @('credentials', 'token-blogger', '*.b64', '.env')) { Check ('.gitignore cubre ' + $k) ($t -match [regex]::Escape($k)) '' }
} else { Fail '.gitignore no existe' '' }
try {
    $xml = & schtasks /query /tn 'EmpleosDiarioEstado' /xml 2>&1 | Out-String
    Check 'tarea Windows EmpleosDiarioEstado deshabilitada' ($xml -match '<Enabled>false</Enabled>') (($xml.Substring(0, [Math]::Min(160, $xml.Length))))
} catch { Pass 'no se pudo consultar la tarea (omitida)' }

# =============================================================== T16 git
Bloque 'T16 repositorio git sin secretos'
$tieneGit = Test-Path (Join-Path $BaseDir '.git')
Check 'repositorio git inicializado' $tieneGit ''
if ($tieneGit) {
    if (-not $Git) { Fail 'git no encontrado en el PATH ni en rutas habituales' '' }
    else {
        $gitFiles = & $Git -C $BaseDir ls-files 2>&1 | Out-String
        Check 'no hay credentials/token en los archivos tracked' ($gitFiles -notmatch '(?i)(credentials|token-blogger|\.b64)') ''
        Check 'sin cambios criticos sin commitear' ((& $Git -C $BaseDir status --porcelain -- publicaciones.txt datos/cola/historico-bloqueado.txt 2>&1 | Out-String).Trim() -eq '') ''
    }
}

# =============================================================== resumen
Check 'INTEGRIDAD: publicaciones.txt intacto al final' ((Hash $RutaPub) -eq $HashPub) ''
Write-Host ''
Write-Host ('== RESUMEN PRUEBAS: PASS=' + $script:OK + ' FAIL=' + $script:FAL + ' ==')
if ($script:FAL -eq 0) { Write-Host 'TODAS LAS PRUEBAS PASARON (0 escrituras reales)'; exit 0 }
Write-Host 'HAY PRUEBAS FALLIDAS' -ForegroundColor Red
exit 1
