#
# Copyright: 2666680 Ontario Inc.
# Reason: Creates commands to execute on the host system.
#
import strformat
import strutils
import sequtils
import sugar
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
    @["host",
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
      "kvm=off",
      "topoext=on"
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
  ##
  ## Side Effects - Arbitrarily executes the command and checks return status.
  execShellCmd(join(@[command.exec] & command.args, " ")) == 0

func removeFiles*(files: seq[string]): Args =
  ## removeFiles - Mass removes a set of files using sudo.
  ##
  ## Inputs
  ## @files - List of files to remove
  ##
  ## Returns
  ## result - Argument to run to remove a set of files using sudo.
  result.exec = "/usr/bin/sudo"
  result.args &= "/bin/rm"
  result.args &= "-rf"
  result.args &= files

func sudoWriteFile*(data: string, path: string): Args =
  ## startMdev - Starts an mdevctl device.
  ##
  ## Inputs
  ## @data - Message data for file.
  ## @path - File to send message into.
  ##
  ## Returns
  ## result - Writes a file using sudo (super user)
  ##
  ## NOTE: Can only be run as sudo.
  result.exec = "/usr/bin/sudo"
  result.args &= "/usr/bin/su"
  result.args &= "-c"
  result.args &= &"\"echo '{data}' > {path}\""

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

func changeGroup*(sudo: bool, files: seq[string]): Args =
  ## changeGroup - Changes the files group to allow not to use sudo.
  ##
  ## Inputs
  ## @sudo - Do we use sudo?
  ## @files - Files to change.
  ##
  ## Returns
  ## result - Arguments to change the file group.
  result.exec = "/usr/bin/chgrp"

  # If we need sudo
  if sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Set the group to KVM
  result.args &= "kvm"

  # Add all files
  result.args &= files

func changePermissions*(sudo: bool, files: seq[string]): Args =
  ## changePermissions - Changes the permission on the file.
  ##
  ## Inputs
  ## @sudo - Do we use sudo?
  ## @files - Files to change.
  ##
  ## Returns
  ## result - Arguments to change the permissions for the files.
  result.exec = "/usr/bin/chmod"

  # If we need sudo
  if sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Set the group to KVM
  result.args &= "g+rwx"

  # Add all files
  result.args &= files


func qemuLaunch*(cfg: Config, uuid: string,
                 vfios: seq[Vfio], mdevs: seq[Mdev],
                 kernel: string, install: bool,
                 logDir: string, sockets: seq[string]): Args =
  ## qemuLaunch - Generates a qemu command to be executed.
  ##
  ## Inputs
  ## @cfg - Configuration for the qemu launch.
  ## @uuid - UUID of the app.
  ## @vfios - List of VFIOs to put pass into the VM.
  ## @mdevs - List of MDevs to pass into the VM.
  ## @kernel - Kernel path.
  ## @install - Is this an installation?
  ## @logDir - Directory for logging.
  ## @sockets - Sockets to create.
  ##
  ## Returns
  ## result - Arguments to launch a kernel.
  func vfioArgs(device: Vfio): seq[string] =
    if isGpu(device):
      result &= "-device"
      result &= &"vfio-pci,host={device},multifunction=on,display=off"
      result &= "-mem-prealloc"

  func mdevArgs(device: Mdev): seq[string] =
    const mdevBase = "/sys/bus/mdev/devices"
    result &= "-device"
    result &=
       &"vfio-pci,id={device.devId},sysfsdev={mdevBase}/{device.uuid},display=off"

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

  # Causes issues with mdev devices.
  result.args &= "-no-hpet"

  # NOTE: We do not allow installing in no graphics mode just yet.
  if cfg.nographics and not install:
    # No graphics flag
    result.args &= "-nographic"

    # Sets the VGA output to nothing
    result.args &= "-vga"
    result.args &= "none"

  # If spice server is enabled.
  if cfg.spice and not install:
    # Additional no defaults flags which cause issues with MDev support
    result.args &= "-serial"
    result.args &= "none"

    result.args &= "-parallel"
    result.args &= "none"

    # Additional mouse for USB redirects from spice
    result.args &= "-device"
    result.args &= "qemu-xhci,p2=15,p3=15,id=usb"

    # VirtIO Serial PCI Device
    result.args &= "-device"
    result.args &= "virtio-serial-pci,id=virtio-serial0"

    # Chardev
    result.args &= "-chardev"
    result.args &= "pty,id=charserial0"

    # ISA Serial device
    result.args &= "-device"
    result.args &= "isa-serial,chardev=charserial0,id=serial0"

    # SPICE Char Channel
    result.args &= "-chardev"
    result.args &= "spicevmc,id=charchannel0,name=vdagent"

    # Virtual Serial Port
    result.args &= "-device"
    result.args &=
      "virtserialport,bus=virtio-serial0.0,nr=1,chardev=charchannel0,id=channel0,name=com.redhat.spice.0"

    # Spice port
    result.args &= "-spice"
    result.args &=
      "port=5900,addr=127.0.0.1,disable-ticketing,image-compression=off,seamless-migration=on"

    # SPICE USB Redirects
    result.args &= "-chardev"
    result.args &= "spicevmc,id=charredir0,name=usbredir"
    result.args &= "-device"
    result.args &= "usb-redir,chardev=charredir0,id=redir0"
    result.args &= "-chardev"
    result.args &= "spicevmc,id=charredir1,name=usbredir"
    result.args &= "-device"
    result.args &= "usb-redir,chardev=charredir1,id=redir1"

  # Introspection related commands.
  # NOTE: All introspection devices cannot be used on install
  if not install:
    case cfg.introspect
    of isLookingGlass:
      # Create device for looking glass
      result.args &= "-device"
      result.args &= "ivshmem-plain,id=shmem0,memdev=ivshmem"

      # Create looking glass object
      result.args &= "-object"
      result.args &=
       &"memory-backend-file,id=ivshmem,mem-path=/dev/shm/kvmfr-{uuid},size=128M,share=yes"
    else: discard

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

  # Set vfio arguments
  for vfio in vfios:
    result.args &= vfioArgs(vfio)

  # Set mdev arguments
  for mdev in mdevs:
    result.args &= mdevArgs(mdev)

  # Enable sound
  result.args &= "--soundhw"
  result.args &= "all"

  # Port forward for all exposed ports
  if len(cfg.connectivity.exposedPorts) > 0:
    let hostfwds = map(cfg.connectivity.exposedPorts,
                      (port: Port) => &"hostfwd=tcp::{port.host}-:{port.guest}")
    result.args &= "-device"
    result.args &= "rtl8139,netdev=net0"
    result.args &= "-netdev"
    result.args &= join(@["user", "id=net0"] & hostfwds, ",")

  if isSome(cfg.shareddir) and not install:
    result.args &= "-hdb"
    result.args &= &"fat:rw:{get(cfg.shareddir)}"

  # Enable QMP socket for all sockets.
  for socket in sockets:
    result.args &= "-qmp"
    result.args &= &"unix:{socket},server,nowait"

  # States
  for i, state in cfg.container.state:
    let s = cfg.root / "states" / state
    result.args &= "-hdd"
    result.args &= s

  # If it is being installed
  if isSome(cfg.container.iso):
    result.args &= "-cdrom"
    result.args &= get(cfg.container.iso)

  # Additional commands sent into the qemu command
  # NOTE: Start Process quotes these commands.
  for command in cfg.commands:
    let values = join(command.values, ",")
    result.args &= command.arg
    if values != "":
      result.args &= values
