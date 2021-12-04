#!/bin/bash
#
# Reason: Installation of libvf.io
#

# Generate a driver signing key
mkdir -p ~/.ssh/
openssl req -new -x509 -newkey rsa:4096 -keyout ~/.ssh/module-private.key -outform DER -out ~/.ssh/module-public.key -nodes -days 3650 -subj "/CN=kernel-module"
echo "The following password will need to be used in enroll MOK on your next startup."
sudo mokutil --import ~/.ssh/module-public.key
sudo ./*$1.run --module-signing-secret-key=$HOME/.ssh/module-private.key --module-signing-public-key=$HOME/.ssh/module-public.key -q
