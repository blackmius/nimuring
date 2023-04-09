import nimuring

var q = newQueue(16, {})
for i in 1..10:
    q.nop(cast[pointer](i))
    assert q.sqReady() == i.uint32

assert q.submit() == 10
assert q.sqReady() == 0
assert q.submit() == 0