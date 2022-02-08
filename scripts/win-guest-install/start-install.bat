cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
cmd.exe /c powershell -Command "Start-Process powershell -verb RunAs -ArgumentList "D:\install.ps1""
