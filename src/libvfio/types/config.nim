#
# Copyright: 2666680 Ontario Inc.
# Reason: Configuration specific parameters/loaders
#
import parseopt
import options
import os
import streams
import strutils
import logging
import yaml

import connectivity, hardware, environment, process

type
  CommandEnum* = enum                 ## Different first layer commands.
    ceHelp = "help",                 ## Help dialog.
    ceLs = "ls",                     ## List kernels, states, and apps.
    ceStart = "start",               ## Start a VM.
    ceCreate = "create",             ## Create a VM.
    ceIntrospect = "introspect"      ## Introspect a VM.
    ceStop = "stop",                 ## Stop a VM.
    cePs = "ps",                     ## List running VMs.
    ceDeploy = "deploy",             ## Deploy arcd's resources to disk.
    ceUndeploy = "undeploy"          ## Undeploy arcd's resources from disk.
    ceApp = "app"                    ## Runs arcd application.

  IntrospectEnum* = enum             ## Available introspection tools.
    isNone = "none",                 ## No introspection.
    isLookingGlass = "looking-glass" ## Looking Glass IVSHMEM Frame Relay

  RequestedGpuType* = enum           ## Types of GPUs we support.
    rgSRIOVGpu = "sriovdev",         ## PCI address based mediated device functionality.
    rgMdevGpu = "sysfsdev"           ## VFIO-Mdev based mediated device functionality.
    rgPassthroughGpu = "passthrough" ## Passthrough GPU using VFIO PCI.

  RequestedGpu* = object                ## Object to request a GPU.
    maxVRam*          {.defaultVal: 2000.}: int                       ## Maximum acceptable vRAM.
    minVRam*          {.defaultVal: 1000.}: int                       ## Minimal acceptable vRAM.
    case gpuType*: RequestedGpuType
    of rgSRIOVGpu:
      acceptableTypes*: seq[string]     ## Possible types of GPUs we accept
    of rgMdevGpu:
      mdevType*: string                 ## Wildcard that needs to appear in the type.
      parentPort*: Option[string]       ## Optional parent port override.
      devId*          {.defaultVal: "hostdev0".}: string              ## Name of the device for additional commands
                                                                      ##  in the command argument.
      suffix*         {.defaultVal: "".}: string                      ## Suffix for end of the name.
    of rgPassthroughGpu:
      bdf*: string                      ## Bus slot function for the GPU to pass.
      passthroughType*: Option[string]  ## Identifier for GPU on this Bus slot function

  RequestedNet* = object                ## Object to request a network NIC.
    mac*: string                        ## MAC address for the requested NIC.

  Config* = object                                                    ## Configuration object for spawning a
                                                                      ##  VM.
    startintro*       {.defaultVal: false.}: bool                     ## If we start the introspection by
                                                                      ##  default.
    name*             {.defaultVal: "".}: string                      ## VM name identifier
    startapp*         {.defaultVal: false.}: bool                     ## If we start the application by
                                                                      ##  default.
    installOs*        {.defaultVal: osNone.}: OsInstallEnum           ## Installs the given operating system
                                                                      ##  in a create command.
    nographics*       {.defaultVal: false.}: bool                     ## If we have the no graphics flag set.
    showhypervisor*   {.defaultVal: true.}: bool                      ## If we show hypervisor indication in vm
    spice*            {.defaultVal: false.}: bool                     ## If we want to use a spice server.
    introspect*       {.defaultVal: isLookingGlass.}: IntrospectEnum  ## What type of introspection we use.
    shareddir*        {.defaultVal: none(string).}: Option[string]    ## Shared directory between os and host.
    spicePort*        {.defaultVal: 5900.}: int                       ## Spice port number.
    sshPort*          {.defaultVal: 2222.}: int                       ## SSH port number.
    vncPort*          {.defaultVal: -1.}: int                         ## VNC port number.
    connectivity*     {.defaultVal: Connectivity(
                        exposedPorts: @[]).}: Connectivity            ## Code to connect to the machine.
    container*: ArcContainer                                          ## The specifics for how to spawn the
                                                                      ##  container.
    cpus*             {.defaultVal: Cpu(
                        cores: 4,
                        sockets: 1,
                        threads: 1,
                        ramAlloc: 8192).}: Cpu                        ## CPU parameters.
    gpus*             {.defaultVal: @[].}:  seq[RequestedGpu]         ## Structure for requesting GPUs.
    nics*             {.defaultVal: @[].}:  seq[RequestedNet]         ## Structure for requestion network nics.
    root*: string                                                     ## Current root for the system.
    sudo*             {.defaultVal: false.}: bool                     ## Do we run this vm as sudo?
    commands*         {.defaultVal: @[].}: seq[QemuArgs]              ## Additional commands to pass into qemu.
    startupCommands*  {.defaultVal: @[].}: seq[CommandList]           ## Startup command list.
    teardownCommands* {.defaultVal: @[].}: seq[CommandList]           ## Teardown command list.
    installCommands*  {.defaultVal: @[].}: seq[CommandList]           ## Installation command list.
    appCommands*      {.defaultVal: @[].}: seq[CommandList]           ## Application command list.
    blacklistedPci*   {.defaultVal: @[].}: seq[string]                ## Blacklisted PCI devices to avoid.

  CommandLineArguments* = object     ## Arguments passed into the system.
    config*: Option[string]          ## Path for the configuration file.
    root*: Option[string]            ## Base root of arcd installation.
    save*: bool                      ## Do we save the updated config?
    nocopy*: bool                    ## Helper to avoid having to copy the file
                                     ##  every single time (useful for prototyping)
    noconfig*: bool                  ## No user config preload.
    kernel*: Option[string]          ## Kernel image to use.
    shareddir*: Option[string]       ## Shared directory.
    preinstall*: bool                ## If the user is in a preinstall state.
    disablegpu*: bool                    ## If the user wants to detach the GPU on boot.
    safemode*: bool                  ## If the user is in a safemode state.
    case command*: CommandEnum       ## Different commands have different
                                     ##  variables, so we need to only allow
                                     ##  some variables to be used in the
                                     ##  different commands.
    of ceCreate:
      iso*: Option[string]           ## Installation image.
      size*: Option[int]             ## Size of the initial kernel.
    of ceStart:
      additionalStates*: seq[string] ## Additional state variables to send in.
    of ceStop, ceIntrospect, ceApp:
      uuid*: string                  ## UUID of the container we want to stop.
    of ceLs:
      option*: Option[string]        ## Option for ls [all, kernels, states, apps]
    of cePs:
      search*: Option[string]        ## UUID for more detailed ps command
    else:
      nil

const
  DefaultConfig = Config(            ## Default configuration value if nothing
                                     ##  is already found.
    startintro: false,
    startapp: false,
    installOs: osNone,
    nographics: false,
    spice: false,
    introspect: isLookingGlass,
    shareddir: none(string),
    sshPort: 2222,
    connectivity: Connectivity(
      exposedPorts: @[]
    ),
    container: ArcContainer(
      kernel: "windows.arc",
      state: @[],
      initialSize: 40,
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
    root: getHomeDir() / ".local" / "libvf.io",
    sudo: false,
    commands: @[],
    startupCommands: @[],
    teardownCommands: @[],
    installCommands: @[],
    appCommands: @[],
    blacklistedPci: @[]
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
    of $ceHelp:
      some(ceHelp)
    of $ceIntrospect:
      some(ceIntrospect)
    of $ceCreate:
      some(ceCreate)
    of $ceStart:
      some(ceStart)
    of $ceStop:
      some(ceStop)
    of $ceLs:
      some(ceLs)
    of $cePs:
      some(cePs)
    of $ceDeploy:
      some(ceDeploy)
    of $ceUndeploy:
      some(ceUndeploy)
    of $ceApp:
      some(ceApp)
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
        result = CommandLineArguments(command: get(command), nocopy: true)
      else:
        case result.command
        of ceCreate:
          if ".yaml" in key:
            result.config = some(key)
            i -= 1
          else:
            if i == 1:
              result.iso = some(key)
            elif i == 2:
              result.size = some(parseInt(key))
        of ceStart:
          if ".yaml" in key:
            result.config = some(key)
            i -= 1
          else:
            if i == 1:
              result.kernel = some(key)
            else:
              result.additionalStates &= key
        of ceStop, ceIntrospect:
          if i == 1:
            result.uuid = key
          elif i == 2:
            result.config = some(key)
        of ceLs:
          if i == 1:
            result.option = some(key)
        of cePs:
          if i == 1:
            result.search = some(key)
        of ceApp:
          if ".yaml" in key:
            result.config = some(key)
            i -= 1
          else:
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
      of "no-copy":
        result.nocopy = true
      of "copy":
        result.nocopy = false
      of "no-user-preload":
        result.noconfig = true
      of "kernel":
        if result.command == ceCreate:
          result.kernel = some(val)
      of "shared":
        result.shareddir = some(val)
      of "preinstall":
        result.preinstall = true
      of "advanced-help":
        echo("HELP ME I AM STUCK IN YOUR CPU")
        quit(1)
      of "safe-mode":
        result.safemode = true
      of "disable-gpu":
        result.disablegpu = true
      else: discard
    else: discard
  if result.command in @[ceStart, ceCreate, ceIntrospect] and isNone(result.config):
    echo("Config must be passed into arcd for these commands")
    quit(1)
  if result.command in @[ceStop, ceApp, ceIntrospect] and result.uuid == "":
    echo("UUID must be passed into arcd for these commands")
    quit(1)

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
  proc readConfig(s: string, prevRoot: string, prev: Config): Config =
    try:
      let
        root = if isSome(args.root): get(args.root)
               else: prevRoot
        fs = if fileExists(expandTilde(s)): newFileStream(s)
             else: newFileStream(root / "shells" / s)
      load(fs, result)
      close(fs)
    except YamlConstructionError as e:
      log(lvlError, e.msg)
      #echo "Error while reading config: ", e.msg
      quit(1)
    except:
      echo("Error reading config ", s, " or ", prevRoot, ": ", getCurrentExceptionMsg())
      quit(1)

  proc replaceConfig(d: Config, config: Option[string]): Config =
    if isSome(config):
      result = readConfig(get(config), d.root, d)
    else:
      result = d

  result = DefaultConfig

  # If no file was passed in.
  if isSome(args.config):
    # If there is a configuration file passed in.
    result = replaceConfig(result, args.config)

  # Overwrites the root.
  if isSome(args.root):
    result.root = get(args.root)

  # Update the configs using the command line arguments.
  if isSome(args.kernel):
    result.container.kernel = get(args.kernel)

  if isSome(args.shareddir):
    result.shareddir = args.shareddir

  case args.command
  of ceCreate:
    result.startintro = false
    result.nographics = false
    result.spice = false
    if isSome(args.iso):
      result.container.iso = args.iso
    if isSome(args.size):
      result.container.initialSize = get(args.size)
  of ceStart:
    if args.safemode:
      result.startintro = false
      result.nographics = false
      result.spice = false
    if args.preinstall:
      result.startintro = false
      result.nographics = false
      result.spice = false
      result.container.iso = some(result.root / "introspection-installations.rom")
    if args.disablegpu:
      result.gpus = @[]
    if len(args.additionalStates) != 0:
      result.container.state &= args.additionalStates
  else: discard

  result.root = expandTilde(result.root)
  if isSome(result.container.iso):
    result.container.iso = some(expandTilde(get(result.container.iso)))

proc writeConfigFile*(s: string, cfg: Config) =
  ## writeConfigFile - Saves the configuration file.
  ##
  ## Inputs
  ## @s - Name of the configuration file.
  ## @cfg - Configuration to save.
  ##
  ## Side effects - Writes a configuration file.
  let fileStream = newFileStream(s, fmWrite)
  let dumper = canonicalDumper()
  dumper.presentation.outputVersion = ov1_2
  dumper.dump(cfg, fileStream)
  close(fileStream)
