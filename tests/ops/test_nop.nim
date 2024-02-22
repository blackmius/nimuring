import balls
import nimuring

var q = newQueue(1, {})
q.nop(cast[pointer](0xaaaaaaaa))
check q.sqReady() == 1
check q.cqReady() == 0
check q.submit() == 1
check q.sqReady() == 0
check q.cqReady() == 1

var cqes = q.copyCqes(1)
check cqes.len == 1
check cqes[0].userData == 0xaaaaaaaa.uint64
check q.sqReady() == 0
check q.cqReady() == 0


let sqe = q.nop(cast[pointer](0xbbbbbbbb))
# check that io_using correctly processed the previous request,
# so that the new one that is waiting for the previous one will also be processed
sqe.drainPrevious()

check q.sqReady() == 1
check q.cqReady() == 0

check q.submit() == 1
check q.sqReady() == 0
check q.cqReady() == 1

cqes = q.copyCqes(1)
check cqes.len == 1
check cqes[0].userData == 0xbbbbbbbb.uint64
check q.sqReady() == 0
check q.cqReady() == 0