
$Url = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar"
$OutName = "burpsuite_pro.jar"
$LoaderName = "loader.jar"
$BatName = "burp.bat"
$VbsName = "BurpSuiteProfessional.vbs"
$JdkUrl = "https://github.com/nvth/burpsuite/releases/download/v2024.7.4/jdk-21_windows-x64_bin.exe"
$JdkInstallerName = "jdk-21_windows-x64_bin.exe"
$LoaderUrl = "https://github.com/nvth/burpsuite/releases/download/v2024.7.4/loader.jar"
$IconUrl = "https://github.com/nvth/burpsuite/releases/download/v2024.7.4/burppro.ico"
$IconName = "burppro.ico"

# Install directories
$rootDir = Join-Path -Path $env:SystemDrive -ChildPath "burpsuite_nvth"
$binDir = Join-Path -Path $rootDir -ChildPath "bin"
$dataDir = Join-Path -Path $rootDir -ChildPath "data"
$uninstallPath = Join-Path -Path $rootDir -ChildPath "uninstall.ps1"

$outPath = Join-Path -Path $dataDir -ChildPath $OutName
$loaderPath = Join-Path -Path $dataDir -ChildPath $LoaderName
$batPath = Join-Path -Path $binDir -ChildPath $BatName
$vbsPath = Join-Path -Path $binDir -ChildPath $VbsName
$jdkInstallerPath = Join-Path -Path $dataDir -ChildPath $JdkInstallerName
$iconPath = Join-Path -Path $dataDir -ChildPath $IconName

function Get-JavaMajorVersion {
    try {
        $output = & java -version 2>&1
    } catch {
        return $null
    }

    if (-not $output) { return $null }

    $firstLine = ($output | Select-Object -First 1)
    if ($firstLine -match 'version\s+"([^"]+)"') {
        $ver = $Matches[1]
        if ($ver -match '^1\.(\d+)') {
            return [int]$Matches[1]
        }
        if ($ver -match '^(\d+)') {
            return [int]$Matches[1]
        }
    }
    return $null
}

function Get-JavaMajorVersionFromRegistry {
    $regPaths = @(
        "HKLM:\SOFTWARE\JavaSoft\JDK",
        "HKLM:\SOFTWARE\Wow6432Node\JavaSoft\JDK"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            try {
                $current = (Get-ItemProperty -Path $path -Name CurrentVersion -ErrorAction Stop).CurrentVersion
                if ($current -match '^1\.(\d+)$') {
                    return [int]$Matches[1]
                }
                if ($current -match '^(\d+)$') {
                    return [int]$Matches[1]
                }
            } catch {
                # Ignore registry read errors
            }
        }
    }
    return $null
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Require admin (no auto-elevation)
if (-not (Test-Admin)) {
    Write-Host "This script must be run as Administrator. Please re-open PowerShell with admin rights."
    exit 1
}

# Require execution policy
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -ne "Unrestricted") {
    Write-Host "ExecutionPolicy is '$executionPolicy'."
    Write-Host "Please run these commands first:"
    Write-Host "  Set-ExecutionPolicy RemoteSigned"
    Write-Host "  Set-ExecutionPolicy Unrestricted"
    exit 1
}

# Ensure install directories exist
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}
Write-Host "Install directory (bin): $binDir"
Write-Host "Install directory (data): $dataDir"

# Check burpsuite_pro.jar
Write-Host "Checking burpsuite_pro.jar at $dataDir"
Write-Host " - $OutName : " -NoNewline
if (Test-Path $outPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

Write-Host " - $LoaderName : " -NoNewline
if (Test-Path $loaderPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

Write-Host " - $BatName : " -NoNewline
if (Test-Path $batPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

# Check Java 21 and install if missing
Write-Host ""
Write-Host "Checking Java 21..."
$javaMajor = Get-JavaMajorVersion
if (-not $javaMajor) {
    $javaMajor = Get-JavaMajorVersionFromRegistry
}

if ($javaMajor -ge 21) {
    Write-Host "Java $javaMajor detected."
} else {
    Write-Host "Java 21 not found."
    $confirm = Read-Host "Do you want to download and install JDK 21 now? (Y/N)"
    if ($confirm -notmatch '^(?i)y(es)?$') {
        Write-Host "Installation canceled by user."
        exit 1
    }
    Write-Host "Downloading and installing JDK 21..."
    Write-Host "URL: $JdkUrl"
    Write-Host "Save at $jdkInstallerPath"

    & curl.exe -L --fail -o $jdkInstallerPath $JdkUrl
    $exit = $LASTEXITCODE
    if ($exit -ne 0 -or -not (Test-Path $jdkInstallerPath)) {
        Write-Host "Download Failed: $exit"
        exit $exit
    }

    Write-Host "Starting JDK 21 installer (silent)..."
    $proc = Start-Process -FilePath $jdkInstallerPath -ArgumentList "/s" -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Host "JDK installer exited with code $($proc.ExitCode)."
        Write-Host "If Java is not detected, please run the installer manually:"
        Write-Host "  $jdkInstallerPath"
    }

    $javaMajor = Get-JavaMajorVersion
    if (-not $javaMajor) {
        $javaMajor = Get-JavaMajorVersionFromRegistry
    }

    if ($javaMajor -ge 21) {
        Write-Host "Java 21 installed successfully."
    } else {
        Write-Host "Warning: Java 21 still not detected. Please complete installation and rerun the script."
    }
}

# Download loader.jar if missing
if (-not (Test-Path $loaderPath)) {
    Write-Host ""
    Write-Host "loader.jar not found. Downloading..."
    Write-Host "URL: $LoaderUrl"
    Write-Host "Save at $loaderPath"

    & curl.exe -L --fail -o $loaderPath $LoaderUrl
    $exit = $LASTEXITCODE
    if ($exit -eq 0 -and (Test-Path $loaderPath)) {
        Write-Host "Downloaded $LoaderName"
    } else {
        Write-Host "Download Failed: $exit"
        exit $exit
    }
}

# Download burp

if (-not (Test-Path $outPath)) {
    Write-Host ""
    Write-Host "Downloading Burpsuite ..."           
    Write-Host "URL: $Url"
    Write-Host "Save at $outPath"

    & curl.exe -L --fail -o $outPath $Url
    $exit = $LASTEXITCODE

    if ($exit -eq 0 -and (Test-Path $outPath)) {
        Write-Host "Downloaded $OutName"
    } else {
        Write-Host "Download Failed: $exit"
        exit $exit
    }
} else {
    Write-Host ""
    Write-Host "$OutName already exist."
}

# Create bat file
if (Test-Path $batPath) { Remove-Item $batPath -Force }

# Check loader.jar
if (-not (Test-Path $loaderPath)) {
    Write-Host "Warning: $LoaderName not found in $dataDir."
}

# Create uninstall script
$uninstallScript = @'
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "This script must be run as Administrator. Please re-open PowerShell with admin rights."
    exit 1
}

$rootDir = Join-Path -Path $env:SystemDrive -ChildPath "burpsuite_nvth"
$binDir = Join-Path -Path $rootDir -ChildPath "bin"
$dataDir = Join-Path -Path $rootDir -ChildPath "data"

$shortcutName = "BurpSuiteProfessional.lnk"
$commonPrograms = [Environment]::GetFolderPath("CommonPrograms")
$userPrograms = [Environment]::GetFolderPath("Programs")
$commonShortcut = Join-Path -Path $commonPrograms -ChildPath $shortcutName
$userShortcut = Join-Path -Path $userPrograms -ChildPath $shortcutName

$confirm = Read-Host "This will remove Burp Suite NVTH files in $rootDir. Continue? (Y/N)"
if ($confirm -notmatch '^(?i)y(es)?$') {
    Write-Host "Canceled."
    exit 1
}

if (Test-Path $commonShortcut) { Remove-Item -Force $commonShortcut }
if (Test-Path $userShortcut) { Remove-Item -Force $userShortcut }
if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir }
if (Test-Path $dataDir) { Remove-Item -Recurse -Force $dataDir }

$self = $PSCommandPath
Write-Host "Uninstall completed. This script will remove itself and $rootDir."
Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "timeout /t 2 /nobreak >nul & rmdir /s /q `"$rootDir`" & del /f /q `"$self`"" -WindowStyle Hidden
'@
Set-Content -Path $uninstallPath -Value $uninstallScript -Encoding ASCII
Write-Host "Uninstall script created at: $uninstallPath"

# Create uninstall instructions
$uninstallInfoPath = Join-Path -Path $rootDir -ChildPath "UNINSTALL.txt"
$uninstallInfo = @'
UNINSTALL (Windows)

Step 1: Open PowerShell as Administrator.
Step 2: Enable script execution:
  Set-ExecutionPolicy Unrestricted
Step 3: Run the uninstall script:
  C:\burpsuite_nvth\uninstall.ps1
'@
Set-Content -Path $uninstallInfoPath -Value $uninstallInfo -Encoding ASCII
Write-Host "Uninstall instructions created at: $uninstallInfoPath"

# Determine JVM memory setting based on RAM
$javaXmx = ""
try {
    $ramBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    $ramGB = [math]::Round($ramBytes / 1GB, 2)
    if ($ramBytes -lt 16GB) {
        $javaXmx = "-Xmx4G"
        Write-Host "Detected RAM: $ramGB GB. Using $javaXmx."
    } elseif ($ramBytes -le 32GB) {
        $javaXmx = "-Xmx8G"
        Write-Host "Detected RAM: $ramGB GB. Using $javaXmx."
    } else {
        Write-Host "Detected RAM: $ramGB GB."
    }
} catch {
    Write-Host "Warning: Unable to detect RAM. Using default JVM memory settings."
}

# Create Burp.bat
$javaCmd = "java $javaXmx --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:`"$loaderPath`" -noverify -jar `"$outPath`""
Set-Content -Path $batPath -Value $javaCmd -Encoding ASCII

Write-Host "$BatName file is created at: $batPath`n"
Write-Host "Now you can run: `"$batPath`"."

# Create VBS
if (Test-Path $vbsPath) { Remove-Item $vbsPath -Force }
Set-Content -Path $vbsPath -Value "Set WshShell = CreateObject(`"WScript.Shell`")" -Encoding ASCII
Add-Content -Path $vbsPath -Value "WshShell.Run chr(34) & `"$batPath`" & Chr(34), 0"
Add-Content -Path $vbsPath -Value "Set WshShell = Nothing"
Write-Host "====================== $VbsName file is created. You can run it after pressing Enter. =====================`n"

# Download burppro.ico if missing
if (-not (Test-Path $iconPath)) {
    Write-Host ""
    Write-Host "$IconName not found. Downloading..."
    Write-Host "URL: $IconUrl"
    Write-Host "Save at $iconPath"

    & curl.exe -L --fail -o $iconPath $IconUrl
    $exit = $LASTEXITCODE
    if ($exit -eq 0 -and (Test-Path $iconPath)) {
        Write-Host "Downloaded $IconName"
    } else {
        Write-Host "Download Failed: $exit"
    }
}

# Create Start Menu shortcut
$shortcutName = "BurpSuiteProfessional.lnk"
$commonPrograms = [Environment]::GetFolderPath("CommonPrograms")
$userPrograms = [Environment]::GetFolderPath("Programs")
$commonShortcut = Join-Path -Path $commonPrograms -ChildPath $shortcutName
$userShortcut = Join-Path -Path $userPrograms -ChildPath $shortcutName

if (-not (Test-Path $iconPath)) {
    Write-Host "Warning: burppro.ico not found. Shortcut will use default icon."
}

function New-StartMenuShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$WorkingDirectory,
        [string]$IconPath
    )
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($ShortcutPath)
    $sc.TargetPath = $TargetPath
    $sc.WorkingDirectory = $WorkingDirectory
    if ($IconPath -and (Test-Path $IconPath)) {
        $sc.IconLocation = $IconPath
    }
    $sc.Save()
}

try {
    New-StartMenuShortcut -ShortcutPath $commonShortcut -TargetPath $vbsPath -WorkingDirectory $dataDir -IconPath $iconPath
    Write-Host "Start Menu shortcut created at: $commonShortcut"
} catch {
    Write-Host "Could not create all-users Start Menu shortcut. Trying per-user..."
    try {
        New-StartMenuShortcut -ShortcutPath $userShortcut -TargetPath $vbsPath -WorkingDirectory $dataDir -IconPath $iconPath
        Write-Host "Start Menu shortcut created at: $userShortcut"
    } catch {
        Write-Host "Failed to create Start Menu shortcut: $($_.Exception.Message)"
    }
}

# Activate

echo "Reloading Environment Variables ...."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
echo "`n`nStarting Keygenerator ...."
start-process java.exe -argumentlist "-jar `"$loaderPath`""
echo "`n`nStarting Burp Suite Professional"
java --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:"$loaderPath" -noverify -jar "$outPath"
exit 0
