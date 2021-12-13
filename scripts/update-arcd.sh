#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Installation of libvf.io
#

full_path=$(realpath $0)
script_dir_path=$(dirname $full_path)
cd $script_dir_path/..

source $script_dir_path/funcs-libvfio.sh

root_check
check_dir

# Pulling latest from LibVF.IO
git pull

# Recompile & install arcd from updated sources
nimble install -y
