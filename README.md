# loader-burp-modifier-name
Windows  
Tai burp : https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar  
cmd `java -jar loader.jar`  
Create a Bat file
cmd `create-bat`  
Create a vbs file  
cmd `create-ps`  
Play Burp.bat or BurpsuiteProfessional.vbs 
Tao shortcut  
coppy file vbs `BurpSuiteProfessional.vbs` after run `create-ps.ps1` to `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\`  
==> enjoy cai moment nay   
  
Linux(tested on kali)  
tai burp : wget "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar"  
term `curl "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar" -o burpsuite_pro.jar`  
term `java -jar loader.jar` => press Run  
after update license
term `sudo mv burp /bin/burp`  
term `burp` enjoul cai moment nay
