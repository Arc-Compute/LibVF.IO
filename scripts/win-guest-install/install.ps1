# Copy files to temp install path.
mkdir $env:USERPROFILE\temp-install\
cp -r D:\* $env:USERPROFILE\temp-install\
cd $env:USERPROFILE\temp-install\

# Extract guestutil zip files.
Get-ChildItem $env:USERPROFILE\temp-install\ -Filter *.zip | Expand-Archive -DestinationPath $env:USERPROFILE\temp-install\ -Force

# Install SSH.
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Start sshd service.
Start-Service sshd

# Set sshd service to start automatically on boot.
Set-Service -Name sshd -StartupType 'Automatic'

# Allow sshd through Windows firewall on port 22 if it isn't already allowed.
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

# Register SSH public keys in $env:USERPROFILE\.ssh\authorized_keys.

# Fix SSH authorized_keys permissions.

# Restart sshd. 

# Install IVSHMEM driver.
PNPUtil.exe /add-driver $env:USERPROFILE\temp-install\Win10\amd64\ivshmem.inf /install

# Install VirtIO network drivers.
cd $env:USERPROFILE\temp-install\
start-process .\virtio-win-guest-tools.exe

# Install Scream registry tweak.
cd $env:USERPROFILE\temp-install\
start-process .\scream-ivshmem-reg.bat

# Install Scream.
cd $env:USERPROFILE\temp-install\Install\
start-process .\Install-x64.bat

# Install Looking Glass.
cd $env:USERPROFILE\temp-install\
start-process .\looking-glass-host-setup.exe /S

# Verify guest GPU driver (force install if vendorid == 10de && no driver).

# Mount Samba permanently at Z:\.

# Prompt user for disabling explorer.exe (Y/n)?

# Install task-scheduler injection tool (LIME tasks).

# Shutdown Windows VM.