#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Standalone installation of GVM components.
#


full_path=$(realpath $0)
script_dir_path=$(dirname $full_path)
cd $script_dir_path/..

# Check for command line flags
arg0=$(basename "$0" .sh)
blnk=$(echo "$arg0" | sed 's/./ /g')


source $script_dir_path/funcs-libvfio.sh

## Place optional driver packages in the optional directory before running this installation script

# Prevents user from running script with root
root_kick
# Ensures script is ran from proper directory
check_dir
# Runs functions based off of optional install script flags
user_flags "$@"
# Checks which distribution user is using
check_distro

echo
echo "Running LibVF.IO install script for $distro distribution"
echo

# Updates packages
distro_update
# Installs libvfio dependencies
add_depen

# Configure kernel boot parameters
add_boot_param
# Blacklisting non-mediated device drivers
blacklist_drivers
# Updating Initramfs
update_initramfs


# Cleanup unnecesary/conflicting files
sandbox_and_old_driver_cleanup

# Rmmod Nouveau
rm_nouveau

# Check if nouveau is unloaded (pc rebooted)
# IF no, prime system to continue where install script left off after reboot
# IF yes, patch NV optional driver according to kernel version and install
pt1_end


# Reload systemd daemons
sudo systemctl daemon-reload
exit
