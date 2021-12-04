#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Installation of libvf.io
#

# Place optional driver packages in the optional directory before running this installation script

# Current shell path
currentPath=$(pwd)
# CPU Model
cpuModel=$(cat /proc/cpuinfo | grep vendor | head -n1)

if [ ! -f "$HOME/preinstall" ]; then

  sudo usermod -a -G kvm $USER

  # Install base utilities and build dependencies
  yay -Syu && yay -S "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse

  # Generate install Host Packages
  ./scripts/helpers/installHostConfig.sh $cpuModel

  # GRUB
  sudo grub-mkconfig -o /boot/grub/grub.cfg
  # Restarting apparmor service
  sudo systemctl restart apparmor
  # Updating initramfs
  sudo mkinitcpio -P
  # rmmod nouveau
  sudo rmmod nouveau

  # Generate install Host Packages
  ./scripts/helpers/installHostPackages.sh $currentPath

  # Generate introspection Rom for guest VM
  ./scripts/generate-introspection-files.sh
fi

if [ ! -f $currentPath/optional/*.run ]; then
	echo "Optional drivers not found."
	exit 0
fi

cd $currentPath/optional
chmod 755 *.run

# Check kernel version
kernel_release=$(uname -r)
major=`awk '{split($0, a, "."); print a[1]}' <<< $kernel_release`
minor=`awk '{split($0, a, "."); print a[2]}' <<< $kernel_release`
echo "MAJOR: $major"
echo "MINOR: $minor"

# If kernel version is 5.12 or greater apply patch file to optional package
custom=""
if [[ ($major -eq 5) && ($minor -ge 12) ]];then
	echo "Modifying the driver to have the version 5.12 patches."
	custom="-custom"
	./*.run --apply-patch $currentPath/patches/twelve.patch
fi

lsmod | grep "nouveau"

if [ $? -ne 0 ]; then
  # create Signing Key for Module
  ./scripts/helpers/createSSL.sh $custom
  rm $HOME/preinstall
else
  touch $HOME/preinstall
  echo "Nouveau was found, please reboot and run ./install.sh again, it will start from this point."
fi

# Reload systemd daemons
sudo systemctl daemon-reload
