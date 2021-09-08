#
# Copyright: 2666680 Ontario Inc..
# Reason: Algorithms for IOMMU handling.
#
import algorithm
import math
import sequtils
import strutils
import strformat
import sugar
import options
import os
import tables

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

proc lockVf*(f: string, vfio: string, uuid: string, lock: bool = true): bool =
  ## lockVf - Locks a virtual function for the QEMU process.
  ##
  ## Inputs
  ## @f - Lock file to save the file to.
  ## @vfio - Driver override parameter to save the file to.
  ## @uuid - UUID for the application.
  ## @lock - Are we locking to vfio-pci or to (null)?
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
    discard execShellCmd(&"sudo su -c \"echo \'{newState}\' > {vfio}\"")
    result = true

  removeFile(f)

proc getVfios*(cfg: Config, uuid: string): seq[Vfio] =
  ## getVfios - Gets the list of VFIOs that need to be passed to the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID for the process that is currently running.
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
          driverOR = i.baseDir / &"virtfn{j.virtNum}" / "driver_override"

        createDir(lockBase)

        if lockVf(lockPath, driverOR, uuid, true):
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
      device = lastPathPart(dir) # NOTE: Has the 0000 prefix here
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
      vfs = parseInt(strip(readFile(sriovNumFile)))
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
        (x: seq[string]) => get(getVfio(deviceClass, x))
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
    requestedNics = cfg.nics

  # We use this in order to ensure if an individual requests multiple GPUs
  #  they are able to optimize the compute speed by providing them CPUs which
  #  are located closest to the specific GPU.
  sort(gpus, lowCpuLoadSort, order=SortOrder.Descending)

  # TODO: Add code for NICs.

  # How we select the correct GPUs.
  for i in requestedGpus:
    echo gpus
    for k, v in gpus:
      var newSorted = v

      sort(newSorted, gpuSort)

      let
        (selectedGpu, newV) = selectGpu(i, newSorted)

      gpus[k] = newV
      if isSome(selectedGpu):
        result &= get(selectedGpu)
        break

  echo result
