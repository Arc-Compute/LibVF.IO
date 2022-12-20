#!/bin/bash

logFile=./logs/debug.log
exec &>> ./$logFile

# Make the log directory if it doesn't exist.
mkdir -p ./logs/
truncate -s 0 $logFile  # clean it up if already run

# Logging /usr/bin/ binaries
echo "# /usr/bin/ BINARIES START"
ls /usr/bin/
echo "# /usr/bin/ BINARIES END"

# Logging ~/.local/nimble/bin/ binaries
echo "nimble BINARIES START"
DIR=`which nimble | xargs dirname`
echo "Directory: $DIR"
ls $DIR
echo "nimble BINARIES END"

# Logging ~/.local/libvf.io/
echo "# ~/.local/libvf.io/ START"
ls ~/.local/libvf.io/
echo "# ~/.local/libvf.io/ END"

# Logging ~/.config/arc/
echo "# ~/.config/arc/ START"
ls ~/.config/arc/
echo "# ~/.config/arc/ END"

# Logging IOMMU Groups
echo "# IOMMU GROUPS START"
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done
echo "# IOMMU GROUPS END"

# Logging gvm-post.service status
echo "# GVM-user gvm-post.service START"
systemctl status gvm-post.service
echo "# GVM-user gvm-post.service END"

# Logging GVM-user types
echo "# GVM-user GENERATE VGPU TYPES START"
cat /etc/gvm/user/generate-vgpu-types.toml
echo "# GVM-user GENERATE VGPU TYPES END"

# Logging mdevctl types
echo "# MDEVCTL TYPES START"
sudo mdevctl types
echo "# MDEVCTL TYPES END"

# Logging GVM unit test 'test-device'
echo "# GVM-user TEST-DEVICE START"
sudo test-device
echo "# GVM-user TEST-DEVICE END"

# Logging GVM unit test 'test-nvidia-api'
echo "# GVM-user TEST-NVIDIA-API START"
sudo test-nvidia-api
echo "# GVM-user TEST-NVIDIA-API END"

# Logging GVM unit test 'test-nvidia-manager'
echo "# GVM-user TEST-NVIDIA-MANAGER START"
sudo test-nvidia-manager
echo "# GVM-user TEST-NVIDIA-MANAGER END"

# Logging uname -a
echo "# UNAME START"
uname -a
echo "# UNAME END"

# Logging CPU info
echo "# CPUINFO START"
cat /proc/cpuinfo
echo "# CPUINFO END"

# Logging GRUB config
echo "# GRUB START"
cat /etc/default/grub
echo "# GRUB END"

# Logging lspci -vvvn
echo "# LSPCI START"
sudo lspci -vvvn
echo "# LSPCI END"

# Logging lsmod
echo "# LSMOD START"
lsmod
echo "# LSMOD END"
