# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install sed
choco install sed -Y

# Install SSH.
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Start sshd service.
Start-Service sshd

# Set sshd service to start automatically on boot.
Set-Service -Name sshd -StartupType 'Automatic'
Set-Service -Name ssh-agent -StartupType 'Automatic'

# Allow sshd through Windows firewall on port 22 if it isn't already allowed.
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

# Register SSH public keys in $env:USERPROFILE\.ssh\authorized_keys.
mkdir $env:USERPROFILE\.ssh\
cp $env:USERPROFILE\temp-install\authorized_keys $env:USERPROFILE\.ssh\

# Fix SSH authorized_keys permissions.
icacls.exe $env:USERPROFILE\.ssh\authorized_keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Update C:\ProgramData\ssh\sshd_config (remove Match Group administrators lines)
sed -i 's/Match Group administrators/#Match Group administrators/g' C:\ProgramData\ssh\sshd_config
sed -i 's/AuthorizedKeysFile __PROGRAMDATA__/#AuthorizedKeysFile __PROGRAMDATA__/g' C:\ProgramData\ssh\sshd_config

# Restart sshd. 
Restart-Service sshd
