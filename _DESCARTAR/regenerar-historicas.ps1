# regenerar-historicas.ps1 - regenera en Fase A las entradas HISTORICA (BuscoJobs)
# usando las URLs de hist-urls.txt, con -Repasar (salta ventana y antirepeticion).
#
# USO:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\regenerar-historicas.ps1
#
# No toca la cola: despues de regenerar, promover HISTORICA->NUEVA es un paso aparte.

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$urls = Join-Path $raiz 'hist-urls.txt'
if (-not (Test-Path -LiteralPath $urls)) { Write-Host "ERROR: falta $urls"; exit 1 }

& (Join-Path $raiz 'generar-lote.ps1') -Urls $urls -Generador 'generar-entrada-privado.ps1' -Paralelos 2 -RepasarTodas -ArgsExtra '-Repasar'
exit $LASTEXITCODE
