## For more information see https://unixism.net/loti/index.html
## https://man7.org/linux/man-pages/man7/io_uring.7.html
## https://github.com/axboe/liburing/wiki/io_uring-and-networking-in-2023

import posix, os

type
  KernelRwfT* {.importc: "__kernel_rwf_t", header: "<linux/fs.h>".} = int

type
  InnerSqeOffset* {.union.} = object
    off*: Off ##  offset into file
    addr2*: pointer
    cmdOp*: uint32
    pad1*: Off

  InnerSqeAddr* {.union.} = object
    `addr`*: pointer ##  pointer to buffer or iovecs
    spliceOffIn*: Off

  InnerSqeFlags* {.union.} = object
    rwFlags*: KernelRwfT
    fsyncFlags*: FsyncFlags
    pollEvents*: PollFlags ##  compatibility
    poll32Events*: uint32 ##  word-reversed for BE
    syncRangeFlags*: uint32
    msgFlags*: uint32
    timeoutFlags*: TimeoutFlags
    acceptFlags*: uint32
    cancelFlags*: uint32
    openFlags*: uint32
    statxFlags*: uint32
    fadviseAdvice*: uint32
    spliceFlags*: uint32
    renameFlags*: uint32
    unlinkFlags*: uint32
    hardlinkFlags*: uint32
    xattrFlags*: uint32
    msgRingFlags*: MsgRingOpFlags
    uringCmdFlags*: uint32
  
  InnerSqeBuf* {.union, packed.} = object
    bufIndex*: uint16 ##  index into fixed buffers, if used
    bufGroup*: uint16 ##  for grouped buffer selection
  
  InnerSqeSplicePadAddrLen = object
    addrLen* {.importc: "addr_len".}: uint16
    pad3* {.importc: "__pad3".}: array[1, uint16]

  InnerSqeSplice* {.union.} = object
    spliceFdIn* {.importc: "splice_fd_in".}: uint32
    fileIndex* {.importc: "file_index".}: uint32
    addrLen*: InnerSqeSplicePadAddrLen
  
  InnerSqeCmd* {.union.} = object
    addr3* {.importc: "addr3".}: pointer
    pad2* {.importc: "__pad2".}: array[1, uint64]
    cmd* {.importc: "cmd".}: uint8 ## If the ring is initialized with SETUP_SQE128, then
                                   ## this field is used for 80 bytes of arbitrary command data

  ## IO submission data structure (Submission Queue Entry)
  Sqe* {.pure, bycopy.} = object
    opcode*: Op ##  type of operation for this sqe
    flags*: SqeFlags
    ioprio*: IoprioFlags ##  ioprio for the request
    fd*: FileHandle   ##  file descriptor to do IO on
    off*: InnerSqeOffset
    `addr`*: InnerSqeAddr
    len*: int32 ##  buffer size or number of iovecs
    opFlags*: InnerSqeFlags
    userData*: pointer ##  data to be passed back at completion time
    buf*: InnerSqeBuf
    personality*: uint16
    splice*: InnerSqeSplice
    cmd*: InnerSqeCmd

  Op* {.size: sizeof(uint8).} = enum
    OP_NOP
    OP_READV
    OP_WRITEV
    OP_FSYNC
    OP_READ_FIXED
    OP_WRITE_FIXED
    OP_POLL_ADD
    OP_POLL_REMOVE
    OP_SYNC_FILE_RANGE
    OP_SENDMSG
    OP_RECVMSG
    OP_TIMEOUT
    OP_TIMEOUT_REMOVE
    OP_ACCEPT
    OP_ASYNC_CANCEL
    OP_LINK_TIMEOUT
    OP_CONNECT
    OP_FALLOCATE
    OP_OPENAT
    OP_CLOSE
    OP_FILES_UPDATE
    OP_STATX
    OP_READ
    OP_WRITE
    OP_FADVISE
    OP_MADVISE
    OP_SEND
    OP_RECV
    OP_OPENAT2
    OP_EPOLL_CTL
    OP_SPLICE
    OP_PROVIDE_BUFFERS
    OP_REMOVE_BUFFERS
    OP_TEE
    OP_SHUTDOWN
    OP_RENAMEAT
    OP_UNLINKAT
    OP_MKDIRAT
    OP_SYMLINKAT
    OP_LINKAT
    OP_MSG_RING
    OP_FSETXATTR
    OP_SETXATTR
    OP_FGETXATTR
    OP_GETXATTR
    OP_SOCKET
    OP_URING_CMD
    OP_SEND_ZC
    OP_SENDMSG_ZC
    OP_LAST ## this goes last, obviously
  
  SqeFlag* {.size: sizeof(uint8).} = enum
    SQE_FIXED_FILE
    SQE_IO_DRAIN
    SQE_IO_LINK
    SQE_IO_HARDLINK
    SQE_ASYNC
    SQE_BUFFER_SELECT
    SQE_CQE_SKIP_SUCCESS
  SqeFlags* = set[SqeFlag]

  FsyncFlag* {.size: sizeof(uint32).} = enum
    FSYNC_DATASYNC
  FsyncFlags* = set[FsyncFlag]

  TimeoutFlag* {.size: sizeof(uint32).} = enum
    TIMEOUT_ABS
    TIMEOUT_UPDATE
    TIMEOUT_BOOTTIME
    TIMEOUT_REALTIME
    LINK_TIMEOUT_UPDATE
    TIMEOUT_ETIME_SUCCESS
  TimeoutFlags* = set[TimeoutFlag]

  ## POLL_ADD flags. Note that since sqe->poll_events is the flag space, the
  ## command flags for POLL_ADD are stored in sqe->len.
  PollFlag* {.size: sizeof(uint16).} = enum
    POLL_ADD_MULTI ## Multishot poll. Sets CQE_F_MORE if
                          ## the poll handler will continue to report
                          ## CQEs on behalf of the same SQE.
    POLL_UPDATE_EVENTS ## Update existing poll request, matching
                              ## sqe->addr as the old user_data field.
    POLL_UPDATE_USER_DATA ## Level triggered poll.
    POLL_ADD_LEVEL
  PollFlags* = set[PollFlag]

  AsyncCancelFlag* {.size: sizeof(uint32).} = enum
    ASYNC_CANCEL_ALL ## Cancel all requests that match the given key
    ASYNC_CANCEL_FD ## Key off 'fd' for cancelation rather than the
                           ## request 'user_data'
    ASYNC_CANCEL_ANY ## Match any request
    ASYNC_CANCEL_FD_FIXED ## 'fd' passed in is a fixed descriptor
  AsyncCancelFlags* = set[AsyncCancelFlag]

  ## send/sendmsg and recv/recvmsg flags (sqe->ioprio)
  IoprioFlag* {.size: sizeof(uint16).} = enum
    RECVSEND_POLL_FIRST ## If set, instead of first attempting to send
                               ## or receive and arm poll if that yields an
                               ## -EAGAIN result, arm poll upfront and skip
                               ## the initial transfer attempt.
    RECV_MULTISHOT ## Multishot recv. Sets CQE_F_MORE if
                          ## the handler will continue to report
                          ## CQEs on behalf of the same SQE.
    RECVSEND_FIXED_BUF ## Use registered buffers, the index is stored in
                              ## the buf_index field.
    SEND_ZC_REPORT_USAGE ## If set, SEND[MSG]_ZC should report
                                ## the zerocopy usage in cqe.res
                                ## for the CQE_F_NOTIF cqe.
                                ## 0 is reported if zerocopy was actually possible.
                                ## NOTIF_USAGE_ZC_COPIED if data was copied
                                ## (at least partially).
  IoprioFlags* = set[IoprioFlag]

  ## OP_MSG_RING command types, stored in sqe->addr
  MsgRingOp* = enum
    MSG_DATA ## pass sqe->len as 'res' and off as user_data
    MSG_SEND_FD ## send a registered fd to another ring
  
  MsgRingOpFlag* {.size: sizeof(uint32).} = enum
    MSG_RING_CQE_SKIP ## Don't post a CQE to the target ring. Not
                      ## applicable for MSG_DATA, obviously.
    MSG_RING_FLAGS_PASS ## Pass through the flags from sqe->file_index to cqe->flags */
  MsgRingOpFlags* = set[MsgRingOpFlag]

##
##  If sqe->file_index is set to this for opcodes that instantiate a new
##  direct descriptor (like openat/openat2/accept), then io_uring will allocate
##  an available direct descriptor instead of having the application pass one
##  in. The picked direct descriptor will be returned in cqe->res, or -ENFILE
##  if the space is full.
##
const FILE_INDEX_ALLOC* = not 0u

##
##  sqe->uring_cmd_flags
##  URING_CMD_FIXED	use registered buffer; pass this flag
## 				along with setting sqe->buf_index.
##

const URING_CMD_FIXED* = not 0u

const TIMEOUT_CLOCK_MASK* = {TIMEOUT_BOOTTIME, TIMEOUT_REALTIME}
const TIMEOUT_UPDATE_MASK* = {TIMEOUT_UPDATE, LINK_TIMEOUT_UPDATE}

##
##  sqe->splice_flags
##  extends splice(2) flags
##

const SPLICE_F_FD_IN_FIXED* = 1u shl 32


##
##  cqe.res for CQE_F_NOTIF if
##  SEND_ZC_REPORT_USAGE was requested
##
##  It should be treated as a flag, all other
##  bits of cqe.res should be treated as reserved!
##

const NOTIF_USAGE_ZC_COPIED* = 1u shl 32


##
## accept flags stored in sqe->ioprio
##
const ACCEPT_MULTISHOT* = 1u shl 0


type
  ## IO completion data structure (Completion Queue Entry)
  Cqe* = object
    userData*: uint64 ##  sqe->data submission passed back
    res*: int32 ##  result code for this event
    flags*: CqeFlags

  CqeFlag* {.size: sizeof(uint32).} = enum
    CQE_F_BUFFER ## If set, the upper 16 bits are the buffer ID
    CQE_F_MORE ## If set, parent SQE will generate more CQE entries
    CQE_F_SOCK_NONEMPTY ## If set, more data to read after socket recv
    CQE_F_NOTIF ## Set for notification CQEs. Can be used to distinct
                ## them from sends.
  CqeFlags* = set[CqeFlag]


const CQE_BUFFER_SHIFT* = 16

type
  Params* = object
    sqEntries*: uint32
    cqEntries*: uint32
    flags*: SetupFlags
    sqThreadCpu*: uint32
    sqThreadIdle*: uint32
    features*: Features
    wqFd*: uint32
    resv*: array[3, uint32]
    sqOff*: SqringOffsets
    cqOff*: CqringOffsets
  
  SetupFlag* {.size: sizeof(uint32).} = enum
    SETUP_IOPOLL ## io_context is polled
    SETUP_SQPOLL ## SQ poll thread
    SETUP_SQ_AFF ## sq_thread_cpu is valid
    SETUP_CQSIZE ## app defines CQ size
    SETUP_CLAMP ## clamp SQ/CQ ring sizes
    SETUP_ATTACH_WQ ## attach to existing wq
    SETUP_R_DISABLED ## start with ring disabled
    SETUP_SUBMIT_ALL ## continue submit on error
    SETUP_COOP_TASKRUN ## Cooperative task running. When requests complete, they often require
                              ## forcing the submitter to transition to the kernel to complete. If this
                              ## flag is set, work will be done when the task transitions anyway, rather
                              ## than force an inter-processor interrupt reschedule. This avoids interrupting
                              ## a task running in userspace, and saves an IPI.
    SETUP_TASKRUN ## If COOP_TASKRUN is set, get notified if task work is available for
                         ## running and a kernel transition would be needed to run it. This sets
                         ## SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
    SETUP_SQE128 ## SQEs are 128 byte
    SETUP_CQE32 ## CQEs are 32 byte
    SETUP_SINGLE_ISSUER ## Only one task is allowed to submit requests
    SETUP_DEFER_TASKRUN ## Defer running task work to get events.
                               ## Rather than running bits of task work whenever the task transitions
                               ## try to do it just before it is needed.
  SetupFlags* = set[SetupFlag]

  Feature* {.size: sizeof(uint32).} = enum
    FEAT_SINGLE_MMAP
    FEAT_NODROP
    FEAT_SUBMIT_STABLE
    FEAT_RW_CUR_POS
    FEAT_CUR_PERSONALITY
    FEAT_FAST_POLL
    FEAT_POLL_32BITS
    FEAT_SQPOLL_NONFIXED
    FEAT_EXT_ARG
    FEAT_NATIVE_WORKERS
    FEAT_RSRC_TAGS
    FEAT_CQE_SKIP
    FEAT_LINKED_FILE
    FEAT_REG_REG_RING
  Features* = set[Feature]

  ## Filled with the offset for mmap(2)
  SqringOffsets* = object
    head*: uint32
    tail*: uint32
    ringMask*: uint32
    ringEntries*: uint32
    flags*: uint32
    dropped*: uint32
    array*: uint32
    resv1*: uint32
    resv2*: uint64
  
  SqringFlag* {.size: sizeof(uint32).} = enum
    SQ_NEED_WAKEUP ## needs io_uring_enter wakeup
    SQ_CQ_OVERFLOW ## CQ ring is overflown
    SQ_TASKRUN ## task should enter the kernel
  SqringFlags* = set[SqringFlag]

  CqringOffsets* = object
    head*: uint32
    tail*: uint32
    ringMask*: uint32
    ringEntries*: uint32
    overflow*: uint32
    cqes*: uint32
    flags*: uint32
    resv1*: uint32
    resv2*: uint64

  CqringFlag* {.size: sizeof(uint32).} = enum
    CQ_EVENTFD_DISABLED ## disable eventfd notifications
  CqringFlags* = set[CqringFlag]

const OFF_SQ_RING*: Off = 0
const OFF_CQ_RING*: Off = 0x8000000
const OFF_SQES*: Off = 0x10000000

proc `+`*(p: pointer; i: SomeInteger): pointer =
  result = cast[pointer](cast[uint](p) + i.uint)

proc `-`*(p1: pointer; p2: pointer): uint =
  result = cast[uint](p1) - cast[uint](p2)

type
  EnterFlag* {.size: sizeof(cint).} = enum
    ENTER_GETEVENTS
    ENTER_SQ_WAKEUP
    ENTER_SQ_WAIT
    ENTER_EXT_ARG
    ENTER_REGISTERED_RING
  EnterFlags* = set[EnterFlag]

proc uringMap*(offset: Off; fd: FileHandle; begin: uint32;
               count: uint32; typ: typedesc): pointer =
  let
    size = int (begin + count * sizeof(typ).uint32)
  result = mmap(nil, size,
                ProtRead or ProtWrite, MapShared or MapPopulate,
                fd.cint, offset)
  if result == MapFailed:
    result = nil
    raiseOSError osLastError()

proc uringUnmap*(p: pointer; size: int) =
  ## interface to tear down some memory (probably mmap'd)
  let
    code = munmap(p, size)
  if code < 0:
    raiseOSError osLastError()

proc syscall(arg: cint): cint {.importc, header: "<unistd.h>", varargs.}
var
  SYS_io_uring_setup {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_enter {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_register {.importc, header: "<sys/syscall.h>".}: cint

proc setup*(entries: cint, params: ptr Params): FileHandle =
  ## https://man7.org/linux/man-pages/man2/io_uring_setup.2.html
  result = syscall(SYS_io_uring_setup, entries, params, 0, 0, 0, 0)
  if result < 0:
    raiseOSError osLastError()

proc enter*(fd: cint, toSubmit: cint, minComplete: cint,
                         flags: cint, sig: ref Sigset, sz: cint): cint =
  ## https://man7.org/linux/man-pages/man2/io_uring_enter.2.html
  result = syscall(SYS_io_uring_enter, fd, toSubmit, minComplete, flags, sig, sz)
  if result < 0:
    raiseOSError osLastError()

proc register*(fd: cint, op: cint, arg: pointer, nr_args: cint): cint =
  ## https://man7.org/linux/man-pages/man2/io_uring_register.2.html
  result = syscall(SYS_io_uring_register, fd, op, arg, nr_args, 0, 0)
  if result < 0:
    raiseOSError osLastError()

type
  ## io_uring_register(2) opcodes and arguments
  RegisterOp* {.size: sizeof(cint).} = enum
    REGISTER_BUFFERS
    UNREGISTER_BUFFERS
    REGISTER_FILES
    UNREGISTER_FILES
    REGISTER_EVENTFD
    UNREGISTER_EVENTFD
    REGISTER_FILES_UPDATE
    REGISTER_EVENTFD_ASYNC
    REGISTER_PROBE
    REGISTER_PERSONALITY
    UNREGISTER_PERSONALITY
    REGISTER_RESTRICTIONS
    REGISTER_ENABLE_RINGS ##  extended with tagging
    REGISTER_FILES2
    REGISTER_FILES_UPDATE2
    REGISTER_BUFFERS2
    REGISTER_BUFFERS_UPDATE ##  set/clear io-wq thread affinities
    REGISTER_IOWQ_AFF
    UNREGISTER_IOWQ_AFF ##  set/get max number of io-wq workers
    REGISTER_IOWQ_MAX_WORKERS ##  register/unregister io_uring fd with the ring
    REGISTER_RING_FDS
    UNREGISTER_RING_FDS ##  register ring based provide buffer group
    REGISTER_PBUF_RING
    UNREGISTER_PBUF_RING ##  sync cancelation API
    REGISTER_SYNC_CANCEL ##  register a range of fixed file slots for automatic slot allocation
    REGISTER_FILE_ALLOC_RANGE ##  this goes last
    REGISTER_LAST ##  flag added to the opcode to use a registered ring fd

const REGISTER_USE_REGISTERED_RING* = 1u shl 31

const
  IO_WQ_BOUND* = 0              ##  io-wq worker categories
  IO_WQ_UNBOUND* = 1

##
##  Register a fully sparse file space, rather than pass in an array of all
##  -1 file descriptors.
##

const RSRC_REGISTER_SPARSE* = 1u shl 0

type
  RsrcRegister* = object
    nr*: uint32
    flags*: uint32
    resv2*: uint64
    data* {.align: 64.}: uint64
    tags* {.align: 64.}: uint64

  RsrcUpdate* = object
    offset*: uint32
    resv*: uint32
    data*: uint64

  RsrcUpdate2* = object
    offset*: uint32
    resv*: uint32
    data*: uint64
    tags*: uint64
    nr*: uint32
    resv2*: uint32

  NotificationSlot* = object
    tag*: uint64
    resv*: array[3, uint64]

  NotificationRegister* = object
    nrSlots*: uint32
    resv*: uint32
    resv2*: uint64
    data*: uint64
    resv3*: uint64


##  Skip updating fd indexes set to this value in the fd table

const REGISTER_FILES_SKIP* = -2
const OP_SUPPORTED* = 1u shl 0

type
  ProbeOp* = object
    op*: uint8
    resv*: uint8
    flags*: uint16 ##  IO_URING_OP_* flags
    resv2*: uint32

  Probe* = object
    lastOp*: uint8 ##  last opcode supported
    opsLen*: uint8 ##  length of ops[] array below
    resv*: uint16
    resv2*: array[3, uint32]
    ops*: ref ProbeOp

  Restriction* = object
    opcode*: RestrictionOp
    registerOp*: uint8 ##  IORING_RESTRICTION_REGISTER_OP
    sqeOp*: uint8 ##  IORING_RESTRICTION_SQE_OP
    sqeFlags*: uint8
    ##  IORING_RESTRICTION_SQE_FLAGS_*
    resv*: uint8
    resv2*: array[3, uint32]
  
  RestrictionOp* {.size: sizeof(uint16).} = enum
    RESTRICTION_REGISTER_OP ## Allow an io_uring_register(2) opcode
    RESTRICTION_SQE_OP ## Allow an sqe opcode
    RESTRICTION_SQE_FLAGS_ALLOWED ## Allow sqe flags
    RESTRICTION_SQE_FLAGS_REQUIRED ## Require sqe flags (these flags must be set on each submission)
    RESTRICTION_LAST

  Buf* = object
    `addr`*: uint64
    len*: uint32
    bid*: uint16
    resv*: uint16

  BufRing* = object
    resv1*: uint64
    resv2*: uint32
    resv3*: uint16
    tail*: uint16
    bufs*: UncheckedArray[Buf]


type
  BufReg* = object ##  argument for IORING_(UN)REGISTER_PBUF_RING
    ringAddr*: uint64
    ringEntries*: uint32
    bgid*: uint16
    pad*: uint16
    resv*: array[3, uint64]

type
  GeteventsArg* = object
    sigmask*: uint64
    sigmaskSz*: uint32
    pad*: uint32
    ts*: uint64


type
  SyncCancelReg* = object
    ##  Argument for
    ## IORING_REGISTER_SYNC_CANCEL
    `addr`*: uint64
    fd*: int32
    flags*: uint32
    timeout*: Timespec
    pad*: array[4, uint64]


type
  FileIndexRange* = object
    ##  Argument for
    ## IORING_REGISTER_FILE_ALLOC_RANGE
    ##  The range is specified as [off, off + len)
    off*: uint32
    len*: uint32
    resv*: uint64

  RecvmsgOut* = object
    namelen*: uint32
    controllen*: uint32
    payloadlen*: uint32
    flags*: uint32
