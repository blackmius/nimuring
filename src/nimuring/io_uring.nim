import types, posix

##  SPDX-License-Identifier: (GPL-2.0 WITH Linux-syscall-note) OR MIT
##
##  Header file for the io_uring interface.
##
##  Copyright (C) 2019 Jens Axboe
##  Copyright (C) 2019 Christoph Hellwig
##

##
##  this file is shared with liburing and that has to autodetect
##  if linux/time_types.h is available or not, it can
##  define UAPI_LINUX_IO_URING_H_SKIP_LINUX_TIME_TYPES_H
##  if linux/time_types.h is not available
##
type
  KernelRwfT* {.importc: "__kernel_rwf_t", header: "<linux/fs.h>".} = int

  IoUringSqe* {.importc: "struct io_uring_sqe", header: "<liburing.h>", bycopy.} = object
    opcode* {.importc: "opcode".}: U8 ##  type of operation for this sqe
    flags* {.importc: "flags".}: U8 ##  IOSQE_ flags
    ioprio* {.importc: "ioprio".}: U16 ##  ioprio for the request
    fd* {.importc: "fd".}: S32   ##  file descriptor to do IO on
    off* {.importc: "off".}: U64 ##  offset into file
    addr2* {.importc: "addr2".}: U64
    cmdOp* {.importc: "cmd_op".}: U32
    pad1* {.importc: "__pad1".}: U32
    `addr`* {.importc: "addr".}: U64 ##  pointer to buffer or iovecs
    spliceOffIn* {.importc: "splice_off_in".}: U64
    len* {.importc: "len".}: U32 ##  buffer size or number of iovecs
    rwFlags* {.importc: "rw_flags".}: KernelRwfT
    fsyncFlags* {.importc: "fsync_flags".}: U32
    pollEvents* {.importc: "poll_events".}: U16 ##  compatibility
    poll32Events* {.importc: "poll32_events".}: U32 ##  word-reversed for BE
    syncRangeFlags* {.importc: "sync_range_flags".}: U32
    msgFlags* {.importc: "msg_flags".}: U32
    timeoutFlags* {.importc: "timeout_flags".}: U32
    acceptFlags* {.importc: "accept_flags".}: U32
    cancelFlags* {.importc: "cancel_flags".}: U32
    openFlags* {.importc: "open_flags".}: U32
    statxFlags* {.importc: "statx_flags".}: U32
    fadviseAdvice* {.importc: "fadvise_advice".}: U32
    spliceFlags* {.importc: "splice_flags".}: U32
    renameFlags* {.importc: "rename_flags".}: U32
    unlinkFlags* {.importc: "unlink_flags".}: U32
    hardlinkFlags* {.importc: "hardlink_flags".}: U32
    xattrFlags* {.importc: "xattr_flags".}: U32
    msgRingFlags* {.importc: "msg_ring_flags".}: U32
    uringCmdFlags* {.importc: "uring_cmd_flags".}: U32
    userData* {.importc: "user_data".}: U64 ##  data to be passed back at completion time
    bufIndex* {.importc: "buf_index".}: U16 ##  index into fixed buffers, if used
    bufGroup* {.importc: "buf_group".}: U16 ##  for grouped buffer selection
    personality* {.importc: "personality".}: U16
    spliceFdIn* {.importc: "splice_fd_in".}: S32
    fileIndex* {.importc: "file_index".}: U32
    addrLen* {.importc: "addr_len".}: U16
    pad3* {.importc: "__pad3".}: array[1, U16]
    addr3* {.importc: "addr3".}: U64
    pad2* {.importc: "__pad2".}: array[1, U64]
    cmd* {.importc: "cmd".}: UncheckedArray[U8]


##
##  If sqe->file_index is set to this for opcodes that instantiate a new
##  direct descriptor (like openat/openat2/accept), then io_uring will allocate
##  an available direct descriptor instead of having the application pass one
##  in. The picked direct descriptor will be returned in cqe->res, or -ENFILE
##  if the space is full.
##

var IORING_FILE_INDEX_ALLOC* {.importc: "IORING_FILE_INDEX_ALLOC",
                             header: "<liburing.h>".}: int
const
  IOSQE_FIXED_FILE_BIT* = 0
  IOSQE_IO_DRAIN_BIT* = 1
  IOSQE_IO_LINK_BIT* = 2
  IOSQE_IO_HARDLINK_BIT* = 3
  IOSQE_ASYNC_BIT* = 4
  IOSQE_BUFFER_SELECT_BIT* = 5
  IOSQE_CQE_SKIP_SUCCESS_BIT* = 6

##
##  sqe->flags
##
##  use fixed fileset

var IOSQE_FIXED_FILE* {.importc: "IOSQE_FIXED_FILE", header: "<liburing.h>".}: int
##  issue after inflight IO

var IOSQE_IO_DRAIN* {.importc: "IOSQE_IO_DRAIN", header: "<liburing.h>".}: int
##  links next sqe

var IOSQE_IO_LINK* {.importc: "IOSQE_IO_LINK", header: "<liburing.h>".}: int
##  like LINK, but stronger

var IOSQE_IO_HARDLINK* {.importc: "IOSQE_IO_HARDLINK", header: "<liburing.h>".}: int
##  always go async

var IOSQE_ASYNC* {.importc: "IOSQE_ASYNC", header: "<liburing.h>".}: int
##  select buffer from sqe->buf_group

var IOSQE_BUFFER_SELECT* {.importc: "IOSQE_BUFFER_SELECT", header: "<liburing.h>".}: int
##  don't post CQE if request succeeded

var IOSQE_CQE_SKIP_SUCCESS* {.importc: "IOSQE_CQE_SKIP_SUCCESS",
                            header: "<liburing.h>".}: int
##
##  io_uring_setup() flags
##

var IORING_SETUP_IOPOLL* {.importc: "IORING_SETUP_IOPOLL", header: "<liburing.h>".}: int
##
##  Cooperative task running. When requests complete, they often require
##  forcing the submitter to transition to the kernel to complete. If this
##  flag is set, work will be done when the task transitions anyway, rather
##  than force an inter-processor interrupt reschedule. This avoids interrupting
##  a task running in userspace, and saves an IPI.
##

var IORING_SETUP_COOP_TASKRUN* {.importc: "IORING_SETUP_COOP_TASKRUN",
                               header: "<liburing.h>".}: int
##
##  If COOP_TASKRUN is set, get notified if task work is available for
##  running and a kernel transition would be needed to run it. This sets
##  IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
##

var IORING_SETUP_TASKRUN_FLAG* {.importc: "IORING_SETUP_TASKRUN_FLAG",
                               header: "<liburing.h>".}: int
##
##  Only one task is allowed to submit requests
##

var IORING_SETUP_SINGLE_ISSUER* {.importc: "IORING_SETUP_SINGLE_ISSUER",
                                header: "<liburing.h>".}: int
##
##  Defer running task work to get events.
##  Rather than running bits of task work whenever the task transitions
##  try to do it just before it is needed.
##

var IORING_SETUP_DEFER_TASKRUN* {.importc: "IORING_SETUP_DEFER_TASKRUN",
                                header: "<liburing.h>".}: int
type
  IoUringOp* {.size: sizeof(cint).} = enum
    IORING_OP_NOP, IORING_OP_READV, IORING_OP_WRITEV, IORING_OP_FSYNC,
    IORING_OP_READ_FIXED, IORING_OP_WRITE_FIXED, IORING_OP_POLL_ADD,
    IORING_OP_POLL_REMOVE, IORING_OP_SYNC_FILE_RANGE, IORING_OP_SENDMSG,
    IORING_OP_RECVMSG, IORING_OP_TIMEOUT, IORING_OP_TIMEOUT_REMOVE,
    IORING_OP_ACCEPT, IORING_OP_ASYNC_CANCEL, IORING_OP_LINK_TIMEOUT,
    IORING_OP_CONNECT, IORING_OP_FALLOCATE, IORING_OP_OPENAT, IORING_OP_CLOSE,
    IORING_OP_FILES_UPDATE, IORING_OP_STATX, IORING_OP_READ, IORING_OP_WRITE,
    IORING_OP_FADVISE, IORING_OP_MADVISE, IORING_OP_SEND, IORING_OP_RECV,
    IORING_OP_OPENAT2, IORING_OP_EPOLL_CTL, IORING_OP_SPLICE,
    IORING_OP_PROVIDE_BUFFERS, IORING_OP_REMOVE_BUFFERS, IORING_OP_TEE,
    IORING_OP_SHUTDOWN, IORING_OP_RENAMEAT, IORING_OP_UNLINKAT, IORING_OP_MKDIRAT,
    IORING_OP_SYMLINKAT, IORING_OP_LINKAT, IORING_OP_MSG_RING, IORING_OP_FSETXATTR,
    IORING_OP_SETXATTR, IORING_OP_FGETXATTR, IORING_OP_GETXATTR, IORING_OP_SOCKET,
    IORING_OP_URING_CMD, IORING_OP_SEND_ZC, IORING_OP_SENDMSG_ZC, ##  this goes last, obviously
    IORING_OP_LAST


##
##  sqe->uring_cmd_flags
##  IORING_URING_CMD_FIXED	use registered buffer; pass this flag
## 				along with setting sqe->buf_index.
##

var IORING_URING_CMD_FIXED* {.importc: "IORING_URING_CMD_FIXED",
                            header: "<liburing.h>".}: int
##
##  sqe->fsync_flags
##

var IORING_FSYNC_DATASYNC* {.importc: "IORING_FSYNC_DATASYNC", header: "<liburing.h>".}: int
##
##  sqe->timeout_flags
##

var IORING_TIMEOUT_ABS* {.importc: "IORING_TIMEOUT_ABS", header: "<liburing.h>".}: int
##
##  sqe->splice_flags
##  extends splice(2) flags
##

var SPLICE_F_FD_IN_FIXED* {.importc: "SPLICE_F_FD_IN_FIXED", header: "<liburing.h>".}: int
##
##  POLL_ADD flags. Note that since sqe->poll_events is the flag space, the
##  command flags for POLL_ADD are stored in sqe->len.
##
##  IORING_POLL_ADD_MULTI	Multishot poll. Sets IORING_CQE_F_MORE if
## 				the poll handler will continue to report
## 				CQEs on behalf of the same SQE.
##
##  IORING_POLL_UPDATE		Update existing poll request, matching
## 				sqe->addr as the old user_data field.
##
##  IORING_POLL_LEVEL		Level triggered poll.
##

var IORING_POLL_ADD_MULTI* {.importc: "IORING_POLL_ADD_MULTI", header: "<liburing.h>".}: int
##
##  ASYNC_CANCEL flags.
##
##  IORING_ASYNC_CANCEL_ALL	Cancel all requests that match the given key
##  IORING_ASYNC_CANCEL_FD	Key off 'fd' for cancelation rather than the
## 				request 'user_data'
##  IORING_ASYNC_CANCEL_ANY	Match any request
##  IORING_ASYNC_CANCEL_FD_FIXED	'fd' passed in is a fixed descriptor
##

var IORING_ASYNC_CANCEL_ALL* {.importc: "IORING_ASYNC_CANCEL_ALL",
                             header: "<liburing.h>".}: int
##
##  send/sendmsg and recv/recvmsg flags (sqe->ioprio)
##
##  IORING_RECVSEND_POLL_FIRST	If set, instead of first attempting to send
## 				or receive and arm poll if that yields an
## 				-EAGAIN result, arm poll upfront and skip
## 				the initial transfer attempt.
##
##  IORING_RECV_MULTISHOT	Multishot recv. Sets IORING_CQE_F_MORE if
## 				the handler will continue to report
## 				CQEs on behalf of the same SQE.
##
##  IORING_RECVSEND_FIXED_BUF	Use registered buffers, the index is stored in
## 				the buf_index field.
##
##  IORING_SEND_ZC_REPORT_USAGE
## 				If set, SEND[MSG]_ZC should report
## 				the zerocopy usage in cqe.res
## 				for the IORING_CQE_F_NOTIF cqe.
## 				0 is reported if zerocopy was actually possible.
## 				IORING_NOTIF_USAGE_ZC_COPIED if data was copied
## 				(at least partially).
##

var IORING_RECVSEND_POLL_FIRST* {.importc: "IORING_RECVSEND_POLL_FIRST",
                                header: "<liburing.h>".}: int
##
##  cqe.res for IORING_CQE_F_NOTIF if
##  IORING_SEND_ZC_REPORT_USAGE was requested
##
##  It should be treated as a flag, all other
##  bits of cqe.res should be treated as reserved!
##

var IORING_NOTIF_USAGE_ZC_COPIED* {.importc: "IORING_NOTIF_USAGE_ZC_COPIED",
                                  header: "<liburing.h>".}: int
##
##  accept flags stored in sqe->ioprio
##

var IORING_ACCEPT_MULTISHOT* {.importc: "IORING_ACCEPT_MULTISHOT",
                             header: "<liburing.h>".}: int
const
  IORING_MSG_DATA* = 0 ##
                    ##  IORING_OP_MSG_RING command types, stored in sqe->addr
                    ##
  IORING_MSG_SEND_FD* = 1       ##  send a registered fd to another ring

##
##  IORING_OP_MSG_RING flags (sqe->msg_ring_flags)
##
##  IORING_MSG_RING_CQE_SKIP	Don't post a CQE to the target ring. Not
## 				applicable for IORING_MSG_DATA, obviously.
##

var IORING_MSG_RING_CQE_SKIP* {.importc: "IORING_MSG_RING_CQE_SKIP",
                              header: "<liburing.h>".}: int
##  Pass through the flags from sqe->file_index to cqe->flags

var IORING_MSG_RING_FLAGS_PASS* {.importc: "IORING_MSG_RING_FLAGS_PASS",
                                header: "<liburing.h>".}: int
type
  IoUringCqe* {.importc: "struct io_uring_cqe", header: "<liburing.h>", bycopy.} = object ##
                                                                         ##  IO
                                                                         ## completion data
                                                                         ## structure
                                                                         ## (Completion Queue Entry)
                                                                         ##
    userData* {.importc: "user_data".}: U64 ##  sqe->data submission passed back
    res* {.importc: "res".}: S32 ##  result code for this event
    flags* {.importc: "flags".}: U32
    bigCqe* {.importc: "big_cqe".}: ref U64 ##
                                       ##  If the ring is initialized with IORING_SETUP_CQE32, then this field
                                       ##  contains 16-bytes of padding, doubling the size of the CQE.
                                       ##


##
##  cqe->flags
##
##  IORING_CQE_F_BUFFER	If set, the upper 16 bits are the buffer ID
##  IORING_CQE_F_MORE	If set, parent SQE will generate more CQE entries
##  IORING_CQE_F_SOCK_NONEMPTY	If set, more data to read after socket recv
##  IORING_CQE_F_NOTIF	Set for notification CQEs. Can be used to distinct
##  			them from sends.
##

const
  IORING_CQE_F_BUFFER* = (1'u shl 0)
  IORING_CQE_F_MORE* = (1'u shl 1)
  IORING_CQE_F_SOCK_NONEMPTY* = (1'u shl 2)
  IORING_CQE_F_NOTIF* = (1'u shl 3)
  IORING_CQE_BUFFER_SHIFT* = 16

const
  IORING_SQ_NEED_WAKEUP* = (1'u shl 0) ##  needs io_uring_enter wakeup
  IORING_SQ_CQ_OVERFLOW* = (1'u shl 1) ##  CQ ring is overflown
  IORING_SQ_TASKRUN* = (1'u shl 2) ##  task should enter the kernel

type
  IoSqringOffsets* {.importc: "struct io_sqring_offsets", header: "<liburing.h>", bycopy.} = object ##
                                                                                   ##
                                                                                   ## Filled
                                                                                   ## with
                                                                                   ## the
                                                                                   ## offset
                                                                                   ## for
                                                                                   ## mmap(2)
                                                                                   ##
    head* {.importc: "head".}: U32
    tail* {.importc: "tail".}: U32
    ringMask* {.importc: "ring_mask".}: U32
    ringEntries* {.importc: "ring_entries".}: U32
    flags* {.importc: "flags".}: U32
    dropped* {.importc: "dropped".}: U32
    array* {.importc: "array".}: U32
    resv1* {.importc: "resv1".}: U32
    resv2* {.importc: "resv2".}: U64


##
##  sq_ring->flags
##

type
  IoCqringOffsets* {.importc: "struct io_cqring_offsets", header: "<liburing.h>", bycopy.} = object
    head* {.importc: "head".}: U32
    tail* {.importc: "tail".}: U32
    ringMask* {.importc: "ring_mask".}: U32
    ringEntries* {.importc: "ring_entries".}: U32
    overflow* {.importc: "overflow".}: U32
    cqes* {.importc: "cqes".}: U32
    flags* {.importc: "flags".}: U32
    resv1* {.importc: "resv1".}: U32
    resv2* {.importc: "resv2".}: U64


##
##  cq_ring->flags
##
##  disable eventfd notifications

const
  IORING_CQ_EVENTFD_DISABLED* = (1'u shl 0)
##
##  io_uring_enter(2) flags
##

const
  IORING_ENTER_GETEVENTS* = (1'u shl 0)
  IORING_ENTER_SQ_WAKEUP* = (1'u shl 1)
  IORING_ENTER_SQ_WAIT* = (1'u shl 2)
  IORING_ENTER_EXT_ARG* = (1'u shl 3)
  IORING_ENTER_REGISTERED_RING* = (1'u shl 4)

type
  IoUringParams* {.importc: "struct io_uring_params", header: "<liburing.h>", bycopy.} = object ##
                                                                               ##
                                                                               ## Passed
                                                                               ## in
                                                                               ## for
                                                                               ## io_uring_setup(2).
                                                                               ## Copied
                                                                               ## back
                                                                               ## with
                                                                               ## updated
                                                                               ## info
                                                                               ## on
                                                                               ## success
                                                                               ##
    sqEntries* {.importc: "sq_entries".}: U32
    cqEntries* {.importc: "cq_entries".}: U32
    flags* {.importc: "flags".}: U32
    sqThreadCpu* {.importc: "sq_thread_cpu".}: U32
    sqThreadIdle* {.importc: "sq_thread_idle".}: U32
    features* {.importc: "features".}: U32
    wqFd* {.importc: "wq_fd".}: U32
    resv* {.importc: "resv".}: array[3, U32]
    sqOff* {.importc: "sq_off".}: IoSqringOffsets
    cqOff* {.importc: "cq_off".}: IoCqringOffsets


##
##  io_uring_params->features flags
##

const
  IORING_FEAT_SINGLE_MMAP* = (1'u shl 0)
  IORING_FEAT_NODROP* = (1'u shl 1)
  IORING_FEAT_SUBMIT_STABLE* = (1'u shl 2)
  IORING_FEAT_RW_CUR_POS* = (1'u shl 3)
  IORING_FEAT_CUR_PERSONALITY* = (1'u shl 4)
  IORING_FEAT_FAST_POLL* = (1'u shl 5)
  IORING_FEAT_POLL_32BITS* = (1'u shl 6)
  IORING_FEAT_SQPOLL_NONFIXED* = (1'u shl 7)
  IORING_FEAT_EXT_ARG* = (1'u shl 8)
  IORING_FEAT_NATIVE_WORKERS* = (1'u shl 9)
  IORING_FEAT_RSRC_TAGS* = (1'u shl 10)
  IORING_FEAT_CQE_SKIP* = (1'u shl 11)
  IORING_FEAT_LINKED_FILE* = (1'u shl 12)
  IORING_FEAT_REG_REG_RING* = (1'u shl 13)

const
  IORING_REGISTER_BUFFERS* = 0  ##
                            ##  io_uring_register(2) opcodes and arguments
                            ##
  IORING_UNREGISTER_BUFFERS* = 1
  IORING_REGISTER_FILES* = 2
  IORING_UNREGISTER_FILES* = 3
  IORING_REGISTER_EVENTFD* = 4
  IORING_UNREGISTER_EVENTFD* = 5
  IORING_REGISTER_FILES_UPDATE* = 6
  IORING_REGISTER_EVENTFD_ASYNC* = 7
  IORING_REGISTER_PROBE* = 8
  IORING_REGISTER_PERSONALITY* = 9
  IORING_UNREGISTER_PERSONALITY* = 10
  IORING_REGISTER_RESTRICTIONS* = 11
  IORING_REGISTER_ENABLE_RINGS* = 12 ##  extended with tagging
  IORING_REGISTER_FILES2* = 13
  IORING_REGISTER_FILES_UPDATE2* = 14
  IORING_REGISTER_BUFFERS2* = 15
  IORING_REGISTER_BUFFERS_UPDATE* = 16 ##  set/clear io-wq thread affinities
  IORING_REGISTER_IOWQ_AFF* = 17
  IORING_UNREGISTER_IOWQ_AFF* = 18 ##  set/get max number of io-wq workers
  IORING_REGISTER_IOWQ_MAX_WORKERS* = 19 ##  register/unregister io_uring fd with the ring
  IORING_REGISTER_RING_FDS* = 20
  IORING_UNREGISTER_RING_FDS* = 21 ##  register ring based provide buffer group
  IORING_REGISTER_PBUF_RING* = 22
  IORING_UNREGISTER_PBUF_RING* = 23 ##  sync cancelation API
  IORING_REGISTER_SYNC_CANCEL* = 24 ##  register a range of fixed file slots for automatic slot allocation
  IORING_REGISTER_FILE_ALLOC_RANGE* = 25 ##  this goes last
  IORING_REGISTER_LAST* = 26    ##  flag added to the opcode to use a registered ring fd
  IORING_REGISTER_USE_REGISTERED_RING* = 1'u shl 31

const
  IO_WQ_BOUND* = 0              ##  io-wq worker categories
  IO_WQ_UNBOUND* = 1

type
  IoUringFilesUpdate* {.importc: "struct io_uring_files_update", header: "<liburing.h>",
                       bycopy.} = object ##  deprecated, see struct io_uring_rsrc_update
    offset* {.importc: "offset".}: U32
    resv* {.importc: "resv".}: U32
    fds* {.importc: "fds", align: 64.}: U64 ##  __s32 *


##
##  Register a fully sparse file space, rather than pass in an array of all
##  -1 file descriptors.
##

var IORING_RSRC_REGISTER_SPARSE* {.importc: "IORING_RSRC_REGISTER_SPARSE",
                                 header: "<liburing.h>".}: int
type
  IoUringRsrcRegister* {.importc: "struct io_uring_rsrc_register", header: "<liburing.h>",
                        bycopy.} = object
    nr* {.importc: "nr".}: U32
    flags* {.importc: "flags".}: U32
    resv2* {.importc: "resv2".}: U64
    data* {.importc: "data", align: 64.}: U64
    tags* {.importc: "tags", align: 64.}: U64

  IoUringRsrcUpdate* {.importc: "struct io_uring_rsrc_update", header: "<liburing.h>", bycopy.} = object
    offset* {.importc: "offset".}: U32
    resv* {.importc: "resv".}: U32
    data* {.importc: "data", align: 64.}: U64

  IoUringRsrcUpdate2* {.importc: "struct io_uring_rsrc_update2", header: "<liburing.h>",
                       bycopy.} = object
    offset* {.importc: "offset".}: U32
    resv* {.importc: "resv".}: U32
    data* {.importc: "data", align: 64.}: U64
    tags* {.importc: "tags", align: 64.}: U64
    nr* {.importc: "nr".}: U32
    resv2* {.importc: "resv2".}: U32

  IoUringNotificationSlot* {.importc: "struct io_uring_notification_slot",
                            header: "<liburing.h>", bycopy.} = object
    tag* {.importc: "tag".}: U64
    resv* {.importc: "resv".}: array[3, U64]

  IoUringNotificationRegister* {.importc: "struct io_uring_notification_register",
                                header: "<liburing.h>", bycopy.} = object
    nrSlots* {.importc: "nr_slots".}: U32
    resv* {.importc: "resv".}: U32
    resv2* {.importc: "resv2".}: U64
    data* {.importc: "data".}: U64
    resv3* {.importc: "resv3".}: U64


##  Skip updating fd indexes set to this value in the fd table

var IORING_REGISTER_FILES_SKIP* {.importc: "IORING_REGISTER_FILES_SKIP",
                                header: "<liburing.h>".}: int
type
  IoUringProbeOp* {.importc: "struct io_uring_probe_op", header: "<liburing.h>", bycopy.} = object
    op* {.importc: "op".}: U8
    resv* {.importc: "resv".}: U8
    flags* {.importc: "flags".}: U16 ##  IO_URING_OP_* flags
    resv2* {.importc: "resv2".}: U32

  IoUringProbe* {.importc: "struct io_uring_probe", header: "<liburing.h>", bycopy.} = object
    lastOp* {.importc: "last_op".}: U8 ##  last opcode supported
    opsLen* {.importc: "ops_len".}: U8 ##  length of ops[] array below
    resv* {.importc: "resv".}: U16
    resv2* {.importc: "resv2".}: array[3, U32]
    ops* {.importc: "ops".}: ref IoUringProbeOp

  IoUringRestriction* {.importc: "struct io_uring_restriction", header: "<liburing.h>", bycopy.} = object
    opcode* {.importc: "opcode".}: U16
    registerOp* {.importc: "register_op".}: U8 ##  IORING_RESTRICTION_REGISTER_OP
    sqeOp* {.importc: "sqe_op".}: U8 ##  IORING_RESTRICTION_SQE_OP
    sqeFlags* {.importc: "sqe_flags".}: U8
    ##  IORING_RESTRICTION_SQE_FLAGS_*
    resv* {.importc: "resv".}: U8
    resv2* {.importc: "resv2".}: array[3, U32]

  IoUringBuf* {.importc: "struct io_uring_buf", header: "<liburing.h>", bycopy.} = object
    `addr`* {.importc: "addr".}: U64
    len* {.importc: "len".}: U32
    bid* {.importc: "bid".}: U16
    resv* {.importc: "resv".}: U16

  IoUringBufRing* {.importc: "struct io_uring_buf_ring", header: "<liburing.h>", bycopy.} = object
    resv1* {.importc: "resv1".}: U64
    resv2* {.importc: "resv2".}: U32
    resv3* {.importc: "resv3".}: U16
    tail* {.importc: "tail".}: U16
    bufs* {.importc: "bufs".}: UncheckedArray[IoUringBuf]


type
  IoUringBufReg* {.importc: "struct io_uring_buf_reg", header: "<liburing.h>", bycopy.} = object ##  argument for IORING_(UN)REGISTER_PBUF_RING
    ringAddr* {.importc: "ring_addr".}: U64
    ringEntries* {.importc: "ring_entries".}: U32
    bgid* {.importc: "bgid".}: U16
    pad* {.importc: "pad".}: U16
    resv* {.importc: "resv".}: array[3, U64]


const                         ##  Allow an io_uring_register(2) opcode
  IORING_RESTRICTION_REGISTER_OP* = 0 ##
                                   ##  io_uring_restriction->opcode values
                                   ##
  IORING_RESTRICTION_SQE_OP* = 1 ##  Allow sqe flags
  IORING_RESTRICTION_SQE_FLAGS_ALLOWED* = 2 ##  Require sqe flags (these flags must be set on each submission)
  IORING_RESTRICTION_SQE_FLAGS_REQUIRED* = 3
  IORING_RESTRICTION_LAST* = 4

type
  IoUringGeteventsArg* {.importc: "struct io_uring_getevents_arg", header: "<liburing.h>",
                        bycopy.} = object
    sigmask* {.importc: "sigmask".}: U64
    sigmaskSz* {.importc: "sigmask_sz".}: U32
    pad* {.importc: "pad".}: U32
    ts* {.importc: "ts".}: U64


type
  IoUringSyncCancelReg* {.importc: "struct io_uring_sync_cancel_reg",
                         header: "<liburing.h>", bycopy.} = object ##
                                                            ##  Argument for
                                                            ## IORING_REGISTER_SYNC_CANCEL
                                                            ##
    `addr`* {.importc: "addr".}: U64
    fd* {.importc: "fd".}: S32
    flags* {.importc: "flags".}: U32
    timeout* {.importc: "timeout".}: KernelTimespec
    pad* {.importc: "pad".}: array[4, U64]


type
  IoUringFileIndexRange* {.importc: "struct io_uring_file_index_range",
                          header: "<liburing.h>", bycopy.} = object ##
                                                             ##  Argument for
                                                             ## IORING_REGISTER_FILE_ALLOC_RANGE
                                                             ##  The range is specified as [off, off + len)
                                                             ##
    off* {.importc: "off".}: U32
    len* {.importc: "len".}: U32
    resv* {.importc: "resv".}: U64

  IoUringRecvmsgOut* {.importc: "struct io_uring_recvmsg_out", header: "<liburing.h>", bycopy.} = object
    namelen* {.importc: "namelen".}: U32
    controllen* {.importc: "controllen".}: U32
    payloadlen* {.importc: "payloadlen".}: U32
    flags* {.importc: "flags".}: U32

proc syscall(arg: cint): cint {.importc, header: "<unistd.h>", varargs.}
var
  SYS_io_uring_setup {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_enter {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_enter2 {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_register {.importc, header: "<sys/syscall.h>".}: cint

template io_uring_setup*(entries: cint, params: ref IoUringParams): cint =
  syscall(SYS_io_uring_setup, entries, params)

template io_uring_enter*(fd: cint, toSubmit: cint, minComplete: cint,
                         flags: cint, sig: ref Sigset): cint =
  syscall(SYS_io_uring_enter, fd, toSubmit, minComplete, flags, sig)

template io_uring_enter2*(fd: cint, toSubmit: cint, minComplete: cint,
                         flags: cint, sig: ref Sigset, sz: cint): cint =
  syscall(SYS_io_uring_enter2, fd, toSubmit, minComplete, flags, sig, sz)

template io_uring_register*(fd: cint, op: cint, arg: pointer, nr_args: cint): cint =
  syscall(SYS_io_uring_register, fd, op, arg, nr_args)
