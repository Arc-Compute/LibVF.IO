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
  sudo apt update && sudo apt install -y mokutil dkms libglvnd-dev curl gcc cmake fonts-freefont-ttf libegl-dev libgl-dev libfontconfig1-dev libgmp-dev libspice-protocol-dev make nettle-dev pkg-config python3 python3-pip binutils-dev qemu qemu-utils qemu-kvm libx11-dev libxfixes-dev libxi-dev libxinerama-dev libxss-dev libwayland-bin libwayland-dev wayland-protocols gcc-mingw-w64-x86-64 nsis mdevctl git libpulse-dev libasound2-dev

  # Generate install Host Packages
  ./scripts/helpers/installHostConfig.sh $cpuModel

  # GRUB
  sudo update-grub
  # Restarting apparmor service
  sudo systemctl restart apparmor
  # Updating initramfs
  sudo update-initramfs -u -k all
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

kernel_release=$(uname -r)
major=`awk '{split($0, a, "."); print a[1]}' <<< $kernel_release`
minor=`awk '{split($0, a, "."); print a[2]}' <<< $kernel_release`

echo "MAJOR: $major"
echo "MINOR: $minor"

custom=""
if [[ ($major -eq 5) && ($minor -ge 12) ]];then
	echo "Modifying the driver to have the version 5.12 patches."
	custom="-custom"
	./*.run --apply-patch $currentPath/patches/twelve.patch
fi

lsmod | grep "nouveau"

if [ $? -ne 0 ]; then
  # Disabling Ubuntu error reporting (this spams the user in the presence of some mdev drivers)
  sudo systemctl mask apport.service
  sudo apt remove -y apport apport-symptoms

  # create Signing Key for Module
  ./scripts/helpers/createSSL.sh $custom
  rm $HOME/preinstall
else
  touch $HOME/preinstall
  echo "Nouveau was found, please reboot and run ./install.sh again, it will start from this point."
fi

sudo systemctl daemon-reload
