import std/monotimes

proc fn() = discard

let start = getMonoTime().ticks
for _ in 0..<1_000_000:
    fn()
let duration = getMonoTime().ticks - start
echo duration.float / 1_000_000, "ms"