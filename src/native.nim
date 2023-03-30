import posix

type
  KernelRwfT* {.importc: "__kernel_rwf_t", header: "<linux/fs.h>".} = int

  ## IO submission data structure (Submission Queue Entry)
  Sqe* {.importc: "struct io_uring_sqe", header: "<linux/io_uring.h>", bycopy.} = object
    opcode* {.importc: "opcode".}: Op ##  type of operation for this sqe
    flags* {.importc: "flags".}: SqeFlags
    ioprio* {.importc: "ioprio".}: IoprioFlags ##  ioprio for the request
    fd* {.importc: "fd".}: int32   ##  file descriptor to do IO on
    off* {.importc: "off".}: uint64 ##  offset into file
    addr2* {.importc: "addr2".}: uint64
    cmdOp* {.importc: "cmd_op".}: uint32
    pad1* {.importc: "__pad1".}: uint32
    `addr`* {.importc: "addr".}: uint64 ##  pointer to buffer or iovecs
    spliceOffIn* {.importc: "splice_off_in".}: uint64
    len* {.importc: "len".}: uint32 ##  buffer size or number of iovecs
    rwFlags* {.importc: "rw_flags".}: KernelRwfT
    fsyncFlags* {.importc: "fsync_flags".}: FsyncFlags
    pollEvents* {.importc: "poll_events".}: PollFlags ##  compatibility
    poll32Events* {.importc: "poll32_events".}: uint32 ##  word-reversed for BE
    syncRangeFlags* {.importc: "sync_range_flags".}: uint32
    msgFlags* {.importc: "msg_flags".}: uint32
    timeoutFlags* {.importc: "timeout_flags".}: TimeoutFlags
    acceptFlags* {.importc: "accept_flags".}: uint32
    cancelFlags* {.importc: "cancel_flags".}: uint32
    openFlags* {.importc: "open_flags".}: uint32
    statxFlags* {.importc: "statx_flags".}: uint32
    fadviseAdvice* {.importc: "fadvise_advice".}: uint32
    spliceFlags* {.importc: "splice_flags".}: uint32
    renameFlags* {.importc: "rename_flags".}: uint32
    unlinkFlags* {.importc: "unlink_flags".}: uint32
    hardlinkFlags* {.importc: "hardlink_flags".}: uint32
    xattrFlags* {.importc: "xattr_flags".}: uint32
    msgRingFlags* {.importc: "msg_ring_flags".}: MsgRingOpFlags
    uringCmdFlags* {.importc: "uring_cmd_flags".}: uint32
    userData* {.importc: "user_data".}: uint64 ##  data to be passed back at completion time
    bufIndex* {.importc: "buf_index".}: uint16 ##  index into fixed buffers, if used
    bufGroup* {.importc: "buf_group".}: uint16 ##  for grouped buffer selection
    personality* {.importc: "personality".}: uint16
    spliceFdIn* {.importc: "splice_fd_in".}: uint32
    fileIndex* {.importc: "file_index".}: uint32
    addrLen* {.importc: "addr_len".}: uint16
    pad3* {.importc: "__pad3".}: array[1, uint16]
    addr3* {.importc: "addr3".}: uint64
    pad2* {.importc: "__pad2".}: array[1, uint64]
    cmd* {.importc: "cmd".}: UncheckedArray[uint8] ## If the ring is initialized with SETUP_SQE128, then
                                                   ## this field is used for 80 bytes of arbitrary command data
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
    SQE_FIXED_FILE_BIT
    SQE_IO_DRAIN_BIT
    SQE_IO_LINK_BIT
    SQE_IO_HARDLINK_BIT
    SQE_ASYNC_BIT
    SQE_BUFFER_SELECT_BIT
    SQE_CQE_SKIP_SUCCESS_BIT
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
  Cqe* {.importc: "struct io_uring_cqe", header: "<linux/io_uring.h>", bycopy.} = object
    userData* {.importc: "user_data".}: uint64 ##  sqe->data submission passed back
    res* {.importc: "res".}: int32 ##  result code for this event
    flags* {.importc: "flags".}: CqeFlags
    bigCqe* {.importc: "big_cqe".}: ref uint64 ##
                                               ##  If the ring is initialized with SETUP_CQE32, then this field
                                               ##  contains 16-bytes of padding, doubling the size of the CQE.
                                               ##
  CqeFlag* {.size: sizeof(uint32).} = enum
    CQE_F_BUFFER ## If set, the upper 16 bits are the buffer ID
    CQE_F_MORE ## If set, parent SQE will generate more CQE entries
    CQE_F_SOCK_NONEMPTY ## If set, more data to read after socket recv
    CQE_F_NOTIF ## Set for notification CQEs. Can be used to distinct
                ## them from sends.
  CqeFlags* = set[CqeFlag]


const CQE_BUFFER_SHIFT* = 16

type
  Params* {.importc: "struct io_uring_params", header: "<linux/io_uring.h>", bycopy.} = object
    sqEntries* {.importc: "sq_entries".}: uint32
    cqEntries* {.importc: "cq_entries".}: uint32
    flags* {.importc: "flags".}: SetupFlags
    sqThreadCpu* {.importc: "sq_thread_cpu".}: uint32
    sqThreadIdle* {.importc: "sq_thread_idle".}: uint32
    features* {.importc: "features".}: Features
    wqFd* {.importc: "wq_fd".}: uint32
    sqOff* {.importc: "sq_off".}: SqringOffsets
    cqOff* {.importc: "cq_off".}: CqringOffsets
  
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
  SqringOffsets* {.importc: "struct io_sqring_offsets", header: "<linux/io_uring.h>", bycopy.} = object
    head* {.importc: "head".}: uint32
    tail* {.importc: "tail".}: uint32
    ringMask* {.importc: "ring_mask".}: uint32
    ringEntries* {.importc: "ring_entries".}: uint32
    flags* {.importc: "flags".}: SqringFlags
    dropped* {.importc: "dropped".}: uint32
  
  SqringFlag* {.size: sizeof(uint32).} = enum
    SQ_NEED_WAKEUP ## needs io_uring_enter wakeup
    SQ_CQ_OVERFLOW ## CQ ring is overflown
    SQ_TASKRUN ## task should enter the kernel
  SqringFlags* = set[SqringFlag]

  CqringOffsets* {.importc: "struct io_cqring_offsets", header: "<linux/io_uring.h>", bycopy.} = object
    head* {.importc: "head".}: uint32
    tail* {.importc: "tail".}: uint32
    ringMask* {.importc: "ring_mask".}: uint32
    ringEntries* {.importc: "ring_entries".}: uint32
    overflow* {.importc: "overflow".}: uint32
    cqes* {.importc: "cqes".}: uint32
    flags* {.importc: "flags".}: CqringFlags

  CqringFlag* {.size: sizeof(uint32).} = enum
    CQ_EVENTFD_DISABLED ## disable eventfd notifications
  CqringFlags* = set[CqringFlag]

const OFF_SQ_RING* = 0u
const OFF_CQ_RING* = 0x8000000u
const OFF_SQES* = 0x10000000u

type
  EnterFlag* {.size: sizeof(cint).} = enum
    ENTER_GETEVENTS
    ENTER_SQ_WAKEUP
    ENTER_SQ_WAIT
    ENTER_EXT_ARG
    ENTER_REGISTERED_RING
  EnterFlags* = set[EnterFlag]

proc setup*(entries: cint, params: ref Params): cint {.importc: "sys_io_uring_setup", header: "<unistd.h>".}
proc enter*(fd: cint, toSubmit: cint, minComplete: cint,
            flags: EnterFlags, sig: ref Sigset, sz: cint): cint {.importc: "sys_io_uring_enter", header: "<unistd.h>".}
proc register*(fd: cint, op: cint, arg: pointer, nr_args: cint): cint {.importc: "sys_io_uring_register", header: "<unistd.h>".}

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
  RsrcRegister* {.importc: "struct io_uring_rsrc_register", header: "<linux/io_uring.h>",
                        bycopy.} = object
    nr* {.importc: "nr".}: uint32
    flags* {.importc: "flags".}: uint32
    resv2* {.importc: "resv2".}: uint64
    data* {.importc: "data", align: 64.}: uint64
    tags* {.importc: "tags", align: 64.}: uint64

  RsrcUpdate* {.importc: "struct io_uring_rsrc_update", header: "<linux/io_uring.h>", bycopy.} = object
    offset* {.importc: "offset".}: uint32
    resv* {.importc: "resv".}: uint32
    data* {.importc: "data", align: 64.}: uint64

  RsrcUpdate2* {.importc: "struct io_uring_rsrc_update2", header: "<linux/io_uring.h>",
                       bycopy.} = object
    offset* {.importc: "offset".}: uint32
    resv* {.importc: "resv".}: uint32
    data* {.importc: "data", align: 64.}: uint64
    tags* {.importc: "tags", align: 64.}: uint64
    nr* {.importc: "nr".}: uint32
    resv2* {.importc: "resv2".}: uint32

  NotificationSlot* {.importc: "struct io_uring_notification_slot",
                            header: "<linux/io_uring.h>", bycopy.} = object
    tag* {.importc: "tag".}: uint64
    resv* {.importc: "resv".}: array[3, uint64]

  NotificationRegister* {.importc: "struct io_uring_notification_register",
                                header: "<linux/io_uring.h>", bycopy.} = object
    nrSlots* {.importc: "nr_slots".}: uint32
    resv* {.importc: "resv".}: uint32
    resv2* {.importc: "resv2".}: uint64
    data* {.importc: "data".}: uint64
    resv3* {.importc: "resv3".}: uint64


##  Skip updating fd indexes set to this value in the fd table

const REGISTER_FILES_SKIP* = -2
const OP_SUPPORTED* = 1u shl 0

type
  ProbeOp* {.importc: "struct io_uring_probe_op", header: "<linux/io_uring.h>", bycopy.} = object
    op* {.importc: "op".}: uint8
    resv* {.importc: "resv".}: uint8
    flags* {.importc: "flags".}: uint16 ##  IO_URING_OP_* flags
    resv2* {.importc: "resv2".}: uint32

  Probe* {.importc: "struct io_uring_probe", header: "<linux/io_uring.h>", bycopy.} = object
    lastOp* {.importc: "last_op".}: uint8 ##  last opcode supported
    opsLen* {.importc: "ops_len".}: uint8 ##  length of ops[] array below
    resv* {.importc: "resv".}: uint16
    resv2* {.importc: "resv2".}: array[3, uint32]
    ops* {.importc: "ops".}: ref ProbeOp

  Restriction* {.importc: "struct io_uring_restriction", header: "<linux/io_uring.h>", bycopy.} = object
    opcode* {.importc: "opcode".}: RestrictionOp
    registerOp* {.importc: "register_op".}: uint8 ##  IORING_RESTRICTION_REGISTER_OP
    sqeOp* {.importc: "sqe_op".}: uint8 ##  IORING_RESTRICTION_SQE_OP
    sqeFlags* {.importc: "sqe_flags".}: uint8
    ##  IORING_RESTRICTION_SQE_FLAGS_*
    resv* {.importc: "resv".}: uint8
    resv2* {.importc: "resv2".}: array[3, uint32]
  
  RestrictionOp* {.size: sizeof(uint16).} = enum
    RESTRICTION_REGISTER_OP ## Allow an io_uring_register(2) opcode
    RESTRICTION_SQE_OP ## Allow an sqe opcode
    RESTRICTION_SQE_FLAGS_ALLOWED ## Allow sqe flags
    RESTRICTION_SQE_FLAGS_REQUIRED ## Require sqe flags (these flags must be set on each submission)
    RESTRICTION_LAST

  Buf* {.importc: "struct io_uring_buf", header: "<linux/io_uring.h>", bycopy.} = object
    `addr`* {.importc: "addr".}: uint64
    len* {.importc: "len".}: uint32
    bid* {.importc: "bid".}: uint16
    resv* {.importc: "resv".}: uint16

  BufRing* {.importc: "struct io_uring_buf_ring", header: "<linux/io_uring.h>", bycopy.} = object
    resv1* {.importc: "resv1".}: uint64
    resv2* {.importc: "resv2".}: uint32
    resv3* {.importc: "resv3".}: uint16
    tail* {.importc: "tail".}: uint16
    bufs* {.importc: "bufs".}: UncheckedArray[Buf]


type
  BufReg* {.importc: "struct io_uring_buf_reg", header: "<linux/io_uring.h>", bycopy.} = object ##  argument for IORING_(UN)REGISTER_PBUF_RING
    ringAddr* {.importc: "ring_addr".}: uint64
    ringEntries* {.importc: "ring_entries".}: uint32
    bgid* {.importc: "bgid".}: uint16
    pad* {.importc: "pad".}: uint16
    resv* {.importc: "resv".}: array[3, uint64]

type
  GeteventsArg* {.importc: "struct io_uring_getevents_arg", header: "<linux/io_uring.h>",
                        bycopy.} = object
    sigmask* {.importc: "sigmask".}: uint64
    sigmaskSz* {.importc: "sigmask_sz".}: uint32
    pad* {.importc: "pad".}: uint32
    ts* {.importc: "ts".}: uint64


type
  SyncCancelReg* {.importc: "struct io_uring_sync_cancel_reg",
                         header: "<linux/io_uring.h>", bycopy.} = object ##
                                                            ##  Argument for
                                                            ## IORING_REGISTER_SYNC_CANCEL
                                                            ##
    `addr`* {.importc: "addr".}: uint64
    fd* {.importc: "fd".}: int32
    flags* {.importc: "flags".}: uint32
    timeout* {.importc: "timeout".}: Timespec
    pad* {.importc: "pad".}: array[4, uint64]


type
  FileIndexRange* {.importc: "struct io_uring_file_index_range",
                          header: "<linux/io_uring.h>", bycopy.} = object ##
                                                             ##  Argument for
                                                             ## IORING_REGISTER_FILE_ALLOC_RANGE
                                                             ##  The range is specified as [off, off + len)
                                                             ##
    off* {.importc: "off".}: uint32
    len* {.importc: "len".}: uint32
    resv* {.importc: "resv".}: uint64

  RecvmsgOut* {.importc: "struct io_uring_recvmsg_out", header: "<linux/io_uring.h>", bycopy.} = object
    namelen* {.importc: "namelen".}: uint32
    controllen* {.importc: "controllen".}: uint32
    payloadlen* {.importc: "payloadlen".}: uint32
    flags* {.importc: "flags".}: uint32