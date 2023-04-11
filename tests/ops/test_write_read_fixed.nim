import nimuring
import std/os
import posix

const path = getTempDir() / "test_io_uring_write_read_fixed"

var q = newQueue(4, {})
let fd = open(path, fmReadWrite).getFileHandle

var writeBuffer: array[11, char] = ['z', 'z', 'z', 'f', '0', 'o', 'b', 'a', 'r', 'z', 'z']
var readBuffer: array[11, char]
let iovecs: seq[IoVec] = @[
    IoVec(iov_base: writeBuffer[0].unsafeAddr, iov_len: 11),
    IoVec(iov_base: readBuffer[0].unsafeAddr, iov_len: 11)
]

# q.registerBuffers(iovecs)

var sqe_write = q.writev_fixed(cast[pointer](1), fd, iovecs[0..0], 3, 0)
sqe_write.linkNext()


q.readv_fixed(cast[pointer](2), fd, iovecs[1..1], 0, 1)
q.submit()

var cqes = q.copyCqes(2)

assert cqes[0].userData == 1
assert cqes[0].res == 11

assert cqes[1].userData == 2
assert cqes[1].res == 11

let result: array[11, char] = ['\0', '\0', '\0', 'f', '0', 'o', 'b', 'a', 'r', 'z', 'z']
for i in 0..10:
    assert readBuffer[i] == result[i]