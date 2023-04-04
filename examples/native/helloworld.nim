import nimuring

var q = newQueue(2)

let buf = "Hello world\n"

q.write(cast[pointer](0), stdout.getFileHandle, buf)
q.write(cast[pointer](1), stdout.getFileHandle, buf)
q.submit()
echo q.copyCqes(1) # wait until done