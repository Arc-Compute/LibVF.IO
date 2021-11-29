#!/bin/bash

logFile=./logs/debug.log

# Dumping uname to log
uname -a >> $logFile

# Dumping CPU info
cat /proc/cpuinfo >> $logFile

# Dumping GRUB config to log
cat /etc/default/grub >> $logFile 

# Dumping lspci -vvvn
sudo lspci -vvvn >> $logFile

# Dumping IOMMU Groups to log
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done >> $logFile
