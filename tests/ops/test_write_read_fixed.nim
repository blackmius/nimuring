import unittest2
import nimuring
import std/os
import posix

template withFixedBuffers(body: untyped) =
  let path {.inject.} = getTempDir() / "test_io_uring_write_read_fixed"
  var q {.inject.} = newQueue(4, {})
  let fd {.inject.} = open(path, fmReadWrite).getFileHandle
  var writeBuffer {.inject.}: array[11, char]
  copyMem(writeBuffer[0].addr, "zzzf0obarzz".cstring, 11)
  var readBuffer {.inject.}: array[11, char]
  let iovecs {.inject.}: seq[IoVec] = @[
    IoVec(iov_base: writeBuffer[0].addr, iov_len: 11),
    IoVec(iov_base: readBuffer[0].addr, iov_len: 11)
  ]
  q.registerBuffers(iovecs)
  try:
    body
  finally:
    discard close(fd)
    if fileExists(path):
      removeFile(path)

suite "writev_fixed/readv_fixed operation":
  test "writev_fixed writes data":
    withFixedBuffers:
      var sqe_write = q.writev_fixed(cast[pointer](1), fd, iovecs[0], 3, 0)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 1
      check cqes[0].res == 11

  test "readv_fixed reads data":
    withFixedBuffers:
      discard q.writev_fixed(cast[pointer](1), fd, iovecs[0], 3, 0)
      q.submit()
      discard q.copyCqes(1)
      var sqe_read = q.readv_fixed(cast[pointer](2), fd, iovecs[1], 3, 1)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 2
      check cqes[0].res == 11
      for i in 0..10:
        check readBuffer[i] == writeBuffer[i]

  test "writev_fixed and readv_fixed chained":
    withFixedBuffers:
      var sqe_write = q.writev_fixed(cast[pointer](1), fd, iovecs[0], 3, 0)
      sqe_write.linkNext()
      q.readv_fixed(cast[pointer](2), fd, iovecs[1], 3, 1)
      q.submit()
      let cqes = q.copyCqes(2)
      check cqes[0].userData == 1
      check cqes[0].res == 11
      check cqes[1].userData == 2
      check cqes[1].res == 11
      for i in 0..10:
        check readBuffer[i] == writeBuffer[i]