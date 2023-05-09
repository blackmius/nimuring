# Intel(R) Core(TM) i7-10850H CPU @ 2.70GHz
# threads: 1 count: 7 733 497 count per thread: 7 733 497
# threads: 2 count: 12 004 674 count per thread: 6 002 337
# threads: 4 count: 16 913 595 count per thread: 4 228 398.75
# threads: 6 count: 18 863 626 count per thread: 3 143 937
# threads: 8 count: 17 061 970 count per thread: 2 132 746.25
# threads: 10 count: 15 984 601 count per thread: 1 598 460.1
# threads: 12 count: 15 899 753 count per thread: 1 324 979.416

import atomics
import nimuring/async

var i: Atomic[int]
i.store(0)

proc run() {.async.} =
  while true:
    await nop()
    i.atomicInc()

const coros = 100

proc worker() {.thread.} =
  for _ in 0..<coros:
    asyncCheck run()
  runForever()

let cpus = 12
var pool = newSeq[Thread[void]](cpus)
for i in 0..pool.high:
  pool[i].createThread(worker)
  pool[i].pinToCpu(i)
sleepAsync(30_000).addCallback(
  proc () =
    let rps = int(i.load/30)
    echo "threads: ", cpus, " count: ", rps, " count per thread: ", rps/cpus
)
runForever()
joinThreads(pool)