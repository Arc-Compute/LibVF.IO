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
  MachineConfig* = join(
    @["pc-q35-4.2",
      "accel=kvm",
      "usb=off",
      "vmport=off",
      "dump-guest-core=off"
    ],
    ","
  )
  CpuConfig* = join(
    @["host",
      "ss=on",
      "vmx=on",
      "pcid=on",
      "-hypervisor",
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
      #"ibrs=on",
      "amd-stibp=on",
      "amd-ssbd=on",
      "skip-l1dfl-vmentry=on",
      "pschange-mc-no=on",
      "hv-vapic",
      "hv_time",
      "hv-spinlocks=0x1fff",
      "hv-vendor-id=null",
      "kvm=off",
      "topoext=on"
    ],
    ","
  )
  CpuConfigHypervisor* = join(
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
      #"ibrs=on",
      "amd-stibp=on",
      "amd-ssbd=on",
      "skip-l1dfl-vmentry=on",
      "pschange-mc-no=on",
      "hv-vapic",
      "hv_time",
      "hv-spinlocks=0x1fff",
      "hv-vendor-id=null",
      "kvm=off",
      "topoext=on"
    ],
    ","
  )


func removeFiles*(files: seq[string]): Args =
  ## removeFiles - Mass removes a set of files.
  ##
  ## Inputs
  ## @files - List of files to remove
  ##
  ## Returns
  ## result - Argument to run to remove a set of files.
  result.exec = "/bin/rm"
  result.args &= "-rf"
  result.args &= files

func commandWriteFile*(data: string, path: string): Args =
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
  result.exec &= "echo"
  result.args &= &"'{data}'"
  result.args &= ">"
  result.args &= path

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
  result.args &= "-o"
  result.args &= "preallocation=metadata"
  result.args &= name
  result.args &= &"{size}G"

func changeGroup*(files: seq[string]): Args =
  ## changeGroup - Changes the files group to allow not to use sudo.
  ##
  ## Inputs
  ## @files - Files to change.
  ##
  ## Returns
  ## result - Arguments to change the file group.
  result.exec = "/usr/bin/chgrp"

  # Set the group to KVM
  result.args &= "kvm"

  # Add all files
  result.args &= files

func changePermissions*(files: seq[string]): Args =
  ## changePermissions - Changes the permission on the file.
  ##
  ## Inputs
  ## @files - Files to change.
  ##
  ## Returns
  ## result - Arguments to change the permissions for the files.
  result.exec = "/usr/bin/chmod"

  # Set the group to KVM
  result.args &= "g+rwx"

  # Add all files
  result.args &= files

func vfioArgs*(device: Vfio): seq[string] =
  ## vfioArgs - Qemu arguments for adding VFIO device.
  ##
  ## Inputs
  ## @device - Device to make into arguments.
  ##
  ## Returns
  ## result - Arguments to add to qemu arguments to attach vfio device.
  if isGpu(device):
    result &= "-device"
    result &= &"vfio-pci,host={device},multifunction=on,display=off"

func mdevArgs*(device: Mdev): seq[string] =
  ## mdevArgs - Qemu arguments for adding MDEV device.
  ##
  ## Inputs
  ## @device - Device to make into arguments.
  ##
  ## Returns
  ## result - Arguments to add to qemu arguments to attach mdev device.
  const mdevBase = "/sys/bus/mdev/devices"
  result &= "-device"
  result &=
        &"vfio-pci,id={device.devId},sysfsdev={mdevBase}/{device.uuid},display=off"

func additionalArgs*(args: QemuArgs): seq[string] =
  ## additionalArgs - Qemu arguments for additional commands.
  ##
  ## Inputs
  ## @args - Args to add
  ##
  ## Returns
  ## result - Arguments to add to qemu arguments to modify the object.
  let values = join(args.values, ",")
  result = @[args.arg, values]

func qemuLaunch*(cfg: Config, uuid: string,
                 vfios: seq[Vfio], mdevs: seq[Mdev],
                 kernel: string, install: bool,
                 logDir: string, sockets: seq[string], cid: int): Args =
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
  let
    qemuLogFile = logDir / (uuid & "-session.txt")

  # executing target
  result.exec = "/bin/qemu-system-x86_64"

  # Log file
  result.args &= "-D"
  result.args &= qemuLogFile

  # REVIEW productionize
  if cfg.vncPort < 100 and cfg.vncPort > -1 and not install:
    result.args &= "-display"
    result.args &= fmt"vnc=0.0.0.0:{cfg.vncPort}"

  # Causes issues with mdev devices.
  result.args &= "-no-hpet"

  # Preallocating RAM.
  result.args &= "-mem-prealloc"

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
      &"port={cfg.spicePort},addr=127.0.0.1,disable-ticketing=on,image-compression=off,seamless-migration=on"

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
      # Create device for Looking Glass
      result.args &= "-device"
      result.args &= "ivshmem-plain,id=shmem0,memdev=ivshmem_kvmfr"

      # Create Looking Glass IVSHMEM object
      result.args &= "-object"
      result.args &=
       &"memory-backend-file,id=ivshmem_kvmfr,mem-path=/dev/shm/kvmfr-{uuid},size=128M,share=yes"

      # Create device for Scream
      result.args &= "-device"
      result.args &= "ivshmem-plain,id=shmem1,memdev=ivshmem_kvmsr"

      # Create Scream IVSHMEM object
      result.args &= "-object"
      result.args &=
        &"memory-backend-file,id=ivshmem_kvmsr,mem-path=/dev/shm/kvmsr-{uuid},size=2M,share=yes"
    else: discard

  # UUID - Necessary for NVidia MDEV support
  result.args &= "-uuid"
  result.args &= uuid

  # Machine settings needed for NVidia MDEV support
  result.args &= "-machine"
  result.args &= MachineConfig

  # Cpu settings needed for NVidia MDEV support
  result.args &= "-cpu"
  if cfg.showhypervisor:
    result.args &= CpuConfigHypervisor
  else:
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
  if not cfg.sudo:
    result.args &= "-drive"
    result.args &= &"file={kernel}"
  else:
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
  # Port forward ssh port
  result.args &= "-device"
  result.args &= "rtl8139,netdev=net0"
  result.args &= "-netdev"
  result.args &= join(
    @["user", "id=net0"] &
    @[&"hostfwd=tcp::{cfg.sshPort}-:22"],
    ","
  )
  # Port forward for all exposed ports
  if len(cfg.connectivity.exposedPorts) > 0:
    let hostfwds = map(cfg.connectivity.exposedPorts,
                      (port: Port) => &"hostfwd={port.protocol}::{port.host}-:{port.guest}")
    result.args &= "-device"
    result.args &= "rtl8139,netdev=net1"
    result.args &= "-netdev"
    result.args &= join(@["user", "id=net1"] & hostfwds, ",")

  # VirtIO netdev
  result.args &= "-net"
  result.args &= "user"
  result.args &= "-net"
  result.args &= "nic" # NOTE: DO NOT USE VIRTIO IT IS BROKE

  result.args &= "-device"
  result.args &= &"vhost-vsock-pci,guest-cid={cid}"

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
    result.args &= "-drive"
    result.args &= &"file={s}"

  # If it is being installed
  if isSome(cfg.container.iso):
    result.args &= "-cdrom"
    result.args &= get(cfg.container.iso)

  # Additional commands sent into the qemu command
  # NOTE: Start Process quotes these commands.
  for command in cfg.commands:
    result.args &= additionalArgs(command)
