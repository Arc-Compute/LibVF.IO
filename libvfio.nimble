# Package

version       = "1.0.4.1"
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
