import std/async
import nimuring/async as nasync

proc run() {.async.} =
  await cast[AsyncFD](stdout.getFileHandle).write("Hello world\n".cstring, 12) # 1
  echo "sync hello world"
  await cast[AsyncFD](stdout.getFileHandle).write("Hello world\n".cstring, 12) # 2

discard run()
poll() # 1
poll() # 2