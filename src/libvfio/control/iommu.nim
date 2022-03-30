#
# Copyright: 2666680 Ontario Inc.
# Reason: Algorithms for IOMMU handling.
#
import algorithm
import math
import sequtils
import strutils
import parseutils
import strformat
import sugar
import options
import os
import tables
import logging

import arguments
import root

import ../types

type
  Physical = object         ## Internal structure to help us with sorting
                            ##  the files.
    numVfs: Positive        ## Number of virtual functions exposed by the PCI.
    baseDir: string         ## Base directory holding the physical device.
    case kind: VfioTypes
    of vtGPU:
      vgpus: seq[Vfio]      ## The list of vGPUs.
      gpuType: string       ## Type of the physical GPU that was split.
    else: discard

proc lockVf(f: string, vfio: string, uuid: string, lock: bool = true,
            monad: CommandMonad): bool =
  ## lockVf - Locks a virtual function for the QEMU process.
  ##
  ## Inputs
  ## @f - Lock file to save the file to.
  ## @vfio - Driver override parameter to save the file to.
  ## @uuid - UUID for the application.
  ## @lock - Are we locking to vfio-pci or to (null)?
  ## @monad - Monad to wrap command in.
  ##
  ## Returns
  ## result - Boolean on if we were able to lock the file or not.
  ##
  ## Side effects - REQUIRES SUDO REEEEEEEEEEEEEEEEE.
  result = false

  if fileExists(f):
    return false

  let
    state = if lock: "(null)"
            else: "vfio-pci"
    newState = if not lock: "(null)"
               else: "vfio-pci"

  writeFile(f, uuid)

  # Sleeps to allow another device to take the lock instead.
  sleep(300)

  if fileExists(f) and strip(readFile(f)) == uuid and
     strip(readFile(vfio)) == state:
    result = sendCommand(monad, commandWriteFile(newState, vfio))

  removeFile(f)

proc bindVf*(f: string, uuid: string, dev: Vfio, state: bool,
             monad: CommandMonad): bool =
  ## bindVf - Binds the VF to the correct driver for QEMU passing.
  ##
  ## Inputs
  ## @f - Lock file to save the file to.
  ## @vfio - Driver override parameter to save the file to.
  ## @uuid - UUID for the application.
  ## @dev - Device to bind.
  ## @state - Do we bind or unbind the resource.
  ## @monad - Monad to wrap command in.
  ##
  ## Side effects - Binds the VFIO.
  let
    base = "/sys/bus/pci/drivers/vfio-pci"
    b = if state: base / "bind"
        else: base / "unbind"

  if state:
    result = lockVf(f, dev.base, uuid, state, monad)
    result = result and sendCommand(monad, commandWriteFile(dev.deviceName, b))
  else:
    result = sendCommand(monad, commandWriteFile(dev.deviceName, b))
    result = result and lockVf(f, dev.base, uuid, state, monad)

proc getVfios*(cfg: Config, uuid: string, monad: CommandMonad): seq[Vfio] =
  ## getVfios - Gets the list of VFIOs that need to be passed to the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID for the process that is currently running.
  ## @monad - Monad to wrap command in.
  ##
  ## Returns
  ## result - List of selected VFIOs for the device in question.
  ##
  ## Side effects - DANGEROUS, REQUIRES ROOT LEVEL FUNCTIONS
  ##                Reads system IOMMU mapping and overrides drivers for
  ##                 selected components.
  func gpuSort(a, b: Physical): int =
    if a.numVfs > b.numVfs: -1
    elif a.numVfs == b.numVfs: 0
    else: 1

  proc selectGpu(request: RequestedGpu, list: seq[Physical]):
                (Option[Vfio], seq[Physical]) =
    result = (none(Vfio), list)

    var
      ret = none(Vfio)
      newList = list

    for idx0, i in newList:
      if not (i.gpuType in request.acceptableTypes): continue
      var vgpus = i.vgpus
      for idx, j in i.vgpus:
        if j.vRam < request.minVRam: continue
        if j.vRam > request.maxVRam and request.maxVRam != -1: continue

        # Generate lock constants.
        let
          lockBase = "/tmp" / "locks" / i.baseDir
          lockPath = lockBase / "lock"

        createDir(lockBase)

        if bindVf(lockPath, uuid, j, true, monad):
          delete(vgpus, idx, idx)
          ret = some(j)
          break
      if isSome(ret):
        newList[idx0].vgpus = vgpus
        newList[idx0].numVfs -= 1
        break
      ret = none(Vfio)

    result = (ret, newList)

  func lowCpuLoadSort(a, b: (string, seq[Physical])): int =
    const
      # Nim is complaining about this syntax
      f = (y: seq[Physical]) => sum(map(y, (x: Physical) => x.numVfs))
    let
      aSum: int = f(a[1])
      bSum: int = f(b[1])
    result = system.cmp(aSum, bSum)

  result = @[]

  var
    gpus = newOrderedTable[string, seq[Physical]]() # Stored GPUs.

  # Walk through all known IOMMU groups.
  for dir in walkDirs("/sys/kernel/iommu_groups/*/devices/*/"):
    let
      deviceClassFile = dir / "class"
      sriovNumFile = dir / "sriov_numvfs"

    if not fileExists(deviceClassFile) or not fileExists(sriovNumFile):
      continue

    let
      # Device class format is assumed: 0xN0000, where N is the 2 byte
      #  number for the class.
      deviceClass = fromHex[int](readFile(deviceClassFile)[0 .. 3])

    # If we do not support this device type, we do not pass it through.
    if not deviceClass in PassableVfios:
      continue

    let
      vfs = parseInt(strip(readFile(sriovNumFile))) # Number of VFs.
      cpulist = readFile(dir / "local_cpulist") # How we determine which
                                                #  discrete device the gpu
                                                #  is on.

    # If the SRIOV is enabled but no VFs where generated, assume it is not
    #  enabled.
    if vfs == 0: continue

    # Here we must have either a networking NIC, or a GPU, WITH SRIOV Enabled.
    case VfioTypes(deviceClass)
    of vtGPU:
      # NOTE: Currently assuming AMDGPUs with GIM only.
      let gimGpuFile = dir / "gpuvf"
      var s: seq[string] = @[]

      if not fileExists(gimGpuFile):
        continue

      for line in lines(gimGpuFile):
        s &= strip(line)

      let gimGpus = map(
        distribute(s, vfs),
        (x: seq[string]) => get(getVfio(deviceClass, x, dir))
      )

      gpus[cpulist] = getOrDefault(gpus, cpulist, @[]) & @[
        Physical(
          kind: vtGPU,
          baseDir: dir,
          gpuType: gimGpus[0].gpuType,
          numVfs: len(gimGpus),
          vgpus: gimGpus
        )
      ]
    else: discard

  var
    requestedGpus = cfg.gpus

  # We use this in order to ensure if an individual requests multiple GPUs
  #  they are able to optimize the compute speed by providing them CPUs which
  #  are located closest to the specific GPU.
  sort(gpus, lowCpuLoadSort, order=SortOrder.Descending)

  # TODO: Add code for NICs.

  # How we select the correct GPUs.
  for i in requestedGpus:
    case i.gpuType
      of rgSRIOVGpu:
        for k, v in gpus:
          var newSorted = v

          sort(newSorted, gpuSort)

          let
            (selectedGpu, newV) = selectGpu(i, newSorted)

          gpus[k] = newV
          if isSome(selectedGpu):
            result &= get(selectedGpu)
            break
      else: discard

proc getMdevs*(cfg: Config, monad: CommandMonad): seq[Mdev] =
  ## getMdevs - Gets the list of MDEVs that need to be passed to the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @monad - Monad to wrap the command in.
  ##
  ## Returns
  ## result - List of selected MDEVs for the device in question.
  ##
  ## Side effects - Generates MDevs.
  for i in cfg.gpus:
    case i.gpuType
    of rgMdevGpu:
      let mdev = if isNone(i.parentPort):
                   "/sys/class/mdev_bus/*/mdev_supported_types/*"
                 else:
                   &"/sys/class/mdev_bus/{get(i.parentPort)}/mdev_supported_types/*"
      for dir in walkDirs(mdev):
        let
          createFile = dir / "create"
          description = dir / "description"
          name = dir / "name"
          desc = readFile(description)
          isGVTg = "GVTg" in dir
          framebufferStart = find(
            desc,
            if isGVTg: "high_gm_size"
            else: "framebuffer"
          )
          framebufferStr = captureBetween(
            desc,
            if isGVTg: ' '
            else: '=',
            'M',
            start=framebufferStart
          )
          framebuffer = parseInt(framebufferStr)
          gpuUUID = getUUID()
          startArgs = commandWriteFile(gpuUUID, createFile)

        echo framebuffer, " ", dir
        if not (i.mdevType in lastPathPart(dir)):
          continue

        if i.minVRam > framebuffer or i.maxVRam < framebuffer:
          continue

        if fileExists(name) and not endsWith(strip(readFile(name)), i.suffix):
          continue

        # BUG: Merged driver does not support multiple vGPU types on a card.
        discard sendCommand(monad, startArgs)
        result &= Mdev(
          uuid: gpuUUID,
          devId: i.devId,
          stop: "/sys/bus/mdev/devices" / gpuUUID / "remove"
        )
        break
    else: discard

proc getIommuGroups*(cfg: Config, uuid: string,
                     monad: CommandMonad): (seq[Vfio], seq[Mdev]) =
  ## getIommuGroups - Gets a list of vfios, and a seperate list of mdevs.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - Process's UUID.
  ## @monad - Monad to wrap commands.
  ##
  ## Returns
  ## result - A list of vfios and a list of mdevs
  let
    vfios = getVfios(cfg, uuid, monad)
    mdevs = getMdevs(cfg, monad)
  result = (vfios, mdevs)
