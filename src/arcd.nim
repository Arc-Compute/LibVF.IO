#
# Copyright: 2666680 Ontario Inc.
# Reason: Main file for running the arcd process
#
import std/options
import std/os
import std/posix

import libvfio/[control, logger, types, comms]

proc continueVM(vm: VM) =
  ## continueVM - Code for continuing a VM's sequence after it is started.
  ##
  ## Input
  ## @vm - VM to continue the lifecycle for.
  ##
  ## Side Effects - VM side effects.
  if vm.child:
    # Continues VM.
    cleanVM(vm)

when isMainModule:
  # Checks if process is running as root and exits if it is.
  if getuid() == 0:
    echo("DO NOT RUN THIS AS ROOT")
    quit 0

  let
    # Gets command line arguments.
    cmd = getCommandLine()
    # Get config file.
    cfg = getConfigFile(cmd)
    # Sets the log path.
    log = cfg.root / "logs" / "arcd"
    # Get the session UUID.
    uid = getUUID()
    # Sets the config path.
    homeConfigDir = getHomeDir() / ".config" / "arc"

  # Create the log directory.
  createDir(log)
  # Create the config directory.
  createDir(homeConfigDir)
  # Start logging.
  initLogger(log / (uid & ".log"), true)

  # Command line interface cases.
  case cmd.command
  # Create VM.
  of ceCreate:
    continueVM(startVm(cfg, uid, true, false, false))
  # Start VM.
  of ceStart:
    continueVM(startVm(cfg, uid, false, cmd.nocopy, cmd.save))
  # Stop VM via QEMU Machine Protocol (QMP) signal.
  of ceStop:
    stopVm(cfg, cmd)
  # Introspect a VM.
  of ceIntrospect:
    introspectVm(cfg, cmd.uuid)
  # List available kernels, states, and apps.
  of ceLs:
    arcLs(cfg, cmd)
  # List running VMs by UUID.
  of cePs:
    arcPs(cfg, cmd)
  # Deploy the arcd directory.
  of ceDeploy:
    removeFile(homeConfigDir / "arc.yaml")
    writeConfigFile(homeConfigDir / "arc.yaml", cfg)
    createDir(cfg.root / "states")
    copyFile(
      homeConfigDir / "introspection-installations.rom",
      cfg.root / "introspection-installations.rom"
    )
  # Undeploy the arcd directory
  of ceUndeploy:
    removeFile(homeConfigDir / "arc.yaml")

  # Save the config file
  if cmd.save and isSome(cmd.config):
    info("Saving new config file.")
    let config = get(cmd.config)
    removeFile(config)
    writeConfigFile(config, cfg)
