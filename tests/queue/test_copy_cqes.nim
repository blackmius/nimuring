import nimuring

var q = newQueue(4, {})
# sqEntries == 4
# cqEntries == 8

# empty

assert q.copyCqes().len == 0

# 1

q.nop(cast[pointer](1))
q.submit()
assert q.cqReady() == 1
var cqes = q.copyCqes(1)
assert cqes.len == 1

assert cqes[0].userData == 1


# +4

q.nop(cast[pointer](2))
q.nop(cast[pointer](3))
q.nop(cast[pointer](4))
q.nop(cast[pointer](5))
q.submit()
assert q.cqReady() == 4
cqes = q.copyCqes(4)
assert cqes.len == 4

assert cqes[0].userData == 2
assert cqes[1].userData == 3
assert cqes[2].userData == 4
assert cqes[3].userData == 5