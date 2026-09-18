@echo off
setlocal EnableDelayedExpansion
title Restaurador de Sistema ABBAMAT
color 4F
echo ==========================================================
echo       RESTAURADOR DE BASE DE DATOS ABBAMAT
echo ==========================================================
echo.
echo ADVERTENCIA: Asegurate de que el sistema ABBAMAT este 
echo COMPLETAMENTE CERRADO antes de continuar.
echo.
pause
echo.
echo Buscando copias de seguridad en esta carpeta...
echo.

set count=0
for %%F in (*.zip) do (
    set /a count+=1
    set "backup[!count!]=%%F"
    echo [!count!] %%F
)

if %count%==0 (
    echo No se encontraron copias de seguridad en formato zip.
    pause
    exit /b
)

echo.
set /p opt="Escribe el NUMERO de la copia a restaurar y presiona ENTER: "
echo.

if "%opt%"=="" (
    echo ERROR: Debes ingresar un numero.
    pause
    exit /b
)

if not defined backup[%opt%] (
    echo ERROR: El numero %opt% no es valido.
    pause
    exit /b
)

set "file=!backup[%opt%]!"

echo Preparando para restaurar: !file!
if not exist "..\ABBAMAT_PORTABLE" (
    mkdir "..\ABBAMAT_PORTABLE"
)
echo Extrayendo todos los archivos del sistema...
tar -xf "!file!" -C "..\ABBAMAT_PORTABLE"
echo.
echo RESTAURACION COMPLETADA CON EXITO.
pause
