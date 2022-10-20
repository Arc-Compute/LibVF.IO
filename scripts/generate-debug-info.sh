#!/bin/bash

logFile=./logs/debug.log

# Make the log directory if it doesn't exist.
mkdir -p ./logs/

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

# Logging IOMMU Groups
echo "# IOMMU GROUPS START" >> $logFile
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done >> $logFile
echo "# IOMMU GROUPS END" >> $logFile

# Logging lsmod
echo "# LSMOD START" >> $logFile
lsmod >> $logFile
echo "# LSMOD END" >> $logFile
