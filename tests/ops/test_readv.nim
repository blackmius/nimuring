import balls
import nimuring
import posix

var q = newQueue(1, {})
let fd = open("/dev/zero").getFileHandle
var buffer: array[128, uint8]
for i in 0..high(buffer):
    buffer[i] = 42
let iovecs: seq[IoVec] = @[IoVec(iov_base: buffer[0].unsafeAddr, iov_len: 128)]
q.readv(cast[pointer](0xcccccccc), fd, iovecs)
q.submit()

var cqes = q.copyCqes(1)
check cqes[0].userData == 0xcccccccc.uint64

check cqes[0].userData == 0xcccccccc.uint64
check cqes[0].res == 128

for i in 0..high(buffer):
    check buffer[i] == 0