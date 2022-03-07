#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function to get locks
#
import os
import std/strformat

import ../types


type
  wLock* = object  ## Wrapper for lock so it can contain path
    lock*: Lock
    path*: string

proc getLocks*(root: string): seq[wLock] =
  ## getLocks - Gets locks
  ## 
  ## Inputs
  ## @cfg: Config - Config object to get arcRoot
  ## 
  ## Returns
  ## result - List of wrapped locks 
  ## 
  ## Side effects - reading files on system
  let pattern = root / "lock" / "*.json"

  for filePath in walkPattern(pattern):
    let l = wLock(
      lock: getLockFile(filePath),
      path: filePath
    )
    if not dirExists(&"/proc/{l.lock.pidNum}"):
      removeFile(filePath)
    else:
      result &= l

proc findLocksByUuid*(root: string, uuid: string): seq[wLock] =
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
  ## @cfg: Config - Config object to get arcRoot
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
