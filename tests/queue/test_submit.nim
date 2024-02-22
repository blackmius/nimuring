import balls
import nimuring

var q = newQueue(16, {})
for i in 1..10:
    q.nop(cast[pointer](i))
    check q.sqReady() == i.uint32

check q.submit() == 10
check q.sqReady() == 0
check q.submit() == 0