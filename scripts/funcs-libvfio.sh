#!/bin/bash
#
# Copyright: 2666680 Ontario Inc
# Reason: libvf.io bash functions
#

function root_kick() {
  if [[ $(/usr/bin/id -u) == 0 ]]; then
    echo "This script should not be run as root."
    exit
  fi

}

function check_dir() {
  if [ ! -f ./src/arcd.nim ];then
    echo "Run the script from the main libvf.io directory, using ./scripts/uninstall-libvfio.sh"
    exit
  else
    current_path=$(pwd)
  fi
}

function check_distro() {

  if [ -z ${other_distro+x} ];then
    other_distro="init"
  fi
  
  if [[ $other_distro == "init" ]];then
    uname_a=$(uname -a)
    uname_a_upper=$(echo $uname_a | tr '[:lower:]' '[:upper:]')

    # if detected distro is not recognized
    case $uname_a_upper in
      *"FEDORA"*)	distro="Fedora";;
      *"UBUNTU"*)	distro="Ubuntu";;
      *"ARCH"*)	distro="Arch";;
      *)		echo What linux distribution are you running?
      			echo -e "Type '1' or 'Fedora'\nType '2' or 'Ubuntu'\nType '3' or 'Arch'\nType '4' or 'OTHER' "
      		read -p "Response: " a1_distro

      			a_distro=$(echo $a1_distro | tr '[:lower:]' '[:upper:]')
      			# user Input checks
      			if [ $a_distro == "1" ] || [ $a_distro == "FEDORA" ];then
      			  distro="Fedora"
      			  other_distro="n/a"
      			elif [ $a_distro == "2" ] || [ $a_distro == "UBUNTU" ];then
      			  distro="Ubuntu"
      			  other_distro="n/a"
      			elif [ $a_distro == "3" ] || [ $a_distro == "ARCH" ];then
      			  distro="Arch"
      			  other_distro="n/a"
      			elif [ $a_distro == "4" ] || [ $a_distro == "OTHER" ];then
      			  echo
      			  echo "Note: your distribution likely isnt supported yet."
      			  echo "Some feautures may not work properly."
      			  read -p "Your Distribution: " other_distro
      			  distro=$other_distro
      			else
      			  echo "Make a valid choice"
      			  exit
      			fi
    esac
  fi
  # message displayed in case when distro unsupported
  case_dist_msg="Your distro, $distro, is not one that is supported (Fedora, Ubuntu, Arch). Unsure how to proceed."
}

function set_sandbox_dir {
  compile_sandbox=$(echo ~)"/.cache/libvf.io/compile/"
  mkdir -p $compile_sandbox
  cd $compile_sandbox
}

function add_kvm_group {
  sudo usermod -a -G kvm $USER 
}

function distro_update() {
  check_distro
  case $distro in
    "Fedora")	sudo dnf upgrade -y;;
    "Ubuntu")	sudo apt update -y; sudo apt upgrade -y;;
    "Arch")     echo
                echo "Arch users will require yay to update Arch and install libvf.io dependencies."
                read -p "Press 'Enter' key to acknowledge and proceed..."
    		yay -Syu;;
    *)		echo $case_dist_msg;;
  esac
}

function ls_depen() {
  lookingglass_dep_fedora=" binutils-devel cmake texlive-gnu-freefont fontconfig-devel SDL2-devel SDL2_ttf-devel spice-protocol libX11-devel nettle-devel wayland-protocols-devel libXScrnSaver-devel libXfixes-devel libXi-devel wayland-devel libXinerama-devel "
  lookingglass_dep_ubuntu="  " 
  lookingglass_dep_arch="  "
  xyz_dep_fedora="  "
}

function add_depen() {
  check_distro
  ls_depen
  case $distro in
    "Fedora") 	sudo dnf install -y nsis plasma-wayland-protocols dkms mingw64-gcc $lookingglass_dep_fedora qemu patch kernel-devel openssl;;
    "Ubuntu")	sudo apt install -y packer mokutil dkms libglvnd-dev curl gcc cmake fonts-freefont-ttf libegl-dev libgl-dev libfontconfig1-dev libgmp-dev libspice-protocol-dev make nettle-dev pkg-config python3 python3-pip binutils-dev qemu qemu-utils qemu-kvm libx11-dev libxfixes-dev libxi-dev libxinerama-dev libxss-dev libwayland-bin libwayland-dev wayland-protocols gcc-mingw-w64-x86-64 nsis mdevctl git libpulse-dev libasound2-dev;;
    "Arch")	yay -S "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse wget;;
     *)		echo $case_dist_msg;;
  esac
}

function add_boot_param() {
  check_distro
  cpuModel=$(cat /proc/cpuinfo | grep vendor | head -n1)
  echo "Updating kernel boot parameters."
  # Intel users
  if [[ $cpuModel == *"GenuineIntel"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"intel_iommu=on iommu=pt vfio_pci vfio mdev /g' /etc/default/grub
  # AMD users
  elif [[ $cpuModel == *"AuthenticAMD"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"amd_iommu=on iommu=pt vfio_pci vfio mdev /g' /etc/default/grub
  fi
  # GRUB
  case $distro in 
    "Fedora")	sudo grub2-mkconfig -o /boot/grub2/grub.cfg;;
    "Ubuntu")	sudo update-grub;;
    "Arch")	sudo grub-mkconfig -o /boot/grub/grub.cfg;;
     *)		echo $case_dist_msg;;
  esac
}


function add_policies() {
  if [ $distro == "Ubuntu" ] || [ $distro == "Arch" ];then
    # Configure AppArmor policies, shared memory file permissions, and blacklisting non-mediated device drivers.
    echo "Updating AppArmor policies."
    sudo su root -c "mkdir -p /etc/apparmor.d/local/abstractions/ && echo '/dev/shm/kvmfr-* rw,' >> /etc/apparmor.d/local/abstractions/libvirt-qemu"
  fi
}

function mem_permissions() {
  echo "Configuring shared memory device file permissions."
  sudo su root -c "echo \"f /dev/shm/kvmfr-* 0660 $USER kvm -\" >> /etc/tmpfiles.d/10-looking-glass.conf"
}

function blacklist_drivers() {
  echo "Blacklisting non-mediated device drivers."
  sudo su root -c "echo '# Libvf.io GPU driver blacklist' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdgpu' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdkfd' >> /etc/modprobe.d/blacklist.conf"

}  

function restart_apparmor() {
  # Restarting apparmor service
  if [ $distro == "Ubuntu" ] || [ $distro == "Arch" ];then
    sudo systemctl restart apparmor
  fi
}

function update_initramfs() {
  # Updating initramfs
  case $distro in
    "Fedora")	sudo dracut -fv --regenerate-all;;
    "Ubuntu")	sudo update-initramfs -u -k all;;
    "Arch")	sudo mkinitcpio -P;;
    *)		echo $case_dist_msg;;
  esac
}

function rm_nouveau() {
  sudo rmmod nouveau
}

function check_shell_fns() {
  shell_path=$SHELL
  case $shell_path in
    *zsh*)	shell_current="zsh"
			if [[ $shell_fn == "path nim" ]];then
			  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.zshrc
			elif [[ $shell_fn == "rm path nim" ]];then
			  sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.zshrc
			fi;;
    *bash*)	shell_current="bash"
 			if [[ $shell_fn == "path nim" ]];then
			  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.bashrc
			elif [[ $shell_fn == "rm path nim" ]];then
			  sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.bashrc 
			fi;;
    *fish*)	shell_current="fish"
		echo -e "\nWhat do FISH pray to?\n"
 			if [[ $shell_fn == "path nim" ]];then
			  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.config/fish/config.fish
			elif [[ $shell_fn == "path nim" ]];then
			  sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.config/fish/config.fish
			fi;;
    *csh*)	shell_current="csh"
 			if [[ $shell_fn == "path nim" ]];then
			  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.cshrc
			elif [[ $shell_fn == "rm path nim" ]];then
			  sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.cshrc
			fi;;
    *tcsh*)	shell_current="tcsh"
 			if [[ $shell_fn == "path nim" ]];then
			  echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.tcshrc
			elif [[ $shell_fn == "rm path nim" ]];then
			  sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.tcshrc
			fi;;
    *sh*)	shell_current="sh";;
    *)		echo "Cannot find your current shell"
  esac
  echo Shell detected: $shell_current.
  if [[ $shell_fn == "path nim" ]];then echo Added Nim to $shell_current shell path
  elif [[ $shell_fn == "rm path nim" ]];then echo Removed Nim from $shell_current shell path
  fi

  shell_fn=""
}

function install_choosenim() {
  if ! which nimble;then
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh
    shell_fn="path nim"
    check_shell_fns
    export PATH=$HOME/.nimble/bin:$PATH
    choosenim update stable --verbose
  fi
}

function install_libvfio() {
  # Compile and install libvf.io
  cd $current_path
  nimble install -y --verbose
  rm ./arcd
}

function dl_lookingglass() {
  set_sandbox_dir
  # Download Looking Glass beta 4 sources
  rm -rf LookingGlass
  curl -o lg.tar.gz https://looking-glass.io/artifact/B4/source
  tar -xvf lg.tar.gz
  mv looking-glass-B4 LookingGlass
}

function install_lookingglass() {
  # Compile & install Looking Glass sources
  set_sandbox_dir
  cd LookingGlass
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
  cd $current_path
}

function get_scream() {
  set_sandbox_dir
  # Download Scream sources
  git clone https://github.com/duncanthrax/scream/
  cd scream/Receivers/unix
  # Compile & install scream sources
  mkdir build && cd build
  cmake ..
  make
  sudo make install
  cd $current_path
}

function get_introspection() {
  set_sandbox_dir
  mkdir -p $HOME/.local/libvf.io/
  rm -rf $HOME/.local/libvf.io/introspection-installations
  mkdir -p $HOME/.local/libvf.io/introspection-installations
  wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip
  wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe
  wget https://github.com/duncanthrax/scream/releases/download/3.8/Scream3.8.zip
  cp $current_path/scripts/win-guest-install/install.ps1 ./
  cp $current_path/scripts/win-guest-install/enable-powershell.bat ./
  cp $HOME/.ssh/id_rsa.pub ./authorized_keys
  cp $HOME/.cache/libvf.io/compile/LookingGlass/host/build/platform/Windows/looking-glass-host-setup.exe ./
  echo "REG ADD HKLM\SYSTEM\CurrentControlSet\Services\Scream\Options /v UseIVSHMEM /t REG_DWORD /d 2" >> scream-ivshmem-reg.bat
  wget -O adksetup.exe "https://go.microsoft.com/fwlink/?linkid=2120254"
  wget -O virtio-win.iso "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.215-2/virtio-win-0.1.215.iso"
  cp $current_path/scripts/win-guest-install/*.ps1 .
  cp -r * $HOME/.local/libvf.io/introspection-installations
  cd $HOME/.local/libvf.io/
  mkisofs -A introspection-installations.rom -l -allow-leading-dots -allow-lowercase -allow-multidot -relaxed-filenames -d -D -o ./introspection-installations.rom introspection-installations
  mkdir -p ~/.config/arc/
  cp introspection-installations.rom ~/.config/arc/
  cp -r $HOME/.local/libvf.io/introspection-installations/ ~/.config/arc/
  cp $current_path/conf/smb.conf ~/.config/arc/
  cd $current_path
}

# Cause newer Arch requires a newer and unsupported driver
function arch_ignore_abi() {
  if [ $distro == "Arch" ]; then
    sudo su root -c "echo 'Section \"ServerFlags\"' >> /etc/X11/xorg.conf.d/50-IgnoreABI.conf && echo '        Option \"IgnoreABI\" \"1\"' >> /etc/X11/xorg.conf.d/50-IgnoreABI.conf && echo 'EndSection' >> /etc/X11/xorg.conf.d/50-IgnoreABI.conf"
  fi
}

function arcd_deploy() {
  # Deploying arcd (libvfio component)
  arcd deploy --root=$HOME/.local/libvf.io/
}

function check_optional_driver() {
  if [ ! -f $current_path/optional/*.run ]; then
    echo "Optional drivers not found."
    exit 0
  else 
    chmod 755 $current_path/optional/*.run
  fi
}


function check_k_version() {
  # Check kernel version
  kernel_release=$(uname -r)
  major=`awk '{split($0, a, "."); print a[1]}' <<< $kernel_release`
  minor=`awk '{split($0, a, "."); print a[2]}' <<< $kernel_release`
  echo "MAJOR: $major"
  echo "MINOR: $minor"
}

function patch_nv() {
  # Patch NV driver according to kernel version 
  check_k_version
  check_optional_driver
  cd $current_path
  cd ./optional #in order for uodated driver to be placed in 'optional' folder
  custom=""  
  if [[ ($major -eq 5) && ($minor -ge 14) ]];then
    echo "Modifying the driver to have the version 5.14/15 patches."
    custom="-custom"
    $current_path/optional/*.run --apply-patch $current_path/patches/fourteen.patch 
  elif [[ ($major -eq 5) && ($minor -eq 13) ]];then
    echo "Modifying the driver to have the version 5.13 patches."
    custom="-custom"
    $current_path/optional/*.run --apply-patch $current_path/patches/thirteen.patch 
  elif [[ ($major -eq 5) && ($minor -ge 12) ]];then
    echo "Modifying the driver to have the version 5.12 patches."
    custom="-custom"
    $current_path/optional/*.run --apply-patch $current_path/patches/twelve.patch 
  fi
  cd $current_path
}

function install_nv() {
  patch_nv
  arch_ignore_abi
  sudo modprobe vfio
  sudo modprobe mdev
  # Generate a driver signing key
  mkdir -p ~/.ssh/
  openssl req -new -x509 -newkey rsa:4096 -keyout ~/.ssh/module-private.key -outform DER -out ~/.ssh/module-public.key -nodes -days 3650 -subj "/CN=kernel-module"
  echo "The following password will need to be used in enroll MOK on your next startup."
  sudo mokutil --import ~/.ssh/module-public.key
  sudo $current_path/optional/*$custom.run --module-signing-secret-key=$HOME/.ssh/module-private.key --module-signing-public-key=$HOME/.ssh/module-public.key -q --no-x-check
}

# Check if nouveau is unloaded (pc rebooted)
# Install nvidia if nouveau is isn't loaded
function pt1_end() {
  # To ensure these are loaded before install driver install
  sudo modprobe vfio
  sudo modprobe mdev
  if ! lsmod | grep "nouveau";then
    install_nv
    echo "Install of Libvfio has been finalized!"
    echo "Reboot now to enroll MOK."
    if [ -f "$HOME/preinstall" ];then rm $HOME/preinstall;fi
  else
    touch $HOME/preinstall
    echo "Nouveau was found, please reboot and run ./install-libvfio.sh again, it will start from this point."
  fi
}

function pt2_check() {
  if [ -f "$HOME/preinstall" ] && [ -f "$HOME/.local/libvf.io/" ] && lsmod | grep "nouveau" ;then
    echo "Error, It seems you've been through the first part of install and reboot, but Nouveau is still loaded"
    echo "Try removing Nouveau manually, reboot, then run install script again to install NV drivers."
    exit
  elif [ -f "$HOME/preinstall" ] && [ ! -f "$HOME/.local/libvf.io/" ] && lsmod | grep "nouveau";then
    echo "Nouveau is still loaded, and you seem to be missing files that should've been added in Part 1 of libvfio install"
    echo "Try the install from the beginning. Otherwise submit an error report."
    rm $HOME/preinstall
    exit
  elif [ -f "$HOME/preinstall" ]; then
    install_nv
    echo "Install of Libvfio has been finalized! Reboot is necessary to enroll MOK."
    rm $HOME/preinstall
    exit
  fi
}



function rm_kvm_group() {
  check_distro
  case $distro in
    "Fedora")	sudo gpasswd -d $USER kvm;;
    "Ubuntu")	sudo deluser $USER kvm;;
    "Arch")	sudo gpasswd -d $USER kvm;;
  esac	
}

function rm_depen() {
  check_distro
  ls_depen 
  case $distro in
    "Fedora")	sudo dnf remove nsis plasma-wayland-protocols dkms mingw64-gcc $lookingglass_dep_fedora qemu patch kernel-devel openssl;;
    "Ubuntu")	sudo apt remove dkms libglvnd-dev curl gcc cmake libegl-dev libgl-dev libfontconfig1-dev libgmp-dev libspice-protocol-dev make nettle-dev python3-pip binutils-dev qemu qemu-utils qemu-kvm libx11-dev libxfixes-dev libxi-dev libxinerama-dev libxss-dev libwayland-bin libwayland-dev wayland-protocols gcc-mingw-w64-x86-64 nsis mdevctl libpulse-dev libasound2-dev;;
    #ubuntu present before libvfio install: mokutil fonts-freefont-ttf pkg-config python3
    "Arch")	yay -R "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse wget;;
    *)		echo $case_dist_msg;;
  esac
}

function rm_stuff() {
  rm -rf ~/.local/libvf.io
  rm -rf ~/.cache/libvf.io
  rm -rf ~/.config/arc
  sudo rm /etc/tmpfiles.d/10-looking-glass.conf
}

function rm_nim() {
  rm -rf ~/.choosenim
  rm -rf ~/.nimble
  rm -rf ~/.cache/nim
  shell_fn="rm path nim"
  check_shell_fns
}

function def_driver() {
  cpuModel=$(cat /proc/cpuinfo | grep vendor | head -n1)
  #GRUB
    if [[ $cpuModel == *"GenuineIntel"* ]]; then
    sudo sed -i 's/intel_iommu=on iommu=pt vfio_pci vfio mdev//g' /etc/default/grub
    sudo sed -i 's/intel_iommu=on iommu=pt vfio_pci//g' /etc/default/grub
  elif [[ $cpuModel == *"AuthenticAMD"* ]]; then
    sudo sed -i 's/amd_iommu=on iommu=pt vfio_pci vfio mdev//g' /etc/default/grub
    sudo sed -i 's/amd_iommu=on iommu=pt vfio_pci//g' /etc/default/grub
  else 
    echo cpu model?
    exit
  fi
  check_distro
  case $distro in
    "Fedora")	sudo grub2-mkconfig -o /boot/grub2/grub.cfg;;
    "Ubuntu")	sudo update-grub;;
    "Arch")	sudo grub-mkconfig -o /boot/grub/grub.cfg;;
    *)          echo $case_dist_msg;;
  esac
  #blacklist
  sudo sed -i 's/# Libvf.io GPU driver blacklist//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist nouveau//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist amdgpu//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist amdkfd//g' /etc/modprobe.d/blacklist.conf
  update_initramfs

  #uninstall nvidia driver
  sudo nvidia-uninstall

  #load nouveau driver
  sudo modprobe nouveau
  #Fedora unload vfio and mdev modules
  if [ $distro == "Fedora" ];then sudo modprobe -r vfio;    sudo modprobe -r mdev;  fi
}

function rm_main() {
  libvf=$(pwd)
  cd ..
  rm -rf $libvf
}


