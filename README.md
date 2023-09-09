# loader-burp-modifier-name

Tai burp : https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar  
run java -jar loader.jar  
Create a Bat file
```
if (Test-Path burp.bat) {rm burp.bat} 
$path = "java --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:`"$pwd\loader-nvth.jar`" -noverify -jar `"$pwd\burpsuite_pro_v2023.9.4.jar`""
$path | add-content -path Burp.bat
```
enjoy cai moment nay  
