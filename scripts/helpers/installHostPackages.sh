#!/bin/bash
#
# Reason: Installation of libvf.io
#

# Install choosenim
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.bashrc
export PATH=$HOME/.nimble/bin:$PATH
choosenim update stable

# Compile and install libvf.io
cd $0
nimble install -y
rm ./arcd

# Deploying arcd (libvf.io component)
mkdir -p ~/.local/libvf.io/
arcd deploy --root=$HOME/.local/libvf.io/
