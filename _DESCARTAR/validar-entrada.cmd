@echo off
rem ============================================================
rem  VALIDAR ENTRADA DE EMPLEO (antes de pegarla en Blogger)
rem
rem  COMO USARLO:
rem   1) Arrastra el archivo .html de la entrada sobre este archivo.
rem   2) Pega la URL de la publicacion original y pulsa Enter
rem      (Enter sin pegar nada = solo se valida la estructura).
rem
rem  Si dice OK, puedes pegar la entrada en Blogger.
rem  Si dice ERROR, no la pegues: corrige primero.
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
echo  Entrada: %ARCHIVO%
echo.
set "FUENTE="
set /p "FUENTE= URL de la publicacion original (Enter para omitir la comprobacion de enlaces): "
echo.
if "%FUENTE%"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0validar-entrada.ps1" -Archivo "%ARCHIVO%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0validar-entrada.ps1" -Archivo "%ARCHIVO%" -Fuente "%FUENTE%"
)
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
