import nimuring
import unittest2

template overflow_queue() =
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

suite "copyCqes overflow behavior":
  test "queue initialization":
    var q = newQueue(4, {})
    check q.params.sqEntries == 4
    check q.params.cqEntries == 8

  test "fill cq and overflow":
    var q = newQueue(4, {})
    overflow_queue()
    check SQ_CQ_OVERFLOW in q.sq.flags[]
    check q.cqReady() == 8

  test "copyCqes returns correct values after overflow":
    var q = newQueue(4, {})
    overflow_queue()
    var cqes = q.copyCqes() # flushed cqes
    check cqes[0].userData == 1
    check cqes[1].userData == 2
    check cqes[2].userData == 3
    check cqes[3].userData == 4
    check cqes[4].userData == 5
    check cqes[5].userData == 6
    check cqes[6].userData == 7
    check cqes[7].userData == 8

  test "can submit tasks again after flush":
    var q = newQueue(4, {})
    overflow_queue()
    discard q.copyCqes(1)
    q.nop(cast[pointer](17)) # cq[0]
    q.nop(cast[pointer](18)) # cq[1]
    q.nop(cast[pointer](19)) # cq[2]
    q.nop(cast[pointer](20)) # cq[3]
    q.submit()
    var cqes = q.copyCqes(1)
    check cqes[0].userData == 17
    check cqes[1].userData == 18
    check cqes[2].userData == 19
    check cqes[3].userData == 20
