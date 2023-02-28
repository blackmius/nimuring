import types, io_uring

{.passl: "-luring".}

type
  IoUringSq* {.importc: "struct io_uring_sq", header: "<liburing.h>", bycopy.} = object ##
                                                                       ##  Library interface to io_uring
                                                                       ##
    khead* {.importc: "khead".}: ref cuint
    ktail* {.importc: "ktail".}: ref cuint
    kringMask* {.importc: "kring_mask".}: ref cuint ##  Deprecated: use `ring_mask` instead of `*kring_mask`
    kringEntries* {.importc: "kring_entries".}: ref cuint ##  Deprecated: use `ring_entries` instead of `*kring_entries`
    kflags* {.importc: "kflags".}: ref cuint
    kdropped* {.importc: "kdropped".}: ref cuint
    array* {.importc: "array".}: ref cuint
    sqes* {.importc: "sqes".}: ptr IoUringSqe
    sqeHead* {.importc: "sqe_head".}: cuint
    sqeTail* {.importc: "sqe_tail".}: cuint
    ringSz* {.importc: "ring_sz".}: csize_t
    ringPtr* {.importc: "ring_ptr".}: pointer
    ringMask* {.importc: "ring_mask".}: cuint
    ringEntries* {.importc: "ring_entries".}: cuint
    pad* {.importc: "pad".}: array[2, cuint]

  IoUringCq* {.importc: "struct io_uring_cq", header: "<liburing.h>", bycopy.} = object
    khead* {.importc: "khead".}: ref cuint
    ktail* {.importc: "ktail".}: ref cuint
    kringMask* {.importc: "kring_mask".}: ref cuint ##  Deprecated: use `ring_mask` instead of `*kring_mask`
    kringEntries* {.importc: "kring_entries".}: ref cuint ##  Deprecated: use `ring_entries` instead of `*kring_entries`
    kflags* {.importc: "kflags".}: ref cuint
    koverflow* {.importc: "koverflow".}: ref cuint
    cqes* {.importc: "cqes".}: ptr IoUringCqe
    ringSz* {.importc: "ring_sz".}: csize_t
    ringPtr* {.importc: "ring_ptr".}: pointer
    ringMask* {.importc: "ring_mask".}: cuint
    ringEntries* {.importc: "ring_entries".}: cuint
    pad* {.importc: "pad".}: array[2, cuint]

  IoUring* {.importc: "struct io_uring", header: "<liburing.h>", bycopy.} = object
    sq* {.importc: "sq".}: IoUringSq
    cq* {.importc: "cq".}: IoUringCq
    flags* {.importc: "flags".}: cuint
    ringFd* {.importc: "ring_fd".}: cint
    features* {.importc: "features".}: cuint
    enterRingFd* {.importc: "enter_ring_fd".}: cint
    intFlags* {.importc: "int_flags".}: U8
    pad* {.importc: "pad".}: array[3, U8]
    pad2* {.importc: "pad2".}: cuint


proc ioUringGetProbeRing*(ring: ref IoUring): ref IoUringProbe {.
    importc: "io_uring_get_probe_ring", header: "<liburing.h>".}
  ##
  ##  Library interface
  ##
  ##
  ##  return an allocated io_uring_probe structure, or NULL if probe fails (for
  ##  example, if it is not available). The caller is responsible for freeing it
  ##
proc ioUringGetProbe*(): ref IoUringProbe {.importc: "io_uring_get_probe",
                                        header: "<liburing.h>".}
  ##  same as io_uring_get_probe_ring, but takes care of ring init and teardown
proc ioUringFreeProbe*(probe: ref IoUringProbe) {.importc: "io_uring_free_probe",
    header: "<liburing.h>".}
  ##
  ##  frees a probe allocated through io_uring_get_probe() or
  ##  io_uring_get_probe_ring()
  ##
proc ioUringOpcodeSupported*(p: ref IoUringProbe; op: cint): cint {.
    importc: "io_uring_opcode_supported", header: "<liburing.h>".}

proc ioUringQueueInitParams*(entries: cuint; ring: ref IoUring; p: ref IoUringParams): cint {.
    importc: "io_uring_queue_init_params", header: "<liburing.h>".}
proc ioUringQueueInit*(entries: cuint; ring: ref IoUring; flags: cuint): cint {.
    importc: "io_uring_queue_init", header: "<liburing.h>".}
proc ioUringQueueMmap*(fd: cint; p: ref IoUringParams; ring: ref IoUring): cint {.
    importc: "io_uring_queue_mmap", header: "<liburing.h>".}
proc ioUringRingDontfork*(ring: ref IoUring): cint {.
    importc: "io_uring_ring_dontfork", header: "<liburing.h>".}
proc ioUringQueueExit*(ring: ref IoUring) {.importc: "io_uring_queue_exit",
                                        header: "<liburing.h>".}
proc ioUringPeekBatchCqe*(ring: ref IoUring; cqes: ptr ptr IoUringCqe; count: cuint): cuint {.
    importc: "io_uring_peek_batch_cqe", header: "<liburing.h>".}
proc ioUringWaitCqes*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe; waitNr: cuint;
                     ts: ref KernelTimespec; sigmask: ref SigsetT): cint {.
    importc: "io_uring_wait_cqes", header: "<liburing.h>".}
proc ioUringWaitCqeTimeout*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe;
                           ts: ref KernelTimespec): cint {.
    importc: "io_uring_wait_cqe_timeout", header: "<liburing.h>".}
proc ioUringSubmit*(ring: ref IoUring): cint {.importc: "io_uring_submit",
    header: "<liburing.h>".}
proc ioUringSubmitAndWait*(ring: ref IoUring; waitNr: cuint): cint {.
    importc: "io_uring_submit_and_wait", header: "<liburing.h>".}
proc ioUringSubmitAndWaitTimeout*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe;
                                 waitNr: cuint; ts: ref KernelTimespec;
                                 sigmask: ref SigsetT): cint {.
    importc: "io_uring_submit_and_wait_timeout", header: "<liburing.h>".}
proc ioUringRegisterBuffers*(ring: ref IoUring; iovecs: ref Iovec; nrIovecs: cuint): cint {.
    importc: "io_uring_register_buffers", header: "<liburing.h>".}
proc ioUringRegisterBuffersTags*(ring: ref IoUring; iovecs: ref Iovec; tags: ref U64;
                                nr: cuint): cint {.
    importc: "io_uring_register_buffers_tags", header: "<liburing.h>".}
proc ioUringRegisterBuffersSparse*(ring: ref IoUring; nr: cuint): cint {.
    importc: "io_uring_register_buffers_sparse", header: "<liburing.h>".}
proc ioUringRegisterBuffersUpdateTag*(ring: ref IoUring; off: cuint;
                                     iovecs: ref Iovec; tags: ref U64; nr: cuint): cint {.
    importc: "io_uring_register_buffers_update_tag", header: "<liburing.h>".}
proc ioUringUnregisterBuffers*(ring: ref IoUring): cint {.
    importc: "io_uring_unregister_buffers", header: "<liburing.h>".}
proc ioUringRegisterFiles*(ring: ref IoUring; files: ref cint; nrFiles: cuint): cint {.
    importc: "io_uring_register_files", header: "<liburing.h>".}
proc ioUringRegisterFilesTags*(ring: ref IoUring; files: ref cint; tags: ref U64;
                              nr: cuint): cint {.
    importc: "io_uring_register_files_tags", header: "<liburing.h>".}
proc ioUringRegisterFilesSparse*(ring: ref IoUring; nr: cuint): cint {.
    importc: "io_uring_register_files_sparse", header: "<liburing.h>".}
proc ioUringRegisterFilesUpdateTag*(ring: ref IoUring; off: cuint; files: ref cint;
                                   tags: ref U64; nrFiles: cuint): cint {.
    importc: "io_uring_register_files_update_tag", header: "<liburing.h>".}
proc ioUringUnregisterFiles*(ring: ref IoUring): cint {.
    importc: "io_uring_unregister_files", header: "<liburing.h>".}
proc ioUringRegisterFilesUpdate*(ring: ref IoUring; off: cuint; files: ref cint;
                                nrFiles: cuint): cint {.
    importc: "io_uring_register_files_update", header: "<liburing.h>".}
proc ioUringRegisterEventfd*(ring: ref IoUring; fd: cint): cint {.
    importc: "io_uring_register_eventfd", header: "<liburing.h>".}
proc ioUringRegisterEventfdAsync*(ring: ref IoUring; fd: cint): cint {.
    importc: "io_uring_register_eventfd_async", header: "<liburing.h>".}
proc ioUringUnregisterEventfd*(ring: ref IoUring): cint {.
    importc: "io_uring_unregister_eventfd", header: "<liburing.h>".}
proc ioUringRegisterProbe*(ring: ref IoUring; p: ref IoUringProbe; nr: cuint): cint {.
    importc: "io_uring_register_probe", header: "<liburing.h>".}
proc ioUringRegisterPersonality*(ring: ref IoUring): cint {.
    importc: "io_uring_register_personality", header: "<liburing.h>".}
proc ioUringUnregisterPersonality*(ring: ref IoUring; id: cint): cint {.
    importc: "io_uring_unregister_personality", header: "<liburing.h>".}
proc ioUringRegisterRestrictions*(ring: ref IoUring; res: ref IoUringRestriction;
                                 nrRes: cuint): cint {.
    importc: "io_uring_register_restrictions", header: "<liburing.h>".}
proc ioUringEnableRings*(ring: ref IoUring): cint {.importc: "io_uring_enable_rings",
    header: "<liburing.h>".}
proc ioUringRegisterIowqAff*(ring: ref IoUring; cpusz: csize_t; mask: ref CpuSetT): cint {.
    importc: "io_uring_register_iowq_aff", header: "<liburing.h>".}
proc ioUringUnregisterIowqAff*(ring: ref IoUring): cint {.
    importc: "io_uring_unregister_iowq_aff", header: "<liburing.h>".}
proc ioUringRegisterIowqMaxWorkers*(ring: ref IoUring; values: ref cuint): cint {.
    importc: "io_uring_register_iowq_max_workers", header: "<liburing.h>".}
proc ioUringRegisterRingFd*(ring: ref IoUring): cint {.
    importc: "io_uring_register_ring_fd", header: "<liburing.h>".}
proc ioUringUnregisterRingFd*(ring: ref IoUring): cint {.
    importc: "io_uring_unregister_ring_fd", header: "<liburing.h>".}
proc ioUringCloseRingFd*(ring: ref IoUring): cint {.
    importc: "io_uring_close_ring_fd", header: "<liburing.h>".}
proc ioUringRegisterBufRing*(ring: ref IoUring; reg: ref IoUringBufReg; flags: cuint): cint {.
    importc: "io_uring_register_buf_ring", header: "<liburing.h>".}
proc ioUringUnregisterBufRing*(ring: ref IoUring; bgid: cint): cint {.
    importc: "io_uring_unregister_buf_ring", header: "<liburing.h>".}
proc ioUringRegisterSyncCancel*(ring: ref IoUring; reg: ref IoUringSyncCancelReg): cint {.
    importc: "io_uring_register_sync_cancel", header: "<liburing.h>".}
proc ioUringRegisterFileAllocRange*(ring: ref IoUring; off: cuint; len: cuint): cint {.
    importc: "io_uring_register_file_alloc_range", header: "<liburing.h>".}
proc ioUringGetEvents*(ring: ref IoUring): cint {.importc: "io_uring_get_events",
    header: "<liburing.h>".}
proc ioUringSubmitAndGetEvents*(ring: ref IoUring): cint {.
    importc: "io_uring_submit_and_get_events", header: "<liburing.h>".}
proc ioUringEnter*(fd: cuint; toSubmit: cuint; minComplete: cuint; flags: cuint;
                  sig: ref SigsetT): cint {.importc: "io_uring_enter",
                                        header: "<liburing.h>".}
  ##
  ##  io_uring syscalls.
  ##
proc ioUringEnter2*(fd: cuint; toSubmit: cuint; minComplete: cuint; flags: cuint;
                   sig: ref SigsetT; sz: csize_t): cint {.importc: "io_uring_enter2",
    header: "<liburing.h>".}
proc ioUringSetup*(entries: cuint; p: ref IoUringParams): cint {.
    importc: "io_uring_setup", header: "<liburing.h>".}
proc ioUringRegister*(fd: cuint; opcode: cuint; arg: pointer; nrArgs: cuint): cint {.
    importc: "io_uring_register", header: "<liburing.h>".}
proc ioUringGetCqe*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe; submit: cuint;
                   waitNr: cuint; sigmask: ref SigsetT): cint {.
    importc: "__io_uring_get_cqe", header: "<liburing.h>".}
  ##
  ##  Helper for the peek/wait single cqe functions. Exported because of that,
  ##  but probably shouldn't be used directly in an application.
  ##
var LIBURING_UDATA_TIMEOUT* {.importc: "LIBURING_UDATA_TIMEOUT",
                            header: "<liburing.h>".}: int

{.push, header: "<liburing.h>".}

proc ioUringCqeSeen*(ring: ref IoUring; cqe: ptr IoUringCqe) {.
    importc: "io_uring_cqe_seen".}
  ##
  ##  Must be called after io_uring_{peek,wait}_cqe() after the cqe has
  ##  been processed by the application.
  ##

proc ioUringSqeSetData*(sqe: ptr IoUringSqe; data: pointer) {.
    importc: "io_uring_sqe_set_data".}
  ##
  ##  Command prep helpers
  ##
  ##
  ##  Associate pointer @data with the sqe, for later retrieval from the cqe
  ##  at command completion time with io_uring_cqe_get_data().
  ##

proc ioUringCqeGetData*(cqe: ptr IoUringCqe): pointer {.
    importc: "io_uring_cqe_get_data".}

proc ioUringSqeSetData64*(sqe: ptr IoUringSqe; data: U64) {.
    importc: "io_uring_sqe_set_data64".}
  ##
  ##  Assign a 64-bit value to this sqe, which can get retrieved at completion
  ##  time with io_uring_cqe_get_data64. Just like the non-64 variants, except
  ##  these store a 64-bit type rather than a data pointer.
  ##

proc ioUringCqeGetData64*(cqe: ptr IoUringCqe): U64 {.
    importc: "io_uring_cqe_get_data64".}

proc ioUringSqeSetFlags*(sqe: ptr IoUringSqe; flags: cuint) {.
    importc: "io_uring_sqe_set_flags".}
  ##
  ##  Tell the app the have the 64-bit variants of the get/set userdata
  ##

proc ioUringPrepRw*(op: cint; sqe: ptr IoUringSqe; fd: cint; `addr`: pointer; len: cuint;
                   offset: U64) {.importc: "io_uring_prep_rw".}

proc ioUringPrepSplice*(sqe: ptr IoUringSqe; fdIn: cint; offIn: int64; fdOut: cint;
                       offOut: int64; nbytes: cuint; spliceFlags: cuint) {.
    importc: "io_uring_prep_splice".}
  ##
  ##  io_uring_prep_splice() - Either @fd_in or @fd_out must be a pipe.
  ##
  ##  - If @fd_in refers to a pipe, @off_in is ignored and must be set to -1.
  ##
  ##  - If @fd_in does not refer to a pipe and @off_in is -1, then @nbytes are read
  ##    from @fd_in starting from the file offset, which is incremented by the
  ##    number of bytes read.
  ##
  ##  - If @fd_in does not refer to a pipe and @off_in is not -1, then the starting
  ##    offset of @fd_in will be @off_in.
  ##
  ##  This splice operation can be used to implement sendfile by splicing to an
  ##  intermediate pipe first, then splice to the final destination.
  ##  In fact, the implementation of sendfile in kernel uses splice internally.
  ##
  ##  NOTE that even if fd_in or fd_out refers to a pipe, the splice operation
  ##  can still fail with EINVAL if one of the fd doesn't explicitly support splice
  ##  operation, e.g. reading from terminal is unsupported from kernel 5.7 to 5.11.
  ##  Check issue #291 for more information.

proc ioUringPrepTee*(sqe: ptr IoUringSqe; fdIn: cint; fdOut: cint; nbytes: cuint;
                    spliceFlags: cuint) {.importc: "io_uring_prep_tee".}

proc ioUringPrepReadv*(sqe: ptr IoUringSqe; fd: cint; iovecs: ref Iovec; nrVecs: cuint;
                      offset: U64) {.importc: "io_uring_prep_readv".}

proc ioUringPrepReadv2*(sqe: ptr IoUringSqe; fd: cint; iovecs: ref Iovec; nrVecs: cuint;
                       offset: U64; flags: cint) {.importc: "io_uring_prep_readv2".}

proc ioUringPrepReadFixed*(sqe: ptr IoUringSqe; fd: cint; buf: pointer; nbytes: cuint;
                          offset: U64; bufIndex: cint) {.
    importc: "io_uring_prep_read_fixed".}

proc ioUringPrepWritev*(sqe: ptr IoUringSqe; fd: cint; iovecs: ref Iovec; nrVecs: cuint;
                       offset: U64) {.importc: "io_uring_prep_writev".}

proc ioUringPrepWritev2*(sqe: ptr IoUringSqe; fd: cint; iovecs: ref Iovec; nrVecs: cuint;
                        offset: U64; flags: cint) {.importc: "io_uring_prep_writev2".}

proc ioUringPrepWriteFixed*(sqe: ptr IoUringSqe; fd: cint; buf: pointer; nbytes: cuint;
                           offset: U64; bufIndex: cint) {.
    importc: "io_uring_prep_write_fixed".}

proc ioUringPrepRecvmsg*(sqe: ptr IoUringSqe; fd: cint; msg: ref Tmsghdr; flags: cuint) {.
    importc: "io_uring_prep_recvmsg".}

proc ioUringPrepRecvmsgMultishot*(sqe: ptr IoUringSqe; fd: cint; msg: ref Tmsghdr;
                                 flags: cuint) {.
    importc: "io_uring_prep_recvmsg_multishot".}

proc ioUringPrepSendmsg*(sqe: ptr IoUringSqe; fd: cint; msg: ref Tmsghdr; flags: cuint) {.
    importc: "io_uring_prep_sendmsg".}

proc ioUringPrepPollAdd*(sqe: ptr IoUringSqe; fd: cint; pollMask: cuint) {.
    importc: "io_uring_prep_poll_add".}

proc ioUringPrepPollMultishot*(sqe: ptr IoUringSqe; fd: cint; pollMask: cuint) {.
    importc: "io_uring_prep_poll_multishot".}

proc ioUringPrepPollRemove*(sqe: ptr IoUringSqe; userData: U64) {.
    importc: "io_uring_prep_poll_remove".}

proc ioUringPrepPollUpdate*(sqe: ptr IoUringSqe; oldUserData: U64; newUserData: U64;
                           pollMask: cuint; flags: cuint) {.
    importc: "io_uring_prep_poll_update".}

proc ioUringPrepFsync*(sqe: ptr IoUringSqe; fd: cint; fsyncFlags: cuint) {.
    importc: "io_uring_prep_fsync".}

proc ioUringPrepNop*(sqe: ptr IoUringSqe) {.importc: "io_uring_prep_nop".}

proc ioUringPrepTimeout*(sqe: ptr IoUringSqe; ts: ref KernelTimespec; count: cuint;
                        flags: cuint) {.importc: "io_uring_prep_timeout".}

proc ioUringPrepTimeoutRemove*(sqe: ptr IoUringSqe; userData: U64; flags: cuint) {.
    importc: "io_uring_prep_timeout_remove".}

proc ioUringPrepTimeoutUpdate*(sqe: ptr IoUringSqe; ts: ref KernelTimespec;
                              userData: U64; flags: cuint) {.
    importc: "io_uring_prep_timeout_update".}

proc ioUringPrepAccept*(sqe: ptr IoUringSqe; fd: cint; `addr`: ref Sockaddr;
                       addrlen: ref SocklenT; flags: cint) {.
    importc: "io_uring_prep_accept".}

proc ioUringPrepAcceptDirect*(sqe: ptr IoUringSqe; fd: cint; `addr`: ref Sockaddr;
                             addrlen: ref SocklenT; flags: cint; fileIndex: cuint) {.
    importc: "io_uring_prep_accept_direct".}

proc ioUringPrepMultishotAccept*(sqe: ptr IoUringSqe; fd: cint; `addr`: ref Sockaddr;
                                addrlen: ref SocklenT; flags: cint) {.
    importc: "io_uring_prep_multishot_accept".}

proc ioUringPrepMultishotAcceptDirect*(sqe: ptr IoUringSqe; fd: cint;
                                      `addr`: ref Sockaddr; addrlen: ref SocklenT;
                                      flags: cint) {.
    importc: "io_uring_prep_multishot_accept_direct".}

proc ioUringPrepCancel64*(sqe: ptr IoUringSqe; userData: U64; flags: cint) {.
    importc: "io_uring_prep_cancel64".}

proc ioUringPrepCancel*(sqe: ptr IoUringSqe; userData: pointer; flags: cint) {.
    importc: "io_uring_prep_cancel".}

proc ioUringPrepCancelFd*(sqe: ptr IoUringSqe; fd: cint; flags: cuint) {.
    importc: "io_uring_prep_cancel_fd".}

proc ioUringPrepLinkTimeout*(sqe: ptr IoUringSqe; ts: ref KernelTimespec; flags: cuint) {.
    importc: "io_uring_prep_link_timeout".}

proc ioUringPrepConnect*(sqe: ptr IoUringSqe; fd: cint; `addr`: ref Sockaddr;
                        addrlen: SocklenT) {.importc: "io_uring_prep_connect".}

proc ioUringPrepFilesUpdate*(sqe: ptr IoUringSqe; fds: ref cint; nrFds: cuint;
                            offset: cint) {.importc: "io_uring_prep_files_update".}

proc ioUringPrepFallocate*(sqe: ptr IoUringSqe; fd: cint; mode: cint; offset: OffT;
                          len: OffT) {.importc: "io_uring_prep_fallocate".}

proc ioUringPrepOpenat*(sqe: ptr IoUringSqe; dfd: cint; path: cstring; flags: cint;
                       mode: ModeT) {.importc: "io_uring_prep_openat".}

proc ioUringPrepOpenatDirect*(sqe: ptr IoUringSqe; dfd: cint; path: cstring;
                             flags: cint; mode: ModeT; fileIndex: cuint) {.
    importc: "io_uring_prep_openat_direct".}

proc ioUringPrepClose*(sqe: ptr IoUringSqe; fd: cint) {.importc: "io_uring_prep_close".}

proc ioUringPrepCloseDirect*(sqe: ptr IoUringSqe; fileIndex: cuint) {.
    importc: "io_uring_prep_close_direct".}

proc ioUringPrepRead*(sqe: ptr IoUringSqe; fd: cint; buf: pointer; nbytes: cuint;
                     offset: U64) {.importc: "io_uring_prep_read".}

proc ioUringPrepWrite*(sqe: ptr IoUringSqe; fd: cint; buf: pointer; nbytes: cuint;
                      offset: U64) {.importc: "io_uring_prep_write".}

proc ioUringPrepStatx*(sqe: ptr IoUringSqe; dfd: cint; path: cstring; flags: cint;
                      mask: cuint; statxbuf: ref Statx) {.
    importc: "io_uring_prep_statx".}

proc ioUringPrepFadvise*(sqe: ptr IoUringSqe; fd: cint; offset: U64; len: OffT;
                        advice: cint) {.importc: "io_uring_prep_fadvise".}

proc ioUringPrepMadvise*(sqe: ptr IoUringSqe; `addr`: pointer; length: OffT;
                        advice: cint) {.importc: "io_uring_prep_madvise".}

proc ioUringPrepSend*(sqe: ptr IoUringSqe; sockfd: cint; buf: pointer; len: csize_t;
                     flags: cint) {.importc: "io_uring_prep_send".}

proc ioUringPrepSendZc*(sqe: ptr IoUringSqe; sockfd: cint; buf: pointer; len: csize_t;
                       flags: cint; zcFlags: cuint) {.
    importc: "io_uring_prep_send_zc".}

proc ioUringPrepSendZcFixed*(sqe: ptr IoUringSqe; sockfd: cint; buf: pointer;
                            len: csize_t; flags: cint; zcFlags: cuint; bufIndex: cuint) {.
    importc: "io_uring_prep_send_zc_fixed".}

proc ioUringPrepSendmsgZc*(sqe: ptr IoUringSqe; fd: cint; msg: ref Tmsghdr; flags: cuint) {.
    importc: "io_uring_prep_sendmsg_zc".}

proc ioUringPrepSendSetAddr*(sqe: ptr IoUringSqe; destAddr: ref Sockaddr; addrLen: U16) {.
    importc: "io_uring_prep_send_set_addr".}

proc ioUringPrepRecv*(sqe: ptr IoUringSqe; sockfd: cint; buf: pointer; len: csize_t;
                     flags: cint) {.importc: "io_uring_prep_recv".}

proc ioUringPrepRecvMultishot*(sqe: ptr IoUringSqe; sockfd: cint; buf: pointer;
                              len: csize_t; flags: cint) {.
    importc: "io_uring_prep_recv_multishot".}

proc ioUringRecvmsgValidate*(buf: pointer; bufLen: cint; msgh: ref Tmsghdr): ref IoUringRecvmsgOut {.
    importc: "io_uring_recvmsg_validate".}

proc ioUringRecvmsgName*(o: ref IoUringRecvmsgOut): pointer {.
    importc: "io_uring_recvmsg_name".}

proc ioUringRecvmsgCmsgFirsthdr*(o: ref IoUringRecvmsgOut; msgh: ref Tmsghdr): ref Cmsghdr {.
    importc: "io_uring_recvmsg_cmsg_firsthdr".}

proc ioUringRecvmsgCmsgNexthdr*(o: ref IoUringRecvmsgOut; msgh: ref Tmsghdr;
                               cmsg: ref Cmsghdr): ref Cmsghdr {.
    importc: "io_uring_recvmsg_cmsg_nexthdr".}

proc ioUringRecvmsgPayload*(o: ref IoUringRecvmsgOut; msgh: ref Tmsghdr): pointer {.
    importc: "io_uring_recvmsg_payload".}

proc ioUringRecvmsgPayloadLength*(o: ref IoUringRecvmsgOut; bufLen: cint;
                                 msgh: ref Tmsghdr): cuint {.
    importc: "io_uring_recvmsg_payload_length".}

proc ioUringPrepOpenat2*(sqe: ptr IoUringSqe; dfd: cint; path: cstring; how: ref OpenHow) {.
    importc: "io_uring_prep_openat2".}

proc ioUringPrepOpenat2Direct*(sqe: ptr IoUringSqe; dfd: cint; path: cstring;
                              how: ref OpenHow; fileIndex: cuint) {.
    importc: "io_uring_prep_openat2_direct".}

proc ioUringPrepEpollCtl*(sqe: ptr IoUringSqe; epfd: cint; fd: cint; op: cint;
                         ev: ref EpollEvent) {.importc: "io_uring_prep_epoll_ctl".}

proc ioUringPrepProvideBuffers*(sqe: ptr IoUringSqe; `addr`: pointer; len: cint;
                               nr: cint; bgid: cint; bid: cint) {.
    importc: "io_uring_prep_provide_buffers".}

proc ioUringPrepRemoveBuffers*(sqe: ptr IoUringSqe; nr: cint; bgid: cint) {.
    importc: "io_uring_prep_remove_buffers".}

proc ioUringPrepShutdown*(sqe: ptr IoUringSqe; fd: cint; how: cint) {.
    importc: "io_uring_prep_shutdown".}

proc ioUringPrepUnlinkat*(sqe: ptr IoUringSqe; dfd: cint; path: cstring; flags: cint) {.
    importc: "io_uring_prep_unlinkat".}

proc ioUringPrepUnlink*(sqe: ptr IoUringSqe; path: cstring; flags: cint) {.
    importc: "io_uring_prep_unlink".}

proc ioUringPrepRenameat*(sqe: ptr IoUringSqe; olddfd: cint; oldpath: cstring;
                         newdfd: cint; newpath: cstring; flags: cuint) {.
    importc: "io_uring_prep_renameat".}

proc ioUringPrepRename*(sqe: ptr IoUringSqe; oldpath: cstring; newpath: cstring) {.
    importc: "io_uring_prep_rename".}

proc ioUringPrepSyncFileRange*(sqe: ptr IoUringSqe; fd: cint; len: cuint; offset: U64;
                              flags: cint) {.
    importc: "io_uring_prep_sync_file_range".}

proc ioUringPrepMkdirat*(sqe: ptr IoUringSqe; dfd: cint; path: cstring; mode: ModeT) {.
    importc: "io_uring_prep_mkdirat".}
proc ioUringPrepMkdir*(sqe: ptr IoUringSqe; path: cstring; mode: ModeT) {.
    importc: "io_uring_prep_mkdir".}

proc ioUringPrepSymlinkat*(sqe: ptr IoUringSqe; target: cstring; newdirfd: cint;
                          linkpath: cstring) {.importc: "io_uring_prep_symlinkat".}

proc ioUringPrepSymlink*(sqe: ptr IoUringSqe; target: cstring; linkpath: cstring) {.
    importc: "io_uring_prep_symlink".}

proc ioUringPrepLinkat*(sqe: ptr IoUringSqe; olddfd: cint; oldpath: cstring;
                       newdfd: cint; newpath: cstring; flags: cint) {.
    importc: "io_uring_prep_linkat".}

proc ioUringPrepLink*(sqe: ptr IoUringSqe; oldpath: cstring; newpath: cstring;
                     flags: cint) {.importc: "io_uring_prep_link".}

proc ioUringPrepMsgRingCqeFlags*(sqe: ptr IoUringSqe; fd: cint; len: cuint; data: U64;
                                flags: cuint; cqeFlags: cuint) {.
    importc: "io_uring_prep_msg_ring_cqe_flags".}

proc ioUringPrepMsgRing*(sqe: ptr IoUringSqe; fd: cint; len: cuint; data: U64;
                        flags: cuint) {.importc: "io_uring_prep_msg_ring".}

proc ioUringPrepMsgRingFd*(sqe: ptr IoUringSqe; fd: cint; sourceFd: cint;
                          targetFd: cint; data: U64; flags: cuint) {.
    importc: "io_uring_prep_msg_ring_fd".}

proc ioUringPrepGetxattr*(sqe: ptr IoUringSqe; name: cstring; value: cstring;
                         path: cstring; len: cuint) {.
    importc: "io_uring_prep_getxattr".}

proc ioUringPrepSetxattr*(sqe: ptr IoUringSqe; name: cstring; value: cstring;
                         path: cstring; flags: cint; len: cuint) {.
    importc: "io_uring_prep_setxattr".}

proc ioUringPrepFgetxattr*(sqe: ptr IoUringSqe; fd: cint; name: cstring; value: cstring;
                          len: cuint) {.importc: "io_uring_prep_fgetxattr".}

proc ioUringPrepFsetxattr*(sqe: ptr IoUringSqe; fd: cint; name: cstring; value: cstring;
                          flags: cint; len: cuint) {.
    importc: "io_uring_prep_fsetxattr".}

proc ioUringPrepSocket*(sqe: ptr IoUringSqe; domain: cint; `type`: cint; protocol: cint;
                       flags: cuint) {.importc: "io_uring_prep_socket".}

proc ioUringPrepSocketDirect*(sqe: ptr IoUringSqe; domain: cint; `type`: cint;
                             protocol: cint; fileIndex: cuint; flags: cuint) {.
    importc: "io_uring_prep_socket_direct".}

proc ioUringPrepSocketDirectAlloc*(sqe: ptr IoUringSqe; domain: cint; `type`: cint;
                                  protocol: cint; flags: cuint) {.
    importc: "io_uring_prep_socket_direct_alloc".}

proc ioUringSqReady*(ring: ref IoUring): cuint {.importc: "io_uring_sq_ready".}

proc ioUringSqSpaceLeft*(ring: ref IoUring): cuint {.
    importc: "io_uring_sq_space_left".}

proc ioUringSqringWait*(ring: ref IoUring): cint {.importc: "io_uring_sqring_wait".}

proc ioUringCqReady*(ring: ref IoUring): cuint {.importc: "io_uring_cq_ready".}

proc ioUringCqHasOverflow*(ring: ref IoUring): bool {.
    importc: "io_uring_cq_has_overflow".}

proc ioUringCqEventfdEnabled*(ring: ref IoUring): bool {.
    importc: "io_uring_cq_eventfd_enabled".}

proc ioUringCqEventfdToggle*(ring: ref IoUring; enabled: bool): cint {.
    importc: "io_uring_cq_eventfd_toggle".}

proc ioUringWaitCqeNr*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe; waitNr: cuint): cint {.
    importc: "io_uring_wait_cqe_nr".}

proc ioUringPeekCqe*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe): cint {.
    importc: "io_uring_peek_cqe".}

proc ioUringWaitCqe*(ring: ref IoUring; cqePtr: ptr ptr IoUringCqe): cint {.
    importc: "io_uring_wait_cqe".}

proc ioUringBufRingMask*(ringEntries: U32): cint {.importc: "io_uring_buf_ring_mask".}

proc ioUringBufRingInit*(br: ref IoUringBufRing) {.importc: "io_uring_buf_ring_init".}

proc ioUringBufRingAdd*(br: ref IoUringBufRing; `addr`: pointer; len: cuint;
                       bid: cushort; mask: cint; bufOffset: cint) {.
    importc: "io_uring_buf_ring_add".}

proc ioUringBufRingAdvance*(br: ref IoUringBufRing; count: cint) {.
    importc: "io_uring_buf_ring_advance".}

proc ioUringBufRingCqAdvance*(ring: ref IoUring; br: ref IoUringBufRing; count: cint) {.
    importc: "io_uring_buf_ring_cq_advance".}

proc ioUringGetSqe*(ring: ref IoUring): ptr IoUringSqe {.importc: "io_uring_get_sqe".}
proc ioUringMlockSize*(entries: cuint; flags: cuint): SsizeT {.
    importc: "io_uring_mlock_size", header: "<liburing.h>".}
proc ioUringMlockSizeParams*(entries: cuint; p: ref IoUringParams): SsizeT {.
    importc: "io_uring_mlock_size_params", header: "<liburing.h>".}
proc ioUringMajorVersion*(): cint {.importc: "io_uring_major_version",
                                 header: "<liburing.h>".}

proc ioUringMinorVersion*(): cint {.importc: "io_uring_minor_version",
                                 header: "<liburing.h>".}
proc ioUringCheckVersion*(major: cint; minor: cint): bool {.
    importc: "io_uring_check_version", header: "<liburing.h>".}

{.pop.}