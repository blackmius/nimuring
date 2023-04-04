import nimuring
import std/[times]

var q = newQueue(4096, {})
var count: int = 0

var time = cpuTime()
while count < 1_000_000:
    for i in 0..q.params.sqEntries-1:
        q.nop(cast[pointer](i))
    q.submit()
    count += len(q.copyCqes(1))
time = cpuTime() - time
echo 1_000_000 / time, " OPS per second"