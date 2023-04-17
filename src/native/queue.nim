import io_uring
import posix

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
  # Directly map SQ slots to SQEs
  for i in 0..size:
    cast[ptr UncheckedArray[uint32]](result.array)[i] = i
  result.sqes = cast[ptr Sqe](OffSqes.uringMap(fd, 0, size, Sqe))
  result.init offset

proc `=destroy`(queue: var Queue) =
  ## tear down the queue
  if queue.cq.ring != nil:
    uringUnmap(queue.cq.ring, queue.params.cqEntries.int * sizeof(Cqe))
  if queue.sq.ring != nil:
    uringUnmap(queue.sq.ring, queue.params.sqEntries.int * sizeof(pointer))
  if queue.sq.sqes != nil:
    uringUnmap(queue.sq.sqes, queue.params.sqEntries.int * sizeof(Sqe))

proc isPowerOfTwo(x: int): bool = (x != 0) and ((x and (x - 1)) == 0)

proc newQueue*(entries: int; flags = defaultFlags; sqThreadCpu = false;
    sqThreadIdle = false): Queue =
  assert entries.isPowerOfTwo, "Entries must be in the power of two"
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
    startCount = queue.cq.entries[].int - startIndex
  result = newSeq[Cqe](ready)
  if startCount < ready.int:
    # overflow needs 2 memcpy
    copyMem(result[0].unsafeAddr, queue.cq.cqes + startIndex * sizeof(Cqe), startCount * sizeof(Cqe))
    copyMem(result[startCount].unsafeAddr, queue.cq.cqes, (endIndex + 1) * sizeof(Cqe))
  else:
    copyMem(result[0].unsafeAddr, queue.cq.cqes + startIndex * sizeof(Cqe), ready.int * sizeof(Cqe))
  atomic_store_explicit(queue.cq.head, tail, moRelease)


proc registerFiles*(q: var Queue; fds: seq[FileHandle]): int {.discardable.} =
  ## Registers an array of file descriptors.
  ## Every time a file descriptor is put in an SQE and submitted to the kernel, the kernel must
  ## retrieve a reference to the file, and once I/O has completed the file reference must be
  ## dropped. The atomic nature of this file reference can be a slowdown for high IOPS workloads.
  ## This slowdown can be avoided by pre-registering file descriptors.
  ## To refer to a registered file descriptor, IOSQE_FIXED_FILE must be set in the SQE's flags,
  ## and the SQE's fd must be set to the index of the file descriptor in the registered array.
  ## Registering file descriptors will wait for the ring to idle.
  ## Files are automatically unregistered by the kernel when the ring is torn down.
  ## An application need unregister only if it wants to register a new array of file descriptors.
  return register(q.fd.cint, REGISTER_FILES.cint, fds[0].unsafeAddr, fds.len.cint)

proc registerFilesUpdate*(q: var Queue; offset: Off; fds: seq[FileHandle]): int {.discardable.} =
  ## Updates registered file descriptors.
  ##
  ## Updates are applied starting at the provided offset in the original file descriptors slice.
  ## There are three kind of updates:
  ## * turning a sparse entry (where the fd is -1) into a real one
  ## * removing an existing entry (set the fd to -1)
  ## * replacing an existing entry with a new fd
  ## Adding new file descriptors must be done with `register_files`.
  let update = RsrcUpdate(
    offset: offset.uint32,
    data: cast[uint64](fds[0].unsafeAddr)
  )
  return register(q.fd.cint, REGISTER_FILES_UPDATE.cint, update.unsafeAddr, fds.len.cint)

proc unregisterFiles*(q: var Queue;): int {.discardable.} =
  ## Unregisters all registered file descriptors previously associated with the ring.
  return register(q.fd.cint, UNREGISTER_FILES.cint, nil, 0)

proc registerEventFd*(q: var Queue; fd: FileHandle): int {.discardable.} =
  ## Registers the file descriptor for an eventfd that will be notified of completion events on
  ##  an io_uring instance.
  ## Only a single a eventfd can be registered at any given point in time.
  return register(q.fd.cint, REGISTER_EVENTFD.cint, fd.unsafeAddr, 1)

proc registerEventFdAsync*(q: var Queue; fd: FileHandle): int {.discardable.} =
  ## Registers the file descriptor for an eventfd that will be notified of completion events on
  ## an io_uring instance. Notifications are only posted for events that complete in an async manner.
  ## This means that events that complete inline while being submitted do not trigger a notification event.
  ## Only a single eventfd can be registered at any given point in time.
  return register(q.fd.cint, REGISTER_EVENTFD_ASYNC.cint, fd.unsafeAddr, 1)

proc unregisterEventFd*(q: var Queue;): int {.discardable.} =
  ## Unregister the registered eventfd file descriptor.
  return register(q.fd.cint, UNREGISTER_EVENTFD.cint, nil, 0)

proc registerBuffers*(q: var Queue; buffers: seq[IOVec]): int {.discardable.} =
  ## Registers an array of buffers for use with `read_fixed` and `write_fixed`.
  ## known issues:
  ## * EOPNOTSUPP
  ##   User buffers point to file-backed memory.
  ##   error occured then you try to pass pointer allocated on stack
  ##   use alloc or alloc0
  return register(q.fd.cint, REGISTER_BUFFERS.cint, buffers[0].unsafeAddr, buffers.len.cint)

proc unregisterBuffers*(q: var Queue;): int {.discardable.} =
  ## Unregister the registered buffers.
  return register(q.fd.cint, UNREGISTER_BUFFERS.cint, nil, 0)
