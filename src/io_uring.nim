import posix
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

when not defined(UAPI_LINUX_IO_URING_H_SKIP_LINUX_TIME_TYPES_H):
  discard
##
##  IO submission data structure (Submission Queue Entry)
##

type
  INNER_C_STRUCT_io_uring_1* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy.} = object
    cmd_op* {.importc: "cmd_op".}: uint32
    pad1* {.importc: "__pad1".}: uint32

  INNER_C_UNION_io_uring_0* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    off* {.importc: "off".}: uint64
    ##  offset into file
    addr2* {.importc: "addr2".}: uint64
    ano_io_uring_2* {.importc: "ano_io_uring_2".}: INNER_C_STRUCT_io_uring_1

  INNER_C_UNION_io_uring_4* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    `addr`* {.importc: "addr".}: uint64
    ##  pointer to buffer or iovecs
    splice_off_in* {.importc: "splice_off_in".}: uint64
  
  KernelRwf* {.importc: "__kernel_rwf_t", header: "<linux/fs.h>".} = int

  INNER_C_UNION_io_uring_6* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    rw_flags* {.importc: "rw_flags".}: KernelRwf
    fsync_flags* {.importc: "fsync_flags".}: uint32
    poll_events* {.importc: "poll_events".}: uint16
    ##  compatibility
    poll32_events* {.importc: "poll32_events".}: uint32
    ##  word-reversed for BE
    sync_range_flags* {.importc: "sync_range_flags".}: uint32
    msg_flags* {.importc: "msg_flags".}: uint32
    timeout_flags* {.importc: "timeout_flags".}: uint32
    accept_flags* {.importc: "accept_flags".}: uint32
    cancel_flags* {.importc: "cancel_flags".}: uint32
    open_flags* {.importc: "open_flags".}: uint32
    statx_flags* {.importc: "statx_flags".}: uint32
    fadvise_advice* {.importc: "fadvise_advice".}: uint32
    splice_flags* {.importc: "splice_flags".}: uint32
    rename_flags* {.importc: "rename_flags".}: uint32
    unlink_flags* {.importc: "unlink_flags".}: uint32
    hardlink_flags* {.importc: "hardlink_flags".}: uint32
    xattr_flags* {.importc: "xattr_flags".}: uint32
    msg_ring_flags* {.importc: "msg_ring_flags".}: uint32
    uring_cmd_flags* {.importc: "uring_cmd_flags".}: uint32

  INNER_C_UNION_io_uring_8* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    ##  index into fixed buffers, if used
    buf_index* {.importc: "buf_index".}: uint16
    ##  for grouped buffer selection
    buf_group* {.importc: "buf_group".}: uint16

  INNER_C_STRUCT_io_uring_11* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy.} = object
    addr_len* {.importc: "addr_len".}: uint16
    pad3* {.importc: "__pad3".}: array[1, uint16]

  INNER_C_UNION_io_uring_10* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    splice_fd_in* {.importc: "splice_fd_in".}: int32
    file_index* {.importc: "file_index".}: uint32
    ano_io_uring_12* {.importc: "ano_io_uring_12".}: INNER_C_STRUCT_io_uring_11

  INNER_C_STRUCT_io_uring_15* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy.} = object
    addr3* {.importc: "addr3".}: uint64
    pad2* {.importc: "__pad2".}: array[1, uint64]

  INNER_C_UNION_io_uring_14* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    ano_io_uring_16* {.importc: "ano_io_uring_16".}: INNER_C_STRUCT_io_uring_15
    cmd* {.importc: "cmd".}: UncheckedArray[uint8]

  io_uring_sqe* {.importc: "struct io_uring_sqe", header: "<linux/io_uring.h>", bycopy.} = object
    opcode* {.importc: "opcode".}: uint8
    ##  type of operation for this sqe
    flags* {.importc: "flags".}: uint8
    ##  IOSQE_ flags
    ioprio* {.importc: "ioprio".}: uint16
    ##  ioprio for the request
    fd* {.importc: "fd".}: int32
    ##  file descriptor to do IO on
    ano_io_uring_3* {.importc: "ano_io_uring_3".}: INNER_C_UNION_io_uring_0
    ano_io_uring_5* {.importc: "ano_io_uring_5".}: INNER_C_UNION_io_uring_4
    len* {.importc: "len".}: uint32
    ##  buffer size or number of iovecs
    ano_io_uring_7* {.importc: "ano_io_uring_7".}: INNER_C_UNION_io_uring_6
    user_data* {.importc: "user_data".}: uint64
    ##  data to be passed back at completion time
    ##  pack this to avoid bogus arm OABI complaints
    ano_io_uring_9* {.importc: "ano_io_uring_9".}: INNER_C_UNION_io_uring_8
    personality* {.importc: "personality".}: uint16
    ano_io_uring_13* {.importc: "ano_io_uring_13".}: INNER_C_UNION_io_uring_10
    ano_io_uring_17* {.importc: "ano_io_uring_17".}: INNER_C_UNION_io_uring_14


##
##  If sqe->file_index is set to this for opcodes that instantiate a new
##  direct descriptor (like openat/openat2/accept), then io_uring will allocate
##  an available direct descriptor instead of having the application pass one
##  in. The picked direct descriptor will be returned in cqe->res, or -ENFILE
##  if the space is full.
##

const
  IORING_FILE_INDEX_ALLOC* = (not 0'u)

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

const
  IOSQE_FIXED_FILE* = (1'u shl IOSQE_FIXED_FILE_BIT)

##  issue after inflight IO

const
  IOSQE_IO_DRAIN* = (1'u shl IOSQE_IO_DRAIN_BIT)

##  links next sqe

const
  IOSQE_IO_LINK* = (1'u shl IOSQE_IO_LINK_BIT)

##  like LINK, but stronger

const
  IOSQE_IO_HARDLINK* = (1'u shl IOSQE_IO_HARDLINK_BIT)

##  always go async

const
  IOSQE_ASYNC* = (1'u shl IOSQE_ASYNC_BIT)

##  select buffer from sqe->buf_group

const
  IOSQE_BUFFER_SELECT* = (1'u shl IOSQE_BUFFER_SELECT_BIT)

##  don't post CQE if request succeeded

const
  IOSQE_CQE_SKIP_SUCCESS* = (1'u shl IOSQE_CQE_SKIP_SUCCESS_BIT)

##
##  io_uring_setup() flags
##

const
  IORING_SETUP_IOPOLL* = (1'u shl 0) ##  io_context is polled
  IORING_SETUP_SQPOLL* = (1'u shl 1) ##  SQ poll thread
  IORING_SETUP_SQ_AFF* = (1'u shl 2) ##  sq_thread_cpu is valid
  IORING_SETUP_CQSIZE* = (1'u shl 3) ##  app defines CQ size
  IORING_SETUP_CLAMP* = (1'u shl 4) ##  clamp SQ/CQ ring sizes
  IORING_SETUP_ATTACH_WQ* = (1'u shl 5) ##  attach to existing wq
  IORING_SETUP_R_DISABLED* = (1'u shl 6) ##  start with ring disabled
  IORING_SETUP_SUBMIT_ALL* = (1'u shl 7) ##  continue submit on error

##
##  Cooperative task running. When requests complete, they often require
##  forcing the submitter to transition to the kernel to complete. If this
##  flag is set, work will be done when the task transitions anyway, rather
##  than force an inter-processor interrupt reschedule. This avoids interrupting
##  a task running in userspace, and saves an IPI.
##

const
  IORING_SETUP_COOP_TASKRUN* = (1'u shl 8)

##
##  If COOP_TASKRUN is set, get notified if task work is available for
##  running and a kernel transition would be needed to run it. This sets
##  IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
##

const
  IORING_SETUP_TASKRUN_FLAG* = (1'u shl 9)
  IORING_SETUP_SQE128* = (1'u shl 10) ##  SQEs are 128 byte
  IORING_SETUP_CQE32* = (1'u shl 11) ##  CQEs are 32 byte

##
##  Only one task is allowed to submit requests
##

const
  IORING_SETUP_SINGLE_ISSUER* = (1'u shl 12)

##
##  Defer running task work to get events.
##  Rather than running bits of task work whenever the task transitions
##  try to do it just before it is needed.
##

const
  IORING_SETUP_DEFER_TASKRUN* = (1'u shl 13)

type
  io_uring_op* {.size: sizeof(cint).} = enum
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

const
  IORING_URING_CMD_FIXED* = (1'u shl 0)

##
##  sqe->fsync_flags
##

const
  IORING_FSYNC_DATASYNC* = (1'u shl 0)

##
##  sqe->timeout_flags
##

const
  IORING_TIMEOUT_ABS* = (1'u shl 0)
  IORING_TIMEOUT_UPDATE* = (1'u shl 1)
  IORING_TIMEOUT_BOOTTIME* = (1'u shl 2)
  IORING_TIMEOUT_REALTIME* = (1'u shl 3)
  IORING_LINK_TIMEOUT_UPDATE* = (1'u shl 4)
  IORING_TIMEOUT_ETIME_SUCCESS* = (1'u shl 5)
  IORING_TIMEOUT_CLOCK_MASK* = (IORING_TIMEOUT_BOOTTIME or
      IORING_TIMEOUT_REALTIME)
  IORING_TIMEOUT_UPDATE_MASK* = (
    IORING_TIMEOUT_UPDATE or IORING_LINK_TIMEOUT_UPDATE)

##
##  sqe->splice_flags
##  extends splice(2) flags
##

const
  SPLICE_F_FD_IN_FIXED* = (1'u shl 31) ##  the last bit of uint32

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

const
  IORING_POLL_ADD_MULTI* = (1'u shl 0)
  IORING_POLL_UPDATE_EVENTS* = (1'u shl 1)
  IORING_POLL_UPDATE_USER_DATA* = (1'u shl 2)
  IORING_POLL_ADD_LEVEL* = (1'u shl 3)

##
##  ASYNC_CANCEL flags.
##
##  IORING_ASYNC_CANCEL_ALL	Cancel all requests that match the given key
##  IORING_ASYNC_CANCEL_FD	Key off 'fd' for cancelation rather than the
## 				request 'user_data'
##  IORING_ASYNC_CANCEL_ANY	Match any request
##  IORING_ASYNC_CANCEL_FD_FIXED	'fd' passed in is a fixed descriptor
##

const
  IORING_ASYNC_CANCEL_ALL* = (1'u shl 0)
  IORING_ASYNC_CANCEL_FD* = (1'u shl 1)
  IORING_ASYNC_CANCEL_ANY* = (1'u shl 2)
  IORING_ASYNC_CANCEL_FD_FIXED* = (1'u shl 3)

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

const
  IORING_RECVSEND_POLL_FIRST* = (1'u shl 0)
  IORING_RECV_MULTISHOT* = (1'u shl 1)
  IORING_RECVSEND_FIXED_BUF* = (1'u shl 2)
  IORING_SEND_ZC_REPORT_USAGE* = (1'u shl 3)

##
##  cqe.res for IORING_CQE_F_NOTIF if
##  IORING_SEND_ZC_REPORT_USAGE was requested
##
##  It should be treated as a flag, all other
##  bits of cqe.res should be treated as reserved!
##

const
  IORING_NOTIF_USAGE_ZC_COPIED* = (1'u shl 31)

##
##  accept flags stored in sqe->ioprio
##

const
  IORING_ACCEPT_MULTISHOT* = (1'u shl 0)

##
##  IORING_OP_MSG_RING command types, stored in sqe->addr
##

const
  IORING_MSG_DATA* = 0          ##  pass sqe->len as 'res' and off as user_data
  IORING_MSG_SEND_FD* = 1       ##  send a registered fd to another ring

##
##  IORING_OP_MSG_RING flags (sqe->msg_ring_flags)
##
##  IORING_MSG_RING_CQE_SKIP	Don't post a CQE to the target ring. Not
## 				applicable for IORING_MSG_DATA, obviously.
##

const
  IORING_MSG_RING_CQE_SKIP* = (1'u shl 0)

##  Pass through the flags from sqe->file_index to cqe->flags

const
  IORING_MSG_RING_FLAGS_PASS* = (1'u shl 1)

##
##  IO completion data structure (Completion Queue Entry)
##

type
  io_uring_cqe* {.importc: "io_uring_cqe", header: "<linux/io_uring.h>", bycopy.} = object
    user_data* {.importc: "user_data".}: uint64
    ##  sqe->data submission passed back
    res* {.importc: "res".}: int32
    ##  result code for this event
    flags* {.importc: "flags".}: uint32
    ##
    ##  If the ring is initialized with IORING_SETUP_CQE32, then this field
    ##  contains 16-bytes of padding, doubling the size of the CQE.
    ##
    big_cqe* {.importc: "big_cqe".}: UncheckedArray[uint64]


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

const
  IORING_CQE_BUFFER_SHIFT* = 16

##
##  Magic offsets for the application to mmap the data it needs
##

const
  IORING_OFF_SQ_RING* = 0'u64
  IORING_OFF_CQ_RING* = 0x8000000
  IORING_OFF_SQES* = 0x10000000

##
##  Filled with the offset for mmap(2)
##

type
  io_sqring_offsets* {.importc: "struct io_sqring_offsets", header: "<linux/io_uring.h>", bycopy.} = object
    head* {.importc: "head".}: uint32
    tail* {.importc: "tail".}: uint32
    ring_mask* {.importc: "ring_mask".}: uint32
    ring_entries* {.importc: "ring_entries".}: uint32
    flags* {.importc: "flags".}: uint32
    dropped* {.importc: "dropped".}: uint32
    array* {.importc: "array".}: uint32
    resv1* {.importc: "resv1".}: uint32
    resv2* {.importc: "resv2".}: uint64


##
##  sq_ring->flags
##

const
  IORING_SQ_NEED_WAKEUP* = (1'u shl 0) ##  needs io_uring_enter wakeup
  IORING_SQ_CQ_OVERFLOW* = (1'u shl 1) ##  CQ ring is overflown
  IORING_SQ_TASKRUN* = (1'u shl 2) ##  task should enter the kernel

type
  io_cqring_offsets* {.importc: "struct io_cqring_offsets", header: "<linux/io_uring.h>", bycopy.} = object
    head* {.importc: "head".}: uint32
    tail* {.importc: "tail".}: uint32
    ring_mask* {.importc: "ring_mask".}: uint32
    ring_entries* {.importc: "ring_entries".}: uint32
    overflow* {.importc: "overflow".}: uint32
    cqes* {.importc: "cqes".}: uint32
    flags* {.importc: "flags".}: uint32
    resv1* {.importc: "resv1".}: uint32
    resv2* {.importc: "resv2".}: uint64


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

##
##  Passed in for io_uring_setup(2). Copied back with updated info on success
##

type
  io_uring_params* {.importc: "struct io_uring_params", header: "<linux/io_uring.h>", bycopy.} = object
    sq_entries* {.importc: "sq_entries".}: uint32
    cq_entries* {.importc: "cq_entries".}: uint32
    flags* {.importc: "flags".}: uint32
    sq_thread_cpu* {.importc: "sq_thread_cpu".}: uint32
    sq_thread_idle* {.importc: "sq_thread_idle".}: uint32
    features* {.importc: "features".}: uint32
    wq_fd* {.importc: "wq_fd".}: uint32
    resv* {.importc: "resv".}: array[3, uint32]
    sq_off* {.importc: "sq_off".}: io_sqring_offsets
    cq_off* {.importc: "cq_off".}: io_cqring_offsets


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

##
##  io_uring_register(2) opcodes and arguments
##

const
  IORING_REGISTER_BUFFERS* = 0
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

##  io-wq worker categories

const
  IO_WQ_BOUND* = 0
  IO_WQ_UNBOUND* = 1

##  deprecated, see struct io_uring_rsrc_update

type
  io_uring_files_update* {.importc: "struct io_uring_files_update", header: "<linux/io_uring.h>",
                          bycopy.} = object
    offset* {.importc: "offset".}: uint32
    resv* {.importc: "resv".}: uint32
    fds* {.importc: "fds", align: 64.}: int ##  int32 *


##
##  Register a fully sparse file space, rather than pass in an array of all
##  -1 file descriptors.
##

const
  IORING_RSRC_REGISTER_SPARSE* = (1'u shl 0)

type
  io_uring_rsrc_register* {.importc: "struct io_uring_rsrc_register",
                           header: "<linux/io_uring.h>", bycopy.} = object
    nr* {.importc: "nr".}: uint32
    flags* {.importc: "flags".}: uint32
    resv2* {.importc: "resv2".}: uint64
    data* {.importc: "data", align: 64.}: int
    tags* {.importc: "tags", align: 64.}: int

  io_uring_rsrc_update* {.importc: "struct io_uring_rsrc_update", header: "<linux/io_uring.h>",
                         bycopy.} = object
    offset* {.importc: "offset".}: uint32
    resv* {.importc: "resv".}: uint32
    data* {.importc: "data", align: 64.}: int

  io_uring_rsrc_update2* {.importc: "struct io_uring_rsrc_update2", header: "<linux/io_uring.h>",
                          bycopy.} = object
    offset* {.importc: "offset".}: uint32
    resv* {.importc: "resv".}: uint32
    data* {.importc: "data", align: 64.}: int
    tags* {.importc: "tags", align: 64.}: int
    nr* {.importc: "nr".}: uint32
    resv2* {.importc: "resv2".}: uint32

  io_uring_notification_slot* {.importc: "struct io_uring_notification_slot",
                               header: "<linux/io_uring.h>", bycopy.} = object
    tag* {.importc: "tag".}: uint64
    resv* {.importc: "resv".}: array[3, uint64]

  io_uring_notification_register* {.importc: "struct io_uring_notification_register",
                                   header: "<linux/io_uring.h>", bycopy.} = object
    nr_slots* {.importc: "nr_slots".}: uint32
    resv* {.importc: "resv".}: uint32
    resv2* {.importc: "resv2".}: uint64
    data* {.importc: "data".}: uint64
    resv3* {.importc: "resv3".}: uint64


##  Skip updating fd indexes set to this value in the fd table

const
  IORING_REGISTER_FILES_SKIP* = (-2)
  IO_URING_OP_SUPPORTED* = (1'u shl 0)

type
  io_uring_probe_op* {.importc: "struct io_uring_probe_op", header: "<linux/io_uring.h>", bycopy.} = object
    op* {.importc: "op".}: uint8
    resv* {.importc: "resv".}: uint8
    flags* {.importc: "flags".}: uint16
    ##  IO_URING_OP_* flags
    resv2* {.importc: "resv2".}: uint32

  io_uring_probe* {.importc: "struct io_uring_probe", header: "<linux/io_uring.h>", bycopy.} = object
    last_op* {.importc: "last_op".}: uint8
    ##  last opcode supported
    ops_len* {.importc: "ops_len".}: uint8
    ##  length of ops[] array below
    resv* {.importc: "resv".}: uint16
    resv2* {.importc: "resv2".}: array[3, uint32]
    ops* {.importc: "ops".}: UncheckedArray[io_uring_probe_op]

  INNER_C_UNION_io_uring_18* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    register_op* {.importc: "register_op".}: uint8
    ##  IORING_RESTRICTION_REGISTER_OP
    sqe_op* {.importc: "sqe_op".}: uint8
    ##  IORING_RESTRICTION_SQE_OP
    sqe_flags* {.importc: "sqe_flags".}: uint8
    ##  IORING_RESTRICTION_SQE_FLAGS_*

  io_uring_restriction* {.importc: "struct io_uring_restriction", header: "<linux/io_uring.h>",
                         bycopy.} = object
    opcode* {.importc: "opcode".}: uint16
    ano_io_uring_19* {.importc: "ano_io_uring_19".}: INNER_C_UNION_io_uring_18
    resv* {.importc: "resv".}: uint8
    resv2* {.importc: "resv2".}: array[3, uint32]

  io_uring_buf* {.importc: "struct io_uring_buf", header: "<linux/io_uring.h>", bycopy.} = object
    `addr`* {.importc: "addr".}: uint64
    len* {.importc: "len".}: uint32
    bid* {.importc: "bid".}: uint16
    resv* {.importc: "resv".}: uint16

  INNER_C_STRUCT_io_uring_21* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy.} = object
    resv1* {.importc: "resv1".}: uint64
    resv2* {.importc: "resv2".}: uint32
    resv3* {.importc: "resv3".}: uint16
    tail* {.importc: "tail".}: uint16

  INNER_C_STRUCT_io_uring_23* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy.} = object
    bufs* {.importc: "bufs".}: UncheckedArray[io_uring_buf]

  INNER_C_UNION_io_uring_20* {.importc: "no_name", header: "<linux/io_uring.h>", bycopy, union.} = object
    ##
    ##  To avoid spilling into more pages than we need to, the
    ##  ring tail is overlaid with the io_uring_buf->resv field.
    ##
    ano_io_uring_22* {.importc: "ano_io_uring_22".}: INNER_C_STRUCT_io_uring_21
    ano_io_uring_24* {.importc: "ano_io_uring_24".}: INNER_C_STRUCT_io_uring_23

  io_uring_buf_ring* {.importc: "struct io_uring_buf_ring", header: "<linux/io_uring.h>", bycopy.} = object
    ano_io_uring_25* {.importc: "ano_io_uring_25".}: INNER_C_UNION_io_uring_20


##  argument for IORING_(UN)REGISTER_PBUF_RING

type
  io_uring_buf_reg* {.importc: "struct io_uring_buf_reg", header: "<linux/io_uring.h>", bycopy.} = object
    ring_addr* {.importc: "ring_addr".}: uint64
    ring_entries* {.importc: "ring_entries".}: uint32
    bgid* {.importc: "bgid".}: uint16
    pad* {.importc: "pad".}: uint16
    resv* {.importc: "resv".}: array[3, uint64]


##
##  io_uring_restriction->opcode values
##

const                         ##  Allow an io_uring_register(2) opcode
  IORING_RESTRICTION_REGISTER_OP* = 0 ##  Allow an sqe opcode
  IORING_RESTRICTION_SQE_OP* = 1 ##  Allow sqe flags
  IORING_RESTRICTION_SQE_FLAGS_ALLOWED* = 2 ##  Require sqe flags (these flags must be set on each submission)
  IORING_RESTRICTION_SQE_FLAGS_REQUIRED* = 3
  IORING_RESTRICTION_LAST* = 4

type
  io_uring_getevents_arg* {.importc: "struct io_uring_getevents_arg",
                           header: "<linux/io_uring.h>", bycopy.} = object
    sigmask* {.importc: "sigmask".}: uint64
    sigmask_sz* {.importc: "sigmask_sz".}: uint32
    pad* {.importc: "pad".}: uint32
    ts* {.importc: "ts".}: uint64


##
##  Argument for IORING_REGISTER_SYNC_CANCEL
##

type
  io_uring_sync_cancel_reg* {.importc: "struct io_uring_sync_cancel_reg",
                             header: "<linux/io_uring.h>", bycopy.} = object
    `addr`* {.importc: "addr".}: uint64
    fd* {.importc: "fd".}: int32
    flags* {.importc: "flags".}: uint32
    timeout* {.importc: "timeout".}: Timespec
    pad* {.importc: "pad".}: array[4, uint64]


##
##  Argument for IORING_REGISTER_FILE_ALLOC_RANGE
##  The range is specified as [off, off + len)
##

type
  io_uring_file_index_range* {.importc: "struct io_uring_file_index_range",
                              header: "<linux/io_uring.h>", bycopy.} = object
    off* {.importc: "off".}: uint32
    len* {.importc: "len".}: uint32
    resv* {.importc: "resv".}: uint64

  io_uring_recvmsg_out* {.importc: "struct io_uring_recvmsg_out", header: "<linux/io_uring.h>",
                         bycopy.} = object
    namelen* {.importc: "namelen".}: uint32
    controllen* {.importc: "controllen".}: uint32
    payloadlen* {.importc: "payloadlen".}: uint32
    flags* {.importc: "flags".}: uint32


proc syscall(arg: cint): cint {.importc, header: "<unistd.h>", varargs.}
var
  SYS_io_uring_setup {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_enter {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_register {.importc, header: "<sys/syscall.h>".}: cint

proc io_uring_setup*(entries: uint32, params: ptr io_uring_params): cint =
  return syscall(SYS_io_uring_setup, entries, params)

proc io_uring_enter*(fd: uint32, to_submit: uint32, min_complete: uint32,
                     flags: uint32, argp: pointer, argsz: uint32): cint =
  return syscall(SYS_io_uring_enter, fd, to_submit, min_complete, flags, argp, argsz)

proc io_uring_register*(fd: uint32, op: uint32, arg: pointer, nr_args: uint): cint =
  return syscall(SYS_io_uring_register, fd, op, arg, nr_args)
