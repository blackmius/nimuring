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
q.nop(cast[pointer](7)) # cq[6]
q.nop(cast[pointer](8)) # cq[7]
q.submit()
# ignored because of overflow
q.nop(cast[pointer](9)) # cq[0]
q.nop(cast[pointer](10)) # cq[1]
q.nop(cast[pointer](11)) # cq[2]
q.nop(cast[pointer](12)) # cq[3]
q.submit()
assert q.cqReady() == 8
var cqes = q.copyCqes() # flushed cqes
assert cqes[0].userData == 1
assert cqes[1].userData == 2
assert cqes[2].userData == 3
assert cqes[3].userData == 4
assert cqes[4].userData == 5
assert cqes[5].userData == 6
assert cqes[6].userData == 7
assert cqes[7].userData == 8

# after flush can submit tasks again
q.nop(cast[pointer](13)) # cq[0]
q.nop(cast[pointer](14)) # cq[1]
q.nop(cast[pointer](15)) # cq[2]
q.nop(cast[pointer](16)) # cq[3]
q.submit()
cqes = q.copyCqes()
assert cqes[0].userData == 13
assert cqes[1].userData == 14
assert cqes[2].userData == 15
assert cqes[3].userData == 16