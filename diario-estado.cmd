@echo off
rem ============================================================
rem  DIARIO ESTADO - rutina diaria programada (07:00)
rem   1) obtener-urls.ps1        -> urls.txt con las convocatorias nuevas
rem   2) generar-lote.ps1        -> genera las entradas nuevas en salida\
rem   3) generar-lote -ReintentarFallidas -> segundo pase de las que fallen
rem   4) publicar-blogger -Si    -> publica lo pendiente (excluye bj-/ct-)
rem
rem  Todo queda registrado en reporte\diario-estado.log
rem ============================================================
setlocal
cd /d "%~dp0"
rem --- guard: si config\ejecucion.json = nube, no correr (GitHub Actions publica) ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { if ((Get-Content '%~dp0config\ejecucion.json' -Raw | ConvertFrom-Json).modo -eq 'nube') { exit 1 } } catch { } ; exit 0"
if errorlevel 1 (
  echo == SALTADO: modo nube - corre el pipeline de GitHub Actions %DATE% %TIME% >> "%~dp0reporte\diario-estado.log"
  endlocal & exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls.ps1"      >> "%~dp0reporte\diario-estado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-lote.ps1"      >> "%~dp0reporte\diario-estado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-lote.ps1" -ReintentarFallidas >> "%~dp0reporte\diario-estado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-cdt2.ps1"       >> "%~dp0reporte\diario-estado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar-blogger.ps1" -Si -Excluir bj-*,ct-* >> "%~dp0reporte\diario-estado.log" 2>&1
echo == DIARIO ESTADO FIN %DATE% %TIME% == >> "%~dp0reporte\diario-estado.log"
endlocal
