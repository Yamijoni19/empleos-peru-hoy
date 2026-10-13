@echo off
rem ============================================================
rem  GENERAR ENTRADAS EN LOTE (sin pegar URL por URL)
rem
rem  COMO USARLO:
rem   1) Primero: obtener-urls.cmd  (deja las nuevas en urls.txt)
rem   2) Doble clic aqui            (genera todas en paralelo)
rem
rem  OPCIONES (arrastra el cmd sobre una terminal o escribe):
rem   generar-lote.cmd -Maximo 3           solo 3 (prueba)
rem   generar-lote.cmd -Paralelos 8        mas rapido
rem   generar-lote.cmd -Serial             una por una (depurar)
rem   generar-lote.cmd -ReintentarFallidas solo las que fallaron
rem
rem  Guarda salida\*.html + fuentes\*.txt, escribe el reporte en
rem  reporte\ y agrega a historial-urls.txt las que salieron OK.
rem ============================================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-lote.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
