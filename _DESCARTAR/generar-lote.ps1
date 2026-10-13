# generar-lote.ps1 - genera las entradas de TODAS las URLs de urls.txt.
#
# USO (PowerShell):
#   .\generar-lote.ps1                       # procesa urls.txt con 5 trabajos en paralelo
#   .\generar-lote.ps1 -Paralelos 8          # mas rapidez
#   .\generar-lote.ps1 -Maximo 3             # solo las 3 primeras (prueba)
#   .\generar-lote.ps1 -Serial               # una por una (para depurar)
#   .\generar-lote.ps1 -ReintentarFallidas   # solo las que fallaron en el ultimo reporte
#
# Por cada URL: llama a generar-entrada.ps1 -SinPortapapeles (descarga, extrae,
# rellena, valida, guarda salida\ y fuentes\). Si sale OK, la URL se agrega a
# historial-urls.txt para que obtener-urls no la ofrezca otra vez.
#
# Reporte: reporte\reporte-AAAA-MM-DD-HHmm.txt  (lineas "OK | ..." / "ERROR | ...")

param(
    [string]$Urls = "",
    [string]$Generador = "",
    [int]$Paralelos = 5,
    [int]$PausaMs = 0,
    [int]$Maximo = 0,
    [switch]$Serial,
    [switch]$ReintentarFallidas,
    [switch]$RepasarTodas,
    [string]$ArgsExtra = ""
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Urls.Trim() -eq "") { $Urls = Join-Path $raiz "urls.txt" }
if ($Generador.Trim() -eq "") { $Generador = "generar-entrada.ps1" }
$generar = Join-Path $raiz $Generador
if (-not (Test-Path $generar)) { Write-Host ("ERROR: no existe el generador " + $generar); exit 1 }
$historialPath = Join-Path $raiz "historial-urls.txt"
$dirReporte = Join-Path $raiz "reporte"
if (-not (Test-Path $dirReporte)) { New-Item -ItemType Directory -Path $dirReporte | Out-Null }

if (-not (Test-Path $Urls)) { Write-Host ("ERROR: no existe " + $Urls + " (ejecuta primero obtener-urls.cmd)"); exit 1 }

$historial = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $historialPath) {
    foreach ($l in [IO.File]::ReadAllLines($historialPath)) { $l = $l.Trim(); if ($l -ne "") { [void]$historial.Add($l) } }
}

$lista = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($l in [IO.File]::ReadAllLines($Urls)) {
    $l = $l.Trim()
    if ($l -match '^https?://' -and $lista.Add($l)) { continue }
}
$todo = @($lista)
if ($todo.Count -eq 0) { Write-Host ("No hay URLs que procesar en " + $Urls); exit 0 }

if ($ReintentarFallidas) {
    $ult = Get-ChildItem $dirReporte -Filter "reporte-*.txt" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if (-not $ult) { Write-Host "No hay reportes previos."; exit 1 }
    $fallidas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($l in [IO.File]::ReadAllLines($ult.FullName)) {
        if ($l -match '^ERROR\s*\|\s+(\S+)') { [void]$fallidas.Add($Matches[1]) }
    }
    $todo = @($todo | Where-Object { $fallidas.Contains($_) })
    Write-Host ("Reintento de " + $todo.Count + " fallidas (ultimo reporte: " + $ult.Name + ")")
    if ($todo.Count -eq 0) { exit 0 }
}
if (-not $RepasarTodas -and -not $ReintentarFallidas) {
    $antes = $todo.Count
    $todo = @($todo | Where-Object { -not $historial.Contains($_) })
    if ($antes -ne $todo.Count) { Write-Host ("Omitidas ya procesadas: " + ($antes - $todo.Count)) }
}
if ($Maximo -gt 0 -and $todo.Count -gt $Maximo) { $todo = $todo[0..($Maximo - 1)] }
if ($todo.Count -eq 0) { Write-Host "Nada que procesar: todo esta en el historial."; exit 0 }

$reporte = Join-Path $dirReporte ("reporte-" + (Get-Date -Format 'yyyy-MM-dd-HHmm') + ".txt")
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($reporte, ("# generar-lote " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " | urls=" + $todo.Count + "`n"), $enc)

$script:total = $todo.Count
$script:k = 0
$script:ok = 0
$script:fail = 0

function Registrar($r) {
    $script:k++
    $linea = ""
    $url = [string]$r.url
    $rc = [int]$r.rc
    $texto = [string]$r.texto
    $avisos = ([regex]::Matches($texto, 'AVISO')).Count
    if ($rc -eq 0) {
        $script:ok++
        $res = [regex]::Match($texto, '(?m)^\s+\d+\s+vacantes?\s*\|.*$')
        $extra = ""
        if ($res.Success) { $extra = (($res.Value -replace '\s+', ' ').Trim()) }
        if ($extra.Length -gt 95) { $extra = $extra.Substring(0, 92) + "..." }
        $linea = "OK   | avisos=" + $avisos + " | " + $extra + " | " + $url
        if ($historial.Add($url)) { [IO.File]::AppendAllText($historialPath, $url + "`n", $enc) }
        Write-Host ("[" + $script:k + "/" + $script:total + "] OK   " + $url)
    } else {
        $script:fail++
        $msg = "sin detalle"
        $me = [regex]::Match($texto, '(?m)^ERROR:.*$')
        if ($me.Success) { $msg = ($me.Value -replace '\s+', ' ').Trim() }
        if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 147) + "..." }
        $linea = "ERROR| " + $url + " | " + $msg
        Write-Host ("[" + $script:k + "/" + $script:total + "] ERROR " + $url)
        Write-Host ("        " + $msg)
    }
    [IO.File]::AppendAllText($reporte, $linea + "`n", $enc)
}

$bloque = {
    param($ruta, $u, $argsExtra)
    $ErrorActionPreference = 'Continue'
    try {
        $extraParams = @{}
        if ($argsExtra) { foreach ($p in ($argsExtra -split '\s+')) { if ($p -match '^-') { $extraParams[($p.TrimStart('-').Split(' ')[0])] = $true } } }
        $texto = (& $ruta @extraParams -Url $u -SinPortapapeles *>&1 | Out-String)
        [pscustomobject]@{ url = $u; rc = $LASTEXITCODE; texto = $texto }
    } catch {
        [pscustomobject]@{ url = $u; rc = 1; texto = ("ERROR: " + $_.Exception.Message) }
    }
}

Write-Host ""
Write-Host ("== GENERANDO ENTRADAS: " + $script:total + " URLs | paralelos=" + $(if ($Serial) { 1 } else { $Paralelos }) + " ==")
Write-Host ("Reporte: " + $reporte)
Write-Host ""

if ($Serial) {
    foreach ($u in $todo) { Registrar (& $bloque $generar $u $ArgsExtra) }
} else {
    $cola = New-Object System.Collections.Generic.Queue[string]
    foreach ($u in $todo) { $cola.Enqueue($u) }
    $activos = @()
    while ($cola.Count -gt 0 -or $activos.Count -gt 0) {
        while ($activos.Count -lt $Paralelos -and $cola.Count -gt 0) {
            $u = $cola.Dequeue()
            $activos += Start-Job -ScriptBlock $bloque -ArgumentList $generar, $u, $ArgsExtra
            if ($PausaMs -gt 0) { Start-Sleep -Milliseconds $PausaMs }
        }
        $listos = @($activos | Where-Object { $_.State -ne 'Running' })
        foreach ($j in $listos) {
            $salida = Receive-Job -Job $j
            Remove-Job -Job $j -Force
            $activos = @($activos | Where-Object { $_.Id -ne $j.Id })
            foreach ($r in @($salida)) {
                if ($r -is [pscustomobject] -and $r.PSObject.Properties['url']) { Registrar $r }
                else { Registrar ([pscustomobject]@{ url = "(desconocida)"; rc = 1; texto = ("ERROR: sin resultado del trabajo: " + $r) }) }
            }
        }
        if ($listos.Count -eq 0) { Start-Sleep -Milliseconds 400 }
    }
}

Write-Host ""
Write-Host "== RESUMEN DEL LOTE =="
Write-Host ("  total: " + $script:total + " | OK: " + $script:ok + " | ERROR: " + $script:fail)
Write-Host ("  reporte: " + $reporte)
if ($script:fail -gt 0) { Write-Host "  (reintenta con: generar-lote.cmd -ReintentarFallidas)" }
exit $(if ($script:fail -gt 0) { 1 } else { 0 })
