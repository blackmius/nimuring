import nimuring

var q = newQueue(4, {})

q.nop(cast[pointer](1))
q.nop(cast[pointer](2))
q.nop(cast[pointer](3))

assert q.sqReady() == 3
assert q.submit(waitNr=3) == 3
assert q.sqReady() == 0
assert q.cqReady() == 3
