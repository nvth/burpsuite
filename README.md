# loader-burp

### Installation
```cmd.cmd
git clone https://github.com/nvth/loader-burp.git
```
requirement jdk >=20  
## Windows  
Tai burp : https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar and rename `burpsuite_pro_v20xx.xx.xx.jar` to `burpsuite_pro.jar` or  
curl "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar" --output burpsuite_pro.jar  
copy `burpsuite_pro.jar` to folder have `loader.jar` file  
on cmd `java -jar loader.jar`  
Create a Bat file  
on cmd `create-bat`  
Create a vbs file  
on cmd `create-ps`  
Play Burp.bat or BurpsuiteProfessional.vbs  
Tao shortcut   
copy file vbs `BurpSuiteProfessional.vbs` after run `create-ps.ps1` to `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\`  
==> On keyboard `Windows` => `burp` enjoy cai moment nay   
  
## Linux  
### Kali
Choose jdk 18, go on next step  
tai burp : wget "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar" and rename `burpsuite_pro_v20xx.xx.xx.jar` to `burpsuite_pro.jar`    
on term `curl "https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar" -o burpsuite_pro.jar`  
copy `burpsuite_pro.jar` to folder have `loader.jar`, `burp` file  
on term `java -jar loader.jar`=> press Run  
after update license
on term `chmod u+x burp`  
on term `sudo mv burp /bin/burp`  
on term `burp` enjoul cai moment nay  

### ubuntu :  switch jdk to jdk18  
`sudo apt-get install openjdk-18-jdk`    
`update-java-alternatives --list`  
`sudo update-java-alternatives --set /path/to/java/version`  
`sudo update-alternatives --config java`  
use loader_ubuntu.jar instead of loader.jar  
Do the same as the kali part
