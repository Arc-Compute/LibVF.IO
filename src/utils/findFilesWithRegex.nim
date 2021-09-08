import os
import re

proc findFilesWithRegex*(path: string, pattern: Regex): seq[string] =
  for filePath in walkDirRec(path):
    if match(filePath, pattern):
      result &= filePath
