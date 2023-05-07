when defined(nimuring):
  import nimuring/async
  # coro: 1 time: 1514ms
  # coro: 10 time: 352ms
  # coro: 100 time: 116ms
  # coro: 1000 time: 111ms
  # coro: 100000 time: 156ms
  # coro: 1000000 time: 155ms
else:
  import asyncdispatch
  # coro: 1 time: 143ms
  # coro: 10 time: 129ms
  # coro: 100 time: 127ms
  # coro: 1000 time: 134ms
  # coro: 100000 time: 220ms
  # coro: 1000000 time: 462ms

  discard getGlobalDispatcher()

  proc nop(): Future[void] =
    var retfuture = newFuture[void]("nop")
    proc cb() =
      retfuture.complete()
    callSoon(cb)
    return retfuture

import std/monotimes, times

var i = 0

proc run() {.async.} =
  while i < 1_000_000:
    await nop()
    i += 1

for coros in @[1, 10, 100, 1000, 100_000, 1_000_000]:
  i = 0
  for _ in 0..coros:
    asyncCheck run()
  let start = getMonoTime()
  while i < 1_000_000:
    poll()
  echo "coro: ", coros, " time: ", (getMonoTime() - start).inMilliseconds, "ms"