import std/deques
import nimuring

var sqeDequeue = initDeque[Sqe]() # raw Sqe
var cqeDequeue = initDeque[Cqe]()

for i in 1..20:
  var sqe = Sqe(opcode: OP_NOP)
  sqeDequeue.addLast(sqe)

var q = newQueue(4)

while sqeDequeue.len > 0:
  let available = q.params.sqEntries - q.sqReady
  for _ in 1..available:
    let inQueueSqe = sqeDequeue.popFirst()
    var sqe = q.getSqe()
    copyMem(sqe, inQueueSqe.unsafeAddr, sizeof(Sqe))
  q.submit() # if not SetupSqPoll flag specified
  var waitNr = 1.uint
  if sqeDequeue.len == 0:
    # when all sqes are submitted we have to wait for all of them
    # because will be no additional iterations
    waitNr = q.params.sqEntries - q.sqReady
  for cqe in q.copyCqes(waitNr):
    cqeDequeue.addLast(cqe)