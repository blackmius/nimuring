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
assert cqes[0].userData == 0xcccccccc.uint64

assert cqes[0].userData == 0xcccccccc.uint64
assert cqes[0].res == 128

for i in 0..high(buffer):
    assert buffer[i] == 0