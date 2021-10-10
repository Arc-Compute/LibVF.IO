#
# Copyright: 2666680 Ontario Inc.
# Reason: Main file for running the arcd process
#
import options
import os

import libvfio/[control, logger, types, comms]

when isMainModule:
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
    startVm(cfg, uid, true, false, false)
  of ceStart:
    startVm(cfg, uid, false, cmd.nocopy, cmd.save)
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
