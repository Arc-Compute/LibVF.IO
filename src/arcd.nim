#
# Copyright: 2666680 Ontario Inc.
# Reason: Main file for running the arcd process
#
import options
import os

import libarcdpkg/[control, logger, types, comms]

when isMainModule:
  let
    cmd = getCommandLine()
    cfg = getConfigFile(cmd)
    log = cfg.root / "logs" / "arcd"
    uid = getUUID()

  createDir(log)
  initLogger(log / (uid & ".log"), true)

  case cmd.command
  of ceCreate:
    startVm(cfg, uid, true)
  of ceStart:
    startVm(cfg, uid, cmd.save)
  of ceStop:
    stopVm(cfg, cmd)
  of ceLs:
    arcLs(cfg, cmd)
  of cePs:
    arcPs(cfg, cmd)

  if cmd.save and isSome(cmd.config):
    info("Saving new config file.")
    let config = get(cmd.config)
    removeFile(config)
    writeConfigFile(config, cfg)
