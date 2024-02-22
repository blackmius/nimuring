import balls
import nimuring

var q = newQueue(4, {})

q.nop(cast[pointer](1))
q.nop(cast[pointer](2))
q.nop(cast[pointer](3))

check q.sqReady() == 3
check q.submit(waitNr=3) == 3
check q.sqReady() == 0
check q.cqReady() == 3
