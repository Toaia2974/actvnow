@echo off
title Desinstalador de Actvnow
echo ====================================================
echo      Desinstalando Actvnow por completo...
echo ====================================================
echo.

:: 1. Cerrar procesos activos
echo [+] Deteniendo procesos activos de Actvnow...
taskkill /f /im Actvnow.exe >nul 2>&1
wmic process where "name='wscript.exe' and commandline like '%%sys_watchdog.vbs%%'" call terminate >nul 2>&1
timeout /t 2 /nobreak >nul

:: 2. Limpiar el Registro de Windows
echo [+] Removiendo configuraciones del registro...
powershell -Command "Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Actvnow' -ErrorAction SilentlyContinue"
powershell -Command "Remove-Item -Path 'HKCU:\Software\Actvnow' -Recurse -Force -ErrorAction SilentlyContinue"

:: 3. Eliminar Accesos Directos (Menú de Inicio y Carpeta Startup Portable)
echo [+] Borrando accesos directos del sistema...
set "StartMenuShortcut=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Actvnow.lnk"
set "StartupShortcut=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Actvnow.lnk"

if exist "%StartMenuShortcut%" del /f /q "%StartMenuShortcut%" >nul 2>&1
if exist "%StartupShortcut%" del /f /q "%StartupShortcut%" >nul 2>&1

:: 4. Eliminar la carpeta de la aplicación en AppData\Local y Archivos Temporales
echo [+] Borrando archivos locales y temporales...
if exist "%LocalAppData%\Actvnow" (
    rmdir /s /q "%LocalAppData%\Actvnow"
)
if exist "%TEMP%\sys_watchdog.vbs" (
    del /f /q "%TEMP%\sys_watchdog.vbs" >nul 2>&1
)

echo.
echo ====================================================
echo   [OK] !Actvnow ha sido desinstalado por completo!
echo ====================================================
echo.
pause
exit