import os, posix
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
    ringMask: ptr uint
    ringEntries: ptr uint
    flags: ptr SubmissionQueueFlags
    dropped: ptr uint
    arr: ptr uint
    sqes: ptr io_uring_sqe

    sqeHead: uint
    sqeTail: uint

    ringSize: int
    ringPtr: pointer
  
  CompletionQueueFlag* = enum
    cqEventFDDisabled
  CompletionQueueFlags* = set[CompletionQueueFlag]
  
  CompletionQueue* = object
    head: ptr uint
    tail: ptr uint
    ringMask: ptr uint
    ringEntries: ptr uint
    flags: ptr CompletionQueueFlags
    overflow: ptr uint
    cqes: ptr io_uring_cqe

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

  result.sq.ringSize = max(
    params.sq_off.array + params.sq_entries * sizeof(uint32).uint,
    params.cq_off.cqes + params.cq_entries * sizeof(io_uring_cqe).uint
  ).int
  result.cq.ringSize = result.sq.ringSize

  result.sq.ringPtr = mmap(
    cast[pointer](nil), result.sq.ringSize,
    cast[cint](PROT_READ or PROT_WRITE),
    cast[cint](MAP_SHARED or MAP_POPULATE),
    result.ringFD,
    cast[Off](IORING_OFF_SQ_RING),
  )
  result.cq.ringPtr = result.sq.ringPtr
  if result.sq.ringPtr == MAP_FAILED:
    raiseOsError osLastError()
  
  # Initialize the SubmissionQueue
  result.sq.head = cast[ptr uint](result.sq.ringPtr + params.sq_off.head)
  result.sq.tail = cast[ptr uint](result.sq.ring_ptr + params.sq_off.tail)
  result.sq.ringMask = cast[ptr uint](result.sq.ring_ptr + params.sq_off.ring_mask)
  result.sq.ringEntries = cast[ptr uint](result.sq.ring_ptr + params.sq_off.ring_entries)
  result.sq.flags = cast[ptr SubmissionQueueFlags](result.sq.ring_ptr + params.sq_off.flags)
  result.sq.dropped = cast[ptr uint](result.sq.ring_ptr + params.sq_off.dropped)
  result.sq.arr = cast[ptr uint](result.sq.ring_ptr + params.sq_off.array)
  result.sq.sqes = cast[ptr io_uring_sqe](mmap(
    cast[pointer](nil),
    int(params.sq_entries * sizeof(io_uring_sqe).uint),
    cast[cint](PROT_READ or PROT_WRITE),
    cast[cint](MAP_SHARED or MAP_POPULATE),
    result.ringFD,
    cast[Off](IORING_OFF_SQES),
  ))
  if result.sq.sqes == MAP_FAILED:
    discard munmap(result.sq.ringPtr, result.sq.ringSize)
    raiseOsError osLastError()
  
  # Initialize the CompletionQueue
  result.cq.head = cast[ptr uint](result.cq.ringPtr + params.cq_off.head)
  result.cq.tail = cast[ptr uint](result.cq.ringPtr + params.cq_off.tail)
  result.cq.ringMask = cast[ptr uint](result.cq.ringPtr + params.cq_off.ring_mask)
  result.cq.ringEntries = cast[ptr uint](result.cq.ringPtr + params.cq_off.ring_entries)
  result.cq.overflow = cast[ptr uint](result.cq.ringPtr + params.cq_off.overflow)
  result.cq.cqes = cast[ptr io_uring_cqe](result.cq.ringPtr + params.cq_off.cqes)
  
