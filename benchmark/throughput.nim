import nimuring
import std/[times]

const repeat = 1_000_000

proc run(entries: int) =
  var q = newQueue(entries, {})
  var count = 0
  # run 1 million nops to check queue throughput
  var time = cpuTime()
  while count < repeat:
      for i in 0..<entries:
        q.nop(i)
      q.submit()
      count += q.copyCqes(entries.uint).len
  time = cpuTime() - time
  var rps = repeat / time
  echo q.params.sqEntries, " ", rps

for entries in @[64, 128, 256, 512, 1024, 2048, 4096]:
  run(entries)