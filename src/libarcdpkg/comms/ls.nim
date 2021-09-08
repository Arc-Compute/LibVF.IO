#
# Copyright: 2666680 Ontario Inc..
# Reason: Provide functions for ls
#
import os
import strformat

import ../types


type
  LsEnum* = enum                        ## Plausible ls commands
    leKernels = "kernels",
    leStates = "states",
    leApps = "apps",
    leAll = "all"


const patterns: array[3, string] = [    ## Array to contain patterns
  "kernels/*.arc",                      ## kernels pattern
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


proc arcLs*(cfg: Config, lsEnum: LsEnum = leAll) =
  ## arcLs - Prints a list of available containers
  ## 
  ## Inputs
  ## @cfg - Config object that contains arcRoot
  ## @lsEnum - Chosen ls subcommand
  ## 
  ## Side effects - reading files and printing to terminal
  case lsEnum
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
