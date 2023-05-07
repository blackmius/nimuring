import nimuring
var q = newQueue(2)
q.write(cast[pointer](0), stdout.getFileHandle, "Hello world\n")
q.submit()
echo q.copyCqes(1) # wait until complete