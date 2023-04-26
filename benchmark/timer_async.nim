when defined(nimuring):
  import nimuring/async
# (seconds: 2, nanosecond: 898271)
# (seconds: 2, nanosecond: 712721)
# (seconds: 2, nanosecond: 68105)
# (seconds: 2, nanosecond: 225934)
# (seconds: 2, nanosecond: 120265)
# (seconds: 2, nanosecond: 721209)
# (seconds: 2, nanosecond: 729402)
# (seconds: 2, nanosecond: 711149)
# (seconds: 2, nanosecond: 704166)
# (seconds: 2, nanosecond: 177247)
# (seconds: 2, nanosecond: 633842)
else:
  import std/asyncdispatch
# (seconds: 2, nanosecond: 1366304)
# (seconds: 2, nanosecond: 2068084)
# (seconds: 2, nanosecond: 1686382)
# (seconds: 2, nanosecond: 919747)
# (seconds: 2, nanosecond: 643899)
# (seconds: 2, nanosecond: 812972)
# (seconds: 2, nanosecond: 1884320)
# (seconds: 2, nanosecond: 1484132)
# (seconds: 2, nanosecond: 1796494)
# (seconds: 2, nanosecond: 1396925)
# (seconds: 2, nanosecond: 1384705)

import std/monotimes

proc run() {.async.} =
  for i in 0..10:
    var time = getMonoTime()
    await sleepAsync(2000)
    echo getMonoTime() - time

discard run()

runForever()