import os
import shutil
import time

def copiar_con_reintento(func, *args, **kwargs):
    max_intentos = 5
    for intento in range(1, max_intentos + 1):
        try:
            return func(*args, **kwargs)
        except PermissionError as e:
            if intento < max_intentos:
                print(f"  [AVISO] Archivo bloqueado temporalmente por Windows/Antivirus (WinError 32).")
                print(f"  Reintentando operación ({intento}/{max_intentos-1}) en 2 segundos...")
                time.sleep(2)
            else:
                print(f"  [ERROR FINAL] No se pudo copiar tras {max_intentos} intentos: {e}")
                raise

# Rutas originales
BASE_DIR = r"c:\Sistemas ABBAMAT\control_herramientas_PROYECTO"
FRONT_BUILD = os.path.join(BASE_DIR, r"control_herramientas_front\build\windows\x64\runner\Release")
BACK_BUILD = os.path.join(BASE_DIR, r"controlHerramientas\dist\abbamat_api.exe")
DB_FILE = os.path.join(BASE_DIR, r"controlHerramientas\db.sqlite3")

# Ruta de destino
DIST_DIR = os.path.join(BASE_DIR, "ABBAMAT_PORTABLE")

print(f"Borrando {DIST_DIR}...")
if os.path.exists(DIST_DIR):
    shutil.rmtree(DIST_DIR, ignore_errors=True)

print(f"Copiando Flutter App...")
copiar_con_reintento(shutil.copytree, FRONT_BUILD, DIST_DIR, dirs_exist_ok=True)

print(f"Copiando Backend API...")
copiar_con_reintento(shutil.copy2, BACK_BUILD, os.path.join(DIST_DIR, "abbamat_api.exe"))

print(f"Copiando Base de Datos...")
copiar_con_reintento(shutil.copy2, DB_FILE, os.path.join(DIST_DIR, "db.sqlite3"))

# Crear archivo BAT lanzador
BAT_CONTENT = """@echo off
cd /d %~dp0
title Lanzador ABBAMAT Portable
echo =========================================
echo   ABBAMAT - SISTEMA PORTABLE
echo =========================================
echo.
echo Iniciando el motor de base de datos (Django API)...
start /b abbamat_api.exe
echo.
echo Esperando que el puerto 8000 se active...
timeout /t 5 /nobreak > nul
echo.
echo Iniciando interfaz de usuario (Flutter)...
start /wait control_herramientas_front.exe
echo.
echo Cerrando servidor en segundo plano...
taskkill /f /im abbamat_api.exe > nul
exit
"""

bat_path = os.path.join(DIST_DIR, "Iniciar_ABBAMAT.bat")
with open(bat_path, "w") as f:
    f.write(BAT_CONTENT)

print(f"¡Listo! La carpeta portable está en {DIST_DIR}")

# Crear Restaurador de Sistema
BACKUP_DIR = os.path.join(BASE_DIR, "Backups_ABBAMAT")
os.makedirs(BACKUP_DIR, exist_ok=True)
RESTAURADOR_CONTENT = r"""@echo off
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
"""
restaurador_path = os.path.join(BACKUP_DIR, "Restaurar_Sistema.bat")
with open(restaurador_path, "w") as f:
    f.write(RESTAURADOR_CONTENT)
print(f"Restaurador creado en {BACKUP_DIR}")
