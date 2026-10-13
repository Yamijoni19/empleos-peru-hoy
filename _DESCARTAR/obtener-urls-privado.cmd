@echo off
rem ============================================================
rem  OBTENER OFERTAS DEL SECTOR PRIVADO NUEVAS
rem
rem  COMO USARLO:
rem   1) Doble clic            -> ultimos 4 dias (semilla inicial)
rem                               -> urls-privado.txt
rem   2) Barrido diario:       obtener-urls-privado.cmd -Dias 3
rem   3) Solo una fuente:      ... -SoloBuscojobs  /  -SoloComputrabajo
rem
rem  Fuentes: BuscoJobs (sitemap con lastmod) y Computrabajo
rem  (listados por ciudad con fechas "Hace X"). Usa
rem  historial-urls.txt como memoria de lo ya procesado.
rem
rem  Siguiente paso (genera las entradas en salida\):
rem   generar-lote.cmd -Urls urls-privado.txt -Generador generar-entrada-privado.ps1
rem ============================================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls-privado.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
