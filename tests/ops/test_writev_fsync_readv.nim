import unittest2
import nimuring
import posix
import std/os

template withWritevFsyncReadv(body: untyped) =
  let path {.inject.} = getTempDir() / "test_io_uring_writev_fsync_readv"
  var q {.inject.} = newQueue(4, {})
  let file = open(path, fmReadWrite)
  let fd {.inject.} = file.getFileHandle
  const offset {.inject.} = 13
  var writeBuffer {.inject.}: array[128, uint8]
  var readBuffer {.inject.}: array[128, uint8]
  let iovecsWrite {.inject.}: seq[IoVec] = @[IoVec(iov_base: writeBuffer[0].unsafeAddr, iov_len: 128)]
  let iovecsRead {.inject.}: seq[IoVec] = @[IoVec(iov_base: readBuffer[0].unsafeAddr, iov_len: 128)]
  try:
    for i in 0..high(writeBuffer):
      writeBuffer[i] = 42
    for i in 0..high(readBuffer):
      readBuffer[i] = 0
    body
  finally:
    close(file)
    if fileExists(path):
      removeFile(path)

suite "writev, fsync, readv operation":
  test "writev then fsync then readv":
    withWritevFsyncReadv:
      var sqe_write = q.writev(cast[pointer](0xdddddddd), fd, iovecsWrite, offset)
      sqe_write.linkNext()
      var sqe_fsync = q.fsync(cast[pointer](0xeeeeeeee), fd)
      sqe_fsync.linkNext()
      q.readv(cast[pointer](0xffffffff), fd, iovecsRead, offset)
      q.submit(waitNr=3)
      let cqes = q.copyCqes(3)
      check cqes[0].userData == 0xdddddddd.uint64
      check cqes[0].res == 128
      check cqes[1].userData == 0xeeeeeeee.uint64
      check cqes[1].res == 0
      check cqes[2].userData == 0xffffffff.uint64
      check cqes[2].res == 128
      for i in 0..high(writeBuffer):
        check writeBuffer[i] == readBuffer[i]

  test "writev only":
    withWritevFsyncReadv:
      discard q.writev(cast[pointer](0xdddddddd), fd, iovecsWrite, offset)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 0xdddddddd.uint64
      check cqes[0].res == 128

  test "fsync only after writev":
    withWritevFsyncReadv:
      discard q.writev(cast[pointer](0xdddddddd), fd, iovecsWrite, offset)
      q.submit()
      discard q.copyCqes(1)
      q.fsync(cast[pointer](0xeeeeeeee), fd)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 0xeeeeeeee.uint64
      check cqes[0].res == 0

  test "readv only after writev and fsync":
    withWritevFsyncReadv:
      discard q.writev(cast[pointer](0xdddddddd), fd, iovecsWrite, offset)
      q.fsync(cast[pointer](0xeeeeeeee), fd)
      q.submit(waitNr=2)
      discard q.copyCqes(2)
      q.readv(cast[pointer](0xffffffff), fd, iovecsRead, offset)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 0xffffffff.uint64
      check cqes[0].res == 128
      for i in 0..high(writeBuffer):
        check writeBuffer[i] == readBuffer[i]