import nimuring

var q = newQueue(4, {SETUP_SQPOLL}, 0, 10)
q.nop(0)
q.nop(0)
q.nop(0)
q.nop(0)
q.submit()
assert q.copyCqes(1).len == 4