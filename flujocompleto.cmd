@echo off
rem ============================================================
rem  FLUJO COMPLETO DIARIO (un solo comando)
rem
rem  1) obtener-urls   -> busca convocatorias nuevas en
rem                       convocatoriasdetrabajo.com (urls.txt)
rem  2) generar-lote   -> genera y valida cada entrada en paralelo
rem                       (salida\ + fuentes\ + reporte\)
rem  3) publicar-blogger -> las publica en Blogger con la
rem                       etiqueta Empleo (log publicaciones.txt)
rem
rem  USO:
rem    flujocompleto.cmd          diario: solo lo nuevo
rem    flujocompleto.cmd full     backfill: rastrea TODAS las paginas
rem    (si publicar-blogger pide credentials.json, sigue el setup
rem     que imprime el propio script; hasta entonces puedes usar
rem     generar-entrada.cmd a mano como siempre)
rem ============================================================
setlocal
set "RC=0"
set "ARGS=%*"
if /i "%~1"=="full" set "ARGS=-Full %2 %3 %4 %5 %6 %7 %8 %9"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls.ps1" %ARGS%
if errorlevel 1 set "RC=1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-lote.ps1"
if errorlevel 1 set "RC=1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar-blogger.ps1" -Si
if errorlevel 1 set "RC=1"

echo.
echo ===================================================
echo  FIN DEL FLUJO (codigo %RC%): revisa los mensajes
echo  de arriba y el reporte en reporte\ y publicaciones.txt
echo ===================================================
pause
exit /b %RC%
