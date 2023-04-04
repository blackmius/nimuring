import io_uring
import std/sequtils

from atomics import MemoryOrder
{.push, header: "<stdatomic.h>", importc.}
proc atomic_load_explicit[T](location: ptr T; order: MemoryOrder): T
proc atomic_store_explicit[T, A](location: ptr A; desired: T;
    order: MemoryOrder = moSequentiallyConsistent)
proc atomic_thread_fence(order: MemoryOrder)
{.pop.}

type
  Queue* = object
    params*: ptr Params
    fd: FileHandle
    cq: CqRing
    sq: SqRing

  # convenience typeclass
  Offsets = SqringOffsets or CqringOffsets

  Ring = object of RootObj
    head: ptr uint32
    tail: ptr uint32
    mask: ptr uint32
    entries: ptr uint32
    size: uint32
    ring: pointer

  SqRing = object of Ring
    flags: SqringFlags
    dropped: pointer
    array: pointer
    sqes: ptr Sqe

    ## We use `sqe_head` and `sqeTail` in the same way as liburing:
    ## We increment `sqeTail` (but not `tail`) for each call to `getSqe()`.
    ## We then set `tail` to `sqeTail` once, only when these events are actually submitted.
    ## This allows us to amortize the cost of the `atomicStore` to `tail` across multiple SQEs.
    sqeTail: uint32
    sqeHead: uint32

  CqRing = object of Ring
    flags: CqringFlags
    overflow: pointer
    cqes: pointer

const
  defaultFlags: SetupFlags = {}

proc init(ring: var Ring; offset: ptr Offsets) =
  ## setup common properties of a Ring given a struct of Offsets
  ring.head = cast[ptr uint32](ring.ring + offset.head)
  ring.tail = cast[ptr uint32](ring.ring + offset.tail)
  ring.mask = cast[ptr uint32](ring.ring + offset.ring_mask)
  ring.entries = cast[ptr uint32](ring.ring + offset.ring_entries)
  assert offset.ring_entries > 0

proc newRing(fd: FileHandle; offset: ptr CqringOffsets; size: uint32): CqRing =
  ## mmap a Cq ring from the given file-descriptor, using the size spec'd
  result = CqRing(size: size)
  let ring = OffCqRing.uringMap(fd, offset.cqes, size, Cqe)
  result.ring = ring
  result.cqes = ring + offset.cqes
  result.overflow = ring + offset.overflow
  result.init offset

proc newRing(fd: FileHandle; offset: ptr SqringOffsets; size: uint32): SqRing =
  ## mmap a Sq ring from the given file-descriptor, using the size spec'd
  result = SqRing(size: size)
  let ring = OffSqRing.uringMap(fd, offset.array, size, pointer)
  result.size = size
  result.ring = ring
  result.dropped = ring + offset.dropped
  result.array = ring + offset.array
  result.sqes = cast[ptr Sqe](OffSqes.uringMap(fd, 0, size, Sqe))
  result.init offset

proc `=destroy`(queue: var Queue) =
  ## tear down the queue
  uringUnmap(queue.cq.ring, queue.params.cqEntries.int * sizeof(Cqe))
  uringUnmap(queue.sq.ring, queue.params.sqEntries.int * sizeof(pointer))
  uringUnmap(queue.sq.sqes, queue.params.sqEntries.int * sizeof(Sqe))

proc isPowerOfTwo(x: uint32): bool = (x != 0) and ((x and (x - 1)) == 0)

proc newQueue*(entries: uint32; flags = defaultFlags; sqThreadCpu = false;
    sqThreadIdle = false): Queue =
  assert entries.isPowerOfTwo
  var params = cast[ptr Params](allocShared(sizeof Params))
  params.flags = flags
  params.sqThreadCpu = sqThreadCpu.uint32
  params.sqThreadIdle = sqThreadIdle.uint32
  # ask the kernel for the file-descriptor to a ring pair of the spec'd size
  # this also populates the contents of the params object
  result.fd = setup(entries.cint, params)
  # save that
  result.params = params
  # setup the two rings
  result.cq = newRing(result.fd, addr params.cqOff, params.cqEntries)
  result.sq = newRing(result.fd, addr params.sqOff, params.sqEntries)

proc sqFlush(queue: var Queue): int =
  ## Sync internal state with kernel ring state on the SQ side. Returns the
  ## number of pending items in the SQ ring, for the shared ring.
  var
    sq = queue.sq
    tail = sq.sqe_tail
  if sq.sqe_head != tail:
    queue.sq.sqe_head = tail
    # Ensure kernel sees the SQE updates before the tail update.
    if SetupSqpoll in queue.params.flags:
      atomic_store_explicit(sq.tail, tail, moRelaxed)
    else:
      atomic_store_explicit(sq.tail, tail, moRelease)
  # This _may_ look problematic, as we're not supposed to be reading
  # SQ->head without acquire semantics. When we're in SQPOLL mode, the
  # kernel submitter could be updating this right now. For non-SQPOLL,
  # task itself does it, and there's no potential race. But even for
  # SQPOLL, the load is going to be potentially out-of-date the very
  # instant it's done, regardless or whether or not it's done
  # atomically. Worst case, we're going to be over-estimating what
  # we can submit. The point is, we need to be able to deal with this
  # situation regardless of any perceived atomicity.
  return int(tail - sq.head[])

proc getSqe*(queue: var Queue): ptr Sqe =
  ## Return an sqe to fill. Application must later call queue.submit()
  ## when it's ready to tell the kernel about it. The caller may call this
  ## function multiple times before calling queue.submit().
  ## Returns a vacant sqe, or nil if we're full.
  result = nil
  var
    sq = queue.sq
    head: uint32
    next = sq.sqe_tail + 1
    shift = 0
  if SetupSqe128 in queue.params.flags:
    shift = 1
  if SetupSqpoll in queue.params.flags:
    head = atomic_load_explicit(sq.head, moRelaxed)
  else:
    head = atomic_load_explicit(sq.head, moAcquire)
  if next - head <= sq.entries[]:
    let index = (sq.sqe_tail and sq.mask[]) shl shift
    result = cast[ptr Sqe](sq.sqes + index.int * sizeof(Sqe))
    queue.sq.sqe_tail = next

proc sqNeedsEnter(queue: var Queue; submit: int; flags: var EnterFlags): bool =
  ## Returns true if we're not using SQ thread (thus nobody submits but us)
  ## or if IORING_SQ_NEED_WAKEUP is set, so submit thread must be explicitly
  ## awakened. For the latter case, we set the thread wakeup flag.
  ## If no SQEs are ready for submission, returns false.
  if submit == 0:
    return false
  if SetupSqpoll notin queue.params.flags:
    return true
  # Ensure the kernel can see the store to the SQ tail before we read
  # the flags.
  atomic_thread_fence(moSequentiallyConsistent)
  if SqNeedWakeup in atomic_load_explicit[SqringFlags](addr queue.sq.flags, moRelaxed):
    flags.incl(EnterSqWakeup)
    return true
  return false;

template cqNeedsFlush(queue: var Queue): bool =
  {SqCqOverflow, SqTaskrun} <= atomic_load_explicit[SqringFlags](addr queue.sq.flags, moRelaxed)

template cqNeedsEnter(queue: var Queue): bool =
  SetupIopoll in queue.params.flags or queue.cqNeedsFlush

proc submit*(queue: var Queue; waitNr: uint = 0; getEvents: bool = false): int {.discardable.} =
  ## Submit sqes acquired from queue.getSqe() to the kernel.
  ## Returns number of sqes submitted
  let
    submited = queue.sqFlush
    cqNeedsEnter = getEvents or queue.cqNeedsEnter
  var flags: EnterFlags
  if queue.sqNeedsEnter(submited, flags) or cqNeedsEnter:
    if cqNeedsEnter:
      flags.incl(EnterGetevents)
    result = enter(queue.fd, submited.cint, waitNr.cint, cast[cint](flags), nil, 0.cint)
  else:
    result = submited


proc sqReady*(queue: var Queue): uint32 =
  ## Returns the number of flushed and unflushed SQEs pending in the submission queue.
  ## In other words, this is the number of SQEs in the submission queue, i.e. its length.
  ## These are SQEs that the kernel is yet to consume.
  ## Matches the implementation of io_uring_sq_ready in liburing.
  # Always use the shared ring state (i.e. head and not sqe_head) to avoid going out of sync,
  # see https://github.com/axboe/liburing/issues/92.
  return queue.sq.sqe_tail - atomic_load_explicit(queue.sq.head, moAcquire)

proc cqReady*(queue: var Queue): uint32 =
  ## Returns the number of CQEs in the completion queue, i.e. its length.
  ## These are CQEs that the application is yet to consume.
  ## Matches the implementation of io_uring_cq_ready in liburing.
  return atomic_load_explicit(queue.cq.tail, moAcquire) - queue.cq.head[]

proc copyCqes*(queue: var Queue; waitNr: uint = 0): seq[Cqe] =
  ## Copies as many CQEs as are ready.
  ## If none are available, enters into the kernel to wait for at most `wait_nr` CQEs.
  ## Returns the number of CQEs copied, advancing the CQ ring.
  ## Provides all the wait/peek methods found in liburing, but with batching and a single method.
  ## The rationale for copying CQEs rather than copying pointers is that pointers are 8 bytes
  ## whereas CQEs are not much more at only 16 bytes, and this provides a safer faster interface.
  ## Safer, because you no longer need to call cqe_seen(), avoiding idempotency bugs.
  ## Faster, because we can now amortize the atomic store release to `cq.head` across the batch.
  ## See https://github.com/axboe/liburing/issues/103#issuecomment-686665007.
  ## Matches the implementation of io_uring_peek_batch_cqe() in liburing, but supports waiting.
  var ready = queue.cqReady
  if ready == 0 and (queue.cqNeedsFlush or waitNr > 0):
    discard enter(queue.fd, 0.cint, waitNr.cint, cast[cint]({EnterGetevents}), nil, 0.cint)
    ready = queue.cqReady
  if ready == 0:
    return @[]
  var
    head = queue.cq.head[]
    tail = head + ready
  let
    startIndex = int(head and queue.cq.mask[])
    endIndex = int(tail and queue.cq.mask[])
  if endIndex < startIndex:
    # overflow needs 2 memcpy
    let arr = cast[ptr UncheckedArray[Cqe]](queue.cq.cqes)
    let first = @(arr.toOpenArray(startIndex, queue.cq.entries[].int-1))
    let second = @(arr.toOpenArray(0, endIndex-1))
    result = concat(first, second)
  else:
    let arr = cast[ptr UncheckedArray[Cqe]](queue.cq.cqes)
    result = @(arr.toOpenArray(startIndex, endIndex-1))
  atomic_store_explicit(queue.cq.head, tail, moRelease)