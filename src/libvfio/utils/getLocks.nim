#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function to get locks
#
import os
import std/strformat
import logging

import ../types
import ../control/vm


type
  wLock* = object  ## Wrapper for lock so it can contain path
    lock*: Lock
    path*: string

proc getLocks*(root: string): seq[wLock] =
  ## getLocks - Gets locks and cleans after dead vms
  ## 
  ## Inputs
  ## @root: string - String to get arcRoot
  ## 
  ## Returns
  ## result - List of wrapped locks 
  ## 
  ## Side effects - reading and deleting files on system
  let pattern = root / "lock" / "*.json"

  for filePath in walkPattern(pattern):
    let l = wLock(
      lock: getLockFile(filePath),
      path: filePath
    )
    if not dirExists(&"/proc/{l.lock.pidNum}"):
      notice(fmt"PID of vm {splitFile(l.path).name} not running. Cleaning up")
      cleanVm(l.lock.vm)                      ## Clean dead VM
      removeFile(filePath)                    ## Remove dead VM's lock file
    else:
      result &= l

proc findLocksByUuid*(root, uuid: string): seq[wLock] =
  ## findLocksByUuid - Finds locks by matching UUID
  ## 
  ## Inputs
  ## @root: string - String to get arcRoot
  ## @uuid: string - UUID to match
  ## 
  ## Returns
  ## result - list of wrapped Locks
  ## 
  ## Side effects - reading files on system
  let pattern = root / "lock" / "*" & uuid & "*.json"

  for filePath in walkPattern(pattern):
    let l = wLock(
      lock: getLockFile(filePath),
      path: filePath
    )
    if not dirExists(&"/proc/{l.lock.pidNum}"):
      removeFile(filePath)
    else:
      result &= l

proc findLocksByPid*(root: string, pid: int): seq[wLock] =
  ## findLocksByPid - Finds locks by matching PID
  ## 
  ## Inputs
  ## @root: string - String to get arcRoot
  ## @pid: int - PID to match
  ## 
  ## Returns
  ## result - list of wrapped Locks
  ## 
  ## Side effects - reading files on system
  let pattern = root / "lock" / "*.json"

  for filePath in walkPattern(pattern):
    let lock = getLockFile(filePath)
    if lock.pidNum == pid:
      let l = wLock(
        lock: getLockFile(filePath),
        path: filePath
      )
      if not dirExists(&"/proc/{l.lock.pidNum}"):
        removeFile(filePath)
      else:
        result &= l

proc changeLockSave*(root, uuid: string, save: bool) =
  ## changeLockSave - Get lock corresponding to uuid and change
  ##  save field of lock's vm object
  ##
  ## Inputs
  ## @root: string - String to get arcRoot
  ## @uuid: string - UUID to match
  ## @save: bool - Value to set as VM object's save field
  ##
  ## Side effects - read and write of files on system
  var lock : Lock
  for l in findLocksByUuid(root, uuid) :
    lock = getLockFile(l.path)
    lock.vm.save = save
    debug(fmt"VM {uuid} container save set to {lock.vm.save}")
    writeLockFile(l.path, lock)
  sleep(2000) # Sleeping to avoid trying to open the file too soon.
