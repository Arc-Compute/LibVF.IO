#
# Copyright: 2666680 Ontario Inc.
# Reason: Introspection specific code.
#
import os
import osproc
import posix
import strformat
import logging

import ../types

func getIntrospections*(cfg: Config, uuid: string,
                        install: bool = false): seq[string] =
  ## getIntrospections - Gets a list of introspection devices.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID to use.
  ## @install - If we are installing there are no introspection tools we can use.
  ##
  ## Returns
  ## result - A list of devices that can be used for introspection.
  if not install:
    case cfg.introspect
    of isLookingGlass:
      result = @["/dev/shm/kvmfr-" & uuid, "/dev/shm/kvmsr-" & uuid]
    else: discard

proc lookingGlassIntrospect(introspections: seq[string], uuid: string) =
  ## lookingGlassIntrospect - Introspection using looking glass.
  ##
  ## Inputs
  ## @introspections - Devices we can run introspections on.
  ## @uuid - UUID Name for this introspection.
  ##
  ## Side effect - Spawns up a looking glass introspection window.
  let
    lookingGlassArgs = Args(
      exec: "/usr/local/bin/looking-glass-client",
      args: @[
        "-f", introspections[0], "-a", "yes", "egl:scale", "1", "-m", "58", "-p", cfg.spicePort,
        "input:rawMouse", "yes", "input:captureOnly", "yes", "spice:captureOnStart", "yes",
        "win:title=" & "Looking Glass + LibVF.IO (CapsLock toggles input | Hold CapsLock for menu) UUID: " & uuid
      ]
    )
    screamArgs = Args(
      exec: "/usr/local/bin/scream",
      args: @[
        "-m", introspections[1]
      ]
    )


  # Fork to spawn up the introspection client.
  let forkRet = fork()
  if forkRet > 0:
    return
  elif forkRet < 0:
    error("Could not fork for introspection process")
    return

  # Spawn up looking glass
  var
    lookingGlassPid = startProcess(
      lookingGlassArgs.exec,
      args=lookingGlassArgs.args,
      options={poEchoCmd, poParentStreams}
    )
    screamPid = startProcess(
      screamArgs.exec,
      args=screamArgs.args,
      options={poEchoCmd, poParentStreams}
    )

  # This allows us to potentially expend this introspection.
  discard waitForExit(lookingGlassPid)
  terminate(screamPid)
  quit(0)

proc realIntrospect*(intro: IntrospectEnum, introspections: seq[string],
                     uuid: string) =
  ## introspectVm - Starts an introspection script for the VM.
  ##
  ## Inputs
  ## @intro - Introspection type.
  ## @introspections - List of introspection devices.
  ## @uuid - UUID for the name of the introspection.
  ##
  ## Side effects - Opens all introspection devices.
  case intro
  of isLookingGlass:
    lookingGlassIntrospect(introspections, uuid)
  else: discard

proc introspectVm*(cfg: Config, uuid: string) =
  ## introspectVm - Starts an introspection script for the VM.
  ##
  ## Inputs
  ## @cfg - Configuration file to use.
  ## @uuid - UUID of the VM to introspect.
  ##
  ## Side effects - Opens all introspection devices.
  let
    lockFile = cfg.root / "lock" / &"{uuid}.json"
    lock = getLockFile(lockFile)
    config = lock.config
  realIntrospect(config.introspect, getIntrospections(config, uuid), uuid)
