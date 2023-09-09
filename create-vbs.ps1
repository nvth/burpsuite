if (Test-Path BurpSuiteProfessional.vbs) {
   Remove-Item BurpSuiteProfessional.vbs}
echo "Set WshShell = CreateObject(`"WScript.Shell`")" > BurpSuiteProfessional.vbs
add-content BurpSuiteProfessional.vbs "WshShell.Run chr(34) & `"$pwd\Burp.bat`" & Chr(34), 0"
add-content BurpSuiteProfessional.vbs "Set WshShell = Nothing"
echo "Burp-Suite-Pro.vbs file is created.`n"