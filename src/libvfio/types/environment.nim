#
# Copyright: 2666680 Ontario Inc.
# Reason: Environment specific values.
#
import std/asyncnet
import std/options
import std/posix
import std/osproc

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
