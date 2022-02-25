#
# Copyright: 2666680 Ontario Inc.
# Reason: Code to interact with VMs.
#
import asyncnet
import asyncdispatch
import asyncfutures
import os
import osproc
import posix
import options
import strformat
import sequtils
import sugar
import logging

import app
import arguments
import install
import introspection
import iommu
import root

import ../comms/qmp
import ../types

proc realCleanup(vm: VM) =
  ## realCleanup - Real cleanup function.
  ##
  ## Inputs
  ## @vm - VM object created by startVM.
  ##
  ## Side effects - Cleans up the VM.
  info("Cleaning up VM")
  removeFile(vm.lockFile)
  removeDir(vm.socketDir)

  # Unlock all locked vfios.
  for vfio in vm.vfios:
    let
      lockBase = "/tmp" / "locks" / parentDir(parentDir(vfio.base))
      lockPath = lockBase / "lock"

    createDir(lockBase)

    while not bindVf(lockPath, vm.uuid, vfio, false, vm.monad):
      discard

    info(&"Unlocked: {vfio.deviceName}")

  # Unlock all locked MDevs
  for mdev in vm.mdevs:
    discard sendCommand(vm.monad, commandWriteFile("1", mdev.stop))
    info(&"Deleted MDEV: {mdev.devId}")

  if vm.introspections != @[]:
    discard sendCommand(vm.monad, removeFiles(vm.introspections))

  # Runs the teardown command.
  info("Running teardown command lists")
  for cmdList in vm.teardownCommands:
    discard sendCommandList(vm.monad, cmdList)

  info("Cleaned up VM")

proc cleanupVm*(vm: VM) =
  ## cleanupVm - Cleans up the entire VM active stack once it is finished
  ##              executing.
  ##
  ## Inputs
  ## @vm - VM object created by startVM.
  ##
  ## Side effects - Deletes files, and sockets, also will kill the VM if
  ##                 necessary.
  var
    timeouts = 0
    poweringDown = false
    res = if isSome(vm.socket): getResponse(get(vm.socket))
          else: newFuture[QmpResponse]()

  while vm.child and running(vm.qemuPid):
    if not(finished(res)):
      if timeouts < 1000 and poweringDown: # Keeps going for up to 30 seconds
                                           #  before killing the process.
        timeouts += 1
      elif poweringDown:                   # KILL THE PROCESS
        discard setRoot(vm.monad, true)    # Sets the root if necessary to kill.
        terminate(vm.qemuPid)              # Prevents self garbage collection
                                           # need garbage collection daemon
                                           # to run after this.
        discard setRoot(vm.monad, false)   # Sets back to the user.
      waitFor(sleepAsync(300))
      continue

    let x = read(res)

    res = getResponse(get(vm.socket))

    case x.event
    of qrPowerDown:
      poweringDown = true
    of qrShutdown:
      break
    of qrDevTrayMove:
      if poweringDown:
        waitFor(
          sendMessage(
            get(vm.socket),
            QmpCommand(command: qcSendKey, keys: @["kp_enter"])
          )
        )
    else: discard

  realCleanup(vm)

proc startVm*(c: Config, uuid: string, newInstall: bool,
              noCopy: bool, save: bool): VM =
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
    limeDir = cfg.root / "lime" / uuid
    baseKernel = kernelPath / cfg.container.kernel
    lockFile = lockPath / (uuid & ".json")
    liveKernel = if noCopy: baseKernel else: livePath / uuid
    socketDir = "/tmp" / "sockets" / uuid
    dirs = [
      kernelPath, livePath, lockPath, qemuLogs, socketDir,
      limeDir
    ]
    sockets = map(
      @["main.sock", "master.sock"],
      (s: string) => socketDir / s
    )
    introspections = getIntrospections(cfg, uuid, newInstall)

  # If we are passing a vfio, we need to run the command as sudo
  if len(cfg.gpus) > 0 or len(cfg.nics) > 0:
    cfg.sudo = true

  # Command monad
  let
    rootMonad = createCommandMonad(cfg.sudo)
    userMonad = createCommandMonad(false)

  result.monad = rootMonad

  # If we are passing a vfio, we need to run the command as sudo
  let (vfios, mdevs) = getIommuGroups(cfg, uuid, rootMonad)

  result.vfios = vfios
  result.mdevs = mdevs
  result.lockFile = lockFile
  result.socketDir = socketDir
  result.uuid = uuid
  result.introspections = introspections & limeDir
  result.liveKernel = liveKernel
  result.baseKernel = baseKernel
  result.newInstall = newInstall
  result.save = save
  result.noCopy = noCopy
  result.sshPort = cfg.sshPort
  result.teardownCommands = cfg.teardownCommands

  # If we do not have the necessary directories, create them
  for dir in dirs:
    createDir(dir)

  # Setup lock file.
  var
    lock = Lock(
      config: cfg,
      vfios: vfios,
      mdevs: mdevs,
      pidNum: 0
    )

  # Either moves the file or creates a new file
  if fileExists(baseKernel) and not newInstall and not noCopy:
    copyFile(baseKernel, liveKernel)
  elif newInstall and isSome(cfg.container.iso):
    if cfg.installOs != osNone:
      var t = getInstallationParams(limeDir, cfg.installOs)
      t.introspectionDir = cfg.root / "introspection-installations"
      updateIso(
        get(cfg.container.iso), t, cfg.installOs,
        cfg.container.initialSize, baseKernel, mdevs,
        vfios, rootMonad, uuid
      )
      realCleanup(result)
      result.child = false
      return

    let
      kernelArgs = createKernel(liveKernel, cfg.container.initialSize)
    discard sendCommand(userMonad, kernelArgs)
  elif noCopy or save:
    discard
  else:
    error("Invalid command sequence")
    return

  # At this point we are in the child process
  let
    qemuArgs = qemuLaunch(
      cfg=cfg,
      uuid=uuid,
      vfios=lock.vfios,
      mdevs=lock.mdevs,
      kernel=liveKernel,
      install=newInstall,
      logDir=qemuLogs,
      sockets=sockets
    )

  # Runs startup commands.
  var commands = true
  for cmdList in cfg.startupCommands:
    commands = commands and sendCommandList(result.monad, cmdList)

  if not commands:
    error("Failed startup commands, cleaning up VM.")
    realCleanup(result)
    result.child = false
    return

  # Spawn up qemu image
  let forkRet = fork()

  result.child = forkRet == 0

  if forkRet > 0:
    return
  elif forkRet < 0:
    error("Could not fork")
    return

  var qemuPid = startCommand(rootMonad, qemuArgs)

  lock.pidNum = processID(qemuPid)

  writeLockFile(lockFile, lock)

  sleep(3000) # Sleeping to avoid trying to open the file too soon.

  result.qemuPid = qemuPid
  if not running(qemuPid):
      error("PID not started, cleaning up")
      return

  let
    ownedFiles = sockets & introspections
    groupArgs = changeGroup(ownedFiles)
    permissionsArgs = changePermissions(ownedFiles)

  # If sudo we need to switch the permissions.
  if cfg.sudo:
    discard sendCommand(rootMonad, groupArgs)
    discard sendCommand(rootMonad, permissionsArgs)

  if cfg.startintro and not newInstall:
    realIntrospect(cfg, cfg.introspect, introspections, uuid)

  let
    socketMaybe = createSocket(socketDir / "main.sock")

  result.socket = socketMaybe

  if newInstall:
    commands = startRealApp(result.monad, cfg.install_commands, result.uuid,
                            result.sshPort)
    if not commands:
      error("Could not install the VM.")
      discard setRoot(result.monad, true)
      terminate(result.qemuPid)
      discard setRoot(result.monad, false)
  elif cfg.startapp:
    discard startRealApp(result.monad, cfg.app_commands, result.uuid,
                         result.sshPort)

proc cleanVm*(vm: VM) =
  ## cleanVm - Cleans the VM/waits for VM to finish.
  ##
  ## Inputs
  ## @vm - VM object for the created VM.
  cleanupVm(vm)

  if (vm.newInstall or vm.save) and fileExists(vm.liveKernel):
    info("Installing to base kernel")
    moveFile(vm.liveKernel, vm.baseKernel)
  elif not vm.noCopy and fileExists(vm.liveKernel):
    removeFile(vm.liveKernel)

proc stopVm*(uuid: string) =
  ## stopVm - Stops a VM.
  ##
  ## Inputs
  ## @uuid - Stops the VM with the given UUID.
  ##
  ## Side effects - Stops a VM.
  let
    socketPath = "/tmp" / "sockets" / uuid / "master.sock"

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
    info("Sent stop command to VM powering down now")
