#!/bin/bash
#
# Reason: Installation of libvf.io
#

# Generate introspection files
compileSandbox=$(echo ~)"/.cache/libvf.io/compile/"

# Download Looking Glass beta 4 sources
rm -rf $compileSandbox && mkdir $compileSandbox && cd $compileSandbox
rm -rf LookingGlass
git clone -b Release/B4 --recursive https://github.com/gnif/LookingGlass/
cd LookingGlass

# Compile & install Looking Glass sources
mkdir client/build && mkdir host/build
cd client/build
cmake ../
make
#sudo make install

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
#sudo make install

# Generate guest introspection files
mkdir -p $compileSandbox/client && cd $compileSandbox/client
rm -rf $HOME/.local/libvf.io/introspection-installations
mkdir -p $HOME/.local/libvf.io/introspection-installations
# get IVSHMEM driver for LG
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip
# get Scream Sound Driver for Guest
wget https://github.com/duncanthrax/scream/releases/download/3.8/Scream3.8.zip
# get Spice guest Tools for Clipboard functions
wget https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe
# get latest stable guest drivers
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

# Extract drivers from ISO
SCRATCH=$(mktemp -d)
mkdir -p virtio-win
sudo mount virtio-win.iso $SCRATCH
cp -r $SCRATCH/* virtio-win
sudo umount $SCRATCH
rm -rf "$SCRATCH" virtio-win.iso

cp $HOME/.cache/libvf.io/compile/LookingGlass/host/build/platform/Windows/looking-glass-host-setup.exe ./
echo "REG ADD HKLM\SYSTEM\CurrentControlSet\Services\Scream\Options /v UseIVSHMEM /t REG_DWORD /d 2" >> scream-ivshmem-reg.bat

# Linux Host Installer to be save - maybe needed
mkdir -p $compileSandbox/host && cd $compileSandbox/host
cp $HOME/.cache/libvf.io/compile/LookingGlass/client/build/looking-glass-client ./
cp $HOME/.cache/libvf.io/compile/scream/Receivers/unix/build/scream ./

rm -rf $compileSandbox/scream
rm -rf $compileSandbox/LookingGlass

# Move Files
cd $compileSandbox
cp -r client/* $HOME/.local/libvf.io/introspection-installations
cd $HOME/.local/libvf.io/
mkisofs -A introspection-installations.rom -l -allow-leading-dots -allow-lowercase -allow-multidot -relaxed-filenames -d -D -o ./introspection-installations.rom introspection-installations
cp introspection-installations.rom ~/.config/arc/
