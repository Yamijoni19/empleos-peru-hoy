@echo off
rem ============================================================
rem  GENERAR ENTRADA DE EMPLEO DESDE UNA URL (sin IA)
rem
rem  COMO USARLO:
rem   1) Ejecuta este archivo y pega la URL de la publicacion.
rem   2) Espera unos segundos. Si dice OK, el HTML queda COPIADO
rem      AL PORTAPAPELES: ve a Blogger y pega (Ctrl+V).
rem
rem  Si dice ERROR, no se copia nada: lee el mensaje.
rem  Ademas guarda:
rem     fuentes\<nombre>.txt      (datos reales de la publicacion)
rem     salida\<nombre>-entrada.html
rem ============================================================
setlocal
set "URL=%~1"
if "%URL%"=="" (
  echo.
  set /p "URL= Pega la URL de la publicacion: "
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar-entrada.ps1" -Url "%URL%"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
