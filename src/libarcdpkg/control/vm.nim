#
# Copyright: 2666680 Ontario Inc..
# Reason: Code to interact with VMs.
#
import os
import osproc
import posix
import posix_utils
import options
import times
import strformat
import strutils
import logging

import arguments
import iommu

import ../types

proc startVm*(cfg: Config, newInstall: bool) =
  ## startVm - Starts a VM.
  ##
  ## Inputs
  ## @cfg - Configuration file for starting a VM.
  ## @newInstall - Do we need to install into a kernel?
  ##
  ## Side effects - Creates an Arc Container.
  let
    kernelPath = cfg.root / "kernel"
    livePath = cfg.root / "live"
    lockPath = cfg.root / "lock"
    qemuLogs = cfg.root / "stats" / "logs" / "qemu"
    baseKernel = kernelPath / cfg.container.kernel
    uuid = getUUID()
    lockName = &"{uuid}-{now()}"
    lockFile = lockPath / (lockName & ".json")
    liveKernel = livePath / lockName
    socketDir = "/tmp" / "sockets" / uuid
    dirs = [
      kernelPath, livePath, lockPath, qemuLogs, socketDir
    ]

  # If we do not have the necessary directories, create them
  for dir in dirs:
    createDir(dir)

  # Setup lock file.
  var
    lock = Lock(
      config: cfg,
      vfios: getVfios(cfg, uuid),
      pidNum: 0
    )

  # Either moves the file or creates a new file
  if fileExists(baseKernel):
    copyFile(baseKernel, liveKernel)
  elif newInstall:
    let
      kernelArgs = createKernel(liveKernel, cfg.container.initialSize)
      cmd = join(@[kernelArgs.exec] & kernelArgs.args, " ")
    discard execShellCmd(cmd)
  else:
    error("Invalid VM commands")
    return

  # Spawn up qemu image
  let forkRet = fork()
  if forkRet > 0:
    return
  elif forkRet < 0:
    error("Could not fork for qemu process")
    return

  # At this point we are in the child process
  let
    qemuArgs = qemuLaunch(
      cfg=cfg,
      uuid=uuid,
      vfios=lock.vfios,
      kernel=liveKernel,
      install=newInstall,
      logDir=qemuLogs,
      socketDir=socketDir
    )

  var
    qemuPid = startProcess(
      qemuArgs.exec,
      args=qemuArgs.args,
      options={poEchoCmd, poParentStreams}
    )

  lock.pidNum = processID(qemuPid)

  writeLockFile(lockFile, lock)

  discard waitForExit(qemuPid)

  if newInstall:
    info("Installing to base kernel")
    moveFile(liveKernel, baseKernel)

  removeFile(lockFile)
  removeDir(socketDir)

proc stopVm*(cfg: Config, cmd: CommandLineArguments) =
  ## stopVm - Stops a VM.
  ##
  ## Inputs
  ## @cmd - Command line arguments for stopping a VM.
  ##
  ## Side effects - Stops a VM.
  let
    lockPath = cfg.root / "lock"
    lockFile = lockPath / (cmd.uuid & ".json")
    lock = getLockFile(lockFile)

  # Sends kill command
  try:
    sendSignal(pid=int32(lock.pidNum), signal=9)
  except:
    discard
