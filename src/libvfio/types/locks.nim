#
# Copyright: 2666680 Ontario Inc.
# Reason: Lock file for the VMs.
#
import json
import uuids

import config, hardware

type
  Lock* = object      ## Lock object.
    config*: Config   ## Hardware configuration.
    vfios*: seq[Vfio] ## List of VFIOs.
    mdevs*: seq[Mdev] ## List of MDEV devices
    pidNum*: int      ## PID number controlling the lock file.
    save*: bool       ## Do we save the VM changes or not?

proc writeLockFile*(lockFile: string, lock: Lock) =
  ## writeLockFile - Writes a lock into a file named lockFile.
  ##
  ## Inputs
  ## @lockFile - Name of the file which will hold the lock.
  ## @lock - Lock to save in the file.
  ##
  ## Side effects - Writes a json file to the disk.
  writeFile(lockFile, $(%*lock))

proc getLockFile*(lockFile: string): Lock =
  ## getLockFile - Reads a lock file into memory.
  ##
  ## Inputs
  ## @lockFile - Name of the lockfile to read.
  ##
  ## Returns
  ## result - Lock file for the particular system.
  ##
  ## Side effects - Reads a file on the disk
  to(parseJson(readFile(lockFile)), Lock)

proc getUUID*(): string = $genUUID() ## Helper to get UUIDs.
