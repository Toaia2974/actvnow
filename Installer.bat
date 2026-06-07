@echo off
title Compilador e Instalador Actvnow
echo ====================================================
echo   Compilando Actvnow.ps1 a EXE (Modo Aplicacion)
echo ====================================================
echo.

:: Forzar que el script trabaje en la carpeta donde reside este .bat
cd /d "%~dp0"

:: Validar recursos indispensables
if not exist "Actvnow.ps1" (
    echo [ERROR] No se ha encontrado el archivo 'Actvnow.ps1' en este directorio.
    goto FinalizarError
)
if not exist "actvnow.ico" (
    echo [ERROR] No se ha encontrado el archivo de icono 'actvnow.ico' en este directorio.
    goto FinalizarError
)

echo [+] Comprobando entorno de PowerShell e instalando modulo 'ps2exe'...
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "if (-not (Get-Module -ListAvailable ps2exe)) { Install-Module ps2exe -Scope CurrentUser -Force }"

echo [+] Generando ejecutable optimizado...
:: Forzamos el Import-Module explícito con bypass antes de invocar la compilación
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Import-Module ps2exe; Invoke-ps2exe -inputFile 'Actvnow.ps1' -outputFile 'Actvnow.exe' -iconFile 'actvnow.ico' -noConsole"

echo.
if exist "Actvnow.exe" (
    echo ====================================================
    echo   [OK] !Compilacion Terminada! 'Actvnow.exe' listo.
    echo ====================================================
    echo Puedes ejecutar 'Actvnow.exe' ahora para iniciar el asistente de instalacion.
    goto FinalizarOK
) else (
    echo [ERROR] No se pudo generar el archivo ejecutable.
    goto FinalizarError
)

:FinalizarOK
echo.
pause
exit

:FinalizarError
echo.
echo La operacion no pudo completarse debido a restricciones de seguridad de Windows.
pause
exit