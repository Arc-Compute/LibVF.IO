#
# Copyright: 2666680 Ontario Inc.
# Reason: Creates commands to execute on the host system.
#
import strformat
import strutils
import options
import os

import ../types

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

func qemuLaunch*(cfg: Config, uuid: string,
                 vfios: seq[Vfio], kernel: string,
                 install: bool, logDir: string,
                 socketDir: string): Args =
  ## qemuLaunch - Generates a qemu command to be executed.
  ##
  ## Inputs
  ## @cfg - Configuration for the qemu launch.
  ## @uuid - UUID of the app.
  ## @vfios - List of VFIOs to put pass into the VM.
  ## @kernel - Kernel path.
  ## @install - Is this an installation?
  ##
  ## Returns
  ## result - Arguments to launch a kernel.
  func vfioArgs(device: Vfio): seq[string] =
    if isGpu(device):
      result &= "--device"
      result &= &"vfio-pci,host={device},multifunction=on"
      result &= "-mem-prealloc"
      result &= "-nographic"

  let
    qemuLogFile = logDir / (uuid & "-session.txt")
    sockets = [socketDir / "main.sock", socketDir / "master.sock"]

  # executing target
  result.exec = "/bin/qemu-system-x86_64"

  # Need sudo to pass VFIOs
  if cfg.sudo:
    result.args &= result.exec
    result.exec = "/bin/sudo"

  # Log file
  result.args &= "-D"
  result.args &= qemuLogFile

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
    result.args &= state

  # If it is being installed
  if install and isSome(cfg.container.iso):
    result.args &= "-cdrom"
    result.args &= get(cfg.container.iso)

  # Additional commands sent into the qemu command
  # NOTE: This is dangerous, so we quote all of these.
  for command in cfg.commands:
    let values = join(command.values, ",")
    result.args &= &"'{command.arg}'"
    if values != "":
      result.args &= &"'{values}'"
