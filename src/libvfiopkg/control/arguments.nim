#
# Copyright: 2666680 Ontario Inc.
# Reason: Creates commands to execute on the host system.
#
import strformat
import strutils
import options
import os

import ../types

const
  # Additional strings to help hide KVM status from the resources.
  MachineConfig = join(
    @["pc-q35-4.2",
      "accel=kvm",
      "usb=off",
      "vmport=off",
      "dump-guest-core=off"
    ],
    ","
  )
  CpuConfig = join(
    @["IvyBridge-IBRS",
      "ss=on",
      "vmx=on",
      "pcid=on",
      "hypervisor=on",
      "arat=on",
      "tsc-adjust=on",
      "umip=on",
      "md-clear=on",
      "stibp=on",
      "arch-capabilities=on",
      "ssbd=on",
      "xsaveopt=on",
      "pdpe1gb=on",
      "ibpb=on",
      "ibrs=on",
      "amd-stibp=on",
      "amd-ssbd=on",
      "skip-l1dfl-vmentry=on",
      "pschange-mc-no=on",
      "hv-vapic",
      "hv-spinlocks=0x1fff",
      "hv-vendor-id=1234567890ab",
      "kvm=off"
    ],
    ","
  )

proc runCommand*(command: Args): bool =
  ## runCommand - Helper to run a command.
  ##
  ## Inputs
  ## @command - Command to run.
  ##
  ## Returns
  ## result - If the command was successful or not.
  execShellCmd(join(@[command.exec] & command.args, " ")) == 0

func createKernel*(name: string, size: int): Args =
  ## createKernel - Creates a kernel image for the Arc Container.
  ##
  ## Inputs
  ## @name - Name of the kernel image.
  ## @size - Initial size of the container.
  ##
  ## Returns
  ## result - Arguments to create a kernel.
  result.exec = "qemu-img"
  result.args &= "create"
  result.args &= "-f"
  result.args &= "qcow2"
  result.args &= name
  result.args &= &"{size}G"

func changeSocketGroup*(sudo: bool, sockets: seq[string]): Args =
  ## changeSocketGroup - Changes the socket group to allow not to use sudo.
  ##
  ## Inputs
  ## @sudo - Do we use sudo?
  ## @sockets - Sockets to change.
  ##
  ## Returns
  ## result - Arguments to change the socket group.
  result.exec = "/usr/bin/chgrp"

  # If we need sudo
  if sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Set the group to KVM
  result.args &= "kvm"

  # Add all sockets
  result.args &= sockets

func changePermissions*(sudo: bool, sockets: seq[string]): Args =
  ## changePermissions - Changes the permission on the socket.
  ##
  ## Inputs
  ## @sudo - Do we use sudo?
  ## @sockets - Sockets to change.
  ##
  ## Returns
  ## result - Arguments to change the permissions for the sockets.
  result.exec = "/usr/bin/chmod"

  # If we need sudo
  if sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Set the group to KVM
  result.args &= "g+rwx"

  # Add all sockets
  result.args &= sockets


func qemuLaunch*(cfg: Config, uuid: string,
                 vfios: seq[Vfio], kernel: string,
                 install: bool, logDir: string,
                 sockets: seq[string]): Args =
  ## qemuLaunch - Generates a qemu command to be executed.
  ##
  ## Inputs
  ## @cfg - Configuration for the qemu launch.
  ## @uuid - UUID of the app.
  ## @vfios - List of VFIOs to put pass into the VM.
  ## @kernel - Kernel path.
  ## @install - Is this an installation?
  ## @logDir - Directory for logging.
  ## @sockets - Sockets to create.
  ##
  ## Returns
  ## result - Arguments to launch a kernel.
  func vfioArgs(device: Vfio): seq[string] =
    if isGpu(device):
      result &= "--device"
      result &= &"vfio-pci,host={device},multifunction=on,display=off"
      result &= "-mem-prealloc"

  let
    qemuLogFile = logDir / (uuid & "-session.txt")

  # executing target
  result.exec = "/bin/qemu-system-x86_64"

  # If we need sudo
  if cfg.sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Log file
  result.args &= "-D"
  result.args &= qemuLogFile

  # UUID - Necessary for NVidia MDEV support
  result.args &= "-uuid"
  result.args &= uuid

  # Machine settings needed for NVidia MDEV support
  result.args &= "-machine"
  result.args &= MachineConfig

  # Cpu settings needed for NVidia MDEV support
  result.args &= "-cpu"
  result.args &= CpuConfig

  # clock settings
  result.args &= "-rtc"
  result.args &= "clock=host,base=localtime"
  
  # RAM allocation
  result.args &= "-m"
  result.args &= $cfg.cpus.ramAlloc

  # CPU configuration
  result.args &= "-smp"
  result.args &= $cfg.cpus

  # Kernel path
  result.args &= "-hda"
  result.args &= kernel

  # Enable KVM
  result.args &= "--enable-kvm"

  # Set GPU vfio
  for vfio in vfios:
    result.args &= vfioArgs(vfio)

  # Enable sound
  result.args &= "--soundhw"
  result.args &= "all"

  # Enable QMP socket for all sockets.
  for socket in sockets:
    result.args &= "-qmp"
    result.args &= &"unix:{socket},server,nowait"

  # States
  for state in cfg.container.state:
    result.args &= "-hdd"
    result.args &= cfg.root / "states" / state

  # If it is being installed
  if install and isSome(cfg.container.iso):
    result.args &= "-cdrom"
    result.args &= get(cfg.container.iso)

  # Additional commands sent into the qemu command
  # NOTE: Start Process quotes these commands.
  for command in cfg.commands:
    let values = join(command.values, ",")
    result.args &= command.arg
    if values != "":
      result.args &= values
