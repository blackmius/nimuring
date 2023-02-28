import nimuring/io_uring
import os

var params: io_uring_params
let res = io_uring_setup(1, params.addr)
if res < 0:
  raiseOSError(osLastError())
  assert false