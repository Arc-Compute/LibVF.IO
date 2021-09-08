import os

proc printList*(list: seq[string]) =
  for path in list:
    echo extractFilename(path)
