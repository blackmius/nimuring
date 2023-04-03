import native/[io_uring, queue]

var q = newQueue(64)

let buf = "Hello world\n"

var sqe = q.getSqe()

sqe.opcode = OpWrite
sqe.flags = {}
sqe.ioprio = {}
sqe.fd = stdout.getFileHandle
sqe.addr = cstring(buf)
sqe.off = 0
sqe.len = buf.len
sqe.rwFlags = 0
sqe.bufIndex = 0
# sqe.personality = 0
# sqe.fileIndex = 0
# sqe.addr3 = cast[pointer](0)
sqe.pad2[0] = 0
discard q.submit()