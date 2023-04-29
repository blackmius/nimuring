import std/[deques, monotimes, asyncfutures, asyncstreams]
import times, os, posix

import io_uring, queue, ops

type
  Pool[T] = ref object
    arr: seq[T]
    freelist: Deque[int]

proc newPool[T](): owned(Pool[T]) =
  result = new Pool[T]

proc alloc[T](p: var Pool[T]): int =
  if p.freelist.len == 0:
    p.arr.add(T())
    return p.arr.len - 1
  return p.freelist.popFirst()

proc dealloc[T](p: var Pool[T], ind: int) =
  p.freelist.addLast(ind)

proc get[T](p: var Pool[T], ind: int): ptr T =
  result = addr p.arr[ind]


type
  Callback = proc (res: int32) {.closure.}
  Event = object
    cb: owned(Callback)
    cell: ForeignCell
  Loop = ref object
    q: Queue
    sqes: Deque[Sqe]
    events: Pool[Event]

var gLoop {.threadvar.}: owned Loop

proc newLoop(): owned Loop =
  result = new(Loop)
  result.q = newQueue(4096, {SETUP_SQPOLL})
  result.sqes = initDeque[Sqe](4096)
  result.events = newPool[Event]()

proc setLoop*(loop: sink Loop) =
  gLoop = loop

proc getLoop*(): Loop =
  if gLoop.isNil:
    setLoop(newLoop())
  result = gLoop


template drainQueue(loop: Loop) =
  while loop.sqes.len != 0:
    var sqe = loop.q.getSqe()
    if sqe.isNil:
      break
    sqe[] = loop.sqes.popFirst()

proc poll*() =
  let loop = getLoop()
  loop.drainQueue()
  loop.q.submit()
  var cqes = loop.q.copyCqes(1)
  # echo loop.q.sqReady
  # new sqes can be added only from callbacks
  # so it doesn't make sense to skip the iteration
  for cqe in cqes:
    let ev = loop.events.get(cqe.userData.int)
    ev.cb(cqe.res)
    loop.events.dealloc(cqe.userData.int)

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

proc event(sqe: ptr Sqe, cb: Callback) =
  let loop = getLoop()
  let ind = loop.events.alloc()
  var event = loop.events.get(ind)
  event.cb = cb
  event.cell = protect(rawEnv(cb))
  sqe.setUserData(ind)

proc nop*(): owned(Future[void]) =
  var retFuture = newFuture[void]("nop")
  proc cb(res: int32) =
    retFuture.complete()
  getSqe().nop().event(cb)
  return retFuture

proc write*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[void]) =
  var retFuture = newFuture[void]("write")
  proc cb(res: int32) =
    if res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(res))))
    else:
      retFuture.complete()
  # TODO: probably buffer can leak if it would destroyed before io_uring it consume
  getSqe().write(cast[FileHandle](fd), buffer, len, offset).event(cb)
  return retFuture

proc read*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[int]) =
  var retFuture = newFuture[int]("read")
  proc cb(res: int32) =
    if res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(res))))
    else:
      retFuture.complete(res)
  getSqe().read(cast[FileHandle](fd), buffer, len, offset).event(cb)
  return retFuture

proc accept*(fd: AsyncFD): owned(Future[AsyncFD]) =
  var retFuture = newFuture[AsyncFD]("accept")
  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  proc cb(res: int32) =
    if res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(res))))
    else:
      retFuture.complete(cast[AsyncFd](res))
  getSqe().accept(cast[SocketHandle](fd), addr accept_addr, addr accept_addr_len, 0).event(cb)
  return retFuture

proc acceptStream*(fd: AsyncFD,): owned(FutureStream[AsyncFD]) =
  var retFuture = newFutureStream[AsyncFD]("accept")
  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  proc cb(res: int32) =
    if res < 0:
      retFuture.complete()
    else:
      discard retFuture.write(cast[AsyncFD](res))
  # TODO: Как понять что надо закончить или произошел fail
  # еще в обратную сторону если FutureStream был удален
  # и еще флаг CQE_F_MORE и если его нет, надо тоже вырубать или переотправлять
  getSqe().accept_multishot(cast[SocketHandle](fd), addr accept_addr, addr accept_addr_len, 0).event(cb)
  return retFuture

proc sleepAsync*(ms: int | float): owned(Future[void]) =
  var retFuture = newFuture[void]("timeout")
  let ns = (ms * 1_000_000).int64
  let after = getMonoTime().ticks + ns
  var ts = create(Timespec)
  ts.tv_sec = posix.Time(after.int div 1_000_000_000)
  ts.tv_nsec = after.int mod 1_000_000_000
  proc cb(res: int32) =
    dealloc(ts)
    retFuture.complete()
  # we are using TIMEOUT_ABS to avoid time mismatch
  # if sqe enqueued not now (sqe is overflowed)
  getSqe().timeout(ts, 0, {TIMEOUT_ABS}).event(cb)
  return retFuture

import std/async
export async