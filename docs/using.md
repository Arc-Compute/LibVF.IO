# SYNOPSIS
**arcd start** `KERNEL [ADDITIONAL_STATES ...] [--root=ROOT_PATH] [--config=CONFIG_PATH]`

**arcd create** `ISO_FILE SIZE [--root=ROOT_PATH] [--config=CONFIG_PATH]`

**arcd stop** `UUID`

**arcd ls** `[kernels|states|apps|all]`

**arcd ps** `[UUID]`

# COMMANDS
## start
Starts VM

Supply with kernel and optionally additional states

`arcd start com.ubuntu-20_04.3-desktop-amd64.arc`

## create
Creates a new kernel

Supply with iso file and size in Megabytes

`arcd create ubuntu-20.04.3-desktop-amd64.iso 12000`

## stop
Stops VM

Supply with UUID

`arcd stop b01f327a-c9d4-4c1c-ab62-3144938f207b`

## ls
Prints a list of available containers

Optional arguments kernels, states, apps, all (default)

`arcd ls kernels`

## ps
Prints details about running containers

Optionally supply with UUID or partial UUID to get more informative output

`arcd ps`

# Options
## --root
Specifies root directory

`arcd create ubuntu-20.04.3-desktop-amd64.iso 12000 --root=/opt/arc`

## --config
Specifies config file to be used

`arcd start com.ubuntu-20_04.3-desktop-amd64.arc --config=~/arcd/custom_config.yaml`

## --save
Saves the new VM.

`arcd start --config=custom_config.yaml --save`
