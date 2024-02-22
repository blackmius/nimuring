# Package

version       = "0.2.0"
author        = "dterlyakhin"
description   = "io_uring wrapper"
license       = "MIT"
srcDir        = "src"

when declared(taskRequires):
  taskRequires "test", "https://github.com/disruptek/balls >= 3.0.0"
