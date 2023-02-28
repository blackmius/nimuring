import os, posix
from atomics import MemoryOrder
import io_uring

type
  SubmissionQueueFlag* = enum
    sqNeedWakeup ##  IORING_SQ_NEED_WAKEUP
    sqCqOverflow ##  IORING_SQ_CQ_OVERFLOW
    sqTaskrun ##  IORING_SQ_TASKRUN
  SubmissionQueueFlags* = set[SubmissionQueueFlag]

  SubmissionQueue* = object
    head: ptr uint
    tail: ptr uint
    flags: ptr SubmissionQueueFlags
    dropped: ptr uint
    arr: ptr uint
    sqes: ptr io_uring_sqe

    sqeHead: uint
    sqeTail: uint

    ringMask: uint
    ringEntries: uint16
    ringSize: int
    ringPtr: pointer
  
  CompletionQueue* = object
    head: ptr uint
    tail: ptr uint
    overflow: ptr uint
    cqes: ptr io_uring_cqe

    ringMask: uint
    ringEntries: uint16
    ringSize: int
    ringPtr: pointer

  Feature* = enum
    fSingleMmap ##  IORING_FEAT_SINGLE_MMAP
    fNodrop ##  IORING_FEAT_NODROP
    fSubmitStable ##  IORING_FEAT_SUBMIT_STABLE
    fRwCurPos ##  IORING_FEAT_RW_CUR_POS
    fCurPersonality ##  IORING_FEAT_CUR_PERSONALITY
    fFastPoll ##  IORING_FEAT_FAST_POLL
    fPoll32Bits ##  IORING_FEAT_POLL_32BITS
    fSqpollNonfixed ##  IORING_FEAT_SQPOLL_NONFIXED
    fExtArg ##  IORING_FEAT_EXT_ARG
    fNativeWorkers ##  IORING_FEAT_NATIVE_WORKERS
    fRsrcTags ##  IORING_FEAT_RSRC_TAGS
    fCqeSkip ##  IORING_FEAT_CQE_SKIP
    fLinkedFile ##  IORING_FEAT_LINKED_FILE
    fRegRegRing ##  IORING_FEAT_REG_REG_RING
  Features* = set[Feature]
  
  SetupFlag* = enum
    sfIopoll ##  IORING_SETUP_IOPOLL
    sfSqpoll ##  IORING_SETUP_IOPOLL
    sfSqAff ##  IORING_SETUP_SQ_AFF
    sfCqsize ##  IORING_SETUP_CQSIZE
    sfClamp ##  IORING_SETUP_CLAMP
    sfAttachWq #  IORING_SETUP_ATTACH_WQ
    sfRDisabled #  IORING_SETUP_R_DISABLED
    sfSubmitAll #  IORING_SETUP_SUBMIT_ALL
    sfCoopTaskrun #  IORING_SETUP_COOP_TASKRUN
    sfTaskrunFlag #  IORING_SETUP_TASKRUN_FLAG
    sfSqe128 #  IORING_SETUP_SQE128
    sfCqe32 #  IORING_SETUP_CQE32
    sfSingleIssuer #  IORING_SETUP_SINGLE_ISSUER
    sfDeferTaskrun #  IORING_SETUP_DEFER_TASKRUN
  SetupFlags* = set[SetupFlag]

  Ring* = object
    sq: SubmissionQueue
    cq: CompletionQueue

    ringFD: cint

    features*: Features
    flags*: SetupFlags

proc `+`[S: SomeInteger](p: pointer, offset: S): pointer =
  ## Increments pointer `p` by `offset` that jumps memory in increments of
  ## single bytes.
  return cast[pointer](cast[ByteAddress](p) +% int(offset))

proc newRing*(queueDepth: uint, flags: SetupFlags, sqThreadCpu: int = 0, sqThreadIdle: int = 0): Ring =
  let params = io_uring_params(
    flags: cast[uint32](flags),
    sq_thread_cpu: sqThreadCpu.uint32,
    sq_thread_idle: sqThreadIdle.uint32
  )
  result.ringFD = io_uring_setup(queueDepth.cint, params.unsafeAddr)
  if result.ringFD < 0:
    raiseOsError osLastError()
  
  result.flags = cast[SetupFlags](params.flags)
  result.features = cast[Features](params.features)

  var size = sizeof(io_uring_cqe)
  if sfCqe32 in flags:
    size += sizeof(io_uring_cqe)

  var
    sq = result.sq
    cq = result.cq
  
  sq.ringSize = int(params.sq_off.array + params.sq_entries * sizeof(uint).uint)
  cq.ringSize = int(params.cq_off.cqes + params.cq_entries * size.uint)

  if fSingleMmap in result.features:
    if cq.ringSize > sq.ringSize:
      sq.ringSize = cq.ringSize
    cq.ringSize = sq.ringSize
  
  sq.ringPtr = mmap(
    cast[pointer](nil), sq.ringSize,
    cast[cint](PROT_READ or PROT_WRITE),
    cast[cint](MAP_SHARED or MAP_POPULATE),
    result.ringFD,
    cast[Off](IORING_OFF_SQ_RING)
  )
  if sq.ringPtr == MAP_FAILED:
    raiseOsError osLastError()

  if fSingleMmap in result.features:
    cq.ringPtr = sq.ringPtr
  else:
    cq.ringPtr = mmap(
      cast[pointer](nil), cq.ringSize,
      cast[cint](PROT_READ or PROT_WRITE),
      cast[cint](MAP_SHARED or MAP_POPULATE),
      result.ringFD,
      cast[Off](IORING_OFF_CQ_RING)
    )
    if cq.ringPtr == MAP_FAILED:
      raiseOsError osLastError()

  # Initialize the SubmissionQueue
  sq.head = cast[ptr uint](sq.ringPtr + params.sq_off.head)
  sq.tail = cast[ptr uint](sq.ringPtr + params.sq_off.tail)
  sq.ringMask = cast[ptr uint](sq.ringPtr + params.sq_off.ring_mask)[]
  sq.ringEntries = cast[ptr uint16](sq.ringPtr + params.sq_off.ring_entries)[]
  sq.flags = cast[ptr SubmissionQueueFlags](sq.ringPtr + params.sq_off.flags)
  sq.dropped = cast[ptr uint](sq.ringPtr + params.sq_off.dropped)
  sq.arr = cast[ptr uint](sq.ringPtr + params.sq_off.array)

  size = sizeof(io_uring_sqe)
  if sfSqe128 in flags:
    size += 64
  
  sq.sqes = cast[ptr io_uring_sqe](mmap(
    cast[pointer](nil),
    int(params.sq_entries * size.uint),
    cast[cint](PROT_READ or PROT_WRITE),
    cast[cint](MAP_SHARED or MAP_POPULATE),
    result.ringFD,
    cast[Off](IORING_OFF_SQES),
  ))
  if sq.sqes == MAP_FAILED:
    raiseOsError osLastError()
  
  # Initialize the CompletionQueue
  cq.head = cast[ptr uint](cq.ringPtr + params.cq_off.head)
  cq.tail = cast[ptr uint](cq.ringPtr + params.cq_off.tail)
  cq.ringMask = cast[ptr uint](cq.ringPtr + params.cq_off.ring_mask)[]
  cq.ringEntries = cast[ptr uint16](cq.ringPtr + params.cq_off.ring_entries)[]
  cq.overflow = cast[ptr uint](cq.ringPtr + params.cq_off.overflow)
  cq.cqes = cast[ptr io_uring_cqe](cq.ringPtr + params.cq_off.cqes)

  # Directly map SQ slots to SQEs
  var sqArr = sq.arr;
  for i in 0..<sq.ringEntries.uint:
    cast[ptr uint](sqArr + i)[] = i.uint;

proc `=destroy`*(ring: var Ring) =
  let
    sq = ring.sq
    cq = ring.cq
  var sqeSize = sizeof(io_uring_sqe)
  if sfSqe128 in ring.flags:
    sqeSize += 64
  if sq.sqes != nil:
    discard munmap(sq.sqes, int(ring.sq.ringEntries * sqeSize.uint))
  if sq.ringPtr != nil:
    discard munmap(sq.ringPtr, sq.ringSize);
  if cq.ringPtr != nil and cq.ringPtr != sq.ringPtr:
    discard munmap(cq.ringPtr, cq.ringSize);
  if ring.ringFD != -1:
    discard close(ring.ringFD)

{.push, header: "<stdatomic.h>", importc.}
proc atomic_load_explicit[T](location: ptr T; order: MemoryOrder): T
proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent)
proc atomic_thread_fence(order: MemoryOrder)
{.pop.}

proc sqFlush(ring: Ring): int =
  ## Sync internal state with kernel ring state on the SQ side. Returns the
  ## number of pending items in the SQ ring, for the shared ring.
  var
    sq = ring.sq
    tail = sq.sqeTail
  if sq.sqeHead != tail:
    sq.sqeHead = tail
    # Ensure kernel sees the SQE updates before the tail update.
    if sfSqpoll in ring.flags:
      atomic_store_explicit(sq.tail, tail, moRelaxed)
    else:
      atomic_store_explicit(sq.tail, tail, moRelease)
  return int(tail - sq.head[])

type
  EnterFlag = enum
    efGetevents ## IORING_ENTER_GETEVENTS
    efSqWakeup ## IORING_ENTER_SQ_WAKEUP
    efSqWait ## IORING_ENTER_SQ_WAIT
    efExtArg ## IORING_ENTER_EXT_ARG
    efRegisteredRing ## IORING_ENTER_REGISTERED_RING
  EnterFlags = set[EnterFlag]

proc sqNeedsEnter(ring: Ring, submit: int, flags: var EnterFlags): bool =
  ## Returns true if we're not using SQ thread (thus nobody submits but us)
  ## or if IORING_SQ_NEED_WAKEUP is set, so submit thread must be explicitly
  ## awakened. For the latter case, we set the thread wakeup flag.
  ## If no SQEs are ready for submission, returns false.
  if submit == 0:
    return false
  if sfSqpoll in ring.flags:
    return true
  # Ensure the kernel can see the store to the SQ tail before we read
  # the flags.
  atomic_thread_fence(moSequentiallyConsistent)
  if sqNeedWakeup in atomic_load_explicit[SubmissionQueueFlags](ring.sq.flags, moRelaxed):
    flags.incl(efSqWakeup)
    return true
  return false;

template cqNeedsFlush(ring: Ring): bool =
  {sqCqOverflow, sqTaskrun} <= atomic_load_explicit[SubmissionQueueFlags](ring.sq.flags, moRelaxed)

template cqNeedsEnter(ring: Ring): bool =
  sfIopoll in ring.flags or ring.cqNeedsFlush

proc submit*(ring: Ring, waitNr: uint = 0, getEvents: bool = false): int =
  ## Submit sqes acquired from io_uring_get_sqe() to the kernel.
  ## Returns number of sqes submitted
  let
    submited = ring.sqFlush
    cqNeedsEnter = getEvents or ring.cqNeedsEnter
  var flags: EnterFlags
  if ring.sqNeedsEnter(submited, flags) or cqNeedsEnter:
    if cqNeedsEnter:
      flags.incl(efGetevents)
    result = io_uring_enter(ring.ringFD, submited.cint, cast[cint](waitNr), cast[cint](flags), nil, 0.cint)
  else:
    result = submited

type
  CompletionQueueEntryFlag = enum
    cqeFBuffer
    cqeFMore
    cqeFSockNonempty
    cqeFNotif
    cqeBufferShift = 16
  CompletionQueueEntryFlags = set[CompletionQueueEntryFlag]

  CompletionQueueEntry* = object
    userData: pointer
    res: int
    flags: CompletionQueueEntryFlags

template getCqe(
  ring: Ring, cqe: var CompletionQueueEntry, submit: var uint, waitNr: uint,
  getFlags: EnterFlags = {}, sz: int = 4, hasTs: bool = false, arg: pointer = nil): int =
  ## Helper for the peek/wait single cqe functions. Exported because of that,
  ## but probably shouldn't be used directly in an application.
  var
    looped = false
    err = 0
  while true:
    var
      needEnter = false
      flags: EnterFlags
      nrAvailable: int
      ret: int

    ret = ring.helpPeekCqe(cqe, nrAvailable)
    if ret > 0:
      if err == 0:
        err = ret
      break

    if cqe == nil and waitNr == 0 and submit == 0:
      if looped or not ring.cqNeedsEnter:
        if err == 0:
          err = -EAGAIN
        break
      needEnter = true
    
    if waitNr > nrAvailable or needEnter:
      flags = getFlags | {efGetevents}
      needEnter = true
    if ring.sqNeedsEnter(submit, flags):
      needEnter = true
    if not needEnter:
      break
    if looped and hasTs:
      let arg = cast[ptr io_uring_getevents_arg](arg)
      if cqe == nil and arg.ts and err == 0:
        err = -ETIME
      break
    
    ret = io_uring_enter(ring.ringFD, submit, waitNr, flags, arg, sz)
    if ret < 0:
      if err == 0:
        err = ret
      break
    submit -= ret
    if cqe != nil:
      break
    if not looped:
      looped = true
      err = ret

  return ret

template waitCqeNr*(ring: Ring, cqe: var CompletionQueueEntry, waitNr: uint): int =
  ## Return an IO completion, waiting for 'wait_nr' completions if one isn't
  ## readily available. Returns 0 with cqe_ptr filled in on success, -errno on
  ## failure.
  ring.getCqe(cqe, 0, waitNr)

template cqAdvance*(ring: Ring, nr: uint) =
  if nr != 0:
    var cq = ring.cq
    # Ensure that the kernel only sees the new value of the head
    # index after the CQEs have been read.
    atomic_store_explicit(cq.head, cq.head + nr, moRelease);
  
template helpPeekCqe(ring: Ring, cqe: var CompletionQueueEntry, nrAvailable: var int = 0): int =
  ## Internal helper, don't use directly in applications. Use one of the
  ## "official" versions of this, peekCqe(), waitCqe(),
  ## or waitCqes().
  var
    err = 0
    available: int
    mask = ring.cq.ringMask
    shift = 0
  if sfCqe32 in ring.flags:
    shift = 1
  while true:
    tail = atomic_load_explicit[int](ring.cq.tail, moAcquire)
    head = ring.cq.head[]

    cqe = nil
    available = tail - head
    if available == 0:
      break

    cqe = cast[ptr CompletionQueueEntry](ring.cq.cqes[(head and mask) shl shift])
    if fExtArg notin ring.features and cqe.userData == nil:
      if cqe.res < 0:
        err = cqe.res
      ring.cqAdvance(1)
      if err == 0:
        continue
      cqe = nil
    break
  nrAvailable = available
  return err

template peekCqe*(ring: Ring, cqe: var CompletionQueueEntry): int =
  ## Return an IO completion, if one is readily available. Returns 0 with
  ## cqe_ptr filled in on success, -errno on failure.
  if ring.helpPeekCqe(cqe) == 0 and cqe != nil:
    return 0
  ring.waitCqeNr(cqe.addr, 0)

template waitCqe*(ring: Ring, cqe: var CompletionQueueEntry): int =
  ## Return an IO completion, waiting for it if necessary. Returns 0 with
  ## cqe_ptr filled in on success, -errno on failure.
  if ring.helpPeekCqe(cqe) == 0 and cqe != nil:
    return 0
  ring.waitCqeNr(cqe.addr, 1)

template waitCqes*(ring: Ring): int = 0

template cqeSeen*(ring: Ring, cqe: var CompletionQueueEntry) =
  ## Must be called after peekCqe, waitCqe after the cqe has
  ## been processed by the application.
  if cqe != nil:
    ring.cqAdvance(1)

template getSqe*(ring: Ring): ref io_uring_sqe =
  ## Return an sqe to fill. Application must later call io_uring_submit()
  ## when it's ready to tell the kernel about it. The caller may call this
  ## function multiple times before calling io_uring_submit().
  ## Returns a vacant sqe, or NULL if we're full.
  let sq = ring.sq
  var
    head: uint
    next = sq.sqeTail + 1
    shift = 0
  if sfSqe128 in ring.flags:
    shift = 1
  if sfSqpoll in ring.flags:
    head = atomic_load_explicit(sq.head, moRelaxed)
  else:
    head = atomic_load_explicit(sq.head, moAcquire)
  if next - head <= sq.ringEntries:
    var sqe: ref io_uring_sqe = io_uring_sqe()
    sqe = sq.sqes[(sq.sqeTail and sq.ringMask) shl shift]
    sq.sqeTail = next
    return sqe
  return nil