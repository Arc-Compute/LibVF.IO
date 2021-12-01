#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Installation of libvf.io
#

# Place optional driver packages in the optional directory before running this installation script

# CurrentUser
currentUser=$USER
# CPU Model
cpuModel=$(cat /proc/cpuinfo | grep vendor | head -n1)
# OS
osName=$(cat /etc/os-release | grep NAME= | head -n1)
# Current shell path
currentPath=$(pwd)
# Compile sandbox path
compileSandbox=$(echo ~)"/.cache/libvf.io/compile/"

if [ ! -f "$HOME/preinstall" ]; then

  sudo usermod -a -G kvm $USER

  # Install base utilities and build dependencies
  yay -Syu && yay -S "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse

  # Configure kernel boot parameters
  echo "Updating kernel boot parameters."
  # Intel users
  if [[ $cpuModel == *"GenuineIntel"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"intel_iommu=on iommu=pt vfio_pci /g' /etc/default/grub
  fi
  # AMD users
  if [[ $cpuModel == *"AuthenticAMD"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"amd_iommu=on iommu=pt vfio_pci /g' /etc/default/grub
  fi
  # GRUB 
  sudo grub-mkconfig -o /boot/grub/grub.cfg

  # Configure AppArmor policies, shared memory file permissions, and blacklisting non-mediated device drivers.
  echo "Updating AppArmor policies."
  sudo su root -c "mkdir -p /etc/apparmor.d/local/abstractions/ && echo '/dev/shm/kvmfr-* rw,' >> /etc/apparmor.d/local/abstractions/libvirt-qemu"
  echo "Configuring shared memory device file permissions."
  sudo su root -c "echo \"f /dev/shm/kvmfr-* 0660 $currentUser kvm -\" >> /etc/tmpfiles.d/10-looking-glass.conf"
  echo "Blacklisting non-mediated device drivers."
  sudo su root -c "echo '# Libvf.io GPU driver blacklist' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdgpu' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdkfd' >> /etc/modprobe.d/blacklist.conf"
  # Restarting apparmor service
  sudo systemctl restart apparmor
  # Updating initramfs
  sudo mkinitcpio -p linux-lts
  # rmmod nouveau
  sudo rmmod nouveau

  # Install choosenim
  curl https://nim-lang.org/choosenim/init.sh -sSf | sh
  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.bashrc
  export PATH=$HOME/.nimble/bin:$PATH
  choosenim update stable

  # Compile and install libvf.io
  cd $currentPath
  nimble install -y
  rm ./arcd

  # Deploying arcd (libvf.io component)
  mkdir -p ~/.local/libvf.io/
  arcd deploy --root=$HOME/.local/libvf.io/

  # Download Looking Glass beta 4 sources
  mkdir -p $compileSandbox
  cd $compileSandbox
  rm -rf LookingGlass
  git clone --recursive https://github.com/gnif/LookingGlass/
  cd LookingGlass
  git checkout Release/B4

  # Compile & install Looking Glass sources
  mkdir client/build
  mkdir host/build
  cd client/build
  cmake ../
  make
  sudo make install

  # Cause we cannot use looking glass host binary
  cd ../../host/build
  cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw64.cmake ..
  make
  cd platform/Windows
  makensis installer.nsi
  
  # Download Scream sources
  cd $compileSandbox
  git clone https://github.com/duncanthrax/scream/
  cd scream/Receivers/unix

  # Compile & install scream sources
  mkdir build && cd build
  cmake ..
  make
  sudo make install

  # Generate guest introspection files
  rm -rf $HOME/.local/libvf.io/introspection-installations
  mkdir -p $HOME/.local/libvf.io/introspection-installations
  wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip
  wget https://github.com/duncanthrax/scream/releases/download/3.8/Scream3.8.zip
  cp $HOME/.cache/libvf.io/compile/LookingGlass/host/build/platform/Windows/looking-glass-host-setup.exe ./
  echo "REG ADD HKLM\SYSTEM\CurrentControlSet\Services\Scream\Options /v UseIVSHMEM /t REG_DWORD /d 2" >> scream-ivshmem-reg.bat
  cp -r * $HOME/.local/libvf.io/introspection-installations
  cd $HOME/.local/libvf.io/
  mkisofs -A introspection-installations.rom -l -allow-leading-dots -allow-lowercase -allow-multidot -relaxed-filenames -d -D -o ./introspection-installations.rom introspection-installations
  cp introspection-installations.rom ~/.config/arc/
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
  # Generate a driver signing key
  mkdir -p ~/.ssh/
  openssl req -new -x509 -newkey rsa:4096 -keyout ~/.ssh/module-private.key -outform DER -out ~/.ssh/module-public.key -nodes -days 3650 -subj "/CN=kernel-module"
  echo "The following password will need to be used in enroll MOK on your next startup."
  sudo mokutil --import ~/.ssh/module-public.key
  sudo ./*$custom.run --module-signing-secret-key=$HOME/.ssh/module-private.key --module-signing-public-key=$HOME/.ssh/module-public.key -q
  rm $HOME/preinstall
else
  touch $HOME/preinstall
  echo "Nouveau was found, please reboot and run ./install.sh again, it will start from this point."
fi

# Reload systemd daemons
sudo systemctl daemon-reload
