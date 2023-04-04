import nimuring

var q = newQueue(64)

let buf = "Hello world\n"

q.write(nil, stdout.getFileHandle, buf)
q.submit(2)
discard q.copyCqes(1) # wait until done