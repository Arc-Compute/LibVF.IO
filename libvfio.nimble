# Package

version       = "1.0.5"
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

proc set_capabilities(s: string) =
  exec("sudo setcap cap_setgid,cap_fsetid,cap_setuid=+ep " & s)

after build:
  echo "Finished building the process, we are now"
  echo "fixing the permissions to allow libvf.io to"
  echo "become root without asking for passwords."
  for i in bin:
    echo "Providing root permissions to: ", i
    set_capabilities("./" & i)

after install:
  echo "Moving files to avoid symbolic linking."
  for i in bin:
    echo "Moving file: ", i
    exec("mv " & i & " ~/.nimble/bin")
    set_capabilities("~/.nimble/bin/" & i)
