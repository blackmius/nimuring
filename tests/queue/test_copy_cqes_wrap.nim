import nimuring

var q = newQueue(4, {})
assert q.params.sqEntries == 4
assert q.params.cqEntries == 8

q.nop(cast[pointer](1)) # cq[0]
q.nop(cast[pointer](2)) # cq[1]
q.nop(cast[pointer](3)) # cq[2]
q.nop(cast[pointer](4)) # cq[3]
q.submit()
q.nop(cast[pointer](5)) # cq[4]
q.nop(cast[pointer](6)) # cq[5]
q.submit()
assert q.cqReady() == 6
var cqes = q.copyCqes(6)
q.nop(cast[pointer](5)) # cq[6]
q.nop(cast[pointer](6)) # cq[7]
q.nop(cast[pointer](7)) # cq[0]
q.nop(cast[pointer](8)) # cq[1]
q.submit()
assert q.cqReady() == 4
cqes = q.copyCqes(4)

assert cqes[0].userData == 5
assert cqes[1].userData == 6
assert cqes[2].userData == 7
assert cqes[3].userData == 8