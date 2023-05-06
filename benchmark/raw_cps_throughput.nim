# check singlecore CPS throughput
import std/monotimes
import cps

type
  MyCont = ref object of Continuation

var i = 0

proc nop(c: MyCont): MyCont {.cpsMagic.} =
  discard

proc run() {.cps: MyCont.} =
  while true:
    nop()
    var j = 0
    while j < 10000:
      i += 1
      j += 1


const coroutinesCount = 100_000
var coroutines = newSeq[Continuation](coroutinesCount)
for i in 0..<coroutinesCount:
  coroutines[i] = whelp run()

let start = getMonoTime().ticks
while i < 1_000_000:
  for j in 0..<coroutinesCount:
    discard trampoline coroutines[j]
#   echo i
let duration = getMonoTime().ticks - start
echo duration.float / 1_000_000, "ms"


# it probably makes sense to use CPS instead of async/await
