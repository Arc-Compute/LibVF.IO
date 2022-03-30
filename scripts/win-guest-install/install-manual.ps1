# Copy files to temp install path.
mkdir $env:USERPROFILE\temp-install\
cp -r D:\* $env:USERPROFILE\temp-install\
cd $env:USERPROFILE\temp-install\

# Extract guestutil zip files.
Get-ChildItem $env:USERPROFILE\temp-install\ -Filter *.zip | Expand-Archive -DestinationPath $env:USERPROFILE\temp-install\ -Force

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

# Install IVSHMEM driver.
PNPUtil.exe /add-driver $env:USERPROFILE\temp-install\Win10\amd64\ivshmem.inf /install

# Install VirtIO network drivers.
cd $env:USERPROFILE\temp-install\
start-process .\virtio-win-guest-tools.exe -ArgumentList "/install /passive"

# Install Scream registry tweak.
cd $env:USERPROFILE\temp-install\
start-process .\scream-ivshmem-reg.bat

# Install Scream.
cd $env:USERPROFILE\temp-install\Install\
start-process .\Install-x64.bat

# Install Looking Glass.
cd $env:USERPROFILE\temp-install\
start-process .\looking-glass-host-setup.exe /S

# Disable all Windows power management timeouts.
powercfg /h off
powercfg /x -hibernate-timeout-ac 0
powercfg /x -hibernate-timeout-dc 0
#powercfg /x -disk-timeout-ac 0
#powercfg /x -disk-timeout-dc 0
powercfg /x -monitor-timeout-ac 0
powercfg /x -monitor-timeout-dc 0
Powercfg /x -standby-timeout-ac 0
powercfg /x -standby-timeout-dc 0

# Verify guest GPU driver (force install if vendorid == 10de && no driver).

# Allow unauthenticated Samba mount.
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters\" -Name "AllowInsecureGuestAuth" -Value 1
cp D:\mount-smb.bat $env:USERPROFILE'\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\'

# Prompt user for disabling explorer.exe (Y/n)?

# Install task-scheduler injection tool (LIME tasks).

# Shutdown Windows VM.
