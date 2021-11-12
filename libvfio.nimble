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
    "yaml >= 0.16.0",
    "uuids >= 0.1.11",
    "psutil >= 0.6.0",
    "terminaltables >= 0.1.1"
