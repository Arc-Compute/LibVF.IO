#!/bin/bash
#
# Reason: Installation of libvf.io
#

# Install Linux Host Config

# Configure kernel boot parameters
echo "Updating kernel boot parameters."
# Intel users
if [[ $1 == *"GenuineIntel"* ]]; then
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"intel_iommu=on iommu=pt vfio_pci /g' /etc/default/grub
fi
# AMD users
if [[ $1 == *"AuthenticAMD"* ]]; then
  sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"amd_iommu=on iommu=pt vfio_pci /g' /etc/default/grub
fi

# Configure AppArmor policies, shared memory file permissions, and blacklisting non-mediated device drivers.
echo "Updating AppArmor policies."
sudo su root -c "mkdir -p /etc/apparmor.d/local/abstractions/ && echo '/dev/shm/kvmfr-* rw,' >> /etc/apparmor.d/local/abstractions/libvirt-qemu"
echo "Configuring shared memory device file permissions."
sudo su root -c "echo \"f /dev/shm/kvmfr-* 0660 $USER kvm -\" >> /etc/tmpfiles.d/10-looking-glass.conf"
echo "Blacklisting non-mediated device drivers."
sudo su root -c "echo '# Libvf.io GPU driver blacklist' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdgpu' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdkfd' >> /etc/modprobe.d/blacklist.conf"
