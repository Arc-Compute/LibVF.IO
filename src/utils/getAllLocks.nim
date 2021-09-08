import os

import ../types/config
import ../types/locks
import ../locks/io

proc getAllLocks*(cfg: Config): seq[Lock] =
  var lockFilePath = cfg.paths.arcRoot & "/lock/"
  for kind, path in walkDir(lockFilePath):
    result.add(getLockFile(path))
