#!/bin/bash
#
# Copyright: 2666680 Ontario Inc
# Reason: Uninstallation of libvf.io
#

full_path=$(realpath $0)
script_dir_path=$(dirname $full_path)
cd $script_dir_path/..

source $script_dir_path/funcs-libvfio.sh

# Prevents user from running script with root
root_kick
# Ensures script is ran from proper directory
check_dir
# Checks which distribution user is using
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
read -p 'Revert back to default graphics driver and kernel boot parameters (y or n): ' a_driver
if [[ $a_driver == "y" ]];then
  read -p 'This require a reboot, are you sure? (y or n): ' a_driver_2
  if [[ $a_driver_2 == "y" ]];then
    def_driver
    reboot_required='y'
    echo done. 
    echo
  else
    reboot_required='n'
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
  echo "done"
  echo
else
  echo "ok, so no."
  echo
fi

echo Uninstall of Libvf.io Complete. 
if [[ $reboot_required == 'y' ]]; then 
  echo "A reboot will be required to finalize this uninstall."
else
  echo "Your uninstall is complete."
fi
exit
