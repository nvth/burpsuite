@echo off
setlocal DisableDelayedExpansion
set "NVTH_INSTALLER_PATH=%~f0"
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    echo [ERROR] Windows PowerShell was not found on this computer.
    pause
    exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "try{$text=[IO.File]::ReadAllText($env:NVTH_INSTALLER_PATH).Replace([string][char]13,'');$marker=[string][char]10+'# NVTH_POWERSHELL_PAYLOAD'+[char]10;$offset=$text.IndexOf($marker);if($offset -lt 0){throw 'Embedded installer payload was not found.'};& ([scriptblock]::Create($text.Substring($offset+$marker.Length)))}catch{Write-Host ('[ERROR] [Bootstrap] '+$_.Exception.Message);Read-Host 'Press Enter to close this window'|Out-Null;exit 1}"
exit /b %ERRORLEVEL%
# NVTH_POWERSHELL_PAYLOAD
[CmdletBinding()]
param([string]$LogPath)

$ErrorActionPreference = 'Stop'
$installStep = 'Preflight'
$transcriptStarted = $false

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

$installerDirectory = Split-Path -Parent ([IO.Path]::GetFullPath($env:NVTH_INSTALLER_PATH))
try {
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('nvth\logs\install-{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)
    } elseif (-not [IO.Path]::IsPathRooted($LogPath)) {
        $LogPath = Join-Path $installerDirectory $LogPath
    }
    $LogPath = [IO.Path]::GetFullPath($LogPath)
    if (Test-Path -LiteralPath $LogPath -PathType Container) {
        throw 'LogPath must name a log file, not an existing directory.'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null
    Start-Transcript -Path $LogPath -Append -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
    Write-Host '[INFO] [Preflight] Starting the standalone Burp Suite installer.'
    Write-Host "[INFO] Log: $LogPath"
    if (-not (Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'curl.exe was not found. Install the Windows curl utility and retry.'
    }
    Write-Host '[INFO] [Preflight] Download-tool check passed. Installing for the current user.'

# Installation workflow: all installation steps are contained in this file.
$DriveUrl = "https://drive.usercontent.google.com/download?id=1FL9-u9cWqho0h8f6sYie0uYras6AUCOK&export=download&authuser=0"
$GitHubUrl = "https://github.com/nvth/burpsuite/releases/download/v2026.3.3/burpsuite_pro.jar"
$Url = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar"
$BurpDownloadUrls = @($DriveUrl, $GitHubUrl, $Url)
$OutName = "burpsuite_pro.jar"
$LoaderName = "core.jar"
$BatName = "burp.bat"
$VbsName = "BurpSuiteProfessional.vbs"
$JdkUrl = "https://github.com/nvth/burpsuite/releases/download/v2024.7.4/jdk-21.0.10_windows-x64_bin.zip"
$JdkArchiveName = "jdk-21.0.10_windows-x64_bin.zip"
$LoaderUrl = "https://github.com/nvth/burpsuite/releases/download/v2026.3.3/core.jar"
$IconUrl = "https://github.com/nvth/burpsuite/releases/download/v2024.7.4/burppro.ico"
$IconName = "burppro.ico"

function Test-JarFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        return ($stream.Length -ge 4 -and $stream.ReadByte() -eq 0x50 -and $stream.ReadByte() -eq 0x4B)
    } catch {
        return $false
    } finally {
        if ($stream) { $stream.Dispose() }
    }
}

function Get-HtmlAttribute {
    param([string]$Tag, [string]$Name)
    $pattern = '(?i)\b' + [regex]::Escape($Name) + '\s*=\s*["'']([^"'']*)["'']'
    $match = [regex]::Match($Tag, $pattern)
    if ($match.Success) {
        return [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    }
    return ''
}

function Invoke-CurlWithResume {
    param(
        [string]$Destination,
        [string[]]$RequestArgs,
        [switch]$Resume
    )

    $lastExitCode = 0
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $curlArgs = @()
        $hasPartial = (Test-Path -LiteralPath $Destination -PathType Leaf) -and ((Get-Item -LiteralPath $Destination).Length -gt 0)
        if ($Resume -and $hasPartial) {
            Write-Host "Download interrupted. Resuming $Destination (attempt $attempt/4)..."
            $curlArgs = @('-C', '-', '-o', $Destination) + @($RequestArgs)
        } elseif (-not $Resume -and $attempt -gt 1 -and $hasPartial) {
            Remove-Item -LiteralPath $Destination -Force
            Write-Host "Retrying download from the beginning (attempt $attempt/4)..."
            $curlArgs = @('-o', $Destination) + @($RequestArgs)
        } else {
            $curlArgs = @('-o', $Destination) + @($RequestArgs)
        }

        & curl.exe @curlArgs
        $lastExitCode = $LASTEXITCODE
        if ($lastExitCode -eq 0) { return 0 }
        if ($attempt -lt 4) { Start-Sleep -Seconds 2 }
    }
    return $lastExitCode
}

function Download-GoogleDriveFile {
    param([string]$Url, [string]$Destination)

    $suffix = [guid]::NewGuid().ToString('N')
    $pagePath = "$Destination.drive-page-$suffix"
    $resultPath = "$Destination.drive-result-$suffix"
    $cookiePath = "$Destination.drive-cookies-$suffix.txt"

    try {
        $responseUrl = & curl.exe -L --fail --progress-bar --show-error --connect-timeout 30 --speed-time 120 --speed-limit 1024 -c $cookiePath -o $pagePath -w '%{url_effective}' $Url
        if ($LASTEXITCODE -ne 0) { return $false }
        $responseUrl = @($responseUrl) -join ''

        if (Test-JarFile $pagePath) {
            Move-Item -LiteralPath $pagePath -Destination $Destination -Force | Out-Null
            return $true
        }

        $html = [IO.File]::ReadAllText($pagePath)
        $formMatch = [regex]::Match($html, '(?is)<form\b(?=[^>]*\bid\s*=\s*["'']download-form["''])[^>]*>(.*?)</form>')
        if (-not $formMatch.Success) { return $false }

        $formTag = [regex]::Match($formMatch.Value, '(?is)^<form\b[^>]*>').Value
        $action = Get-HtmlAttribute -Tag $formTag -Name 'action'
        $method = (Get-HtmlAttribute -Tag $formTag -Name 'method').ToUpperInvariant()
        if (-not $action) { return $false }
        if (-not $method) { $method = 'GET' }
        $actionUrl = ([uri]::new([uri]$responseUrl, $action)).AbsoluteUri

        $formFields = New-Object 'System.Collections.Generic.List[object]'
        foreach ($inputMatch in [regex]::Matches($formMatch.Groups[1].Value, '(?is)<input\b[^>]*>')) {
            $tag = $inputMatch.Value
            $name = Get-HtmlAttribute -Tag $tag -Name 'name'
            $type = (Get-HtmlAttribute -Tag $tag -Name 'type').ToLowerInvariant()
            $value = Get-HtmlAttribute -Tag $tag -Name 'value'
            $id = Get-HtmlAttribute -Tag $tag -Name 'id'
            $isDownloadButton = $type -eq 'submit' -and ($id -eq 'uc-download-link' -or $value -match '(?i)download\s+anyway')
            if ($name -and ($type -eq 'hidden' -or $isDownloadButton)) {
                [void]$formFields.Add([pscustomobject]@{ Name = $name; Value = $value })
            }
        }
        foreach ($buttonMatch in [regex]::Matches($formMatch.Groups[1].Value, '(?is)<button\b[^>]*>.*?</button>')) {
            $buttonHtml = $buttonMatch.Value
            $buttonTag = [regex]::Match($buttonHtml, '(?is)^<button\b[^>]*>').Value
            $name = Get-HtmlAttribute -Tag $buttonTag -Name 'name'
            $id = Get-HtmlAttribute -Tag $buttonTag -Name 'id'
            $value = Get-HtmlAttribute -Tag $buttonTag -Name 'value'
            $label = ([regex]::Replace($buttonHtml, '(?is)<[^>]+>', '')).Trim()
            if ($name -and ($id -eq 'uc-download-link' -or $label -match '(?i)download\s+anyway')) {
                if (-not $value) { $value = $label }
                [void]$formFields.Add([pscustomobject]@{ Name = $name; Value = $value })
            }
        }

        if (-not ($formFields | Where-Object { $_.Name -eq 'id' }) -or
            -not ($formFields | Where-Object { $_.Name -eq 'export' }) -or
            -not ($formFields | Where-Object { $_.Name -eq 'confirm' })) {
            return $false
        }

        $curlArgs = @('-L', '--fail', '--progress-bar', '--show-error', '--connect-timeout', '30', '--speed-time', '120', '--speed-limit', '1024', '-b', $cookiePath, '-c', $cookiePath)
        if ($method -eq 'GET') {
            $query = @($formFields | ForEach-Object {
                [uri]::EscapeDataString($_.Name) + '=' + [uri]::EscapeDataString($_.Value)
            }) -join '&'
            $separator = if ($actionUrl.Contains('?')) { '&' } else { '?' }
            $curlArgs += @('-G', ($actionUrl + $separator + $query))
        } elseif ($method -eq 'POST') {
            $curlArgs += @('-X', 'POST')
            foreach ($field in $formFields) {
                $curlArgs += @('--data-urlencode', ($field.Name + '=' + $field.Value))
            }
            $curlArgs += $actionUrl
        } else {
            return $false
        }

        Write-Host '[INFO] Submitting Google Drive confirmation form.'
        if ($method -eq 'GET') {
            $downloadExitCode = Invoke-CurlWithResume -Destination $resultPath -RequestArgs $curlArgs -Resume
        } else {
            $downloadExitCode = Invoke-CurlWithResume -Destination $resultPath -RequestArgs $curlArgs
        }
        if ($downloadExitCode -ne 0 -or -not (Test-JarFile $resultPath)) { return $false }

        Move-Item -LiteralPath $resultPath -Destination $Destination -Force | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        foreach ($tempPath in @($pagePath, $resultPath, $cookiePath)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# Install directories
$scriptDir = $installerDirectory
$defaultRootDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'nvth\burpsuite'

$installStep = 'Choose installation directory'
Write-Host "[INFO] [$installStep] Starting this step."
Write-Host "Default install directory: $defaultRootDir"
$selectedRootDir = Read-Host "Enter install directory, or press Enter to use default"
if ([string]::IsNullOrWhiteSpace($selectedRootDir)) {
    $rootDir = $defaultRootDir
} else {
    $selectedRootDir = [Environment]::ExpandEnvironmentVariables($selectedRootDir.Trim().Trim('"'))
    if (-not [System.IO.Path]::IsPathRooted($selectedRootDir)) {
        $selectedRootDir = Join-Path -Path $scriptDir -ChildPath $selectedRootDir
    }

    try {
        $rootDir = [System.IO.Path]::GetFullPath($selectedRootDir)
    } catch {
        Write-Host "Invalid install directory: $selectedRootDir"
        exit 1
    }
}
$binDir = Join-Path -Path $rootDir -ChildPath "bin"
$dataDir = Join-Path -Path $rootDir -ChildPath "data"
$uninstallPath = Join-Path -Path $rootDir -ChildPath "uninstall.ps1"

$outPath = Join-Path -Path $dataDir -ChildPath $OutName
$loaderPath = Join-Path -Path $dataDir -ChildPath $LoaderName
$batPath = Join-Path -Path $binDir -ChildPath $BatName
$vbsPath = Join-Path -Path $binDir -ChildPath $VbsName
$jdkDir = Join-Path -Path $rootDir -ChildPath "jdk"
$jdkArchivePath = Join-Path -Path $dataDir -ChildPath $JdkArchiveName
$bundledJavaExePath = Join-Path -Path $jdkDir -ChildPath "bin\java.exe"
$javaExePath = $bundledJavaExePath
$iconPath = Join-Path -Path $dataDir -ChildPath $IconName

function Get-JavaMajorVersion {
    param(
        [string]$JavaPath = "java"
    )

    $javaProcess = New-Object System.Diagnostics.Process
    try {
        # java -version writes to stderr. Reading it as a stream avoids treating
        # normal version output as a terminating PowerShell error.
        $javaProcess.StartInfo.FileName = $JavaPath
        $javaProcess.StartInfo.Arguments = '-version'
        $javaProcess.StartInfo.UseShellExecute = $false
        $javaProcess.StartInfo.CreateNoWindow = $true
        $javaProcess.StartInfo.RedirectStandardError = $true
        $javaProcess.StartInfo.RedirectStandardOutput = $true
        [void]$javaProcess.Start()
        if (-not $javaProcess.WaitForExit(10000)) {
            $javaProcess.Kill()
            return $null
        }
        if ($javaProcess.ExitCode -ne 0) { return $null }
        $output = ($javaProcess.StandardError.ReadToEnd() + "`n" + $javaProcess.StandardOutput.ReadToEnd()) -split '\r?\n'
    } catch {
        return $null
    } finally {
        $javaProcess.Dispose()
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

# Ensure install directories exist
$installStep = 'Create installation directories'
Write-Host "[INFO] [$installStep] Starting this step."
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}
# Check access before downloading or replacing any installation files.
foreach ($directory in @($rootDir, $binDir, $dataDir)) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    $probe = Join-Path $directory ('.write-check-' + [guid]::NewGuid().ToString('N'))
    $stream = $null
    try {
        $stream = [IO.File]::Open($probe, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    } finally {
        if ($stream) {
            $stream.Dispose()
            Remove-Item -LiteralPath $probe -Force
        }
    }
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

# Reuse an existing Java 21 first. Bundle Java 21 only when the machine has no Java 21.
$installStep = 'Ensure Java 21'
Write-Host "[INFO] [$installStep] Starting this step."
Write-Host "Checking bundled Java at $bundledJavaExePath..."
$javaMajor = Get-JavaMajorVersion -JavaPath $bundledJavaExePath

if ($javaMajor -ne 21) {
    $systemJavaCommand = Get-Command 'java.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($systemJavaCommand) {
        $systemJavaPath = $systemJavaCommand.Source
        $systemJavaMajor = Get-JavaMajorVersion -JavaPath $systemJavaPath
        if ($systemJavaMajor -eq 21) {
            $javaExePath = $systemJavaPath
            $javaMajor = $systemJavaMajor
            Write-Host "Found Java 21 at $javaExePath. Reusing it; no JDK download is needed."
        }
    }
}

if ($javaMajor -ne 21) {
    Write-Host "Java 21 was not found in the application folder or PATH. Installing it under $jdkDir."
    Write-Host "Downloading portable JDK 21..."
    Write-Host "URL: $JdkUrl"
    Write-Host "Save at $jdkArchivePath"

    $curlArgs = @('-L', '--fail', '--show-error', '--progress-bar', '--connect-timeout', '30', '--speed-time', '120', '--speed-limit', '1024', $JdkUrl)
    $exit = Invoke-CurlWithResume -Destination $jdkArchivePath -RequestArgs $curlArgs -Resume
    if ($exit -ne 0 -or -not (Test-Path $jdkArchivePath)) {
        Write-Host "Download Failed: $exit"
        if ($exit -eq 0) { exit 1 }
        exit $exit
    }

    Write-Host "Extracting portable JDK 21..."
    $jdkExtractDir = Join-Path -Path $dataDir -ChildPath "jdk_extract"
    if (Test-Path $jdkExtractDir) {
        Remove-Item -Recurse -Force $jdkExtractDir
    }
    New-Item -ItemType Directory -Path $jdkExtractDir -Force | Out-Null
    Expand-Archive -Path $jdkArchivePath -DestinationPath $jdkExtractDir -Force

    $extractedJava = Get-ChildItem -Path $jdkExtractDir -Recurse -Filter "java.exe" |
        Where-Object { $_.FullName -match '\\bin\\java\.exe$' } |
        Select-Object -First 1
    if (-not $extractedJava) {
        throw 'Failed to find java.exe in the downloaded JDK archive.'
    }

    $extractedJdkRoot = Split-Path -Parent (Split-Path -Parent $extractedJava.FullName)
    if (Test-Path $jdkDir) {
        Remove-Item -Recurse -Force $jdkDir
    }
    Move-Item -LiteralPath $extractedJdkRoot -Destination $jdkDir -Force
    if (Test-Path $jdkExtractDir) {
        Remove-Item -Recurse -Force $jdkExtractDir
    }

    $javaExePath = $bundledJavaExePath
    $javaMajor = Get-JavaMajorVersion -JavaPath $javaExePath
}

if ($javaMajor -ne 21) {
    throw "Could not find or install a Java 21 runtime. Last checked: $javaExePath."
}
Write-Host "Using Java 21 at $javaExePath."

# Prefer the personalized Core artifact supplied beside this installer.
$installStep = 'Install Core'
Write-Host "[INFO] [$installStep] Starting this step."
$localCore = Join-Path $scriptDir $LoaderName
if (Test-Path -LiteralPath $localCore -PathType Leaf) {
    if ([IO.Path]::GetFullPath($localCore) -ine [IO.Path]::GetFullPath($loaderPath)) {
        Copy-Item -LiteralPath $localCore -Destination $loaderPath -Force
        Write-Host '[INFO] Installed the local core.jar.'
    }
}
if (-not (Test-Path $loaderPath)) {
    Write-Host ""
    Write-Host '[INFO] Local core.jar not found. Downloading Core from GitHub release v2026.3.3.'
    Write-Host "URL: $LoaderUrl"
    Write-Host "Save at $loaderPath"

    $curlArgs = @('-L', '--fail', '--show-error', '--progress-bar', '--connect-timeout', '30', '--speed-time', '120', '--speed-limit', '1024', $LoaderUrl)
    $exit = Invoke-CurlWithResume -Destination $loaderPath -RequestArgs $curlArgs -Resume
    if ($exit -eq 0 -and (Test-Path $loaderPath)) {
        Write-Host "Downloaded $LoaderName"
    } else {
        Write-Host "Download Failed: $exit"
        if ($exit -eq 0) { exit 1 }
        exit $exit
    }
}

# Download burp
$installStep = 'Download Burp Suite'
Write-Host "[INFO] [$installStep] Starting this step."

if (-not (Test-Path $outPath)) {
    Write-Host ""
    Write-Host "Downloading Burpsuite ..."
    Write-Host "Save at $outPath"

    $downloaded = $false
    foreach ($downloadUrl in $BurpDownloadUrls) {
        Write-Host "Trying download URL: $downloadUrl"
        if ($downloadUrl -eq $DriveUrl) {
            if (Download-GoogleDriveFile -Url $downloadUrl -Destination $outPath) { $exit = 0 } else { $exit = 1 }
        } else {
            $curlArgs = @('-L', '--fail', '--show-error', '--progress-bar', '--connect-timeout', '30', '--speed-time', '120', '--speed-limit', '1024', $downloadUrl)
            $exit = Invoke-CurlWithResume -Destination $outPath -RequestArgs $curlArgs -Resume
        }
        $isJar = $exit -eq 0 -and (Test-JarFile $outPath)

        if ($isJar) {
            Write-Host "Downloaded $OutName"
            $downloaded = $true
            break
        }

        Write-Host "Download from this URL failed or did not return a JAR (curl exit code: $exit). Trying the next source."
        if (Test-Path $outPath) { Remove-Item -LiteralPath $outPath -Force }
    }

    if (-not $downloaded) {
        throw "Unable to download $OutName from any configured source."
    }
} else {
    Write-Host ""
    Write-Host "$OutName already exist."
}

# Create bat file
$installStep = 'Create launchers and uninstall files'
Write-Host "[INFO] [$installStep] Starting this step."
if (Test-Path $batPath) { Remove-Item $batPath -Force }

# Check core.jar
if (-not (Test-Path $loaderPath)) {
    Write-Host "Warning: $LoaderName not found in $dataDir."
}

# Create uninstall script
$uninstallScript = @'
$ErrorActionPreference = 'Stop'
try {
    $rootDir = [IO.Path]::GetFullPath('__ROOT_LITERAL__')
    $actualRoot = [IO.Path]::GetFullPath($PSScriptRoot)
    if ($actualRoot.TrimEnd('\') -ine $rootDir.TrimEnd('\') -or
        $rootDir.TrimEnd('\') -ieq [IO.Path]::GetPathRoot($rootDir).TrimEnd('\')) {
        throw 'The uninstaller must remain in its original installation directory.'
    }
    $installUserSid = '__INSTALL_USER_SID__'
    if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne $installUserSid) {
        throw 'Run this uninstaller as the Windows account that installed Burp, so the correct license store is cleared.'
    }
    Write-Host '[INFO] Close every Burp Suite instance before continuing so it cannot save the license again.'
    $confirm = Read-Host "Remove Burp Suite NVTH files in $rootDir AND this account's stored Burp license/preferences? This affects other Burp installations using the same preferences. (Y/N)"
    if ($confirm -notmatch '^(?i)y(es)?$') { Write-Host 'Canceled.'; exit 1 }

    # Clear only Burp's Java preferences, never the shared JavaSoft preference root.
    $burpPreferences = 'HKCU:\Software\JavaSoft\Prefs\burp'
    if (Test-Path -LiteralPath $burpPreferences) {
        Remove-Item -LiteralPath $burpPreferences -Recurse -Force -ErrorAction Stop
        Write-Host '[INFO] Removed the stored Burp license and preferences for this Windows account.'
    } else {
        Write-Host '[INFO] No Burp Java preferences were found for this Windows account.'
    }

    $userShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'BurpSuiteProfessional.lnk'
    if (Test-Path -LiteralPath $userShortcut) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($userShortcut)
        $expectedTarget = Join-Path $rootDir 'bin\BurpSuiteProfessional.vbs'
        if ($shortcut.TargetPath -ieq $expectedTarget) { Remove-Item -LiteralPath $userShortcut -Force }
    }
    # Remove installation components while preserving unrelated files in a custom folder.
    foreach ($name in @('bin', 'data', 'jdk')) {
        $target = [IO.Path]::GetFullPath((Join-Path $rootDir $name))
        if (-not $target.StartsWith($rootDir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'An uninstall target is outside the installation directory.'
        }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    }
    foreach ($name in @('UNINSTALL.txt', 'uninstall.ps1')) {
        $target = Join-Path $rootDir $name
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    if (-not (Get-ChildItem -LiteralPath $rootDir -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $rootDir -Force
    }
    Write-Host 'Uninstall completed.'
    exit 0
} catch {
    Write-Host ('[ERROR] Uninstall failed: ' + $_.Exception.Message)
    $cause = $_.Exception
    while ($cause) {
        if ($cause -is [UnauthorizedAccessException]) {
            Write-Host '[ERROR] [Permissions] Access denied. If this installation was created by an Administrator, run the uninstaller from an Administrator PowerShell window.'
            exit 5
        }
        $cause = $cause.InnerException
    }
    exit 1
}
'@
$uninstallScript = $uninstallScript.Replace('__ROOT_LITERAL__', $rootDir.Replace("'", "''"))
$uninstallScript = $uninstallScript.Replace('__INSTALL_USER_SID__', [Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
Set-Content -LiteralPath $uninstallPath -Value $uninstallScript -Encoding UTF8
Write-Host "Uninstall script created at: $uninstallPath"

# Create uninstall instructions
$uninstallInfoPath = Join-Path -Path $rootDir -ChildPath "UNINSTALL.txt"
$uninstallInfo = @'
UNINSTALL (Windows)

Step 1: Close all Burp Suite instances. Open PowerShell as the Windows account that installed Burp.
Step 2: Run the uninstall script in a separate PowerShell process:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "__ROOT_DIR__\uninstall.ps1"
If access is denied for an installation created by an Administrator, rerun from
an Administrator PowerShell window.
Uninstall also removes this account's stored Burp license and Java preferences.
Other Burp installations sharing these preferences will need configuration/activation again.
'@
$uninstallInfo = $uninstallInfo.Replace('__ROOT_DIR__', $rootDir)
Set-Content -LiteralPath $uninstallInfoPath -Value $uninstallInfo -Encoding UTF8
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
$javaCmd = "`"$javaExePath`" $javaXmx --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:`"$loaderPath`" -noverify -jar `"$outPath`""
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
$installStep = 'Download icon'
Write-Host "[INFO] [$installStep] Starting this step."
if (-not (Test-Path $iconPath)) {
    Write-Host ""
    Write-Host "$IconName not found. Downloading..."
    Write-Host "URL: $IconUrl"
    Write-Host "Save at $iconPath"

    $curlArgs = @('-L', '--fail', '--show-error', '--progress-bar', '--connect-timeout', '30', '--speed-time', '120', '--speed-limit', '1024', $IconUrl)
    $exit = Invoke-CurlWithResume -Destination $iconPath -RequestArgs $curlArgs -Resume
    if ($exit -eq 0 -and (Test-Path $iconPath)) {
        Write-Host "Downloaded $IconName"
    } else {
        Write-Host "Download Failed: $exit"
    }
}

# Create Start Menu shortcut
$installStep = 'Create Start Menu shortcut'
Write-Host "[INFO] [$installStep] Starting this step."
$shortcutName = "BurpSuiteProfessional.lnk"
$userPrograms = [Environment]::GetFolderPath("Programs")
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
    New-Item -ItemType Directory -Path $userPrograms -Force | Out-Null
    New-StartMenuShortcut -ShortcutPath $userShortcut -TargetPath $vbsPath -WorkingDirectory $dataDir -IconPath $iconPath
    Write-Host "Start Menu shortcut created at: $userShortcut"
} catch {
    Write-Host "[WARN] Could not create the current-user Start Menu shortcut: $($_.Exception.Message)"
}

# Activate
$installStep = 'Start applications'
Write-Host "[INFO] [$installStep] Starting this step."

echo "Reloading Environment Variables ...."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
echo "`n`nStarting Core ...."
Start-Process -FilePath $javaExePath -ArgumentList "-jar `"$loaderPath`""
echo "`n`nStarting Burp Suite Professional"
& $javaExePath --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:"$loaderPath" -noverify -jar "$outPath"
$burpExitCode = $LASTEXITCODE
if ($burpExitCode -ne 0) {
    Write-Host "[ERROR] Burp Suite exited with code $burpExitCode."
    exit $burpExitCode
}
Write-Host '[INFO] Installation and application launch completed successfully.'
exit 0

} catch {
    $failureCode = 1
    $cause = $_.Exception
    $accessDenied = $_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::PermissionDenied
    while ($cause) {
        if ($cause -is [UnauthorizedAccessException] -or
            ($cause -is [ComponentModel.Win32Exception] -and $cause.NativeErrorCode -eq 5)) {
            $accessDenied = $true
        }
        $cause = $cause.InnerException
    }
    $failure = '[ERROR] [{0}] {1} (line {2})' -f $installStep, $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber
    Write-Host $failure
    if ($accessDenied) {
        $failureCode = 5
        if (Test-Admin) {
            Write-Host '[ERROR] [Permissions] Access is still denied with Administrator privileges. Check folder permissions or choose a writable folder.'
        } else {
            Write-Host '[ERROR] [Permissions] Access denied. Choose a folder you can write to, or right-click the CMD installer and select Run as administrator, then choose the same installation folder. For the PS1 source, rerun it from an Administrator PowerShell window.'
        }
    }
    if (-not $transcriptStarted -and $LogPath) {
        Add-Content -LiteralPath $LogPath -Value $failure -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    exit $failureCode
} finally {
    if ($transcriptStarted) {
        Write-Host "[INFO] Installation log saved to: $LogPath"
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }
    Read-Host 'Press Enter to close this window' | Out-Null
}
