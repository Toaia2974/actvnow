# =========================================================================
# CONFIGURACIÓN DEL CICLO DE VIDA E INSTALACIÓN DE ACTVNOW
# =========================================================================

# 1. Definir nombres y rutas dentro del entorno de usuario
$exeName = "Actvnow.exe"
$targetFolder = Join-Path $env:LocalAppData "Actvnow"
$targetPath = Join-Path $targetFolder $exeName

# Rutas especiales de Windows para los accesos directos
$startMenuFolder = [Environment]::GetFolderPath('Programs')
$startMenuShortcut = Join-Path $startMenuFolder "Actvnow.lnk"
$startupFolder = [Environment]::GetFolderPath('Startup')
$portableStartupShortcut = Join-Path $startupFolder "Actvnow.lnk"

# Obtener la ruta del archivo en ejecución
$currentPath = [System.IO.Path]::GetFullPath((Get-Process -Id $PID).MainModule.FileName)

# -------------------------------------------------------------------------
# REDIRECCIÓN INTELIGENTE (El cambio clave que pediste)
# -------------------------------------------------------------------------
$isAlreadyInstalledPath = ($currentPath -eq $targetPath)
$isAlreadyInstalledOnDisk = Test-Path $targetPath

# Si lo abres desde Descargas/Escritorio, pero ya está instalado en AppData:
if (-not $isAlreadyInstalledPath -and $isAlreadyInstalledOnDisk) {
    Start-Process -FilePath $targetPath
    [System.Environment]::Exit(0)
}

# Requerir las librerías gráficas de Windows de forma segura
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

# Rutas del Registro de Windows
$registryRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$registrySettingsPath = "HKCU:\Software\Actvnow"

# Comprobar estados y decisiones previas de manera segura
$installationMode = $null
$startupPromptAnswered = $null
if (Test-Path $registrySettingsPath) {
    $installationMode = (Get-ItemProperty -Path $registrySettingsPath -Name "InstallationMode" -ErrorAction SilentlyContinue).InstallationMode
    $startupPromptAnswered = (Get-ItemProperty -Path $registrySettingsPath -Name "StartupPromptAnswered" -ErrorAction SilentlyContinue).StartupPromptAnswered
}

# Evaluar si el inicio automático ya está configurado
$isStartupRegistry = (Get-ItemProperty -Path $registryRunPath -Name "Actvnow" -ErrorAction SilentlyContinue).Actvnow
$isStartupEnabled = ($isStartupRegistry -ne $null) -or (Test-Path $portableStartupShortcut)

# Función Auxiliar: Crear Accesos Directos (Start Menu / Startup)
function New-AppShortcut {
    param([string]$LinkPath, [string]$TargetPath)
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($LinkPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.WorkingDirectory = Split-Path $TargetPath
        $shortcut.IconLocation = "$TargetPath, 0"
        $shortcut.Save()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshShell) | Out-Null
    } catch { }
}

# Función para realizar la instalación limpia
function Invoke-AppInstallation {
    try {
        if (-not (Test-Path $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        }
        
        # Copiar ejecutable
        if ($currentPath -ne $targetPath) {
            Copy-Item -Path $currentPath -Destination $targetPath -Force
        }

        # Crear acceso directo en el Menú de Inicio
        New-AppShortcut -LinkPath $startMenuShortcut -TargetPath $targetPath

        # Guardar estado persistente
        if (-not (Test-Path $registrySettingsPath)) { New-Item -Path "HKCU:\Software" -Name "Actvnow" -Force | Out-Null }
        New-ItemProperty -Path $registrySettingsPath -Name "InstallationMode" -Value "Instalable" -PropertyType String -Force | Out-Null
        
        # Relanzar el proceso clonado y destruir el actual
        if ($currentPath -ne $targetPath) {
            Start-Process -FilePath $targetPath
            if ($script:notifyIcon) { $script:notifyIcon.Visible = $false; $script:notifyIcon.Dispose() }
            if ($script:timer) { $script:timer.Stop(); $script:timer.Dispose() }
            [System.Environment]::Exit(0)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error durante la instalación: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# -------------------------------------------------------------------------
# PREGUNTA 1: MODO DE INSTALACIÓN
# -------------------------------------------------------------------------
if (-not $isAlreadyInstalledPath -and [string]::IsNullOrEmpty($installationMode)) {
    
    $title1 = "Paso 1/2: Modo de Ejecución"
    $msg1 = "¿Deseas INSTALAR la aplicación en el sistema?`n`n- SÍ: Se instalará y aparecerá en el Buscador de Windows.`n- NO: Se ejecutará en modo Portable."
    
    $resp1 = [System.Windows.Forms.MessageBox]::Show($msg1, $title1, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)

    if (-not (Test-Path $registrySettingsPath)) { New-Item -Path "HKCU:\Software" -Name "Actvnow" -Force | Out-Null }

    if ($resp1 -eq [System.Windows.Forms.DialogResult]::Yes) {
        Invoke-AppInstallation
    } else {
        New-ItemProperty -Path $registrySettingsPath -Name "InstallationMode" -Value "Portable" -PropertyType String -Force | Out-Null
        $installationMode = "Portable" 
    }
}

# -------------------------------------------------------------------------
# PREGUNTA 2: INICIO AUTOMÁTICO
# -------------------------------------------------------------------------
if ([string]::IsNullOrEmpty($startupPromptAnswered)) {
    
    $title2 = "Paso 2/2: Arranque del Sistema"
    $msg2 = "¿Deseas que Actvnow se inicie automáticamente al encender Windows?"
    
    $resp2 = [System.Windows.Forms.MessageBox]::Show($msg2, $title2, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)

    if (-not (Test-Path $registrySettingsPath)) { New-Item -Path "HKCU:\Software" -Name "Actvnow" -Force | Out-Null }
    New-ItemProperty -Path $registrySettingsPath -Name "StartupPromptAnswered" -Value "True" -PropertyType String -Force | Out-Null

    if ($resp2 -eq [System.Windows.Forms.DialogResult]::Yes) {
        if ($installationMode -eq "Instalable" -or $isAlreadyInstalledPath) {
            New-ItemProperty -Path $registryRunPath -Name "Actvnow" -Value "`"$targetPath`"" -PropertyType String -Force | Out-Null
        } else {
            New-AppShortcut -LinkPath $portableStartupShortcut -TargetPath $currentPath
        }
        $isStartupEnabled = $true
    }
}

# =========================================================================
# MONITOR DE ACTIVIDAD PRINCIPAL (CÓDIGO DE LA APLICACIÓN)
# =========================================================================

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = (Get-Location).Path }

$script:logPath = Join-Path -Path $scriptDir -ChildPath "HistorialVentanas.log"
$script:flagPath = Join-Path -Path $scriptDir -ChildPath "cierre_limpio.flag"

if (Test-Path $script:flagPath) { Remove-Item $script:flagPath -Force }

# Watchdog VBS
$tempVbsPath = Join-Path -Path $env:TEMP -ChildPath "sys_watchdog.vbs"
$vbsCode = @"
Set objArgs = WScript.Arguments
If objArgs.Count < 2 Then WScript.Quit
monitorPid = objArgs(0)
targetDir = objArgs(1)
Set fso = CreateObject("Scripting.FileSystemObject")
logPath = fso.BuildPath(targetDir, "HistorialVentanas.log")
flagPath = fso.BuildPath(targetDir, "cierre_limpio.flag")
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Do While True
    WScript.Sleep 1000
    Set colProcesses = objWMIService.ExecQuery("Select * From Win32_Process Where ProcessId = " & monitorPid)
    If colProcesses.Count = 0 Then
        If Not fso.FileExists(flagPath) Then
            Set logFile = fso.OpenTextFile(logPath, 8, True)
            currentTime = Year(Now) & "-" & Right("0" & Month(Now), 2) & "-" & Right("0" & Day(Now), 2) & " " & Right("0" & Hour(Now), 2) & ":" & Right("0" & Minute(Now), 2) & ":" & Right("0" & Second(Now), 2)
            logFile.WriteLine "[" & currentTime & "] [CIERRE FORZADO] El proceso del Monitor se cerro inesperadamente."
            logFile.Close
        Else
            fso.DeleteFile flagPath, True
        End If
        fso.DeleteFile WScript.ScriptFullName, True
        Exit Do
    End If
Loop
"@
Set-Content -Path $tempVbsPath -Value $vbsCode -Encoding Default -Force
$wsh = New-Object -ComObject WScript.Shell
$myPid = $PID 
$wsh.Run("wscript.exe `"$tempVbsPath`" $myPid `"$scriptDir`"", 0, $false) | Out-Null

try {
    # APIs de Windows
    if (-not ("Win32" -as [type])) {
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        public static class Win32 {
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out int processId);
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)] public static extern int GetWindowTextLength(IntPtr hWnd);
        }
"@
    }

    # Interfaz del Sistema (Tray Icon)
    $script:appContext = New-Object System.Windows.Forms.ApplicationContext
    $script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    try { $script:notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($currentPath) } 
    catch { $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application }
    $script:notifyIcon.Text = "Monitor de Actividad"
    $script:notifyIcon.Visible = $true

    # MENÚ CONTEXTUAL DINÁMICO
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    
    # Opción 1: Instalar Monitor
    $installMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    if ($isAlreadyInstalledPath -or $isAlreadyInstalledOnDisk) {
        $installMenuItem.Text = "Aplicación Local (Instalada)"
        $installMenuItem.Enabled = $false
    } else {
        $installMenuItem.Text = "Instalar aplicación en el sistema"
        $installMenuItem.Enabled = $true
        $installMenuItem.Add_Click({ Invoke-AppInstallation })
    }

    # Opción 2: Startup Automático
    $startupMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    if ($isStartupEnabled) {
        $startupMenuItem.Text = "Inicio Automático [Activado]"
        $startupMenuItem.Enabled = $false
    } else {
        $startupMenuItem.Text = "Activar Inicio con Windows"
        $startupMenuItem.Enabled = $true
        $startupMenuItem.Add_Click({
            try {
                if ($isAlreadyInstalledPath -or $installationMode -eq "Instalable") {
                    New-ItemProperty -Path $registryRunPath -Name "Actvnow" -Value "`"$targetPath`"" -PropertyType String -Force | Out-Null
                } else {
                    New-AppShortcut -LinkPath $portableStartupShortcut -TargetPath $currentPath
                }
                $startupMenuItem.Text = "Inicio Automático [Activado]"
                $startupMenuItem.Enabled = $false
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Error al activar: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        })
    }

    # Opción 3: Cerrar Monitor
    $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitMenuItem.Text = "Cerrar Monitor"
    $exitMenuItem.Add_Click({
        New-Item -Path $script:flagPath -ItemType File -Force | Out-Null
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
        $script:timer.Stop()
        $script:timer.Dispose()
        [System.Windows.Forms.Application]::Exit()
        [System.Environment]::Exit(0)
    })

    $contextMenu.Items.Add($installMenuItem) | Out-Null
    $contextMenu.Items.Add($startupMenuItem) | Out-Null
    $contextMenu.Items.Add("-") | Out-Null
    $contextMenu.Items.Add($exitMenuItem) | Out-Null
    $script:notifyIcon.ContextMenuStrip = $contextMenu

    # Temporizador de escaneo
    $script:lastHwnd = [IntPtr]::Zero
    $script:timer = New-Object System.Windows.Forms.Timer
    $script:timer.Interval = 250 

    $script:timer.Add_Tick({
        $hwnd = [Win32]::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero -or $hwnd -eq $script:lastHwnd) { return }
        $script:lastHwnd = $hwnd
        $procId = 0
        [Win32]::GetWindowThreadProcessId($hwnd, [ref]$procId) | Out-Null
        $length = [Win32]::GetWindowTextLength($hwnd)
        $sb = New-Object System.Text.StringBuilder ($length + 1)
        [Win32]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
        $windowTitle = $sb.ToString()
        try {
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc) {
                $tooltipText = "$($proc.ProcessName): $windowTitle"
                if ($tooltipText.Length -gt 63) { $tooltipText = $tooltipText.Substring(0, 60) + "..." }
                $script:notifyIcon.Text = $tooltipText
                $path = $null
                try { $path = $proc.Path } catch { }
                if ($path) {
                    try {
                        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
                        if ($icon) { $script:notifyIcon.Icon = $icon }
                    } catch { }
                }
            }
        } catch { }
    })

    $script:timer.Start()
    [System.Windows.Forms.Application]::Run($script:appContext)
}
catch {
    $errorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $script:logPath -Value "[$errorTime] [ERROR INTERNO] $_" -Encoding UTF8 -ErrorAction SilentlyContinue
    New-Item -Path $script:flagPath -ItemType File -Force | Out-Null
}
