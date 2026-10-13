@echo off
rem ============================================================
rem  DIARIO PRIVADO - rutina diaria programada (08:00)
rem   1) obtener-urls-privado.ps1 -> urls-privado.txt (BuscoJobs + CT)
rem   2) generar-lote             -> entradas nuevas (ritmo lento:
rem        paralelos=1 y pausa=10s para no activar el limite de BJ)
rem   3) publicar-blogger -Si     -> publica lo pendiente en Blogger
rem
rem  Todo queda registrado en reporte\diario-privado.log
rem  NOTA: registrar la tarea programada recien cuando la semilla
rem        inicial (urls-privado.txt) termine de generarse.
rem ============================================================
setlocal
cd /d "%~dp0"
rem --- guard: si config\ejecucion.json = nube, no correr (GitHub Actions publica) ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "$m=''; try { $m=(Get-Content '%~dp0config\publicacion.json' -Raw | ConvertFrom-Json).modo } catch { }; if ($m -eq 'nube') { exit 1 } else { exit 0 }"
if errorlevel 1 (
  echo == SALTADO: modo nube - corre el pipeline de GitHub Actions %DATE% %TIME% >> "%~dp0reporte\diario-privado.log"
  endlocal & exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls-privado.ps1" >> "%~dp0reporte\diario-privado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-lote.ps1" -Urls "%~dp0urls-privado.txt" -Generador generar-entrada-privado.ps1 -Paralelos 1 -PausaMs 10000 >> "%~dp0reporte\diario-privado.log" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar-blogger.ps1" -Si >> "%~dp0reporte\diario-privado.log" 2>&1
echo == DIARIO PRIVADO FIN %DATE% %TIME% == >> "%~dp0reporte\diario-privado.log"
endlocal
