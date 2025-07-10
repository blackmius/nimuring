import unittest2
import nimuring
import std/os

template withWriteReadQueue(body: untyped) =
  let path {.inject.} = getTempDir() / "test_io_uring_write_read"
  var q {.inject.} = newQueue(4, {})
  let file = open(path, fmReadWrite)
  let fd {.inject.} = file.getFileHandle
  var writeBuffer {.inject.}: array[20, uint8]
  var readBuffer {.inject.}: array[20, uint8]
  try:
    for i in 0..high(writeBuffer):
      writeBuffer[i] = 97
    for i in 0..high(readBuffer):
      readBuffer[i] = 98
    body
  finally:
    close(file)
    if fileExists(path):
      removeFile(path)

suite "write/read operation":
  test "write then read with correct data":
    withWriteReadQueue:
      var sqe_write = q.write(cast[pointer](1), fd, writeBuffer[0].unsafeAddr, 10, 10)
      sqe_write.linkNext()
      q.read(cast[pointer](2), fd, readBuffer[0].unsafeAddr, 10, 10)
      q.submit()
      let cqes = q.copyCqes(2)
      check cqes[0].userData == 1
      check cqes[0].res == 10
      check cqes[1].userData == 2
      check cqes[1].res == 10
      for i in 0..<10:
        check writeBuffer[i] == readBuffer[i]
      for i in 10..high(writeBuffer):
        check writeBuffer[i] != readBuffer[i]

  test "write only":
    withWriteReadQueue:
      discard q.write(cast[pointer](1), fd, writeBuffer[0].unsafeAddr, 10, 10)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 1
      check cqes[0].res == 10

  test "read only after write":
    withWriteReadQueue:
      discard q.write(cast[pointer](1), fd, writeBuffer[0].unsafeAddr, 10, 10)
      q.submit()
      discard q.copyCqes(1)
      q.read(cast[pointer](2), fd, readBuffer[0].unsafeAddr, 10, 10)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 2
      check cqes[0].res == 10
      for i in 0..<10:
        check writeBuffer[i] == readBuffer[i]