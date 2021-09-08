#
# Copyright: 2666680 Ontario Inc..
# Reason: Main file for running the arcd process
#
import os

import libarcdpkg/[control, logger, types]

when isMainModule:
  let
    cmd = getCommandLine()
    cfg = getConfigFile(cmd)

  case cmd.command
  of ceCreate:
    startVm(cfg, true)
  of ceStart:
    startVm(cfg, false)
  of ceStop:
    stopVm(cfg, cmd)
  else:
    echo cmd
