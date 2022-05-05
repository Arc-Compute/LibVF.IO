#
# Copyright: 2666680 Ontario Inc.
# Reason: Environment specific values.
#
import std/asyncnet
import std/options
import std/posix
import std/osproc
import std/json
import std/strutils
import std/strformat
import std/random

import hardware, process

type
  OsInstallEnum* = enum              ## Installs the specific OS in the system.
    osNone = "none",                 ## No auto installation script.
    osWin10 = "win10"                ## Auto install windows 10.

  ArcContainer* = object  ## Container for an Arc Kernel.
    kernel*: string       ## The kernel name.
    state*: seq[string]   ## Additional state drives.
    initialSize*: int     ## Initial size of the kernel, in GBs.
    iso*: Option[string]  ## ISO file if we are creating a new file.
                          ## NOTE: Apps are removed for the moment, they
                          ##       will come into the system a bit later.

  Installation* = object      ## Installation object.
    username*: string         ## Username to use.
    password*: string         ## Installation password to use.
    pathToSsh*: string        ## SSH Key to use.
    limeInstall*: string      ## LIME installation directory.
    introspectionDir*: string ## Introspection directory.
    lang*: string             ## Default language/locale to use.
    case os*: OsInstallEnum   ## Type of Os we are installing requires different things.
    of osWin10:
      productKey*: string     ## Windows product key.
    else:
      nil

  ## MONAD: Creates a monad for commands
  CommandMonad* = object
    oldUid*: Uid          ## User Identifier (UID) prior to root elevation.
    rootUid*: Uid         ## User Identifier (UID) post root elevation.
    sudo*: bool           ## Whether or not the process is currently running as root.

  VM* = object                           ## Running VM object.
    socket*: Option[AsyncSocket]         ## Connected QMP socket.
    child*: bool                         ## Are we in the parent or child process.
    lockFile*: string                    ## Lock file path.
    socketDir*: string                   ## Socket directory path.
    uuid*: string                        ## UUID for the VM.
    cid*: int                            ## CID of VM
    vfios*: seq[Vfio]                    ## Normal VFIO devices.
    mdevs*: seq[Mdev]                    ## VFIO-MDEV devices.
    introspections*: seq[string]         ## Introspections list.
    monad*: CommandMonad                 ## Root monad to allow us to use root.
    qemuPid*: owned(Process)             ## PID for qemu.
    liveKernel*: string                  ## Live Kernel name.
    baseKernel*: string                  ## Base Kernel name.
    newInstall*: bool                    ## New installation.
    save*: bool                          ## Do we save the VM.
    noCopy*: bool                        ## Do we copy the VM.
    sshPort*: int                        ## SSH Port to use.
    teardownCommands*: seq[CommandList]  ## Tearing down commands.


proc `%`*(vm: VM): JsonNode =
  ## Overload for converting VM to JSON.
  ##  excludes vm.socket and vm.qemuPid values from serialization
  result = %{
    "child": %vm.child,
    "lockFile": %vm.lockFile,
    "socketDir": %vm.socketDir,
    "uuid": %vm.uuid,
    "cid": %vm.cid,
    "vfios": %vm.vfios,
    "mdevs": %vm.mdevs,
    "introspections": %vm.introspections,
    "monad": %vm.monad,
    "liveKernel": %vm.liveKernel,
    "baseKernel": %vm.baseKernel,
    "newInstall": %vm.newInstall,
    "sshPort": %vm.sshPort,
    "save": %vm.save,
    "noCopy": %vm.noCopy,
    "teardownCommands": %vm.teardownCommands
  }


proc toVm*(js: JsonNode): VM =
  result.child = js["child"].getBool
  result.lockFile = js["lockFile"].getStr
  result.socketDir = js["socketDir"].getStr
  result.uuid = js["uuid"].getStr
  result.cid = js["cid"].getInt
  result.vfios = to(js["vfios"], seq[Vfio])
  result.mdevs = to(js["mdevs"], seq[Mdev])
  result.introspections = to(js["introspections"], seq[string])
  result.monad = to(js["monad"], CommandMonad)
  result.liveKernel = js["liveKernel"].getStr
  result.baseKernel = js["baseKernel"].getStr
  result.newInstall = js["newInstall"].getBool
  result.save = js["save"].getBool
  result.noCopy = js["noCopy"].getBool
  result.sshPort = js["sshPort"].getInt
  result.teardownCommands = to(js["teardownCommands"], seq[CommandList])
  # result.socket = createSocket(fmt"/tmp/sockets/{result.uuid}/master.sock")

proc randFromUuid*(uuid: string): int =
    var nStr = multiReplace(uuid, ("a",""), ("b",""), ("c",""),
        ("d",""), ("e",""), ("f",""), ("g",""), ("h",""), ("i",""),
        ("j",""), ("k",""), ("l",""), ("m",""), ("n",""), ("o",""),
        ("p",""), ("q",""), ("r",""), ("s",""), ("t",""), ("u",""),
        ("v",""), ("w",""), ("x",""), ("y",""), ("z",""), ("-",""))

    if nStr.len >= 19:
      nStr.delete(18..(nStr.len)-1)

    let n = parseInt(nStr)
    var r = initRand(n)
    result = r.rand(99999)
