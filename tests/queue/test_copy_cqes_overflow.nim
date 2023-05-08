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
# ignored because of overflow
q.nop(cast[pointer](13)) # cq[0]
q.nop(cast[pointer](14)) # cq[1]
q.nop(cast[pointer](15)) # cq[2]
q.nop(cast[pointer](16)) # cq[3]
q.submit()

assert SQ_CQ_OVERFLOW in q.sq.flags[]
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
q.nop(cast[pointer](17)) # cq[0]
q.nop(cast[pointer](18)) # cq[1]
q.nop(cast[pointer](19)) # cq[2]
q.nop(cast[pointer](20)) # cq[3]
q.submit()
cqes = q.copyCqes(1)
assert cqes[0].userData == 17
assert cqes[1].userData == 18
assert cqes[2].userData == 19
assert cqes[3].userData == 20

# overflown cqes
cqes = q.copyCqes(1)
assert cqes[0].userData == 9
assert cqes[1].userData == 10
assert cqes[2].userData == 11
assert cqes[3].userData == 12
assert cqes[4].userData == 13
assert cqes[5].userData == 14
assert cqes[6].userData == 15
assert cqes[7].userData == 16
assert SQ_CQ_OVERFLOW notin q.sq.flags[]