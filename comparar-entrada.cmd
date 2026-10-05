@echo off
rem ============================================================
rem  COMPARAR ENTRADA CONTRA LA FUENTE (detecta datos inventados)
rem
rem  COMO USARLO:
rem   1) Arrastra el .html de la entrada sobre este archivo.
rem   2) Arrastra el .txt de la fuente (carpeta fuentes) y pulsa Enter.
rem
rem  Si dice OK: los datos (vacantes, salario, ciudad, fechas,
rem  entidad, contrato) coinciden con la publicacion original.
rem  Si dice DIFF: alguien invento o cambio un dato. No publiques.
rem ============================================================
setlocal
set "HTML=%~1"
if "%HTML%"=="" (
  echo.
  echo  USO: arrastra el archivo .html de la entrada sobre este archivo.
  echo.
  pause
  exit /b 1
)
echo.
set "FUENTE="
set /p "FUENTE= Ruta del .txt de la fuente (carpeta fuentes): "
echo.
if "%FUENTE%"=="" (
  echo  FALTA el archivo de la fuente.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0comparar-entrada.ps1" -Fuente "%FUENTE%" -Html "%HTML%"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
