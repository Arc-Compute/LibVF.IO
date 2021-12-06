# Package

version       = "1.0.4"
author        = "2666680 Ontario Inc."
description   = "Release 1"
license       = "AGPL"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["arcd"]


# Dependencies

requires "nim >= 1.4.8",
    "yaml",
    "uuids",
    "psutil",
    "terminaltables"

after build:
  echo "Finished building the process, we are now"
  echo "fixing the permissions to allow libvf.io to"
  echo "become root without asking for passwords."
  for i in bin:
    echo "Providing root permissions to: ", i
    exec("sudo setcap cap_setuid+ep ./" & i)
