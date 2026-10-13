# regenerar-nuevas.ps1 - regenera TODAS las entradas NUEVA de la cola con la
# plantilla Fase A actual (categoria exacta, bloque oculto de 18 campos, sin
# prefijo de entidad duplicado) y pone en cuarentena las COMPILACIONES
# (paginas que juntan varias convocatorias CAS en un solo articulo).
#
# Garantia de publicacion: lo que no se regenera NO sale al feed (la puerta de
# calidad de publicar-blogger.ps1 lo marca SIN-CALIDAD hasta regenerarlo).
#
# USO (PowerShell):
#   .\regenerar-nuevas.ps1                 # regenera todo lo NUEVA
#   .\regenerar-nuevas.ps1 -Paralelos 5    # mas rapido
#   .\regenerar-nuevas.ps1 -SoloFallidas   # reintenta las que fallaron antes
#
# Salida: reporte\regeneracion-AAAA-MM-DD-HHmm.txt
# Cuarentena: salida\_rechazados\  (compilaciones; jamas se publican)

param(
    [int]$Paralelos = 3,
    [switch]$SoloFallidas
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$dirSalida   = Join-Path $raiz 'salida'
$dirCuarent  = Join-Path $dirSalida '_rechazados'
$dirReporte  = Join-Path $raiz 'reporte'
$colaPath    = Join-Path $raiz 'datos\cola\cola-comun.jsonl'
$rechazadas  = Join-Path $raiz 'datos\cola\rechazadas.txt'
foreach ($d in @($dirSalida, $dirCuarent, $dirReporte)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

# --------------------------------------------------------------- cola NUEVA
$items = @([IO.File]::ReadAllLines($colaPath, [Text.Encoding]::UTF8) |
    Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
$nuevas = @($items | Where-Object { [string]$_.estadoPublicacion -eq 'NUEVA' })
Write-Output ("NUEVA en cola: " + $nuevas.Count)

# reintento selectivo: sin archivo en salida o sin el marcador fase-a
if ($SoloFallidas) {
    $nuevas = @($nuevas | Where-Object {
        $p = Join-Path $dirSalida $_.archivo
        if (-not (Test-Path $p)) { return $true }
        $h = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
        return ($h -notmatch '<strong>Categor') -or ($h -notmatch 'empleo-datos-ocultos') -or
               (([regex]::Match($h, '(?s)TITULO_BLOGGER\s*=\s*(.*?)\s*-->').Groups[1].Value) -match '(?i)^(.+?):\s*\1:')
    })
    Write-Output ("SoloFallidas: " + $nuevas.Count + " por regenerar")
    if ($nuevas.Count -eq 0) { Write-Output "Nada pendiente: todas las NUEVA pasan la puerta fase-a."; exit 0 }
}

$cdt = @($nuevas | Where-Object { [string]$_.fuente -eq 'convocatoriasdetrabajo' })
$bum = @($nuevas | Where-Object { [string]$_.fuente -eq 'bumeran' })
$otras = @($nuevas | Where-Object { $_.fuente -ne 'convocatoriasdetrabajo' -and $_.fuente -ne 'bumeran' })
Write-Output ("  CDT (descarga):    " + $cdt.Count)
Write-Output ("  bumeran (local):   " + $bum.Count)
if ($otras.Count -gt 0) { Write-Output ("  otras fuentes:     " + $otras.Count + " (se regeneran al capturarlas de nuevo)") }

$rep = Join-Path $dirReporte ("regeneracion-" + (Get-Date -Format 'yyyy-MM-dd-HHmm') + ".txt")
$errores = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------- 1) CDT via generar-lote
$compUrls = @()
if ($cdt.Count -gt 0) {
    $urlsPath = Join-Path $raiz 'datos\cola\urls-regenerar.txt'
    [IO.File]::WriteAllLines($urlsPath, @($cdt | ForEach-Object { [string]$_.url } | Where-Object { $_ -match '^https?://' } | Select-Object -Unique), $utf8)
    $nUrls = @(Get-Content $urlsPath).Count
    Write-Output ("Generando " + $nUrls + " entradas CDT (Paralelos=" + $Paralelos + ")...")
    & powershell.exe -NoProfile -ExecutionPolicy 'Bypass' -File (Join-Path $raiz 'generar-lote.ps1') -Urls $urlsPath -RepasarTodas -Paralelos $Paralelos
    Write-Output ("generar-lote exit=" + $LASTEXITCODE)

    $reporteLote = @(Get-ChildItem $dirReporte -Filter 'reporte-*.txt' | Sort-Object Name | Select-Object -Last 1)
    if ($reporteLote.Count -gt 0) {
        $okCnt = 0
        foreach ($l in [IO.File]::ReadAllLines($reporteLote[0].FullName, [Text.Encoding]::UTF8)) {
            if ($l -match '^OK\s*\|') { $okCnt++; continue }
            if ($l -match '^ERROR\s*\|\s+(\S+)\s*\|\s*(.*)$') {
                $u = $Matches[1]; $msg = $Matches[2]
                if ($msg -match 'COMPILACION') { $compUrls += $u }
                else { $errores.Add(("CDT " + $u + " :: " + $msg)) }
            }
        }
        Write-Output ("  CDT OK: " + $okCnt + " | compilaciones: " + $compUrls.Count + " | otras fallas: " + ($errores.Count))
    } else {
        $errores.Add("no encontre el reporte de generar-lote para analizar")
    }
}

# ------------------------------------------- 2) cuarentena de compilaciones
$marcados = 0
foreach ($u in ($compUrls | Select-Object -Unique)) {
    $it = @($cdt | Where-Object { [string]$_.url -eq $u }) | Select-Object -First 1
    if (-not $it) { continue }
    $f = Join-Path $dirSalida ([string]$it.archivo)
    if (Test-Path $f) {
        try { Move-Item -LiteralPath $f -Destination (Join-Path $dirCuarent ([string]$it.archivo)) -Force } catch { $errores.Add("mover " + $it.archivo + ": " + $_.Exception.Message) }
    }
    $it | Add-Member -NotePropertyName 'estadoPublicacion' -NotePropertyValue 'RECHAZADA' -Force
    $it | Add-Member -NotePropertyName 'notaGeneracion' -NotePropertyValue ("COMPILACION " + (Get-Date -Format 'yyyy-MM-dd')) -Force
    try { [IO.File]::AppendAllText($rechazadas, ((Get-Date -Format 'yyyy-MM-dd HH:mm') + " | COMPILACION | " + [string]$it.archivo + " | " + [string]$it.url + "`r\n"), $utf8) } catch {}
    $marcados++
}
if ($marcados -gt 0) { Write-Output ("  en cuarentena (salida\_rechazados): " + $marcados + " compilaciones") }

# ------------------------------------------------------- 3) bumeran local
if ($bum.Count -gt 0) {
    Write-Output ("Regenerando bumeran desde bumeran\normalizado (local, -Repasar)...")
    & powershell.exe -NoProfile -ExecutionPolicy 'Bypass' -File (Join-Path $raiz 'generar-entrada-bumeran.ps1') -Repasar
    Write-Output ("  generar-entrada-bumeran exit=" + $LASTEXITCODE)
}

# ------------------------------------------- 4) reintentables: diagnosticar
$sinMarca = 0
foreach ($it in $nuevas) {
    if ([string]$it.estadoPublicacion -eq 'RECHAZADA') { continue }
    $p = Join-Path $dirSalida ([string]$it.archivo)
    if (-not (Test-Path $p)) {
        $errores.Add(("SIN-ARCHIVO " + [string]$it.archivo + " (" + [string]$it.fuente + ")"))
        continue
    }
    $h = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
    $t = [regex]::Match($h, '(?s)TITULO_BLOGGER\s*=\s*(.*?)\s*-->').Groups[1].Value
    if ($h -notmatch '<strong>Categor' -or $h -notmatch 'empleo-datos-ocultos' -or $t -match '(?i)^(.+?):\s*\1:') { $sinMarca++ }
}
# persistir estados (RECHAZADA) en la cola
try {
    $lineas = @($items | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 6 })
    [IO.File]::WriteAllLines($colaPath, $lineas, $utf8)
} catch { $errores.Add("guardar cola-comun: " + $_.Exception.Message) }

# --------------------------------------------------------------- resumen
$resumen = @(
    "# regeneracion " + (Get-Date -Format 'yyyy-MM-dd HH:mm'),
    "NUEVA total: " + $nuevas.Count + " | CDT: " + $cdt.Count + " | bumeran: " + $bum.Count,
    "compilaciones en cuarentena: " + $marcados,
    "todavia sin marcador fase-a (reintentar con -SoloFallidas): " + $sinMarca,
    "errores: " + $errores.Count
) + @($errores | Select-Object -First 80)
[IO.File]::WriteAllLines($rep, $resumen, $utf8)
Write-Output ("Resumen: " + $rep)
Write-Output ("Todavia sin marcador fase-a: " + $sinMarca)
if ($errores.Count -gt 0) { Write-Output ("Errores (primeros): " + [Math]::Min(5, $errores.Count)); $errores | Select-Object -First 5 | ForEach-Object { Write-Output ("  " + $_) } }
Write-Output "LISTO"
