import unittest2
import nimuring
import posix
import os

template withTempFile(body: untyped) =
  let path {.inject.} = getTempDir() / "test_io_uring_openat"
  try:
    body
  finally:
    if fileExists(path):
      removeFile(path)

suite "openat operation":
  test "openat creates file":
    withTempFile:
      var q = newQueue(1, {})
      q.openat(0, 0, path, O_CLOEXEC or O_RDWR or O_CREAT)
      q.submit(1)
      check fileExists(path)