import balls
import nimuring
import posix
import os

var q = newQueue(1, {})

const path = getTempDir() / "test_io_uring_openat";

q.openat(0, 0, path, O_CLOEXEC or O_RDWR or O_CREAT)
q.submit(1)

check fileExists(path)
removeFile(path)