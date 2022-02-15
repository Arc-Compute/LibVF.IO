# Mount SMB drive
cmd.exe /c powershell -Command "New-PSDrive -Name 'Z' -Root '\\10.0.2.2\Public Files' -Persist -PSProvider Filesystem"
