import balls
import nimuring
import posix
import std/os

const path = getTempDir() / "test_io_uring_writev_fsync_readv"

var q = newQueue(4, {})
let fd = open(path, fmReadWrite).getFileHandle

const offset = 13

var writeBuffer: array[128, uint8]
for i in 0..high(writeBuffer):
    writeBuffer[i] = 42 # todo: is there faster way to create array of {42, .... 42}
let iovecsWrite: seq[IoVec] = @[IoVec(iov_base: writeBuffer[0].unsafeAddr, iov_len: 128)]
var sqe_write = q.writev(cast[pointer](0xdddddddd), fd, iovecsWrite, offset)
sqe_write.linkNext() # TODO: maybe write some macro where each sqe will be linked

var sqe_fsync = q.fsync(cast[pointer](0xeeeeeeee), fd)
sqe_fsync.linkNext()


var readBuffer: array[128, uint8]
let iovecsRead: seq[IoVec] = @[IoVec(iov_base: readBuffer[0].unsafeAddr, iov_len: 128)]
q.readv(cast[pointer](0xffffffff), fd, iovecsRead, offset)

q.submit(waitNr=3)

var cqes = q.copyCqes(3)
check cqes[0].userData == 0xdddddddd.uint64
check cqes[0].res == 128

check cqes[1].userData == 0xeeeeeeee.uint64
check cqes[1].res == 0

check cqes[2].userData == 0xffffffff.uint64
check cqes[2].res == 128

for i in 0..high(writeBuffer):
    check writeBuffer[i] == readBuffer[i]