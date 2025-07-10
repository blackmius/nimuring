# Package

version       = "0.2.1"
author        = "dterliakhin"
description   = "io_uring wrapper"
license       = "MIT"
srcDir        = "src"

when declared(taskRequires):
  taskRequires "test", "unittest2"
