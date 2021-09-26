# Deployment

This document serves as a deployment guide for running
the libvfio system directly on your device.

## Pre-requisites

To use libvfio, you need to ensure your user is part of
the KVM group in Linux. You can easily check if you are
part of this group by running the following command:

``` sh
groups | grep kvm
```

If there is no output to the above command, you are
not a member of the kvm group. We can run the following
script to create and add you to the kvm group:

``` sh
sudo groupadd kvm
sudo usermod -a -G kvm $USER
```

Now you need to relogin into the system to reload your
user's groups.

You will also need to pick a "data root" folder. This
is where the kernels/states get stored automatically.

## Deploying

To fully deploy this system, we need to simply run one
command:

``` sh
arcd deploy
```

If you previously deployed this but wish to rewrite the
configuration with the original default configuration
you can add the flag `--no-user-preload` to the deployment
command.

By default this deployment command attempts to populate the
data in `/opt/arc`, majority of users do not have this location
or have read/write access to this folder. For this reason you
can add a flag specifying where to place all the installation
components. This flag is as follows: `--root=/path/to/folder`

The folder structure for a libvfio deployment is [here](folders.md).
