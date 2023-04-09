import nimuring

var q = newQueue(1, {})
q.nop(cast[pointer](0xaaaaaaaa))
assert q.sqReady() == 1
assert q.cqReady() == 0

assert q.submit() == 1
assert q.sqReady() == 0
assert q.cqReady() == 1

var cqes = q.copyCqes(1)
assert cqes.len == 1
assert cqes[0].userData == 0xaaaaaaaa.uint64
assert q.sqReady() == 0
echo q.cqReady()
assert q.cqReady() == 0


let sqe = q.nop(cast[pointer](0xbbbbbbbb))
# check that io_using correctly processed the previous request,
# so that the new one that is waiting for the previous one will also be processed
sqe.drainPrevious()

assert q.sqReady() == 1
assert q.cqReady() == 0

assert q.submit() == 1
assert q.sqReady() == 0
assert q.cqReady() == 1

cqes = q.copyCqes(1)
assert cqes.len == 1
assert cqes[0].userData == 0xbbbbbbbb.uint64
assert q.sqReady() == 0
assert q.cqReady() == 0