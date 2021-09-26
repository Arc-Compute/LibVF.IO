# Commands

Here are the following commands/structure we use to interact with libvfio.

## Starting

To start a VM we use the following command:

**arcd start** `[KERNEL] [ADDITIONAL_STATES ...]`

Kernel images are stored in `$root/kernel/`, while state images are stored in
`$root/states/`.

Here are some examples of such a command:

``` sh
arcd start com.ubuntu.arc photogrammetry-drive.arc machine-learning.qcow2
arcd start --config=ml.yaml
arcd start
```

If no arguments are passed, the kernel and additional states will be taken
from either the passed config file, home directory config, systemwide config,
or the default config we generate.

## Creating

To create a VM we use the following command:

**arcd create** `[ISO_FILE] [SIZE]`

This is used to install a new kernel image using an iso.

Here are some examples of such a command:

``` sh
arcd create ubuntu.iso 20
arcd create windows.iso
arcd create --config=ml.yaml
arcd create
```

NOTE: Size is in GBs.

If no arguments are passed, the iso file and size will be taken from either
the passed config file, home directory config, systemwide config, or the
default config we generate.

## Stopping

Stopping a VM can be done as follows:

**arcd stop** `UUID`

Some examples are:

``` sh
arcd stop $UUID
arcd stop $UUID --config=ml.yaml
arcd stop --data=$root $UUID
```

## Listing Possible Stuff

Prints a list of available containers.

Optional arguments kernels, states, apps, all (default).

**arcd ls** `[kernels|states|apps|all]`

Some examples include:

``` sh
arcd ls
arcd ls kernels
arcd ls states
arcd ls apps
arcd ls all
```

## Listing Running VMs

Prints details about running containers

Optionally supply with UUID or partial UUID to get more informative output

Example:

``` sh
arcd ps
arcd ps 0a
```

# Options

All these commands have the following additional options that can be added
to them.

## Root

Specifying where the root directory of the libvfio deployment is located, can
be overwritten with the `root` flag.

## Config

Configuration file to use instead can be overwritten with the `config` flag.

## Save

If you want to save the output of this back into the base kernel you can set
that behaviour using the `save` flag.

## Disable Copy

The copy command can take a while, if you are ok with destroying the base
kernel, you can use the `no-copy` flag.

## Disable Initial Config

If you want to only use our default configuration use the `no-user-preload`
flag.

## Kernel

If you want to overwrite default kernel used for some reason you can use the
`kernel` flag.

NOTE: This flag is only really enabled for the create command.
