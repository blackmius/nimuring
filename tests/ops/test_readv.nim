import unittest2
import nimuring
import posix

template withReadvQueue(body: untyped) =
  var q {.inject.} = newQueue(1, {})
  let fd {.inject.} = open("/dev/zero").getFileHandle
  var buffer {.inject.}: array[128, uint8]
  for i in 0..high(buffer):
    buffer[i] = 42
  let iovecs {.inject.}: seq[IoVec] = @[IoVec(iov_base: buffer[0].unsafeAddr, iov_len: 128)]
  try:
    body
  finally:
    discard close(fd)

suite "readv operation":
  test "readv fills buffer with zeros":
    withReadvQueue:
      q.readv(cast[pointer](0xcccccccc), fd, iovecs)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 0xcccccccc.uint64
      check cqes[0].res == 128
      for i in 0..high(buffer):
        check buffer[i] == 0

  test "readv userData and result":
    withReadvQueue:
      q.readv(cast[pointer](0xcccccccc), fd, iovecs)
      q.submit()
      let cqes = q.copyCqes(1)
      check cqes[0].userData == 0xcccccccc.uint64
      check cqes[0].res == 128