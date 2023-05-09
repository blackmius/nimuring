import atomics
import cpuinfo
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

let cpus = countProcessors()
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