import unittest2
import nimuring

suite "multiple queues":
  test "independent queues":
    var q1 = newQueue(4, {})
    q1.nop(0)
    q1.nop(1)
    q1.nop(2)
    q1.nop(3)

    var q2 = newQueue(4, {})
    q2.nop(0)
    q2.nop(1)
    q2.nop(2)
    q2.nop(3)

    q2.submit()
    check q2.copyCqes().len == 4

    q1.submit()
    check q1.copyCqes().len == 4