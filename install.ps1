
$Url = "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar"   
$OutName = "burpsuite_pro.jar"                        
$LoaderName = "loader.jar"                   
$BatName = "burp.bat"            

# Path
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }

$outPath = Join-Path -Path $scriptDir -ChildPath $OutName

$batPath = Join-Path $scriptDir $BatName

# Check burpsuite_pro.jar
Write-Host "Checking burpsuite_pro.jar at $scriptDir"
Write-Host " - $OutName : " -NoNewline
if (Test-Path $outPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

Write-Host " - $LoaderName : " -NoNewline
if (Test-Path $loaderPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

Write-Host " - $BatName : " -NoNewline
if (Test-Path $batPath) { Write-Host "Installed" } else { Write-Host "Not installed" }

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
if (Test-Path $batPath) {
    Remove-Item $batPath -Force
}

# Check burp
if (-not (Test-Path $loaderPath)) {
    Write-Host "Warning: $LoaderName not found $scriptDir."
}

# run ps1
$javaCmd = "java --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:`"" + "$pwd\$LoaderName" + "`" -noverify -jar `"" + "$pwd\$OutName" + "`""

# Create a bat file
Set-Content -Path $batPath -Value $javaCmd -Encoding ASCII

Write-Host "$BatName file is created at: $batPath`n"
Write-Host "Now you can run: `"$batPath`"."


#create vbs
if (Test-Path BurpSuiteProfessional.vbs) {
   Remove-Item BurpSuiteProfessional.vbs}
echo "Set WshShell = CreateObject(`"WScript.Shell`")" > BurpSuiteProfessional.vbs
add-content BurpSuiteProfessional.vbs "WshShell.Run chr(34) & `"$pwd\Burp.bat`" & Chr(34), 0"
add-content BurpSuiteProfessional.vbs "Set WshShell = Nothing"
echo "====================== Burp-Suite-Pro.vbs file is created. You can Run it after enter key=====================`n"

# Activate

echo "Reloading Environment Variables ...."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
echo "`n`nStarting Keygenerator ...."
start-process java.exe -argumentlist "-jar loader.jar"
echo "`n`nStarting Burp Suite Professional"
java --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:"loader.jar" -noverify -jar "burpsuite_pro_v$version.jar"
exit 0

