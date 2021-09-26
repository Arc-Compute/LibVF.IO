
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with VMs.
#
import asyncnet
import asyncdispatch
import os
import osproc
import posix
import options
import strutils
import strformat
import sequtils
import sugar
import logging

import arguments
import iommu

import ../comms/qmp
import ../types

proc realCleanup(lockFile: string, uuid: string, socketDir: string,
                 vfios: seq[Vfio]) =
  ## realCleanup - Real cleanup function.
  ##
  ## Inputs
  ## @lockFile - Lockfile to use.
  ## @uuid - UUID for the VM.
  ## @socketDir - Socket directory for the system.
  ## @vfios - List of connected VFIOs.
  ##
  ## Side effects - Cleans up the VM.
  info("Cleaning up VM")
  removeFile(lockFile)
  removeDir(socketDir)

  # Unlock all locked vfios.
  for vfio in vfios:
    let
      lockBase = "/tmp" / "locks" / parentDir(parentDir(vfio.base))
      lockPath = lockBase / "lock"

    createDir(lockBase)

    while not bindVf(lockPath, uuid, vfio, false):
      discard

    info(&"Unlocked: {vfio.deviceName}")
  info("Cleaned up VM")

proc cleanupVm*(socket: AsyncSocket, pid: Process,
                lockFile: string, socketDir: string,
                uuid: string, vfios: seq[Vfio]) =
  ## cleanupVm - Cleans up the entire VM active stack once it is finished
  ##              executing.
  ##
  ## Inputs
  ## @socket - Socket for internal communications.
  ## @pid - Owned process.
  ## @lockFile - Location of where the lock file is stored.
  ## @socketDir - Directory for where the sockets are stored.
  ## @uuid - UUID for the program.
  ## @vfios - List of locked VFIOs.
  ##
  ## Side effects - Deletes files, and sockets, also will kill the VM if
  ##                 necessary.
  var
    timeouts = 0
    poweringDown = false
    res = getResponse(socket)

  while running(pid):
    if not(finished(res)):
      if timeouts < 1000 and poweringDown: # Keeps going for up to 30 seconds
                                           #  before killing the process.
        timeouts += 1
      elif poweringDown:                   # KILL THE PROCESS
        terminate(pid)
      waitFor(sleepAsync(300))
      continue

    let x = read(res)

    res = getResponse(socket)

    case x.event
    of qrPowerDown:
      poweringDown = true
    of qrShutdown:
      break
    of qrDevTrayMove:
      if poweringDown:
        waitFor(
          sendMessage(
            socket,
            QmpCommand(command: qcSendKey, keys: @["kp_enter"])
          )
        )
    else: discard

  realCleanup(lockFile, uuid, socketDir, vfios)

proc startVm*(c: Config, uuid: string, newInstall: bool,
              noCopy: bool, save: bool) =
  ## startVm - Starts a VM.
  ##
  ## Inputs
  ## @c - Configuration file for starting a VM.
  ## @uuid - String representation of the uid.
  ## @newInstall - Do we need to install into a kernel?
  ## @noCopy - Avoid unnecessary copying when we do not need it.
  ## @save - Do we save the result?
  ##
  ## Side effects - Creates an Arc Container.
  var cfg = c

  let
    kernelPath = cfg.root / "kernel"
    livePath = cfg.root / "live"
    lockPath = cfg.root / "lock"
    qemuLogs = cfg.root / "logs" / "qemu"
    baseKernel = kernelPath / cfg.container.kernel
    lockFile = lockPath / (uuid & ".json")
    liveKernel = if noCopy: baseKernel else: livePath / uuid
    socketDir = "/tmp" / "sockets" / uuid
    dirs = [
      kernelPath, livePath, lockPath, qemuLogs, socketDir
    ]
    sockets = map(
      @["main.sock", "master.sock"],
      (s: string) => socketDir / s
    )

  # If we are passing a vfio, we need to run the command as sudo
  let vfios = getVfios(cfg, uuid)
  if len(vfios) > 0:
    cfg.sudo = true

  # If we do not have the necessary directories, create them
  for dir in dirs:
    createDir(dir)

  # Setup lock file.
  var
    lock = Lock(
      config: cfg,
      vfios: vfios,
      pidNum: 0
    )

  # Either moves the file or creates a new file
  if fileExists(baseKernel) and not newInstall and not noCopy:
    copyFile(baseKernel, liveKernel)
  elif newInstall:
    let
      kernelArgs = createKernel(liveKernel, cfg.container.initialSize)
    if not runCommand(kernelArgs):
      error("Could not create image gracefully failing")
      return
  elif noCopy or save:
    discard
  else:
    error("Invalid command sequence")
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
      sockets=sockets
    )

  var
    qemuPid = startProcess(
      qemuArgs.exec,
      args=qemuArgs.args,
      options={poEchoCmd, poParentStreams}
    )

  lock.pidNum = processID(qemuPid)

  writeLockFile(lockFile, lock)

  sleep(3000) # Sleeping to avoid trying to open the file too soon.

  let
    socketGroupArgs = changeSocketGroup(cfg.sudo, sockets)
    permissionsArgs = changePermissions(cfg.sudo, sockets)

  # If we fail to change socket stuff
  if not runCommand(socketGroupArgs) or not runCommand(permissionsArgs):
    error("Could not change socket information correctly cleaning up.")
    realCleanup(lockFile, uuid, socketDir, vfios)
    if not noCopy:
      removeFile(liveKernel)

  let
    socketMaybe = createSocket(socketDir / "main.sock")
    socket = if isSome(socketMaybe): get(socketMaybe)
             else: newAsyncSocket()

  cleanupVm(socket, qemuPid, lockFile, socketDir, uuid, vfios)

  if newInstall or save:
    info("Installing to base kernel")
    moveFile(liveKernel, baseKernel)
  elif not noCopy:
    removeFile(liveKernel)

proc stopVm*(cfg: Config, cmd: CommandLineArguments) =
  ## stopVm - Stops a VM.
  ##
  ## Inputs
  ## @cmd - Command line arguments for stopping a VM.
  ##
  ## Side effects - Stops a VM.
  let
    socketPath = "/tmp" / "sockets" / cmd.uuid / "master.sock"

  # Sends kill command
  let socket = createSocket(socketPath)
  if isSome(socket):
    const shutdown = QmpCommand(command: qcShutdown)
    let sock = get(socket)

    while true:
      asyncCheck(sendMessage(sock, shutdown))
      let x = waitFor(getResponse(sock))
      if x.event == qrSuccess:
        break
