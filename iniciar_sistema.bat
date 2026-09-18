@echo off
cd /d %~dp0
title Lanzador ABBAMAT
echo =========================================
echo   ABBAMAT - INICIO DE SISTEMA
echo =========================================
echo.
echo 1. Iniciando el backend (Django) en segundo plano...
cd controlHerramientas
start /b python manage.py runserver 8000
cd ..
echo.
echo 2. Esperando que el puerto 8000 este listo...
timeout /t 5 /nobreak > nul
echo.
echo 3. Abriendo Interfaz de Usuario (Flutter)...
cd control_herramientas_front
flutter run -d windows
echo.
echo Cerrando servidor en segundo plano...
taskkill /f /im python.exe > nul
exit
