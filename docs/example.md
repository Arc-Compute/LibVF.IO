# Pre-requisites

We are currently supporting both NVIDIA MDEV, and AMD GIM VFIO passthrough.
For this reason this tutorial covers both senarios.

## Installing Nim-Lang

``` sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

## Installing LibVF.IO

Follow the installation guide here:
https://arccompute.com/blog/libvfio-commodity-gpu-multiplexing/

To pull the latest LibVF.IO source use the following commands:
``` sh
git clone https://git.arccompute.com/Arc-Compute/libvfio.git
cd libvfio
nimble install -y
```

## Deploying LibVF.IO

``` sh
arcd deploy
```

# NVIDIA

Here is the nvidia specific portion of the tutorial.

## Pre-requisites

Setup the MDEV Driver + create a vGPU.

## Create a VM

``` sh
arcd create nvidia-mdev.yaml $iso-file 20
```

Install what you need/how you need to for the mdev setup you have.

## Run the VM after the install.

``` sh
arcd start nvidia-mdev.yaml
```

# AMD

Here is the AMD specific portion of the tutorial.

## Pre-requisites

Setup the GIM Driver + create a vGPU.

## Create a VM

``` sh
arcd create amd-mdev.yaml $iso-file 20
```

Install what you need/how you need to for the GIM setup you have.

## Run the VM after the install.

``` sh
arcd start amd-mdev.yaml
```
