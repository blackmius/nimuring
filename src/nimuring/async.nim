import std/[deques, monotimes, asyncfutures, asyncstreams]
import times, os, posix

import io_uring, queue, ops

## Сохранинение Event в памяти GC
## Ускоряет общий код на 50%
## 1. нам не надо теперь хранить rawEnv замыкания
## 2. не надо выделять и удалять структуры под события
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
  Callback = proc (res: Cqe): bool {.closure.}
  ## Callback takes Cqe and return should loop dealloc Event
  ## or we waiting another cqe
  ## all resubmitting considered to be in that callback
  Event = object
    cb: owned(Callback)
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
    if likely(not ev.cb(cqe)):
      loop.events.dealloc(cqe.userData.int)

proc runForever*() =
  while true:
    poll()

type AsyncFD* = distinct int

proc event*(cb: Callback): ptr Sqe {.discardable.} =
  ## To create your own IO closures
  runnableExamples:
    proc nop(): owned(Future[void]) =
      ## Example wrapping callback into a future
      var retFuture = newFuture[void]("nop")
      proc cb(cqe: Cqe): bool =
        retFuture.complete()
      event(cb)
      return retFuture

    # enqueue an raw Callback
    proc pureCb(cqe: Cqe): bool =
      echo cqe
    event(cb)

  let loop = getLoop()
  loop.drainQueue()
  # move external queue before getting new sqe
  # so its FIFO for requests that doesn't fit previos iteration
  result = loop.q.getSqe()
  if result.isNil:
    loop.sqes.addLast(Sqe())
    result = addr loop.sqes.peekLast()
  
  let ind = loop.events.alloc()
  var event = loop.events.get(ind)
  event.cb = cb

  result.setUserData(ind)

proc nop*(): owned(Future[void]) =
  ## A simple, but nevertheless useful request
  var retFuture = newFuture[void]("nop")
  proc cb(cqe: Cqe): bool =
    retFuture.complete()
  event(cb)
  return retFuture

proc write*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[void]) =
  var retFuture = newFuture[void]("write")
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(cqe.res))))
    else:
      retFuture.complete()
  # TODO: probably buffer can leak if it would destroyed before io_uring it consume
  event(cb).write(cast[FileHandle](fd), buffer, len, offset)
  return retFuture

proc read*(fd: AsyncFD; buffer: pointer; len: int; offset: int = 0): owned(Future[int]) =
  var retFuture = newFuture[int]("read")
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(cqe.res))))
    else:
      retFuture.complete(cqe.res)
  event(cb).read(cast[FileHandle](fd), buffer, len, offset)
  return retFuture

proc accept*(fd: AsyncFD): owned(Future[AsyncFD]) =
  var retFuture = newFuture[AsyncFD]("accept")
  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(cqe.res))))
    else:
      retFuture.complete(cast[AsyncFd](cqe.res))
  event(cb).accept(cast[SocketHandle](fd), addr accept_addr, addr accept_addr_len, O_CLOEXEC)
  return retFuture

proc acceptStream*(fd: AsyncFD): owned(FutureStream[AsyncFD]) =
  var retFuture = newFutureStream[AsyncFD]("accept")
  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.complete()
      return true
    else:
      discard retFuture.write(cast[AsyncFD](cqe.res))
      if not cqe.flags.contains(CQE_F_MORE):
        # application should look at the CQE flags and see if
        # IORING_CQE_F_MORE is set on completion as an indication of
        # whether or not the accept request will generate further CQEs.
        event(cb).accept_multishot(cast[SocketHandle](fd), addr accept_addr, addr accept_addr_len, O_CLOEXEC)
  event(cb).accept_multishot(cast[SocketHandle](fd), addr accept_addr, addr accept_addr_len, O_CLOEXEC)
  return retFuture

proc send*(fd: AsyncFD; buffer: pointer; len: int; flags: cint = 0): owned(Future[void]) =
  var retFuture = newFuture[void]("send")
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(cqe.res))))
    else:
      retFuture.complete()
  # TODO: probably buffer can leak if it would destroyed before io_uring it consume
  event(cb).send(cast[SocketHandle](fd), buffer, len, flags)
  return retFuture

proc recv*(fd: AsyncFD; buffer: pointer; len: int; flags: cint = 0): owned(Future[int]) =
  var retFuture = newFuture[int]("read")
  proc cb(cqe: Cqe): bool =
    if cqe.res < 0:
      retFuture.fail(newException(OSError, osErrorMsg(OSErrorCode(cqe.res))))
    else:
      retFuture.complete(cqe.res)
  event(cb).recv(cast[SocketHandle](fd), buffer, len, flags)
  return retFuture

proc sleepAsync*(ms: int | float): owned(Future[void]) =
  var retFuture = newFuture[void]("timeout")
  let ns = (ms * 1_000_000).int64
  let after = getMonoTime().ticks + ns
  var ts = create(Timespec)
  ts.tv_sec = posix.Time(after.int div 1_000_000_000)
  ts.tv_nsec = after.int mod 1_000_000_000
  proc cb(cqe: Cqe): bool =
    dealloc(ts)
    retFuture.complete()
  # we are using TIMEOUT_ABS to avoid time mismatch
  # if sqe enqueued not now (sqe is overflowed)
  event(cb).timeout(ts, 0, {TIMEOUT_ABS})
  return retFuture

import std/async
export async
export Cqe