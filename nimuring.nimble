# Package

version       = "0.2.0"
author        = "dterlyakhin"
description   = "io_uring wrapper"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.10"

task test, "Run tests":
  exec "testament all"