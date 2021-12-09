#!/bin/bash
#
# Copyright: 2666680 Ontario Inc
# Reason: Uninstallation of libvf.io
#

source ./scripts/funcs-libvfio.sh

# CPU Model
cpuModel=$(cat /proc/cpuinfo | grep vendor | head -n1)
# Current shell path
currentPath=$(pwd)


root_kick
check_dir
check_distro

echo Running uninstall script for $distro distribution.
echo

#KVM Group
read -p "Remove $USER from kvm group? (y or n): " a_kvm
if [[ $a_kvm == "y" ]];then
  rm_kvm_group
  echo done
  echo
else
  echo "ok, so no."
  echo
fi

#Dependency Packages
read -p "Remove installed libvfio $distro dependencies? (y or n): " a_depen
if [[ $a_depen == "y" ]];then
  rm_depen
  echo done
  echo
else
  echo "ok, so no."
  echo
fi

#Libvf.io and lookingglass
read -p 'Remove libvf.io and looking-glass stuff? (y or n): ' a_stuff
if [[ $a_stuff == "y" ]];then
  rm_stuff
  echo done
  echo
else
  echo "ok, so no."
  echo
fi

#Choosenim and Nim
read -p 'Remove choosenim and nim? (y or n): ' a_nim
if [[ $a_nim == "y" ]];then
  rm_nim
  echo done
  echo
else
  echo "ok, so no."
  echo
fi

#Drivers and vfio
read -p 'Revert back to default driver and kernel boot parameters (y or n): ' a_driver
if [[ $a_driver == "y" ]];then
  read -p 'This require a reboot, are you sure? (y or n): ' a_driver_2
  if [[ $a_driver_2 == "y" ]];then
    def_driver
    echo done. a reboot will be required to finalize this part of the uninstallation.
    echo
  else
    echo "ok, so no."
    echo
  fi
else
  echo "ok, so no."
  echo
fi

#Libvfio main directory
read -p 'Remove the current libvfio Directory? (y or n): ' a_final
if [[ $a_final == "y" ]];then
  rm_main
  echo "done, libvfio directory removed and this uninstall script moved to ~/Downloads"
  echo
else
  echo "ok, so no."
  echo
fi

