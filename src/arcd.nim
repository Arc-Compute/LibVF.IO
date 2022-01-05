#
# Copyright: 2666680 Ontario Inc.
# Reason: Main file for running the arcd process
#
import std/options
import std/os
import std/posix

import libvfio/[control, logger, types, comms]

proc continueVM(vm: VM) =
  ## continueVM - Code for continuing a VM's sequence after it is started.
  ##
  ## Input
  ## @vm - VM to continue the lifecycle for.
  ##
  ## Side Effects - VM side effects.
  if vm.child:                                                     ## Continues VM.
    cleanVM(vm)

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
  echo("  arcd create user.yaml")
  echo("  arcd start user.yaml --preinstall")
  echo("  arcd start user.yaml")
  echo("  arcd ls")
  echo("  arcd ps")
  echo("  arcd introspect $UUID user.yaml")
  quit 0

when isMainModule:                                                 ## Checks if process is running as root and exits if it is.
  if getuid() == 0:
    echo("DO NOT RUN THIS AS ROOT")
    quit 0

  let
    cmd = getCommandLine()                                        ## Gets command line arguments.
    cfg = getConfigFile(cmd)                                      ## Gets config file. 
    log = cfg.root / "logs" / "arcd"                              ## Sets the log path.
    uid = getUUID()                                               ## Get the session UUID.
    homeConfigDir = getHomeDir() / ".config" / "arc"              ## Sets the config path. 

  createDir(log)                                                  ## Create the log directory. 
  createDir(homeConfigDir)                                        ## Create the config directory.
  initLogger(log / (uid & ".log"), true)                          ## Start logging.

  case cmd.command                                                ## Command line interface cases.
  of ceHelp:                                                      ## Print help dialog.
    printHelp()
  of ceCreate:                                                    ## Create VM.
    continueVM(startVm(cfg, uid, true, false, false))
  of ceStart:                                                     ## Start VM.
    continueVM(startVm(cfg, uid, false, cmd.nocopy, cmd.save))
  of ceStop:                                                      ## Stop VM via QEMU Machine Protocol (QMP) signal.
    stopVm(cfg, cmd)
  of ceIntrospect:                                                ## Introspect a VM.
    introspectVm(cfg, cmd.uuid) 
  of ceLs:                                                        ## List available kernels, states, and apps.
    arcLs(cfg, cmd)
  of cePs:                                                        ## List running VMs by UUID.
    arcPs(cfg, cmd)
  of ceDeploy:                                                    ## Deploy the arcd directory.
    removeFile(homeConfigDir / "arc.yaml")
    writeConfigFile(homeConfigDir / "arc.yaml", cfg)
    createDir(cfg.root / "states")
    copyFile(
      homeConfigDir / "introspection-installations.rom",
      cfg.root / "introspection-installations.rom"
    )
  of ceUndeploy:                                                  ## Undeploy the arcd directory
    removeFile(homeConfigDir / "arc.yaml")

  if cmd.save and isSome(cmd.config):                             ## Save the config file
    info("Saving new config file.")
    let config = get(cmd.config)
    removeFile(config)
    writeConfigFile(config, cfg)
