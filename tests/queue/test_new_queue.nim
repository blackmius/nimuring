import unittest2
import nimuring

suite "newQueue entries":
  test "raises NimuringError on non-power-of-two entries":
    expect NimuringError:
      discard newQueue(3)
  
  test "raises NimuringError on zero entries":
    expect NimuringError:
      discard newQueue(0)
  
  test "sqEntries and cqEntries relationship":
    for entries in @[1, 2, 4, 8, 4096]:
      var q = newQueue(entries, {})
      check q.params.sqEntries.int == entries
      check q.params.cqEntries.int == entries * 2