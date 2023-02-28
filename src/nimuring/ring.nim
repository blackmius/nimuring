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
    flags: SubmissionQueueFlags
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



proc newRing*(queueDepth: uint, flags: SetupFlags): Ring =
  let params = io_uring_params(flags: cast[uint32](flags))
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
  sq.flags = cast[ptr SubmissionQueueFlags](sq.ringPtr + params.sq_off.flags)[]
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
proc atomic_load_explicit[T, A](location: ptr A; order: MemoryOrder): T
proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent)
proc atomic_thread_fence(order: MemoryOrder)
{.pop.}

proc sqFlush*(ring: Ring): bool =
  var
    sq = ring.sq
    tail = sq.tail[]
    toSubmit = sq.sqeTail - sq.sqeHead
  let mask = sq.ringMask
  if toSubmit == 0:
    return false
  while toSubmit > 0:
    cast[ptr uint](sq.arr + (tail and mask))[] = sq.sqeHead and mask
    tail += 1
    sq.sqeHead += 1u
    toSubmit -= 1
  atomic_store_explicit(sq.tail, tail, moRelease)
  return true
