import unittest2
import nimuring

suite "sqpoll":
  test "sqpoll queue basic":
    var q = newQueue(4, {SETUP_SQPOLL}, 0, 10)
    q.nop(0)
    q.nop(0)
    q.nop(0)
    q.nop(0)
    q.submit()
    check q.copyCqes(1).len == 4