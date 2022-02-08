cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
SCHTASKS /CREATE /SC ONLOGON /TN "install" /TR "cmd.exe /c powershell -File D:\start-install.bat" /RL HIGHEST /RU ADMINISTRATOR
