@echo off
rem ============================================================
rem  PUBLICAR EN BLOGGER (etiqueta Empleo, sin pegar nada)
rem
rem  COMO USARLO:
rem   1) Genera primero las entradas:   generar-lote.cmd
rem   2) publicar-blogger.cmd -Simular  (lista lo que se publicaria)
rem   3) publicar-blogger.cmd           (publica todo lo pendiente)
rem
rem  OPCIONES:
rem   publicar-blogger.cmd -Draft       entra como borrador
rem   publicar-blogger.cmd -Ultimas 3   solo las 3 mas recientes
rem
rem  SETUP UNICO (si pide credentials.json, el script te explica):
rem   Google Cloud -> Blogger API v3 -> OAuth de escritorio ->
rem   guardar el JSON como "credentials.json" en esta carpeta.
rem
rem  Log: publicaciones.txt (fecha, titulo, url del post, archivo)
rem ============================================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar-blogger.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
