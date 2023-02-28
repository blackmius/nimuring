import nimuring
import os

var ring: ref IoUring = (ref IoUring)()
if ioUringQueueInit(4, ring, 0) != 0:
  raiseOsError osLastError()

var sce: ref IoUringSqe = ioUringGetSqe(ring)
echo sce[]