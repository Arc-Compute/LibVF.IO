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
  if getuid() == 0:
    echo("DO NOT RUN THIS AS ROOT")
    quit 0

  let
    cmd = getCommandLine()
    cfg = getConfigFile(cmd)
    log = cfg.root / "logs" / "arcd"
    uid = getUUID()
    homeConfigDir = getHomeDir() / ".config" / "arc"

  createDir(log)
  createDir(homeConfigDir)
  initLogger(log / (uid & ".log"), true)

  case cmd.command
  of ceCreate:
    continueVM(startVm(cfg, uid, true, false, false))
  of ceStart:
    continueVM(startVm(cfg, uid, false, cmd.nocopy, cmd.save))
  of ceStop:
    stopVm(cfg, cmd)
  of ceIntrospect:
    introspectVm(cfg, cmd.uuid)
  of ceLs:
    arcLs(cfg, cmd)
  of cePs:
    arcPs(cfg, cmd)
  of ceDeploy:
    removeFile(homeConfigDir / "arc.yaml")
    writeConfigFile(homeConfigDir / "arc.yaml", cfg)
    createDir(cfg.root / "states")
    copyFile(
      homeConfigDir / "introspection-installations.rom",
      cfg.root / "introspection-installations.rom"
    )
  of ceUndeploy:
    removeFile(homeConfigDir / "arc.yaml")
    removeDir(cfg.root)

  if cmd.save and isSome(cmd.config):
    info("Saving new config file.")
    let config = get(cmd.config)
    removeFile(config)
    writeConfigFile(config, cfg)
