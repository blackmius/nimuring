# Package

version       = "0.2.1"
author        = "dterliakhin"
description   = "io_uring wrapper"
license       = "MIT"
srcDir        = "src"

requires "unittest2"

task test, "Run all tests" :
  exec "nimble --verbose c -r tests/test_all.nim"