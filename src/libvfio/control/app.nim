#
# Copyright: 2666680 Ontario Inc.
# Reason: Code to start applications.
#
import std/os
import std/sequtils
import std/strformat
import std/logging

import root

import ../types

proc startRealApp*(monad: CommandMonad, app: seq[CommandList], uuid: string,
                   sshPort: int): bool =
  ## startApp - Starts an application for the VM.
  ##
  ## Inputs
  ## @monad - Monad to use.
  ## @app - Application to run to interact with VM.
  ##
  ## Side Effects - Runs arbitrary code during the runtime of the VM.
  proc patchArgs(a: Args): Args =
    result.exec = expandFilename(a.exec)
    result.args = @[]
    for arg in a.args:
      var r: string = arg
      case arg:
      of "#uuid#":
        r = uuid
      of "#ssh#":
        r = $sshPort
      else: discard
      result.args &= r

  result = true
  for cmdList in app:
    let realCmdList = CommandList(
      is_root: cmdList.is_root,
      list: map(cmdList.list, patchArgs)
    )
    result = result and sendCommandList(monad, realCmdList)

proc startApp*(cfg: Config, cmd: CommandLineArguments) =
  ## startApp - Starts an application for the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @cmd - Command line arguments.
  ##
  ## Side Effects - Runs arbitrary code during the runtime of the VM.
  let lockFile = cfg.root / "lock" / (cmd.uuid & ".json")

  if fileExists(lockFile):
    let
      lock = getLockFile(lockFile)
      app = if cfg.appCommands != @[]: cfg.appCommands
            else: lock.config.appCommands
      monad = createCommandMonad(true)
    if not dirExists(&"/proc/{lock.pidNum}"):
      removeFile(lockFile)
      error("Lock File is associated with dead process, killing process")
      quit(1)
    discard startRealApp(monad, app, cmd.uuid, lock.config.sshPort)
