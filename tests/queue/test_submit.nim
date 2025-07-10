import unittest2
import nimuring

suite "submit":
  test "basic submit":
    var q = newQueue(16, {})
    for i in 1..10:
      q.nop(cast[pointer](i))
      check q.sqReady() == i.uint32

    check q.submit() == 10
    check q.sqReady() == 0
    check q.submit() == 0
  test "submit with waitNr":
    var q = newQueue(4, {})

    q.nop(cast[pointer](1))
    q.nop(cast[pointer](2))
    q.nop(cast[pointer](3))

    check q.sqReady() == 3
    check q.submit(waitNr=3) == 3
    check q.sqReady() == 0
    check q.cqReady() == 3
