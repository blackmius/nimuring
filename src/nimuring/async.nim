import std/[deques, asyncfutures]
import os, posix

import io_uring, queue, ops


type
  Callback = proc (res: int32) {.closure.}
  Loop = ref object
    q: Queue
    sqes: Deque[Sqe]
  Event = object
    cb: owned(Callback)
    cell: ForeignCell

var gLoop {.threadvar.}: owned Loop

proc newLoop(): owned Loop =
  result = new(Loop)
  result.q = newQueue(4096, {SETUP_SQPOLL})
  result.sqes = initDeque[Sqe](4096)

proc setLoop*(loop: sink Loop) =
  gLoop = loop

proc getLoop*(): Loop =
  if gLoop.isNil:
    setLoop(newLoop())
  result = gLoop


template drainQueue(loop: Loop) =
  while loop.sqes.len != 0:
    var loopSqe = loop.sqes.popFirst()
    var sqe = loop.q.getSqe()
    if sqe.isNil:
      break
    sqe[] = loopSqe

proc poll*() =
  let loop = getLoop()
  loop.drainQueue()
  loop.q.submit()
  var cqes = loop.q.copyCqes(1)
  # echo loop.q.sqReady
  # new sqes can be added only from callbacks
  # so it doesn't make sense to skip the iteration
  for cqe in cqes:
    let ev = cast[ptr Event](cqe.userData)
    ev.cb(cqe.res)
    dispose(ev.cell)
    dealloc(ev)
  while loop.q.params.sqEntries - loop.q.sqReady == 0:
    discard

proc runForever*() =
  while true:
    poll()

proc getSqe(): ptr Sqe =
  let loop = getLoop()
  loop.drainQueue()
  # move external queue before getting new sqe
  # so its FIFO for requests that doesn't fit previos iteration
  result = loop.q.getSqe()
  if result.isNil:
    loop.sqes.addLast(Sqe())
    return addr loop.sqes.peekLast()


type AsyncFD* = distinct int

proc event(cb: Callback): ptr Event {.inline.} =
  result = create(Event)
  result.cb = cb
  result.cell = protect(rawEnv(cb))

proc nop*(): owned(Future[void]) =
  var retFuture = newFuture[void]("nop")
  proc cb(res: int32) =
    retFuture.complete()
  getSqe().nop().setUserData(event(cb))
  return retFuture

proc write*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[void]) =
  var retFuture = newFuture[void]("write")
  proc cb(res: int32) =
    if res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(res))))
    else:
      retFuture.complete()
  # TODO: probably buffer can leak if it would destroyed before io_uring it consume
  getSqe().write(cast[FileHandle](fd), buffer, len, offset).setUserData(event(cb))
  return retFuture

proc read*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[int]) =
  var retFuture = newFuture[int]("read")
  proc cb(res: int32) =
    if res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(res))))
    else:
      retFuture.complete(res)
  getSqe().read(cast[FileHandle](fd), buffer, len, offset).setUserData(event(cb))
  return retFuture