SCHTASKS /CREATE /SC ONLOGON /TN "install" /TR "cmd.exe /c powershell -File D:\start-install.bat" /RL HIGHEST
