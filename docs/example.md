# Pre-requisites

We are currently supporting both NVIDIA MDEV, and AMD GIM VFIO passthrough.
For this reason this tutorial covers both senarios.

## Installing Nim-Lang

``` sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

## Installing LibVFIO

``` sh
git clone https://git.arccompute.com/Arc-Compute/libvfio.git
cd libvfio
nimble install
mkdir /opt/arc/shells
cp example/* /opt/arc/shells
```

## Deploying LibVFIO

``` sh
arcd deploy
```

# NVIDIA

Here is the nvidia specific portion of the tutorial.

## Pre-requisites

Setup the MDEV Driver + create a vGPU.

## Create a VM

``` sh
arcd create $iso-file 20 --kernel=com.demo-mdev.arc --config=nvidia-mdev.yaml
```

Install what you need/how you need to for the mdev setup you have.

## Run the VM after the install.

``` sh
arcd start com.demo-mdev.arc --config=nvidia-mdev.yaml
```

# AMD

Here is the AMD specific portion of the tutorial.

## Pre-requisites

Setup the GIM Driver + create a vGPU.

## Create a VM

``` sh
arcd create $iso-file 20 --kernel=com.demo-amd.arc --config=gim.yaml
```

Install what you need/how you need to for the GIM setup you have.

## Run the VM after the install.

``` sh
arcd start com.demo-amd.arc --config=gim.yaml
```
