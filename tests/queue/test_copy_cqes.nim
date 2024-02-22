import balls
import nimuring

var q = newQueue(4, {})
# sqEntries == 4
# cqEntries == 8

# empty

check q.copyCqes().len == 0

# 1

q.nop(cast[pointer](1))
q.submit()
check q.cqReady() == 1
var cqes = q.copyCqes(1)
check cqes.len == 1

check cqes[0].userData == 1


# +4

q.nop(cast[pointer](2))
q.nop(cast[pointer](3))
q.nop(cast[pointer](4))
q.nop(cast[pointer](5))
q.submit()
check q.cqReady() == 4
cqes = q.copyCqes(4)
check cqes.len == 4

check cqes[0].userData == 2
check cqes[1].userData == 3
check cqes[2].userData == 4
check cqes[3].userData == 5