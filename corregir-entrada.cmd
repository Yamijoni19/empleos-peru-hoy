@echo off
rem ============================================================
rem  CORREGIR ENTRADA DE EMPLEO (arregla sola y luego valida)
rem
rem  COMO USARLO:
rem   1) Arrastra el archivo .html de la entrada sobre este archivo.
 rem   2) Pega la URL de la publicacion original y pulsa Enter
 rem      (Enter = usa sola la URL de 'Fuente' del bloque oculto:
 rem      repara enlaces y completa la lista de Bases).
rem
rem  Genera <nombre>-corregido.html junto al original y lanza
rem  el validador. Si dice OK, el HTML queda COPIADO AL PORTAPAPELES:
rem  en Blogger solo pega (Ctrl+V).
rem ============================================================
setlocal
set "ARCHIVO=%~1"
if "%ARCHIVO%"=="" (
  echo.
  echo  USO: arrastra el archivo .html de la entrada sobre este archivo.
  echo.
  pause
  exit /b 1
)
echo.
set "FUENTE="
set /p "FUENTE= URL de la publicacion original (Enter = usar la de 'Fuente' del bloque oculto): "
echo.
if "%FUENTE%"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corregir-entrada.ps1" -Archivo "%ARCHIVO%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corregir-entrada.ps1" -Archivo "%ARCHIVO%" -Fuente "%FUENTE%"
)
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
