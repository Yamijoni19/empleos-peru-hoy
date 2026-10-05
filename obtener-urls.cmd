@echo off
rem ============================================================
rem  OBTENER CONVOCATORIAS NUEVAS (sin entrar una por una)
rem
rem  COMO USARLO:
rem   1) Doble clic            -> busca SOLO las nuevas desde la
rem                               ultima vez (modo diario).
rem   2) obtener-urls.cmd full -> rastrea TODAS las paginas
rem                               (backfill: miles de convocatorias).
rem   3) obtener-urls.cmd cas  -> solo un listado (portada, cas,
rem                               practicas, 728, 276, scivil,
rem                               locacion, consultoria).
rem
rem  Guarda las URLs nuevas en urls.txt (una por linea) usando
rem  historial-urls.txt como memoria de lo ya procesado.
rem ============================================================
setlocal
if /i "%~1"=="full" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls.ps1" -Full %2 %3 %4 %5 %6 %7 %8 %9
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0obtener-urls.ps1" %*
)
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
