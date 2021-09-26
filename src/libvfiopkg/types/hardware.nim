#
# Copyright: 2666680 Ontario Inc.
# Reason: Hardware configurations for the system.
#
import options
import strformat
import strutils
import os

type
  VfioTypes* = enum          ## Enumeration to determine the types of VFIOs.
    vtUNA = (0x00, "UNA"),   ## 0x00 is the unassigned class.
    vtNET = (0x02, "NET"),   ## 0x02 is the class for networking devices.
    vtGPU = (0x03, "GPU")    ## 0x03 is the class for display devices.

  Cpu* = object              ## CPU configuration object.
    cores*: int              ## How many cores each virtual CPU has.
    sockets*: int            ## How many virtual CPUs we put in the VM.
    threads*: int            ## How many threads each core has.
    ramAlloc*: int           ## Megabytes of RAM required for the VM.

  Vfio* = object             ## VFIO structure for handling different VFIOs.
    deviceName*: string      ## PCI device address
    base*: string            ## Driver override address
    case kind: VfioTypes     ## Private enumeration value stating which
                             ##  version to use.
    of vtNET:
      mac*: string           ## MAC Address to pass into VM.
    of vtGPU:
      virtNum*: int          ## What virtual function is this mapped to.
      gpuType*: string       ## Type of the GPU.
      vRam*: int             ## vRAM available to the GPU.
    else: nil

const
  PassableVfios* = @[        ## List of PCI classes we can pass into the Arc
                             ##  containers.
    ord(vtNET), ord(vtGPU)
  ]

func `$`*(x: Cpu): string =  ## Overload for printing out a CPU
  &"cores={x.cores},threads={x.threads},sockets={x.sockets}"

func `$`*(x: Vfio): string = ## Overload for printing out a VFIO.
  case x.kind:
    of vtGPU:
      if x.deviceName != "": x.deviceName
      else: &"\"{x.gpuType}, {x.vRam}\""
    of vtNET: x.mac
    else: $x.kind

func getVfio*(k: int, l: seq[string], dir: string): Option[Vfio] =
  ## getVfio - Parsing function to get the correct VFIO, handles both gpus
  ##           and networking cards.
  ##
  ## Inputs
  ## @k - Device class to use for the VFIO
  ## @l - List of information.
  ## @dir - Base directory for the VFIO.
  ##
  ## Returns
  ## @result - Either a VFIO device, or a none type.
  var vfio: Vfio
  case k
  of ord(vtNET):
    # NOTE: We require the device name and the MAC address.
    if len(l) == 2:

      vfio = Vfio(kind: vtNET)
      vfio.deviceName = l[0]
      vfio.mac = l[1]

      result = some(vfio)
    else:
      result = none(Vfio)
  of ord(vtGPU):
    # NOTE: 7 is a magic number due to how GIM works.
    if len(l) == 7 and startsWith(l[0], "VF"): # We only get the top level GPU
      let
        gpuType = split(l[1], ":")[1] # Gets the type of the GPU.
        size = parseInt(split(split(l[5], ":")[1], " ")[0]) # Gets size of
                                                            #  GPU.
        nameList = split(l[2], ":") # Gets the Device Id.
        name = join(nameList[1 .. 3], ":")

      vfio = Vfio(kind: vtGPU)
      vfio.virtNum = parseInt(l[0][4 .. ^1])
      vfio.deviceName = name
      vfio.gpuType = gpuType
      vfio.vRam = size
      vfio.base = dir / &"virtfn{vfio.virtNum}" / "driver_override"

      result = some(vfio)
    else: result = none(Vfio)
  else: result = none(Vfio)

func isNet*(x: Vfio): bool = x.kind == vtNET ## Helper function to figure out
                                             ##  if the VFIO is a network
                                             ##  device.
func isGpu*(x: Vfio): bool = x.kind == vtGPU ## Helper function to figure out
                                             ##  if the VFIO is a GPU device.
