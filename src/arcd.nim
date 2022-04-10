#
# Copyright: 2666680 Ontario Inc.
# Reason: Main file for running the arcd process
#
import std/options
import std/os
import std/posix

import libvfio/[control, logger, types, comms]
import libvfio/utils/getLocks

proc continueVm(vm: VM) =
  ## continueVm - Code for continuing a VM's sequence after it is started.
  ##
  ## Input
  ## @vm - VM to continue the lifecycle for.
  ##
  ## Side Effects - VM side effects.
  if vm.child:                                                  ## Continues VM.
    cleanVm(vm)

proc printHelp() =
  ## printHelp - Code for printing help dialog
  ##
  ## Input
  ## none
  ##
  ## Side Effects - Prints help dialog to the terminal.
  echo("LibVF.IO: A vendor neutral GPU multiplexing tool driven by VFIO & YAML.")
  echo("")
  echo("usage: arcd <operation> [...]")
  echo("operations:")
  echo("  arcd create user.yaml boot.iso [disk-size]")
  echo("  arcd start user.yaml --preinstall")
  echo("  arcd start user.yaml")
  echo("  arcd start user.yaml --safe-mode")
  echo("  arcd start user.yaml --disable-gpu")
  echo("  arcd ls")
  echo("  arcd ps")
  echo("  arcd introspect $UUID user.yaml")
  quit 0

when isMainModule:                                              ## Checks if process is running as root and exits if it is.
  if getuid() == 0:
    echo("DO NOT RUN THIS AS ROOT")
    quit 0

  let
    cmd = getCommandLine()                                            ## Gets command line arguments.
    cfg = getConfigFile(cmd)                                          ## Gets config file.
    log = cfg.root / "logs" / "arcd"                                  ## Sets the log path.
    uid = getUUID()                                                   ## Get the session UUID.
    homeConfigDir = getHomeDir() / ".config" / "arc"                  ## Sets the config path.

  createDir(log)                                                      ## Create the log directory.
  createDir(homeConfigDir)                                            ## Create the config directory.
  initLogger(log / (uid & ".log"), true)                              ## Start logging.

  case cmd.command                                                    ## Command line interface cases.
  of ceHelp:                                                          ## Print help dialog.
    printHelp()
  of ceCreate:                                                        ## Create VM.
    continueVm(startVm(cfg, uid, true, false, false, true))
  of ceStart:                                                         ## Start VM.
    continueVm(startVm(cfg, uid, false, cmd.nocopy, cmd.save, true))
  of ceStop:                                                          ## Stop VM via QEMU Machine Protocol (QMP) signal.
      if cmd.save == true :
        changeLockSave(cfg.root, cmd.uuid, true)
      stopVm(cmd.uuid)
  of ceIntrospect:                                                    ## Introspect a VM.
    introspectVm(cfg, cmd.uuid)
  of ceLs:                                                            ## List available kernels, states, and apps.
    arcLs(cfg, cmd)
  of cePs:                                                            ## List running VMs by UUID.
    arcPs(cfg, cmd)
  of ceDeploy:                                                        ## Deploy the arcd directory.
    createDir(cfg.root / "states")
    let temp = homeConfigDir / "introspection-installations"
    if fileExists(temp & ".rom"):
      copyFile(
        temp & ".rom",
        cfg.root / "introspection-installations.rom"
      )
    if dirExists(temp):
      copyDirWithPermissions(
        temp,
        cfg.root / "introspection-installations"
      )
  of ceUndeploy:                                                      ## Undeploy the arcd directory
    discard
  of ceApp:
    startApp(cfg, cmd)

  if cmd.save and isSome(cmd.config):                                 ## Save the config file
    info("Saving new config file.")
    let config = get(cmd.config)
    removeFile(config)
    writeConfigFile(config, cfg)
