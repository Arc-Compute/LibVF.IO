#
# Copyright: 2666680 Ontario Inc.
# Reason: Provide function to get locks
#
import std/os

import ../types


type
  WLock* = object  ## Wrapper for lock so it can contain path
    lock*: Lock
    path*: string

proc initWlock(lock: Lock, path: string): WLock =
  WLock(
    lock: lock,
    path: path
  )

proc getLocks*(cfg: Config): seq[WLock] =
  ## getLocks - Gets locks
  ## 
  ## Inputs
  ## @cfg: Config - Config object to get arcRoot
  ## 
  ## Returns
  ## result - List of wrapped locks 
  ## 
  ## Side effects - reading files on system
  let pattern = cfg.root / "lock" / "*.json"

  for filePath in walkPattern(pattern):
    result &= initWlock(getLockFile(filePath), filePath)

proc findLocksByUuid*(cfg: Config, uuid: string): seq[WLock] =
  ## findLocksByUuid - Finds locks by matching UUID
  ## 
  ## Inputs
  ## @cfg: Config - Config object to get arcRoot
  ## @uuid: string - UUID to match
  ## 
  ## Returns
  ## result - list of wrapped Locks
  ## 
  ## Side effects - reading files on system
  let pattern = cfg.root / "lock" / "*" & uuid & "*.json"

  for filePath in walkPattern(pattern):
    result &= initWlock(getLockFile(filePath), filePath)

proc findLocksByPid*(cfg: Config, pid: int): seq[WLock] =
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
  let pattern = cfg.root / "lock" / "*.json"

  for filePath in walkPattern(pattern):
    let lock = getLockFile(filePath)
    if lock.pidNum == pid:
      result &= initWlock(getLockFile(filePath), filePath)
