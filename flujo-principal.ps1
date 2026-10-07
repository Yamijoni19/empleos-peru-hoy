# flujo-principal.ps1 - FLUJO UNICO de captura -> validacion -> cola -> publicacion
#
#   FUENTE                CAPTURA                  COLA
#   bumeran.com.pe   ->   obtener-bumeran.ps1      ->  generar-entrada-bumeran.ps1  -
#   convocatoriasdetrabajo.com -> obtener-urls.ps1 ->  generar-lote.ps1             -  ->  encolar-ofertas.ps1
#                                                                                      datos\cola\cola-comun.jsonl
#                                                                                              |
#                                                                                     publicar-blogger.ps1
#                                                                                     (solo si publicacion.activada)
#
# USO:
#   .\flujo-principal.ps1                   # captura + cola + publicacion (si esta activada)
#   .\flujo-principal.ps1 -SoloCaptura      # solo captura y cola, NADA de Blogger
#   .\flujo-principal.ps1 -SinPublicar      # captura + cola (publicacion desactivada)
#   .\flujo-principal.ps1 -SoloPublicar     # solo publica lo ya encolado
#   .\flujo-principal.ps1 -MaxBumeran 50 -MaxEstado 30
#   .\flujo-principal.ps1 -MaxPorCorrida 50 # sube el limite por corrida sin editar config
#
# REGLAS:
#   - Privado = SOLO Bumeran (BuscoJobs queda congelado con sus historicos).
#   - Estado  = SOLO convocatoriasdetrabajo.com (Talento Peru no se usa).
#   - No hace backfill ni publica historicos.
#   - La publicacion esta DESACTIVADA en config\publicacion.json mientras
#     Blogger responda 429; con -Simular no se hace ningun POST.
#   - Salida con codigo: 0 = OK, >0 = algo fallo.

param(
    [switch]$SoloCaptura,
    [switch]$SinPublicar,
    [switch]$SoloPublicar,
    [int]$MaxBumeran = 20,
    [int]$MaxEstado = 0,
    [int]$MaxPorCorrida = -1,
    [switch]$Simular,
    [switch]$Nube,
    [string]$BaseDir = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$DirLog = Join-Path $BaseDir 'reporte'
New-Item -ItemType Directory -Path $DirLog -Force | Out-Null
$LogPath = Join-Path $DirLog ('flujo-principal-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))

function Log([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { [IO.File]::AppendAllText($LogPath, ($l + "`r`n"), $utf8) } catch { }
    Write-Host $l
}
function Paso([string]$nombre, [string]$script, [hashtable]$params = @{}) {
    Log ("== " + $nombre + " ==")
    $ruta = Join-Path $BaseDir $script
    if (-not (Test-Path $ruta)) { Log ("  ERROR: falta " + $script); return 1 }
    $rc = 0
    try {
        & $ruta @params | ForEach-Object { Write-Host ("    " + $_) }
        $rc = $LASTEXITCODE
    } catch { Log ("  ERROR " + $nombre + ": " + $_.Exception.Message); $rc = 1 }
    if ($rc -ne $null -and $rc -ne 0) { Log ("  aviso: " + $script + " termino con codigo " + $rc) }
    return $rc
}

# ------------------------------------------------------------------ config
$publicarActivada = $false
$CfgPath = Join-Path $BaseDir 'config\publicacion.json'
if (Test-Path $CfgPath) {
    try {
        $c = Get-Content $CfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($c.publicacion -and $null -ne $c.publicacion.activada) { $publicarActivada = [bool]$c.publicacion.activada }
    } catch { }
}

$script:errores = 0
$Inicio = Get-Date
Log ("FLUJO PRINCIPAL " + $Inicio.ToString('yyyy-MM-dd HH:mm') + $(if ($Nube) { "  [nube]" } else { "  [local]" }))
Log ("  fuentes: PRIVADO=Bumeran | ESTADO=convocatoriasdetrabajo.com | publicacion.activada=" + $publicarActivada)

# ------------------------------------------------------------------ 1) CAPTURA + GENERACION
if (-not $SoloPublicar) {
    # ---- PRIVADO: Bumeran
    if ($MaxBumeran -ne 0) {
        [void](Paso 'CAPTURA BUMERAN' 'obtener-bumeran.ps1' @{ MaxOfertas = $MaxBumeran; PausaSeg = 1 })
        [void](Paso 'ENTRADAS BUMERAN' 'generar-entrada-bumeran.ps1' @{})
    }

    # ---- ESTADO: convocatoriasdetrabajo.com
    $paramsEstado = @{}
    if ($MaxEstado -gt 0) { $paramsEstado.MaxPaginas = $MaxEstado }
    [void](Paso 'CAPTURA ESTADO' 'obtener-urls.ps1' $paramsEstado)

    $urlsPath = Join-Path $BaseDir 'urls.txt'
    $hayUrls = $false
    if (Test-Path $urlsPath) {
        $lineas = @([IO.File]::ReadAllLines($urlsPath) | Where-Object { $_.Trim() -ne '' })
        if ($lineas.Count -gt 0) { $hayUrls = $true }
    }
    if ($hayUrls) {
        [void](Paso 'ENTRADAS ESTADO' 'generar-lote.ps1' @{ Paralelos = 3 })
    } else {
        Log ("  ESTADO: sin URLs nuevas (urls.txt vacio) - no se genera nada")
    }

    if ($SoloCaptura) { Log "SoloCaptura: fin del flujo antes de la cola." }
}

# ------------------------------------------------------------------ 2) COLA COMUN
if (-not $SoloPublicar -and -not $SoloCaptura) {
    [void](Paso 'COLA COMUN' 'encolar-ofertas.ps1' @{})
}

# ------------------------------------------------------------------ 3) PUBLICACION
if ($SinPublicar -or $SoloCaptura) { Log "Sin publicacion: fin del flujo (0 POST)."; exit $script:errores }
if (-not $publicarActivada -and -not $Simular) {
    Log "PUBLICACION DESACTIVADA en config\\publicacion.json: no se llama a publicar-blogger.ps1 (0 POST)."
    Log ("FLUJO TERMINADO en " + ((Get-Date) - $Inicio).ToString('mm\\:ss') + " | errores=" + $script:errores)
    exit $script:errores
}
Log "== PUBLICACION =="
$pPub = @{ Si = $true }
if ($Simular) { $pPub.Simular = $true }
if ($MaxPorCorrida -gt 0) { $pPub.MaxPorCorrida = $MaxPorCorrida }
[void](Paso 'PUBLICAR BLOGGER' 'publicar-blogger.ps1' $pPub)

$tsTotal = (Get-Date) - $Inicio
Log ("FLUJO TERMINADO en " + ("{0:00}:{1:00}:{2:00}" -f [int][math]::Floor($tsTotal.TotalHours), $tsTotal.Minutes, $tsTotal.Seconds) + " | errores=" + $script:errores)
exit $script:errores
