#!/bin/bash

logFile=./logs/debug.log

# Make the log directory if it doesn't exist.
mkdir -p ./logs/

# Logging /usr/bin/ binaries
echo "# /usr/bin/ BINARIES START" >> $logFile
ls /usr/bin/ >> $logFile
echo "# /usr/bin/ BINARIES END" >> $logFile

# Logging ~/.local/nimble/bin/ binaries
echo "# ~/.local/nimble/bin/ BINARIES START" >> $logFile
ls ~/.local/nimble/bin/ >> $logFile
echo "# ~/.local/nimble/bin/ BINARIES END" >> $logFile

# Logging ~/.local/libvf.io/
echo "# ~/.local/libvf.io/ START" >> $logFile
ls ~/.local/libvf.io/ >> $logFile
echo "# ~/.local/libvf.io/ END" >> $logFile

# Logging ~/.config/arc/
echo "# ~/.config/arc/ START" >> $logFile
ls ~/.config/arc/ >> $logFile
echo "# ~/.config/arc/ END" >> $logFile

# Logging IOMMU Groups
echo "# IOMMU GROUPS START" >> $logFile
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done >> $logFile
echo "# IOMMU GROUPS END" >> $logFile

# Logging gvm-post.service status
echo "# GVM-user gvm-post.service START" >> $logFile
systemctl status gvm-post.service >> $logFile
echo "# GVM-user gvm-post.service END" >> $logFile

# Logging GVM-user types
echo "# GVM-user GENERATE VGPU TYPES START" >> $logFile
cat /etc/gvm/user/generate-vgpu-types.toml >> $logFile
echo "# GVM-user GENERATE VGPU TYPES END" >> $logFile

# Logging mdevctl types
echo "# MDEVCTL TYPES START" >> $logFile
mdevctl types >> $logFile
echo "# MDEVCTL TYPES END" >> $logFile

# Logging GVM unit test 'test-device'
echo "# GVM-user TEST-DEVICE START" >> $logFile
sudo test-device >> $logFile
echo "# GVM-user TEST-DEVICE END" >> $logFile 

# Logging GVM unit test 'test-nvidia-api'
echo "# GVM-user TEST-NVIDIA-API START" >> $logFile 
sudo test-nvidia-api >> $logFile
echo "# GVM-user TEST-NVIDIA-API END" >> $logFile 

# Logging GVM unit test 'test-nvidia-manager'
echo "# GVM-user TEST-NVIDIA-MANAGER START" >> $logFile 
sudo test-nvidia-manager >> $logFile
echo "# GVM-user TEST-NVIDIA-MANAGER END" >> $logFile 

# Logging uname -a
echo "# UNAME START" >> $logFile
uname -a >> $logFile
echo "# UNAME END" >> $logFile

# Logging CPU info
echo "# CPUINFO START" >> $logFile
cat /proc/cpuinfo >> $logFile
echo "# CPUINFO END" >> $logFile

# Logging GRUB config
echo "# GRUB START" >> $logFile
cat /etc/default/grub >> $logFile 
echo "# GRUB END" >> $logFile

# Logging lspci -vvvn
echo "# LSPCI START" >> $logFile
sudo lspci -vvvn >> $logFile
echo "# LSPCI END" >> $logFile

# Logging lsmod
echo "# LSMOD START" >> $logFile
lsmod >> $logFile
echo "# LSMOD END" >> $logFile
