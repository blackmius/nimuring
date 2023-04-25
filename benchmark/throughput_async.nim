import std/async
import nimuring/async as nasync

import std/monotimes

var i = 0

proc run() {.async.} =
  while true:
    await nop()
    i += 1


const coroutines = 100_000
for _ in 0..<coroutines:
  discard run()

let start = getMonoTime().ticks
while i < 1_000_000:
  poll()
let duration = getMonoTime().ticks - start
echo duration.float / 1_000_000, "ms"