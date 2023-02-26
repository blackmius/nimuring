import ../src/nimuring

proc perror(s: cstring) {.importc, header: "<stdio.h>".}

var params: io_uring_params
let res = io_uring_setup(1, params.addr)
if res < 0:
  perror "error"
  assert false