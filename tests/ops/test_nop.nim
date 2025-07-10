import unittest2
import nimuring

suite "nop operation":
  test "basic nop submit and completion":
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

  test "drainPrevious and second nop":
    var q = newQueue(1, {})
    q.nop(cast[pointer](0xaaaaaaaa))
    discard q.submit()
    discard q.copyCqes(1)

    let sqe = q.nop(cast[pointer](0xbbbbbbbb))
    sqe.drainPrevious()

    check q.sqReady() == 1
    check q.cqReady() == 0

    check q.submit() == 1
    check q.sqReady() == 0

    let cqes = q.copyCqes(1)
    check cqes.len == 1
    check cqes[0].userData == 0xbbbbbbbb.uint64
    check q.sqReady() == 0
    check q.cqReady() == 0