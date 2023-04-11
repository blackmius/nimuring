import nimuring
import std/os

const path = getTempDir() / "test_io_uring_write_read"

var q = newQueue(4, {})
let fd = open(path, fmReadWrite).getFileHandle

var writeBuffer: array[20, uint8]
for i in 0..high(writeBuffer):
    writeBuffer[i] = 97
var sqe_write = q.write(cast[pointer](1), fd, writeBuffer[0].unsafeAddr, 10, 10)
sqe_write.linkNext() # TODO: maybe write some macro where each sqe will be linked

var readBuffer: array[20, uint8]
for i in 0..high(readBuffer):
    readBuffer[i] = 98

q.read(cast[pointer](2), fd, readBuffer[0].unsafeAddr, 10, 10)
q.submit()

var cqes = q.copyCqes(2)

assert cqes[0].userData == 1
assert cqes[0].res == 10

assert cqes[1].userData == 2
assert cqes[1].res == 10

for i in 0..<10:
    assert writeBuffer[i] == readBuffer[i]

for i in 10..high(writeBuffer):
    assert writeBuffer[i] != readBuffer[i]