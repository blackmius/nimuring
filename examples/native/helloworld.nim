import nimuring

var q = newQueue(64)

let buf = "Hello world\n"

q.write(cast[pointer](2), stdout.getFileHandle, buf)
q.write(cast[pointer](0), stdout.getFileHandle, buf)
q.write(cast[pointer](1), stdout.getFileHandle, buf)
q.submit()
echo q.copyCqes(3) # wait until done