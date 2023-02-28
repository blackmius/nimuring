import nimuring
import os

var ring: ref IoUring = (ref IoUring)()
if ioUringQueueInit(4, ring, 0) != 0:
  raiseOsError osLastError()

var sqe = ioUringGetSqe(ring)

let buf = "Hello world\n"
ioUringPrepWrite(sqe, stdout.getFileHandle, cstring(buf), buf.len.cuint, 0)

discard ioUringSubmit(ring)

var cqe: ptr IoUringCqe
if ioUringWaitCqe(ring, cqe.addr) != 0:
  raiseOsError osLastError()

assert cqe.res > 0

ioUringCqeSeen(ring, cqe)

ioUringQueueExit(ring)