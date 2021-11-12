#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide functions for ls
#
import std/[os, strformat, strutils, options]

import ../types

type
  LsEnum = enum                         ## Sub commands for ls.
    leKernels = "kernels",              ## List only the available kernels.
    leStates = "states",                ## List only the available states.
    leApps = "apps",                    ## List only the available apps.
    leAll = "all"                       ## List everything

converter toOption(s: string): LsEnum = parseEnum[LsEnum](s, leAll)

const patterns: array[3, string] = [    ## Array to contain patterns
  "kernel/*.arc",                       ## kernels pattern
  "states/*.?(arc|qcow2)",              ## states pattern
  "shells/*.yaml",                      ## apps pattern
]


proc lsFiles(cfg: Config, lsEnum: LsEnum) =
  ## lsFiles - Outputs container names to stdout
  ## 
  ## Inputs
  ## @cfg - Config object to get arcRoot
  ## @lsEnum - Containers to be outputted
  ## 
  ## Side effects - reading files and outputting
  ##  to stdout
  let pattern = cfg.root / patterns[int(lsEnum)]

  echo &"Available {lsEnum}:"
  for filePath in walkPattern(pattern):
    echo extractFilename(filePath)
  echo '\l'


proc arcLs*(cfg: Config, cmd: CommandLineArguments) =
  ## arcLs - Prints a list of available containers
  ## 
  ## Inputs
  ## @cfg - Config object that contains arcRoot
  ## @cmd - Get chosen subcommand
  ## 
  ## Side effects - reading files and printing to terminal
  if isSome(cmd.option):
    let option = toOption(get(cmd.option))
    case option
    of leAll:
      lsFiles(cfg, leKernels)
      lsFiles(cfg, leStates)
      lsFiles(cfg, leApps)
    of leKernels:
      lsFiles(cfg, leKernels)
    of leStates:
      lsFiles(cfg, leStates)
    of leApps:
      lsFiles(cfg, leApps)
  else:
      lsFiles(cfg, leKernels)
      lsFiles(cfg, leStates)
      lsFiles(cfg, leApps)
