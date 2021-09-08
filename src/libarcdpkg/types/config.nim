#
# Copyright: 2666680 Ontario Inc..
# Reason: Configuration specific parameters/loaders
#
import parseopt
import options
import os
import streams
import strutils
import logging
import yaml

import connectivity, hardware, environment

type
  CommandEnum* = enum                ## Different first layer commands.
    ceCreate = "create",
    ceStart = "start",
    ceStop = "stop",
    ceLs = "ls",
    cePs = "ps"

  RequestedGpu* = object             ## Object to request a GPU.
    acceptableTypes*: seq[string]    ## Possible types of GPUs we accept
    maxVRam*: int                    ## Maximum acceptable vRAM.
    minVRam*: int                    ## Minimal acceptable vRAM.

  RequestedNet* = object             ## Object to request a network NIC.
    mac*: string                     ## MAC address for the requested NIC.

  Config* = object                   ## Configuration object for spawning a
                                     ##  VM.
    connectivity*: Connectivity      ## Code to connect to the machine.
    container*: ArcContainer         ## The specifics for how to spawn the
                                     ##  container.
    cpus*: Cpu                       ## CPU parameters.
    gpus*: seq[RequestedGpu]         ## Structure for requesting GPUs.
    nics*: seq[RequestedNet]         ## Structure for requestion network nics.
    root*: string                    ## Current root for the system.

  CommandLineArguments* = object     ## Arguments passed into the system.
    config*: Option[string]          ## Path for the configuration file.
    root*: Option[string]            ## Base root of arcd installation.
    save*: bool                      ## Do we save the updated config?
    case command*: CommandEnum       ## Different commands have different
                                     ##  variables, so we need to only allow
                                     ##  some variables to be used in the
                                     ##  different commands.
    of ceCreate:
      iso*: Option[string]           ## Installation image.
      size*: Option[int]             ## Size of the initial kernel.
    of ceStart:
      kernel*: Option[string]        ## Kernel image to use.
      additionalStates*: seq[string] ## Additional state variables to send in.
    of ceStop:
      uuid*: string                  ## UUID of the container we want to stop.
    else:
      nil                            ## No more arguments can be parsed.

const
  DefaultConfig = Config(            ## Default configuration value if nothing
                                     ##  is already found.
    connectivity: Connectivity(
      exposedPorts: @[
        Port(guest: 22, host: 2222),
        Port(guest: 5901, host: 5900),
        Port(guest: 8080, host: 8000)
      ]
    ),
    container: ArcContainer(
      kernel: "ubuntu-20.04.arc",
      state: @[],
      initialSize: 20,
      iso: none(string)
    ),
    cpus: Cpu(
      cores: 8,
      sockets: 1,
      threads: 2,
      ramAlloc: 8192
    ),
    gpus: @[],
    nics: @[],
    root: "/opt/arc"
  )

proc getCommandLine*(): CommandLineArguments =
  ## getCommandLine - Gets the options sent through on the command line.
  ##
  ## Returns
  ## result - A command line argument structure which can be used to update a
  ##          config file.
  ##
  ## Side effects - Reads the command line arguments.
  func getCommand(key: string): Option[CommandEnum] =
    case toLowerAscii(key)
    of $ceCreate:
      some(ceCreate)
    of $ceStart:
      some(ceStart)
    of $ceStop:
      some(ceStop)
    else: none(CommandEnum)

  var
    p = initOptParser()
    i = 0

  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if i == 0:
        let command = getCommand(key)
        var exp: ref Exception
        new(exp)
        exp.msg = "Invalid command format."
        if isNone(command): raise exp
        result = CommandLineArguments(command: get(command))
      else:
        case result.command
        of ceCreate:
          if i == 1:
            result.iso = some(key)
          elif i == 2:
            result.size = some(parseInt(key))
        of ceStart:
          if i == 1:
            result.kernel = some(key)
          else:
            result.additionalStates &= key
        of ceStop:
          if i == 1:
            result.uuid = key
        else: discard
      i += 1
    of cmdLongOption:
      case key
      of "root":
        result.root = some(val)
      of "config":
        result.config = some(val)
      of "save":
        result.save = true
      else: discard
    else: discard

proc getConfigFile*(args: CommandLineArguments): Config =
  ## getConfigFile - Loads a configuration file from disk into memory.
  ##
  ## Inputs
  ## @args - Command line arguments to load the configuration file/modify
  ##         the configuration file with.
  ##
  ## Returns
  ## result - A config file that can be used to create/start/stop an Arc
  ##          Container.
  ##
  ## Side effects - Reads a configuration file from diskspace.
  proc readConfig(s: string): Config =
    try:
      let fs = newFileStream(s)
      load(fs, result)
      close(fs)
    except:
      result = DefaultConfig

  proc replaceConfig(d: Config, config: Option[string]): Config =
    # TODO: Add ability to only pass in from shells in the root.
    if isSome(config):
      result = readConfig(get(config))
    else:
      result = d

  result = DefaultConfig

  # If a user defined initial configuration is built.
  if fileExists("/etc/arc.yaml"):
    result = readConfig("/etc/arc.yaml")

  # If no file was passed in.
  if isSome(args.config):
    # If there is a configuration file passed in.
    result = replaceConfig(result, args.config)

  # Update the configs using the command line arguments.
  case args.command
  of ceCreate:
    if isSome(args.iso):
      result.container.iso = args.iso
    if isSome(args.size):
      result.container.initialSize = get(args.size)
  of ceStart:
    if isSome(args.kernel):
      result.container.kernel = get(args.kernel)
    if len(args.additionalStates) != 0:
      result.container.state &= args.additionalStates
  else: discard

proc writeConfigFile*(s: string, cfg: Config) =
  ## writeConfigFile - Saves the configuration file.
  ##
  ## Inputs
  ## @s - Name of the configuration file.
  ## @cfg - Configuration to save.
  ##
  ## Side effects - Writes a configuration file.
  let fileStream = newFileStream(s, fmWrite)
  dump(cfg, fileStream)
  close(fileStream)
