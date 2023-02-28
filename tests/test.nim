import nimuring/liburing

var ring: ref IoUring = (ref IoUring)()
discard ioUringQueueInit(4, ring, 0)

