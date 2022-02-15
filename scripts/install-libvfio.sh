#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Installation of libvf.io
#

full_path=$(realpath $0)
script_dir_path=$(dirname $full_path)
cd $script_dir_path/..

source $script_dir_path/funcs-libvfio.sh

## Place optional driver packages in the optional directory before running this installation script

# Prevents user from running script with root
root_kick
# Ensures script is ran from proper directory
check_dir
# Checks which distribution user is using
check_distro

echo
echo "Running libvfio install script for $distro distribution"
echo

# Checks if first stage of install script is complete
pt2_check

# Adds user to KVM Group
add_kvm_group
# Updates packages
distro_update
# Installs libvfio dependencies
add_depen

# Looking Glass and AppArmor Policies and Shared memory permissions
mem_permissions
add_policies
restart_apparmor

# Configure kernel boot parameters
add_boot_param
# Blacklisting non-mediated device drivers
blacklist_drivers
# Updating Initramfs
update_initramfs

# Installing Choosenim
install_choosenim
# Compile and install libvfio
install_libvfio

# Download, compile & install Looking Glass beta 4 sources
dl_lookingglass
install_lookingglass

# Download and install scream sources
get_scream
# Install and configure introspection files
get_introspection

# Create SMB resources
create_smb

# Deploying arcd (libvfio component)
arcd_deploy

# Rmmod Nouveau
rm_nouveau

# Check if nouveau is unloaded (pc rebooted)
# IF no, prime system to continue where install script left off after reboot
# IF yes, patch NV optional driver according to kernel version and install
pt1_end


# Reload systemd daemons
sudo systemctl daemon-reload
exit
