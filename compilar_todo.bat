@echo off
echo [0/3] Liberando procesos bloqueados...
:: Mata cualquier proceso de Python, PyInstaller o la app que haya quedado abierto
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im dart.exe >nul 2>&1
:: Reemplaza "control_herramientas.exe" por el nombre real del ejecutable de tu app si es distinto
taskkill /f /im control_herramientas.exe >nul 2>&1

:: Espera 2 segundos para asegurar que Windows libere los archivos
timeout /t 2 /nobreak >nul

echo Limpiando directorios antiguos a la fuerza...
if exist "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\controlHerramientas\build" rmdir /s /q "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\controlHerramientas\build"
if exist "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\control_herramientas_front\build" rmdir /s /q "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\control_herramientas_front\build"
if exist "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\control_herramientas_front\.dart_tool" rmdir /s /q "C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\control_herramientas_front\.dart_tool"

@echo off
setlocal EnableDelayedExpansion
title Creador Portable ABBAMAT
cd /d "%~dp0"

echo [1/3] Compilando Backend (PyInstaller)...
cd /d "%~dp0controlHerramientas"
call pyinstaller abbamat_api.spec --clean

echo.
echo [2/3] Compilando Frontend (Flutter Windows)...
cd /d "%~dp0control_herramientas_front"
call flutter clean
call flutter pub get
call flutter build windows --release

echo.
echo [3/3] Ensamblando carpeta ABBAMAT_PORTABLE...
cd /d "%~dp0"
if exist "ABBAMAT_PORTABLE" rd /s /q "ABBAMAT_PORTABLE"
mkdir "ABBAMAT_PORTABLE"

:: Copiar Backend
copy "controlHerramientas\dist\abbamat_api.exe" "ABBAMAT_PORTABLE\" /Y

:: Copiar Base de Datos
if exist "db.sqlite3" (
    copy "db.sqlite3" "ABBAMAT_PORTABLE\db.sqlite3" /Y
) else if exist "controlHerramientas\db.sqlite3" (
    copy "controlHerramientas\db.sqlite3" "ABBAMAT_PORTABLE\db.sqlite3" /Y
)

:: Copiar Frontend (App y carpeta data)
xcopy /E /Y /I "control_herramientas_front\build\windows\x64\runner\Release\*" "ABBAMAT_PORTABLE\"

:: Generar lanzador
echo @echo off > "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo cd /d %%~dp0 >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo title Lanzador ABBAMAT Portable >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo start /b abbamat_api.exe >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo ping 127.0.0.1 -n 4 ^>nul >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo start /wait control_herramientas_front.exe >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo taskkill /f /im abbamat_api.exe ^>nul 2^>^&1 >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"
echo exit >> "ABBAMAT_PORTABLE\Iniciar_ABBAMAT.bat"

echo.
echo ======================================================
echo   PORTABLE CREADO CON EXITO EN: ABBAMAT_PORTABLE
echo ======================================================
pause