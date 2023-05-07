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
    rwFlags*: KernelRwfT ## rw_flags, specified for read and write operations,
                         ## contains a bitwise OR of per-I/O flags, as described in the preadv2(2) man page.
    fsyncFlags*: FsyncFlags ## The fsync_flags bit mask may contain either 0, for a normal file integrity sync,
                            ## or IORING_FSYNC_DATASYNC to provide data sync only semantics.
                            ## See the descriptions of O_SYNC and O_DSYNC in the open(2) manual page for more information.
    pollEvents*: PollFlags ##  The bits that may be set in poll_events are defined in <poll.h>, and documented in poll(2).
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
    bufIndex*: uint16 ## buf_index is an index into an array of fixed buffers, and is only valid if fixed buffers were registered.
    bufGroup*: uint16 ## for grouped buffer selection
  
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
    ioprio*: IoprioFlags ##  ioprio specifies the I/O priority. See ioprio_get(2) for a description of Linux I/O priorities.
    fd*: FileHandle   ##  file descriptor to do IO on
    off*: InnerSqeOffset
    `addr`*: InnerSqeAddr
    len*: int32 ##  buffer size or number of iovecs
    opFlags*: InnerSqeFlags
    userData*: pointer ## user_data is an application-supplied value that will be copied into the completion queue entry (see below).
    buf*: InnerSqeBuf
    personality*: uint16 ##  personality is the credentials id to use for this operation. See io_uring_register(2) for how to register personalities with io_uring.
                         ## If set to 0, the current personality of the submitting task is used.
    splice*: InnerSqeSplice
    cmd*: InnerSqeCmd

  Op* {.size: sizeof(uint8).} = enum
    ## The opcode describes the operation to be performed. It can be one of:
    ## 
    ## see man page: https://man7.org/linux/man-pages/man2/io_uring_enter.2.html
    ## 
    ## If the operation is one of IORING_OP_READ_FIXED or IORING_OP_WRITE_FIXED,
    ## addr and len must fall within the buffer located at buf_index in the fixed buffer array.
    ## If the operation is either IORING_OP_READV or IORING_OP_WRITEV, then addr points to an iovec array of len entries.
    ## 
    OP_NOP ## Do not perform any I/O. This is useful for testing the performance of the io_uring implementation itself.
    OP_READV
    OP_WRITEV ## Vectored read and write operations, similar to preadv2(2) and pwritev2(2).
    OP_FSYNC ## File sync. See also fsync(2).
             ## Note that, while I/O is initiated in the order in which it appears in the submission queue, completions are unordered.
             ## For example, an application which places a write I/O followed by an fsync in the submission queue cannot expect the fsync to apply to the write.
             ## The two operations execute in parallel, so the fsync may complete before the write is issued to the storage.
             ## The same is also true for previously issued writes that have not completed prior to the fsync.
    OP_READ_FIXED
    OP_WRITE_FIXED ## Read from or write to pre-mapped buffers. See `register` for details on how to setup a context for fixed reads and writes.
    OP_POLL_ADD ## Poll the `fd` specified in the submission queue entry for the events specified in the `poll_events` field.
                ## Unlike poll or epoll without EPOLLONESHOT, this interface always works in one shot mode.
                ## That is, once the poll operation is completed, it will have to be resubmitted.
    OP_POLL_REMOVE ## Remove an existing poll request. If found, the res field of the struct io_uring_cqe will contain 0.
                   ## If not found, res will contain -ENOENT.
    OP_SYNC_FILE_RANGE ## Issue the equivalent of a sync_file_range (2) on the file descriptor.
                       ## * The `fd` field is the file descriptor to sync,
                       ## * the `off` field holds the offset in bytes,
                       ## * the `len` field holds the length in bytes,
                       ## * and the `flags` field holds the flags for the command.
                       ## See also sync_file_range(2). for the general description of the related system call.
                       ## Available since 5.2.
    OP_SENDMSG ## Issue the equivalent of a sendmsg(2) system call.
               ## * `fd` must be set to the socket file descriptor,
               ## * `addr` must contain a pointer to the msghdr structure,
               ## * `flags` holds the flags associated with the system call.
               ## See also sendmsg(2).
               ## for the general description of the related system call.
               ## Available since 5.3.
    OP_RECVMSG ## Works just like IORING_OP_SENDMSG, except for recvmsg(2) instead.
               ## See the description of IORING_OP_SENDMSG.
               ## Available since 5.3.
    OP_TIMEOUT ## This command will register a timeout operation.
               ## * The `addr` field must contain a pointer to a struct timespec64 structure,
               ## * `len must` contain 1 to signify one timespec64 structure,
               ## * `timeout_flags` may contain IORING_TIMEOUT_ABS for an absolute timeout value,
               ## or 0 for a relative timeout. off may contain a completion event count.
               ## If not set, this defaults to 1.
               ## A timeout will trigger a wakeup event on the completion ring for anyone waiting for events.
               ## A timeout condition is met when either the specified timeout expires, or the specified number of events have completed.
               ## Either condition will trigger the event. io_uring timeouts use the CLOCK_MONOTONIC clock source.
               ## The request will complete with -ETIME if the timeout got completed through expiration of the timer,
               ## or 0 if the timeout got completed through requests completing on their own.
               ## If the timeout was cancelled before it expired, the request will complete with -ECANCELED.
               ## Available since 5.4.
    OP_TIMEOUT_REMOVE ## Attempt to remove an existing timeout operation.
                      ## * `addr` must contain the `user_data` field of the previously issued timeout operation.
                      ## If the specified timeout request is found and cancelled successfully, this request will terminate with a result value of 0.
                      ## If the timeout request was found but expiration was already in progress, this request will terminate with a result value of -EBUSY.
                      ## If the timeout request wasn’t found, the request will terminate with a result value of -ENOENT.
                      ## Available since 5.5.
    OP_ACCEPT ## Issue the equivalent of an accept4(2) system call.
              ## * `fd` must be set to the socket file descriptor,
              ## * `addr` must contain the pointer to the sockaddr structure,
              ## * `addr2` must contain a pointer to the socklen_t addrlen field.
              ## See also accept4(2) for the general description of the related system call.
              ## Available since 5.5.
    OP_ASYNC_CANCEL ## Attempt to cancel an already issued request.
                    ## * `addr` must contain the `user_data` field of the request that should be cancelled.
                    ## The cancellation request will complete with one of the following results codes.
                    ## If found, the res field of the cqe will contain 0. If not found, res will contain -ENOENT.
                    ## If found and attempted cancelled, the res field will contain -EALREADY.
                    ## In this case, the request may or may not terminate.
                    ## In general, requests that are interruptible (like socket IO) will get cancelled, while disk IO requests cannot be cancelled if already started.
                    ## Available since 5.5.
    OP_LINK_TIMEOUT ## This request must be linked with another request through IOSQE_IO_LINK which is described below.
                    ## Unlike IORING_OP_TIMEOUT, IORING_OP_LINK_TIMEOUT acts on the linked request, not the completion queue.
                    ## The format of the command is otherwise like IORING_OP_TIMEOUT, except there’s no completion event count as it’s tied to a specific request.
                    ## If used, the timeout specified in the command will cancel the linked command, unless the linked command completes before the timeout.
                    ## The timeout will complete with -ETIME if the timer expired and the linked request was attempted cancelled,
                    ## or -ECANCELED if the timer got cancelled because of completion of the linked request. Like IORING_OP_TIMEOUT the clock source used is CLOCK_MONOTONIC
                    ## Available since 5.5.
    OP_CONNECT ## Issue the equivalent of a connect(2) system call.
               ## * `fd` must be set to the socket file descriptor,
               ## * `addr` must contain the pointer to the sockaddr structure,
               ## * `off` must contain the socklen_t addrlen field.
               ## See also connect(2) for the general description of the related system call.
               ## Available since 5.5.
    OP_FALLOCATE ## Issue the equivalent of a fallocate(2) system call.
                 ## * `fd` must be set to the file descriptor,
                 ## * `off` must contain the offset on which to operate,
                 ## * `len` must contain the length.
                 ## See also fallocate(2) for the general description of the related system call.
                 ## Available since 5.6.
    OP_OPENAT ## Issue the equivalent of a openat(2) system call.
              ## * `fd` is the dirfd argument,
              ## * `addr` must contain a pointer to the *pathname argument,
              ## * `open_flags` should contain any flags passed in,
              ## * and `mode` is access mode of the file.
              ## See also openat(2) for the general description of the related system call.
              ## Available since 5.6.
    OP_CLOSE ## Issue the equivalent of a close(2) system call.
             ## * `fd` is the file descriptor to be closed.
             ## See also close(2) for the general description of the related system call.
             ## Available since 5.6.
    OP_FILES_UPDATE ## This command is an alternative to using IORING_REGISTER_FILES_UPDATE which then works in an async fashion,
                    ## like the rest of the io_uring commands.
                    ## The arguments passed in are the same.
                    ## * `addr` must contain a pointer to the array of file descriptors,
                    ## * `len` must contain the length of the array,
                    ## * and `off` must contain the offset at which to operate.
                    ## Note that the array of file descriptors pointed to in addr must remain valid until this operation has completed.
                    ## Available since 5.6.
    OP_STATX ## Issue the equivalent of a statx(2) system call.
             ## * `fd` is the dirfd argument,
             ## * `addr` must contain a pointer to the *pathname string,
             ## * `statx_flags` is the flags argument,
             ## * `len` should be the mask argument,
             ## * and `off` must contain a pointer to the statxbuf to be filled in.
             ## See also statx(2) for the general description of the related system call.
             ## Available since 5.6.
    OP_READ
    OP_WRITE ## Issue the equivalent of a read(2) or write(2) system call.
             ## * `fd` is the file descriptor to be operated on,
             ## * `addr` contains the buffer in question,
             ## * and `len` contains the length of the IO operation.
             ## These are non-vectored versions of the IORING_OP_READV and IORING_OP_WRITEV opcodes.
             ## See also read(2) and write(2) for the general description of the related system call.
             ## Available since 5.6.
    OP_FADVISE ## Issue the equivalent of a posix_fadvise(2) system call.
               ## * `fd` must be set to the file descriptor,
               ## * `off` must contain the offset on which to operate,
               ## * `len` must contain the length,
               ## * and `fadvise_advice` must contain the advice associated with the operation.
               ## See also posix_fadvise(2) for the general description of the related system call.
               ## Available since 5.6.
    OP_MADVISE ## Issue the equivalent of a madvise(2) system call.
               ## * `addr` must contain the address to operate on,
               ## * `len` must contain the length on which to operate,
               ## * and `fadvise_advice` must contain the advice associated with the operation.
               ## See also madvise(2) for the general description of the related system call.
               ## Available since 5.6.
    OP_SEND ## Issue the equivalent of a send(2) system call.
            ## * `fd` must be set to the socket file descriptor,
            ## * `addr` must contain a pointer to the buffer,
            ## * `len` denotes the length of the buffer to send,
            ## * and `flags` holds the flags associated with the system call.
            ## See also send(2).
            ## for the general description of the related system call.
            ## Available since 5.6.
    OP_RECV ## Works just like IORING_OP_SEND, except for recv(2) instead.
            ## See the description of IORING_OP_SEND.
            ## Available since 5.6.
    OP_OPENAT2 ## Issue the equivalent of a openat2(2) system call.
               ## * `fd` is the dirfd argument,
               ## * `addr` must contain a pointer to the *pathname argument,
               ## * `len` should contain the size of the open_how structure,
               ## * and `off` should be set to the address of the open_how structure.
               ## See also openat2(2) for the general description of the related system call.
               ## Available since 5.6.
    OP_EPOLL_CTL ## Add, remove or modify entries in the interest list of epoll(7).
                 ## See epoll_ctl(2) for details of the system call.
                 ## * `fd` holds the file descriptor that represents the epoll instance,
                 ## * `addr` holds the file descriptor to add, remove or modify,
                 ## * `len` holds the operation (EPOLL_CTL_ADD, EPOLL_CTL_DEL, EPOLL_CTL_MOD) to perform and,
                 ## * `off` holds a pointer to the epoll_events structure.
                 ## Available since 5.6.
    OP_SPLICE ## Issue the equivalent of a splice(2) system call.
              ## * `splice_fd_in` is the file descriptor to read from,
              ## * `splice_off_in` is a pointer to an offset to read from,
              ## * `fd` is the file descriptor to write to,
              ## * `off` is a pointer to an offset to from which to start writing to.
              ## * `len` contains the number of bytes to copy.
              ## * `splice_flags` contains a bit mask for the flag field associated with the system call.
              ## Please note that one of the file descriptors must refer to a pipe.
              ## See also splice(2) for the general description of the related system call.
              ## Available since 5.7.
    OP_PROVIDE_BUFFERS ##  This command allows an application to register a group of
                      ## buffers to be used by commands that read/receive data.
                      ## Using buffers in this manner can eliminate the need to
                      ## separate the poll + read, which provides a convenient
                      ## point in time to allocate a buffer for a given request.
                      ## It's often infeasible to have as many buffers available as
                      ## pending reads or receive. With this feature, the
                      ## application can have its pool of buffers ready in the
                      ## kernel, and when the file or socket is ready to
                      ## read/receive data, a buffer can be selected for the
                      ## operation.  `fd` must contain the number of buffers to
                      ## provide, `addr` must contain the starting address to add
                      ## buffers from, `len` must contain the length of each buffer
                      ## to add from the range, `buf_group` must contain the group ID
                      ## of this range of buffers, and `off` must contain the
                      ## starting buffer ID of this range of buffers. With that
                      ## set, the kernel adds buffers starting with the memory
                      ## address in `addr`, each with a length of `len`.  Hence the
                      ## application should provide `len` * `fd` worth of memory in
                      ## `addr`.  Buffers are grouped by the group ID, and each
                      ## buffer within this group will be identical in size
                      ## according to the above arguments. This allows the
                      ## application to provide different groups of buffers, and
                      ## this is often used to have differently sized buffers
                      ## available depending on what the expectations are of the
                      ## individual request. When submitting a request that should
                      ## use a provided buffer, the IOSQE_BUFFER_SELECT flag must
                      ## be set, and `buf_group` must be set to the desired buffer
                      ## group ID where the buffer should be selected from.
                      ## Available since 5.7.
    OP_REMOVE_BUFFERS ## Remove buffers previously registered with
                      ## IORING_OP_PROVIDE_BUFFERS.  `fd` must contain the number of
                      ## buffers to remove, and `buf_group` must contain the buffer
                      ## group ID from which to remove the buffers. Available since
                      ## 5.7.
    OP_TEE ## Issue the equivalent of a tee(2) system call.
           ## `splice_fd_in` is the file descriptor to read from, `fd` is
           ## the file descriptor to write to, `len` contains the number
           ## of bytes to copy, and `splice_flags` contains a bit mask for
           ## the flag field associated with the system call.  Please
           ## note that both of the file descriptors must refer to a
           ## pipe. See also tee(2) for the general description of the
           ## related system call. Available since 5.8.
    OP_SHUTDOWN ## Issue the equivalent of a shutdown(2) system call.  `fd` is
                ## the file descriptor to the socket being shutdown, and `len`
                ## must be set to the `how` argument. No no other fields should
                ## be set. Available since 5.11.
    OP_RENAMEAT ## Issue the equivalent of a renameat2(2) system call.  `fd`
                ## should be set to the `olddirfd`, `addr` should be set to the
                ## `oldpath`, `len` should be set to the `newdirfd`, `addr` should be
                ## set to the `oldpath`, `addr2` should be set to the `newpath`,
                ## and finally `rename_flags` should be set to the `flags` passed
                ## in to renameat2(2).  Available since 5.11.
    OP_UNLINKAT ##  Issue the equivalent of a unlinkat2(2) system call.  `fd`
                ## should be set to the `dirfd`, `addr` should be set to the
                ## `pathname`, and `unlink_flags` should be set to the `flags`
                ## being passed in to unlinkat(2).  Available since 5.11.
    OP_MKDIRAT ## Issue the equivalent of a mkdirat2(2) system call.  `fd`
               ## should be set to the `dirfd`, `addr` should be set to the
               ## `pathname`, and `len` should be set to the `mode` being passed
               ## in to mkdirat(2).  Available since 5.15.
    OP_SYMLINKAT ## Issue the equivalent of a symlinkat2(2) system call.  `fd`
                 ## should be set to the `newdirfd`, `addr` should be set to the
                 ## `target` and `addr2` should be set to the `linkpath` being
                 ## passed in to symlinkat(2).  Available since 5.15.
    OP_LINKAT ##  Issue the equivalent of a linkat2(2) system call.  `fd`
              ## should be set to the `olddirfd`, `addr` should be set to the
              ## `oldpath`, `len` should be set to the `newdirfd`, `addr2` should
              ## be set to the `newpath`, and `hardlink_flags` should be set to
              ## the `flags` being passed in to linkat(2).  Available since
              ## 5.15.
    OP_MSG_RING ## Send a message to an io_uring.  `fd` must be set to a file
                ## descriptor of a ring that the application has access to,
                ## `len` can be set to any 32-bit value that the application
                ## wishes to pass on, and `off` should be set any 64-bit value
                ## that the application wishes to send. On the target ring, a
                ## CQE will be posted with the `res` field matching the `len`
                ## set, and a `user_data` field matching the `off` value being
                ## passed in. This request type can be used to either just
                ## wake or interrupt anyone waiting for completions on the
                ## target ring, or it can be used to pass messages via the
                ## two fields. Available since 5.18.
    OP_FSETXATTR
    OP_SETXATTR
    OP_FGETXATTR
    OP_GETXATTR
    OP_SOCKET ## Issue the equivalent of a socket(2) system call.  `fd` must
              ## contain the communication domain, `off` must contain the
              ## communication type, `len` must contain the protocol, and
              ## `rw_flags` is currently unused and must be set to zero. See
              ## also socket(2) for the general description of the related
              ## system call. Available since 5.19.
              ## 
              ## If the `file_index` field is set to a positive number, the
              ## file won't be installed into the normal file table as
              ## usual but will be placed into the fixed file table at
              ## index `file_index - 1`.  In this case, instead of returning
              ## a file descriptor, the result will contain either 0 on
              ## success or an error. If the index points to a valid empty
              ## slot, the installation is guaranteed to not fail. If there
              ## is already a file in the slot, it will be replaced,
              ## similar to IORING_OP_FILES_UPDATE.  Please note that only
              ## io_uring has access to such files and no other syscall can
              ## use them. See IOSQE_FIXED_FILE and IORING_REGISTER_FILES.
              ## 
              ## Available since 5.19.
    OP_URING_CMD
    OP_SEND_ZC ## Issue the zerocopy equivalent of a send(2) system call.
               ## Similar to IORING_OP_SEND, but tries to avoid making
               ## intermediate copies of data. Zerocopy execution is not
               ## guaranteed and may fall back to copying. The request may
               ## also fail with -EOPNOTSUPP , when a protocol doesn't
               ## support zerocopy, in which case users are recommended to
               ## use copying sends instead.
               ## 
               ## The `flags` field of the first `struct io_uring_cqe` may
               ## likely contain IORING_CQE_F_MORE , which means that there
               ## will be a second completion event / notification for the
               ## request, with the `user_data` field set to the same value.
               ## The user must not modify the data buffer until the
               ## notification is posted. The first cqe follows the usual
               ## rules and so its `res` field will contain the number of
               ## bytes sent or a negative error code. The notification's
               ## `res` field will be set to zero and the `flags` field will
               ## contain IORING_CQE_F_NOTIF .  The two step model is needed
               ## because the kernel may hold on to buffers for a long time,
               ## e.g. waiting for a TCP ACK, and having a separate cqe for
               ## request completions allows userspace to push more data
               ## without extra delays. Note, notifications are only
               ## responsible for controlling the lifetime of the buffers,
               ## and as such don't mean anything about whether the data has
               ## atually been sent out or received by the other end. Even
               ## errored requests may generate a notification, and the user
               ## must check for IORING_CQE_F_MORE rather than relying on
               ## the result.
               ## 
               ## `fd` must be set to the socket file descriptor, `addr` must
               ## contain a pointer to the buffer, `len` denotes the length of
               ## the buffer to send, and `msg_flags` holds the flags
               ## associated with the system call. When `addr2 is` non-zero it
               ## points to the address of the target with `addr_len`
               ## specifying its size, turning the request into a sendto(2)
               ## system call equivalent.
               ## 
               ## Available since 6.0.
               ## 
               ## This command also supports the following modifiers in
               ## `ioprio`:
               ##      IORING_RECVSEND_POLL_FIRST If set, io_uring will
               ##      assume the socket is currently full and attempting to
               ##      send data will be unsuccessful. For this case,
               ##      io_uring will arm internal poll and trigger a send of
               ##      the data when there is enough space available.  This
               ##      initial send attempt can be wasteful for the case
               ##      where the socket is expected to be full, setting this
               ##      flag will bypass the initial send attempt and go
               ##      straight to arming poll. If poll does indicate that
               ##      data can be sent, the operation will proceed.
               ## 
               ##      IORING_RECVSEND_FIXED_BUF If set, instructs io_uring
               ##      to use a pre-mapped buffer. The `buf_index` field
               ##      should contain an index into an array of fixed
               ##      buffers. See io_uring_register(2) for details on how
               ##      to setup a context for fixed buffer I/O.
    OP_SENDMSG_ZC
    OP_LAST ## this goes last, obviously
  
  SqeFlag* {.size: sizeof(uint8).} = enum
    SQE_FIXED_FILE ## When this flag is specified,
                   ## fd is an index into the files array registered with the io_uring instance
                   ## (see the IORING_REGISTER_FILES section of the io_uring_register(2) man page).
                   ## Available since 5.1.
    SQE_IO_DRAIN ## When this flag is specified,
                 ## the SQE will not be started before previously submitted SQEs have completed,
                 ## and new SQEs will not be started before this one completes.
                 ## Available since 5.2.
    SQE_IO_LINK ## When this flag is specified, it forms a link with the next SQE in the submission ring.
                ## That next SQE will not be started before this one completes.
                ## This, in effect, forms a chain of SQEs, which can be arbitrarily long.
                ## The tail of the chain is denoted by the first SQE that does not have this flag set.
                ## This flag has no effect on previous SQE submissions, nor does it impact SQEs that are outside of the chain tail.
                ## This means that multiple chains can be executing in parallel, or chains and individual SQEs.
                ## Only members inside the chain are serialized.
                ## A chain of SQEs will be broken, if any request in that chain ends in error.
                ## io_uring considers any unexpected result an error.
                ## This means that, eg, a short read will also terminate the remainder of the chain.
                ## If a chain of SQE links is broken, the remaining unstarted part of the chain will be terminated and completed with -ECANCELED as the error code.
                ## Available since 5.3.
    SQE_IO_HARDLINK ## Like IOSQE_IO_LINK, but it doesn’t sever regardless of the completion result.
                    ## Note that the link will still sever if we fail submitting the parent request,
                    ## hard links are only resilient in the presence of completion results for requests that did submit correctly.
                    ## IOSQE_IO_HARDLINK implies IOSQE_IO_LINK.
                    ## Available since 5.5.
    SQE_ASYNC ## Normal operation for io_uring is to try and issue an sqe as non-blocking first, and if that fails, execute it in an async manner.
              ## To support more efficient overlapped operation of requests that the application knows/assumes will always (or most of the time) block,
              ## the application can ask for an sqe to be issued async from the start.
              ## Available since 5.6.
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
                      ## user_data is copied from the field of the same name in the submission queue entry.
                      ## The primary use case is to store data that the application will need to access upon completion of this particular I/O.
    res*: int32 ##  result code for this event
    flags*: CqeFlags
  
  ## These io_uring-specific errors are returned as a negative value
  ##  in the res field of the completion queue entry.
  ##  EACCES The flags field or opcode in a submission queue entry is
  ##         not allowed due to registered restrictions.  See
  ##         io_uring_register(2) for details on how restrictions work.
  ##  EBADF  The fd field in the submission queue entry is invalid, or
  ##         the IOSQE_FIXED_FILE flag was set in the submission queue
  ##         entry, but no files were registered with the io_uring
  ##         instance.
  ##  EFAULT buffer is outside of the process' accessible address space
  ##  EFAULT IORING_OP_READ_FIXED or IORING_OP_WRITE_FIXED was
  ##         specified in the opcode field of the submission queue
  ##         entry, but either buffers were not registered for this
  ##         io_uring instance, or the address range described by addr
  ##         and len does not fit within the buffer registered at
  ##         buf_index.
  ##  EINVAL The flags field or opcode in a submission queue entry is
  ##         invalid.
  ##  EINVAL The buf_index member of the submission queue entry is
  ##         invalid.
  ##  EINVAL The personality field in a submission queue entry is
  ##         invalid.
  ##  EINVAL IORING_OP_NOP was specified in the submission queue entry,
  ##         but the io_uring context was setup for polling
  ##         (IORING_SETUP_IOPOLL was specified in the call to
  ##         io_uring_setup).
  ##  EINVAL IORING_OP_READV or IORING_OP_WRITEV was specified in the
  ##         submission queue entry, but the io_uring instance has
  ##         fixed buffers registered.
  ##  EINVAL IORING_OP_READ_FIXED or IORING_OP_WRITE_FIXED was
  ##         specified in the submission queue entry, and the buf_index
  ##         is invalid.
  ##  EINVAL IORING_OP_READV, IORING_OP_WRITEV, IORING_OP_READ_FIXED,
  ##         IORING_OP_WRITE_FIXED or IORING_OP_FSYNC was specified in
  ##         the submission queue entry, but the io_uring instance was
  ##         configured for IOPOLLing, or any of addr, ioprio, off,
  ##         len, or buf_index was set in the submission queue entry.
  ##  EINVAL IORING_OP_POLL_ADD or IORING_OP_POLL_REMOVE was specified
  ##         in the opcode field of the submission queue entry, but the
  ##         io_uring instance was configured for busy-wait polling
  ##         (IORING_SETUP_IOPOLL), or any of ioprio, off, len, or
  ##         buf_index was non-zero in the submission queue entry.
  ##  EINVAL IORING_OP_POLL_ADD was specified in the opcode field of
  ##         the submission queue entry, and the addr field was non-
  ##         zero.
  ##  EOPNOTSUPP
  ##         opcode is valid, but not supported by this kernel.
  ##  EOPNOTSUPP
  ##         IOSQE_BUFFER_SELECT was set in the flags field of the
  ##         submission queue entry, but the opcode doesn't support
  ##         buffer selection.         

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
    SETUP_IOPOLL ## Perform busy-waiting for an I/O completion,
                 ## as opposed to getting notifications via an asynchronous IRQ (Interrupt Request).
                 ## The file system (if any) and block device must support polling in order for this to work.
                 ## Busy-waiting provides lower latency, but may consume more CPU resources than interrupt driven I/O.
                 ## Currently, this feature is usable only on a file descriptor opened using the O_DIRECT flag.
                 ## When a read or write is submitted to a polled context,
                 ## the application must poll for completions on the CQ ring by calling `enter`.
                 ## It is illegal to mix and match polled and non-polled I/O on an io_uring instance.

    SETUP_SQPOLL ## When this flag is specified, a kernel thread is created to perform submission queue polling.
                 ## An io_uring instance configured in this way enables an application to issue I/O without ever context switching into the kernel.
                 ## By using the submission queue to fill in new submission queue entries and watching for completions on the completion queue,
                 ## the application can submit and reap I/Os without doing a single system call.

    SETUP_SQ_AFF ## If this flag is specified,
                 ## then the poll thread will be bound to the cpu set in the `sq_thread_cpu` field of the struct `Params`.
                 ## This flag is only meaningful when `SETUP_SQPOLL` is specified.

    SETUP_CQSIZE ## Create the completion queue with struct Params.cq_entries entries.
                 ## The value must be greater than entries, and may be rounded up to the next power-of-two.

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
    FEAT_SINGLE_MMAP ## If this flag is set, the two SQ and CQ rings can be mapped with a single mmap(2) call.
                     ## The SQEs must still be allocated separately. This brings the necessary mmap(2) calls down from three to two.
    FEAT_NODROP ## If this flag is set, io_uring supports never dropping completion events.
                ## If a completion event occurs and the CQ ring is full,
                ## the kernel stores the event internally until such a time that the CQ ring has room for more entries.
                ## If this overflow condition is entered, attempting to submit more IO with fail with the -EBUSY error value,
                ## if it can’t flush the overflown events to the CQ ring.
                ## If this happens, the application must reap events from the CQ ring and attempt the submit again.
    FEAT_SUBMIT_STABLE ## If this flag is set, applications can be certain that any data for async offload has been consumed when the kernel has consumed the SQE.
    FEAT_RW_CUR_POS ## If this flag is set, applications can specify offset == -1 with `OP_{READV,WRITEV}`, `OP_{READ,WRITE}_FIXED`,
                    ## and `OP_{READ,WRITE}` to mean current file position,
                    ## which behaves like preadv2(2) and pwritev2(2) with offset == -1.
                    ## It’ll use (and update) the current file position.
                    ## This obviously comes with the caveat that if the application has multiple reads or writes in flight,
                    ## then the end result will not be as expected.
                    ## This is similar to threads sharing a file descriptor and doing IO using the current file position.
    FEAT_CUR_PERSONALITY ## If this flag is set, then io_uring guarantees
                         ## that both sync and async execution of a request assumes the credentials of the task
                         ## that called `enter` to queue the requests.
                         ## If this flag isn’t set, then requests are issued with the credentials of the task that originally registered the io_uring.
                         ## If only one task is using a ring, then this flag doesn’t matter as the credentials will always be the same.
                         ## Note that this is the default behavior, tasks can still register different personalities through `register` with REGISTER_PERSONALITY
                         ## and specify the personality to use in the sqe.
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

type
  EnterFlag* {.size: sizeof(cint).} = enum
    ENTER_GETEVENTS ## If this flag is set, then the system call will wait for
                    ## the specified number of events in min_complete before
                    ## returning. This flag can be set along with to_submit to
                    ## both submit and complete events in a single system call.
    ENTER_SQ_WAKEUP ##  If the ring has been created with IORING_SETUP_SQPOLL,
                    ## then this flag asks the kernel to wakeup the SQ kernel
                    ## thread to submit IO.
    ENTER_SQ_WAIT ## If the ring has been created with IORING_SETUP_SQPOLL,
                  ## then the application has no real insight into when the SQ
                  ## kernel thread has consumed entries from the SQ ring. This
                  ## can lead to a situation where the application can no
                  ## longer get a free SQE entry to submit, without knowing
                  ## when it one becomes available as the SQ kernel thread
                  ## consumes them. If the system call is used with this flag
                  ## set, then it will wait until at least one entry is free in
                  ## the SQ ring.
    ENTER_EXT_ARG ## Since kernel 5.11, the system calls arguments have been
                  ## modified to look like the following:
                  ## 
                  ## int io_uring_enter2(unsigned int fd, unsigned int to_submit,
                  ##                     unsigned int min_complete, unsigned int flags,
                  ##                     const void *arg, size_t argsz);
                  ## 
                  ## which behaves just like the original definition by
                  ## default. However, if IORING_ENTER_EXT_ARG is set, then
                  ## instead of a sigset_t being passed in, a pointer to a
                  ## struct io_uring_getevents_arg is used instead and argsz
                  ## must be set to the size of this structure. The definition
                  ## is as follows:
                  ## 
                  ## struct io_uring_getevents_args {
                  ##         __u64   sigmask;
                  ##         __u32   sigmask_sz;
                  ##         __u32   pad;
                  ##         __u64   ts;
                  ## };
                  ## 
                  ## which allows passing in both a signal mask as well as
                  ## pointer to a struct __kernel_timespec timeout value. If ts
                  ## is set to a valid pointer, then this time value indicates
                  ## the timeout for waiting on events. If an application is
                  ## waiting on events and wishes to stop waiting after a
                  ## specified amount of time, then this can be accomplished
                  ## directly in version 5.11 and newer by using this feature.
    ENTER_REGISTERED_RING ## If the ring file descriptor has been registered through
                          ## use of IORING_REGISTER_RING_FDS, then setting this flag
                          ## will tell the kernel that the ring_fd passed in is the
                          ## registered ring offset rather than a normal file
  EnterFlags* = set[EnterFlag]

proc syscall(arg: cint): cint {.importc, header: "<unistd.h>", varargs.}
var
  SYS_io_uring_setup {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_enter {.importc, header: "<sys/syscall.h>".}: cint
  SYS_io_uring_register {.importc, header: "<sys/syscall.h>".}: cint

proc setup*(entries: cint, params: ptr Params): FileHandle =
  ## The io_uring_setup() system call sets up a submission queue (SQ) and completion queue (CQ)
  ## with at least entries `entries`, and returns a file descriptor
  ## which can be used to perform subsequent operations on the io_uring instance.
  ## The submission and completion queues are shared between userspace and the kernel,
  ## which eliminates the need to copy data when initiating and completing I/O.
  ## 
  ## params is used by the application to pass options to the kernel, and by the kernel to convey information about the ring buffers.
  ## 
  ## setup returns a new file descriptor on success.
  ## The application may then provide the file descriptor in a subsequent mmap(2) call to map the submission and completion queues,
  ## or to the `register` or `enter` system calls.
  ## 
  ## On error, -1 is returned and errno is set appropriately.
  ## * EFAULT  params is outside your accessible address space.
  ## * EINVAL  The resv array contains non-zero data, p.flags contains an unsupported flag,
  ##           entries is out of bounds, IORING_SETUP_SQ_AFF was specified, but IORING_SETUP_SQPOLL was not,
  ##           or IORING_SETUP_CQSIZE was specified, but io_uring_params.cq_entries was invalid.
  ## * EMFILE  The per-process limit on the number of open file descriptors has been reached
  ##           (see the description of RLIMIT_NOFILE in getrlimit(2)).
  ## * ENFILE  The system-wide limit on the total number of open files has been reached.
  ## * ENOMEM  Insufficient kernel resources are available.
  ## * EPERM   SETUP_SQPOLL was specified, but the effective user ID of the caller did not have sufficient privileges.
  ## 
  ## See also:
  ## https://man7.org/linux/man-pages/man2/io_uring_setup.2.html
  result = syscall(SYS_io_uring_setup, entries, params, 0, 0, 0, 0)
  if result < 0:
    raiseOSError osLastError()

## If the kernel thread is idle for more than sq_thread_idle milliseconds,
## it will set the `SQ_NEED_WAKEUP` bit in the flags field of the struct `SqRing`.
## When this happens, the application must call `enter` to wake the kernel thread.
## If I/O is kept busy, the kernel thread will never sleep.
## An application making use of this feature will need to guard the `enter` call with the following code sequence:
## 
## ```
## # Ensure that the wakeup flag is read after the tail pointer has been written.
## smp_mb()
## if SqNeedWakeup in queue.sq.flags[]:
##   enter(queue.fd, 0, 0, EnterSqWakeup);
## ```
## 
## To successfully use this feature,
## the application must register a set of files to be used for IO through `register` using the REGISTER_FILES opcode.
## Failure to do so will result in submitted IO being errored with `EBADF`.

## If no flags are specified, the io_uring instance is setup for interrupt driven I/O.
## I/O may be submitted using `enter` and can be reaped by polling the completion queue.
## 
## The resv array must be initialized to zero.
## 
## `features` is filled in by the kernel, which specifies various features supported by current kernel version.

## The rest of the fields in the struct `Params` are filled in by the kernel,
## and provide the information necessary to memory map the submission queue, completion queue,
## and the array of submission queue entries. sq_entries specifies the number of submission queue entries allocated.
## sq_off describes the offsets of various ring buffer fields
## 
## Taken together, sq_entries and sq_off provide all of the information necessary for accessing the submission queue ring buffer
## and the submission queue entry array.
## 
## The submission queue can be mapped with a call like:
## ```
## ptr = mmap(0, sq_off.array + sq_entries * sizeof(uint32),
##            PROT_READ|PROT_WRITE, MAP_SHARED|MAP_POPULATE,
##            ring_fd, OFF_SQ_RING)
## ```
## where sq_off is the `SqringOffsets` structure, and ring_fd is the file descriptor returned from `setup`.
## The addition of sq_off.array to the length of the region accounts for the fact that the ring located at the end of the data structure.
## As an example, the ring buffer head pointer can be accessed by adding sq_off.head to the address returned from mmap(2):
## ```
## head = ptr + sq_off.head
## ```
## 
## The flags field is used by the kernel to communicate state information to the application.
## Currently, it is used to inform the application when a call to `enter` is necessary.
## See the documentation for the SETUP_SQPOLL flag above.
## The dropped member is incremented for each invalid submission queue entry encountered in the ring buffer.
## 
## The head and tail track the ring buffer state.
## The tail is incremented by the application when submitting new I/O,
## and the head is incremented by the kernel when the I/O has been successfully submitted.
## Determining the index of the head or tail into the ring is accomplished by applying a mask:
## ```
## index = tail & ring_mask
## ```
## 
## The array of submission queue entries is mapped with:
## ```
## sqentries = mmap(0, sq_entries * sizeof(struct io_uring_sqe),
##                  PROT_READ|PROT_WRITE, MAP_SHARED|MAP_POPULATE,
##                  ring_fd, OFF_SQES)
## ```
## 
## The completion queue is described by cq_entries and CqringOffsets structure
## The completion queue is simpler, since the entries are not separated from the queue itself, and can be mapped with:
## ```
## ptr = mmap(0, cq_off.cqes + cq_entries * sizeof(struct io_uring_cqe),
##            PROT_READ|PROT_WRITE, MAP_SHARED|MAP_POPULATE, ring_fd,
##            OFF_CQ_RING);
## ```
## 
## Closing the file descriptor returned by `setup` will free all resources associated with the io_uring context.

proc enter*(fd: cint, toSubmit: cint, minComplete: cint,
                         flags: cint, sig: ref Sigset, sz: cint): cint =
  ## enter is used to initiate and complete I/O using the shared submission and completion queues setup by a call to `setup`.
  ## A single call can both submit new I/O and wait for completions of I/O initiated by this call or previous calls to `enter()`.
  ## 
  ## * `fd` is the file descriptor returned by `setup`.
  ## * `to_submit` specifies the number of I/Os to submit from the submission queue.
  ## 
  ## * If the ENTER_GETEVENTS bit is set in flags, then the system call will attempt to wait for `min_complete` event completions before returning.
  ## 
  ##   If the io_uring instance was configured for polling, by specifying SETUP_IOPOLL in the call to `setup`,
  ##   then min_complete has a slightly different meaning.
  ##   Passing a value of 0 instructs the kernel to return any events which are already complete, without blocking.
  ##   If min_complete is a non-zero value, the kernel will still return immediately if any completion events are available.
  ##   If no event completions are available, then the call will poll either until one or more completions become available,
  ##   or until the process has exceeded its scheduler time slice.
  ## 
  ## ..note:
  ##   for interrupt driven I/O (where IORING_SETUP_IOPOLL was not specified in the call to io_uring_setup(2)),
  ##   an application may check the completion queue for event completions without entering the kernel at all.
  ##   When the system call returns that a certain amount of SQEs have been consumed and submitted,
  ##   it’s safe to reuse SQE entries in the ring. This is true even if the actual IO submission had to be punted to async context,
  ##   which means that the SQE may in fact not have been submitted yet. If the kernel requires later use of a particular SQE entry,
  ##   it will have made a private copy of it.
  ## 
  ## * sig is a pointer to a signal mask (see `sigprocmask(2)`);
  ##   if sig is not NULL, `enter` first replaces the current signal mask by the one pointed to by sig,
  ##   then waits for events to become available in the completion queue,
  ##   and then restores the original signal mask. The following `enter` call:
  ## ```
  ## ret = enter(fd, 0, 1, ENTER_GETEVENTS, sig[])
  ## ```
  ## is equivalent to atomically executing the following calls:
  ## ```
  ## pthread_sigmask(SIG_SETMASK, sig[], orig[])
  ## ret = io_uring_enter(fd, 0, 1, ENTER_GETEVENTS, NULL)
  ## pthread_sigmask(SIG_SETMASK, orig[], NULL)
  ## See the description of pselect(2) for an explanation of why the sig parameter is necessary.
  ## ```
  ## 
  ## Once the submission queue entry is initialized, I/O is submitted by placing the index of the submission queue entry into the tail of the submission queue.
  ## After one or more indexes are added to the queue, and the queue tail is advanced, the io_uring_enter(2) system call can be invoked to initiate the I/O.
  ## 
  ## io_uring_enter() returns the number of I/Os successfully consumed.
  ## This can be zero if `to_submit` was zero or if the submission queue was empty.
  ## The errors below that refer to an error in a submission queue entry will be returned though a completion queue entry,
  ## rather than through the system call itself.
  ## Errors that occur not on behalf of a submission queue entry are returned via the system call directly.
  ## On such an error, -1 is returned and errno is set appropriately.
  ## 
  ## These are the errors returned by io_uring_enter(2) system call.
  ## * EAGAIN The kernel was unable to allocate memory for the request,
  ##          or otherwise ran out of resources to handle it. The
  ##          application should wait for some completions and try
  ##          again.
  ## * EBADF  fd is not a valid file descriptor.
  ## * EBADFD fd is a valid file descriptor, but the io_uring ring is
  ##          not in the right state (enabled). See io_uring_register(2)
  ##          for details on how to enable the ring.
  ## * EBADR  At least one CQE was dropped even with the
  ##          IORING_FEAT_NODROP feature, and there are no otherwise
  ##          available CQEs. This clears the error state and so with no
  ##          other changes the next call to io_uring_setup(2) will not
  ##          have this error. This error should be extremely rare and
  ##          indicates the machine is running critically low on memory
  ##          and. It may be reasonable for the application to terminate
  ##          running unless it is able to safely handle any CQE being
  ##          lost.
  ## * EBUSY  If the IORING_FEAT_NODROP feature flag is set, then EBUSY
  ##          will be returned if there were overflow entries,
  ##          IORING_ENTER_GETEVENTS flag is set and not all of the
  ##          overflow entries were able to be flushed to the CQ ring.
  ##          Without IORING_FEAT_NODROP the application is attempting
  ##          to overcommit the number of requests it can have pending.
  ##          The application should wait for some completions and try
  ##          again. May occur if the application tries to queue more
  ##          requests than we have room for in the CQ ring, or if the
  ##          application attempts to wait for more events without
  ##          having reaped the ones already present in the CQ ring.
  ## * EINVAL Some bits in the flags argument are invalid.
  ## * EFAULT An invalid user space address was specified for the sig
  ##          argument.
  ## * ENXIO  The io_uring instance is in the process of being torn
  ##          down.
  ## * EOPNOTSUPP
  ##          fd does not refer to an io_uring instance.
  ## * EINTR  The operation was interrupted by a delivery of a signal
  ##          before it could complete; see signal(7).  Can happen while
  ##          waiting for events with IORING_ENTER_GETEVENTS.
  ## https://man7.org/linux/man-pages/man2/io_uring_enter.2.html
  result = syscall(SYS_io_uring_enter, fd, toSubmit, minComplete, flags, sig, sz)
  if result < 0:
    raiseOSError osLastError()

proc register*(fd: cint, op: cint, arg: pointer, nr_args: cint): cint =
  ##  The io_uring_register(2) system call registers resources (e.g.
  ##  user buffers, files, eventfd, personality, restrictions) for use
  ##  in an io_uring(7) instance referenced by `fd`.  Registering files
  ##  or user buffers allows the kernel to take long term references to
  ##  internal data structures or create long term mappings of
  ##  application memory, greatly reducing per-I/O overhead.
  ## 
  ##  `fd` is the file descriptor returned by a call to
  ##  io_uring_setup(2).  `opcode` can be one of `RegisterOp`
  ## 
  ##  On success, io_uring_register(2) returns either 0 or a positive
  ##  value, depending on the opcode used.  On error, a negative error
  ##  value is returned. The caller should not rely on the errno
  ##  variable.
  ## 
  ## Errors:
  ## EACCES The opcode field is not allowed due to registered
  ##         restrictions.
  ##  EBADF  One or more fds in the fd array are invalid.
  ##  EBADFD IORING_REGISTER_ENABLE_RINGS or
  ##         IORING_REGISTER_RESTRICTIONS was specified, but the
  ##         io_uring ring is not disabled.
  ##  EBUSY  IORING_REGISTER_BUFFERS or IORING_REGISTER_FILES or
  ##         IORING_REGISTER_RESTRICTIONS was specified, but there were
  ##         already buffers, files, or restrictions registered.
  ##  EFAULT buffer is outside of the process' accessible address
  ##         space, or iov_len is greater than 1GiB.
  ##  EINVAL IORING_REGISTER_BUFFERS or IORING_REGISTER_FILES was
  ##         specified, but nr_args is 0.
  ##  EINVAL IORING_REGISTER_BUFFERS was specified, but nr_args exceeds
  ##         UIO_MAXIOV
  ##  EINVAL IORING_UNREGISTER_BUFFERS or IORING_UNREGISTER_FILES was
  ##         specified, and nr_args is non-zero or arg is non-NULL.
  ##  EINVAL IORING_REGISTER_RESTRICTIONS was specified, but nr_args
  ##         exceeds the maximum allowed number of restrictions or
  ##         restriction opcode is invalid.
  ##  EMFILE IORING_REGISTER_FILES was specified and nr_args exceeds
  ##         the maximum allowed number of files in a fixed file set.
  ##  EMFILE IORING_REGISTER_FILES was specified and adding nr_args
  ##         file references would exceed the maximum allowed number of
  ##         files the user is allowed to have according to the
  ##         RLIMIT_NOFILE resource limit and the caller does not have
  ##         CAP_SYS_RESOURCE capability. Note that this is a per user
  ##         limit, not per process.
  ##  ENOMEM Insufficient kernel resources are available, or the caller
  ##         had a non-zero RLIMIT_MEMLOCK soft resource limit, but
  ##         tried to lock more memory than the limit permitted.  This
  ##         limit is not enforced if the process is privileged
  ##         (CAP_IPC_LOCK).
  ##  ENXIO  IORING_UNREGISTER_BUFFERS or IORING_UNREGISTER_FILES was
  ##         specified, but there were no buffers or files registered.
  ##  ENXIO  Attempt to register files or buffers on an io_uring
  ##         instance that is already undergoing file or buffer
  ##         registration, or is being torn down.
  ##  EOPNOTSUPP
  ##         User buffers point to file-backed memory.
  ## https://man7.org/linux/man-pages/man2/io_uring_register.2.html
  result = syscall(SYS_io_uring_register, fd, op, arg, nr_args, 0, 0)
  if result < 0:
    raiseOSError osLastError()

type
  ## io_uring_register(2) opcodes and arguments
  RegisterOp* {.size: sizeof(cint).} = enum
    REGISTER_BUFFERS ## arg points to a struct iovec array of nr_args entries.
                     ## The buffers associated with the iovecs will be locked in
                     ## memory and charged against the user's RLIMIT_MEMLOCK
                     ## resource limit.  See getrlimit(2) for more information.
                     ## Additionally, there is a size limit of 1GiB per buffer.
                     ## Currently, the buffers must be anonymous, non-file-backed
                     ## memory, such as that returned by malloc(3) or mmap(2) with
                     ## the MAP_ANONYMOUS flag set.  It is expected that this
                     ## limitation will be lifted in the future. Huge pages are
                     ## supported as well. Note that the entire huge page will be
                     ## pinned in the kernel, even if only a portion of it is
                     ## used.
                     ## 
                     ## After a successful call, the supplied buffers are mapped
                     ## into the kernel and eligible for I/O.  To make use of
                     ## them, the application must specify the
                     ## IORING_OP_READ_FIXED or IORING_OP_WRITE_FIXED opcodes in
                     ## the submission queue entry (see the struct io_uring_sqe
                     ## definition in io_uring_enter(2)), and set the buf_index
                     ## field to the desired buffer index.  The memory range
                     ## described by the submission queue entry's addr and len
                     ## fields must fall within the indexed buffer.
                     ## 
                     ## It is perfectly valid to setup a large buffer and then
                     ## only use part of it for an I/O, as long as the range is
                     ## within the originally mapped region.
                     ## 
                     ## An application can increase or decrease the size or number
                     ## of registered buffers by first unregistering the existing
                     ## buffers, and then issuing a new call to
                     ## io_uring_register(2) with the new buffers.
                     ## 
                     ## Note that before 5.13 registering buffers would wait for
                     ## the ring to idle.  If the application currently has
                     ## requests in-flight, the registration will wait for those
                     ## to finish before proceeding.
                     ## 
                     ## An application need not unregister buffers explicitly
                     ## before shutting down the io_uring instance. Available
                     ## since 5.1.
    UNREGISTER_BUFFERS ## This operation takes no argument, and arg must be passed
                       ## as NULL.  All previously registered buffers associated
                       ## with the io_uring instance will be released. Available
                       ## since 5.1.
    REGISTER_FILES ## Register files for I/O.  arg contains a pointer to an
                   ## array of nr_args file descriptors (signed 32 bit
                   ## integers).
                   ## 
                   ## To make use of the registered files, the IOSQE_FIXED_FILE
                   ## flag must be set in the flags member of the struct
                   ## io_uring_sqe, and the fd member is set to the index of the
                   ## file in the file descriptor array.
                   ## 
                   ## The file set may be sparse, meaning that the fd field in
                   ## the array may be set to -1.  See
                   ## IORING_REGISTER_FILES_UPDATE for how to update files in
                   ## place.
                   ## 
                   ## Note that before 5.13 registering files would wait for the
                   ## ring to idle.  If the application currently has requests
                   ## in-flight, the registration will wait for those to finish
                   ## before proceeding. See IORING_REGISTER_FILES_UPDATE for
                   ## how to update an existing set without that limitation.
                   ## 
                   ## Files are automatically unregistered when the io_uring
                   ## instance is torn down. An application needs only
                   ## unregister if it wishes to register a new set of fds.
                   ## Available since 5.1.
    UNREGISTER_FILES ## This operation requires no argument, and arg must be
                     ## passed as NULL.  All previously registered files
                     ## associated with the io_uring instance will be
                     ## unregistered. Available since 5.1.
    REGISTER_EVENTFD ## It's possible to use eventfd(2) to get notified of
                     ## completion events on an io_uring instance. If this is
                     ## desired, an eventfd file descriptor can be registered
                     ## through this operation.  arg must contain a pointer to the
                     ## eventfd file descriptor, and nr_args must be 1. Note that
                     ## while io_uring generally takes care to avoid spurious
                     ## events, they can occur. Similarly, batched completions of
                     ## CQEs may only trigger a single eventfd notification even
                     ## if multiple CQEs are posted. The application should make
                     ## no assumptions on number of events being available having
                     ## a direct correlation to eventfd notifications posted. An
                     ## eventfd notification must thus only be treated as a hint
                     ## to check the CQ ring for completions. Available since 5.2.
                     ## 
                     ## An application can temporarily disable notifications,
                     ## coming through the registered eventfd, by setting the
                     ## IORING_CQ_EVENTFD_DISABLED bit in the flags field of the
                     ## CQ ring.  Available since 5.8.
    UNREGISTER_EVENTFD ## Unregister an eventfd file descriptor to stop
                       ## notifications. Since only one eventfd descriptor is
                       ## currently supported, this operation takes no argument, and
                       ## arg must be passed as NULL and nr_args must be zero.
                       ## Available since 5.2.
    REGISTER_FILES_UPDATE ## This operation replaces existing files in the registered
                          ## file set with new ones, either turning a sparse entry (one
                          ## where fd is equal to -1 ) into a real one, removing an
                          ## existing entry (new one is set to -1 ), or replacing an
                          ## existing entry with a new existing entry.
                          ## 
                          ## arg must contain a pointer to a struct
                          ## io_uring_files_update, which contains an offset on which
                          ## to start the update, and an array of file descriptors to
                          ## use for the update.  nr_args must contain the number of
                          ## descriptors in the passed in array. Available since 5.5.
                          ## 
                          ## File descriptors can be skipped if they are set to
                          ## IORING_REGISTER_FILES_SKIP.  Skipping an fd will not touch
                          ## the file associated with the previous fd at that index.
                          ## Available since 5.12.
    REGISTER_EVENTFD_ASYNC ## This works just like IORING_REGISTER_EVENTFD , except
                           ## notifications are only posted for events that complete in
                           ## an async manner. This means that events that complete
                           ## inline while being submitted do not trigger a notification
                           ## event. The arguments supplied are the same as for
                           ## IORING_REGISTER_EVENTFD.  Available since 5.6.
    REGISTER_PROBE ## This operation returns a structure, io_uring_probe, which
                   ## contains information about the opcodes supported by
                   ## io_uring on the running kernel.  arg must contain a
                   ## pointer to a struct io_uring_probe, and nr_args must
                   ## contain the size of the ops array in that probe struct.
                   ## The ops array is of the type io_uring_probe_op, which
                   ## holds the value of the opcode and a flags field. If the
                   ## flags field has IO_URING_OP_SUPPORTED set, then this
                   ## opcode is supported on the running kernel. Available since
                   ## 5.6.
    REGISTER_PERSONALITY ## This operation registers credentials of the running
                         ## application with io_uring, and returns an id associated
                         ## with these credentials. Applications wishing to share a
                         ## ring between separate users/processes can pass in this
                         ## credential id in the sqe personality field. If set, that
                         ## particular sqe will be issued with these credentials. Must
                         ## be invoked with arg set to NULL and nr_args set to zero.
                         ## Available since 5.6.
    UNREGISTER_PERSONALITY ## This operation unregisters a previously registered
                           ## personality with io_uring.  nr_args must be set to the id
                           ## in question, and arg must be set to NULL. Available since
                           ## 5.6.
    REGISTER_RESTRICTIONS ## arg points to a struct io_uring_restriction array of
                          ## nr_args entries.
                          ## 
                          ## With an entry it is possible to allow an
                          ## io_uring_register(2) opcode, or specify which opcode and
                          ## flags of the submission queue entry are allowed, or
                          ## require certain flags to be specified (these flags must be
                          ## set on each submission queue entry).
                          ## 
                          ## All the restrictions must be submitted with a single
                          ## io_uring_register(2) call and they are handled as an
                          ## allowlist (opcodes and flags not registered, are not
                          ## allowed).
                          ## 
                          ## Restrictions can be registered only if the io_uring ring
                          ## started in a disabled state (IORING_SETUP_R_DISABLED must
                          ## be specified in the call to io_uring_setup(2)).
                          ## 
                          ## Available since 5.10.
    REGISTER_ENABLE_RINGS ## This operation enables an io_uring ring started in a
                          ## disabled state (IORING_SETUP_R_DISABLED was specified in
                          ## the call to io_uring_setup(2)).  While the io_uring ring
                          ## is disabled, submissions are not allowed and registrations
                          ## are not restricted.
                          ## 
                          ## After the execution of this operation, the io_uring ring
                          ## is enabled: submissions and registration are allowed, but
                          ## they will be validated following the registered
                          ## restrictions (if any).  This operation takes no argument,
                          ## must be invoked with arg set to NULL and nr_args set to
                          ## zero. Available since 5.10.
    REGISTER_FILES2 ## Register files for I/O. Similar to IORING_REGISTER_FILES.
                    ## arg points to a struct io_uring_rsrc_register, and nr_args
                    ## should be set to the number of bytes in the structure.
                    ## 
                    ## The data field contains a pointer to an array of nr file
                    ## descriptors (signed 32 bit integers).  tags field should
                    ## either be 0 or or point to an array of nr "tags" (unsigned
                    ## 64 bit integers). See IORING_REGISTER_BUFFERS2 for more
                    ## info on resource tagging.
                    ## 
                    ## Note that resource updates, e.g.
                    ## IORING_REGISTER_FILES_UPDATE, don't necessarily deallocate
                    ## resources, they might be held until all requests using
                    ## that resource complete.
                    ## 
                    ## Available since 5.13.
    REGISTER_FILES_UPDATE2 ## Similar to IORING_REGISTER_FILES_UPDATE, replaces existing
                           ## files in the registered file set with new ones, either
                           ## turning a sparse entry (one where fd is equal to -1 ) into
                           ## a real one, removing an existing entry (new one is set to
                           ## -1 ), or replacing an existing entry with a new existing
                           ## entry.
                           ## 
                           ## arg must contain a pointer to a struct
                           ## io_uring_rsrc_update2, which contains an offset on which
                           ## to start the update, and an array of file descriptors to
                           ## use for the update stored in data.  tags points to an
                           ## array of tags.  nr must contain the number of descriptors
                           ## in the passed in arrays.  See IORING_REGISTER_BUFFERS2 for
                           ## the resource tagging description.
                           ## 
                           ## Available since 5.13.
    REGISTER_BUFFERS2 ## Register buffers for I/O. Similar to
                      ## IORING_REGISTER_BUFFERS but aims to have a more extensible
                      ## ABI.
                      ## 
                      ## arg points to a struct io_uring_rsrc_register, and nr_args
                      ## should be set to the number of bytes in the structure.
                      ## 
                      ##  struct io_uring_rsrc_register {
                      ##      __u32 nr;
                      ##      __u32 resv;
                      ##      __u64 resv2;
                      ##      __aligned_u64 data;
                      ##      __aligned_u64 tags;
                      ##  };
                      ##
                      ##  The data field contains a pointer to a struct iovec array
                      ##  of nr entries.  The tags field should either be 0, then
                      ##  tagging is disabled, or point to an array of nr "tags"
                      ##  (unsigned 64 bit integers). If a tag is zero, then
                      ##  tagging for this particular resource (a buffer in this
                      ##  case) is disabled. Otherwise, after the resource had been
                      ##  unregistered and it's not used anymore, a CQE will be
                      ##  posted with user_data set to the specified tag and all
                      ##  other fields zeroed.
                      ## 
                      ##  Note that resource updates, e.g.
                      ##  IORING_REGISTER_BUFFERS_UPDATE, don't necessarily
                      ##  deallocate resources by the time it returns, but they
                      ##  might be held alive until all requests using it complete.
                      ## 
                      ##  Available since 5.13.
    REGISTER_BUFFERS_UPDATE ## Updates registered buffers with new ones, either turning a
                            ## sparse entry into a real one, or replacing an existing
                            ## entry.
                            ## 
                            ## arg must contain a pointer to a struct
                            ## io_uring_rsrc_update2, which contains an offset on which
                            ## to start the update, and an array of struct iovec.  tags
                            ## points to an array of tags.  nr must contain the number of
                            ## descriptors in the passed in arrays.  See
                            ## IORING_REGISTER_BUFFERS2 for the resource tagging
                            ## description.
                            ## 
                            ##  struct io_uring_rsrc_update2 {
                            ##      __u32 offset;
                            ##      __u32 resv;
                            ##      __aligned_u64 data;
                            ##      __aligned_u64 tags;
                            ##      __u32 nr;
                            ##      __u32 resv2;
                            ##  };
                            ## 
                            ##  Available since 5.13.
    REGISTER_IOWQ_AFF ## By default, async workers created by io_uring will inherit
                      ## the CPU mask of its parent. This is usually all the CPUs
                      ## in the system, unless the parent is being run with a
                      ## limited set. If this isn't the desired outcome, the
                      ## application may explicitly tell io_uring what CPUs the
                      ## async workers may run on.  arg must point to a cpu_set_t
                      ## mask, and nr_args the byte size of that mask.
                      ## 
                      ## Available since 5.14.
    UNREGISTER_IOWQ_AFF ## Undoes a CPU mask previously set with
                        ## IORING_REGISTER_IOWQ_AFF.  Must not have arg or nr_args
                        ## set.
                        ## 
                        ## Available since 5.14.
    REGISTER_IOWQ_MAX_WORKERS ## By default, io_uring limits the unbounded workers created
                              ## to the maximum processor count set by RLIMIT_NPROC and the
                              ## bounded workers is a function of the SQ ring size and the
                              ## number of CPUs in the system. Sometimes this can be
                              ## excessive (or too little, for bounded), and this command
                              ## provides a way to change the count per ring (per NUMA
                              ## node) instead.
                              ## 
                              ## arg must be set to an unsigned int pointer to an array of
                              ## two values, with the values in the array being set to the
                              ## maximum count of workers per NUMA node. Index 0 holds the
                              ## bounded worker count, and index 1 holds the unbounded
                              ## worker count. On successful return, the passed in array
                              ## will contain the previous maximum valyes for each type. If
                              ## the count being passed in is 0, then this command returns
                              ## the current maximum values and doesn't modify the current
                              ## setting.  nr_args must be set to 2, as the command takes
                              ## two values.
                              ## 
                              ## Available since 5.15.
    REGISTER_RING_FDS ## Whenever io_uring_enter(2) is called to submit request or
                      ## wait for completions, the kernel must grab a reference to
                      ## the file descriptor. If the application using io_uring is
                      ## threaded, the file table is marked as shared, and the
                      ## reference grab and put of the file descriptor count is
                      ## more expensive than it is for a non-threaded application.
                      ## 
                      ## Similarly to how io_uring allows registration of files,
                      ## this allow registration of the ring file descriptor
                      ## itself. This reduces the overhead of the io_uring_enter(2)
                      ## system call.
                      ## 
                      ## arg must be set to an unsigned int pointer to an array of
                      ## type struct io_uring_rsrc_register of nr_args number of
                      ## entries. The data field of this struct must point to an
                      ## io_uring file descriptor, and the offset field can be
                      ## either -1 or an explicit offset desired for the registered
                      ## file descriptor value. If -1 is used, then upon successful
                      ## return of this system call, the field will contain the
                      ## value of the registered file descriptor to be used for
                      ## future io_uring_enter(2) system calls.
                      ## 
                      ## On successful completion of this request, the returned
                      ## descriptors may be used instead of the real file
                      ## descriptor for io_uring_enter(2), provided that
                      ## IORING_ENTER_REGISTERED_RING is set in the flags for the
                      ## system call. This flag tells the kernel that a registered
                      ## descriptor is used rather than a real file descriptor.
                      ## 
                      ## Each thread or process using a ring must register the file
                      ## descriptor directly by issuing this request.
                      ## 
                      ## The maximum number of supported registered ring
                      ## descriptors is currently limited to 16.
                      ## 
                      ## Available since 5.18.
    UNREGISTER_RING_FDS ## Unregister descriptors previously registered with
                        ## IORING_REGISTER_RING_FDS.
                        ## 
                        ## arg must be set to an unsigned int pointer to an array of
                        ## type struct io_uring_rsrc_register of nr_args number of
                        ## entries. Only the offset field should be set in the
                        ## structure, containing the registered file descriptor
                        ## offset previously returned from IORING_REGISTER_RING_FDS
                        ## that the application wishes to unregister.
                        ## 
                        ## Note that this isn't done automatically on ring exit, if
                        ## the thread or task that previously registered a ring file
                        ## descriptor isn't exiting. It is recommended to manually
                        ## unregister any previously registered ring descriptors if
                        ## the ring is closed and the task persists. This will free
                        ## up a registration slot, making it available for future
                        ## use.
                        ## 
                        ## Available since 5.18.
    REGISTER_PBUF_RING ## Registers a shared buffer ring to be used with provided
                       ## buffers. This is a newer alternative to using
                       ## IORING_OP_PROVIDE_BUFFERS which is more efficient, to be
                       ## used with request types that support the
                       ## IOSQE_BUFFER_SELECT flag.
                       ## 
                       ## The arg argument must be filled in with the appropriate
                       ## information. It looks as follows:
                       ## 
                       ##      struct io_uring_buf_reg {
                       ##          __u64 ring_addr;
                       ##          __u32 ring_entries;
                       ##          __u16 bgid;
                       ##          __u16 pad;
                       ##          __u64 resv[3];
                       ##      };
                       ## 
                       ##  The ring_addr field must contain the address to the
                       ##  memory allocated to fit this ring.  The memory must be
                       ##  page aligned and hence allocated appropriately using eg
                       ##  posix_memalign(3) or similar. The size of the ring is the
                       ##  product of ring_entries and the size of struct
                       ##  io_uring_buf.  ring_entries is the desired size of the
                       ##  ring, and must be a power-of-2 in size. The maximum size
                       ##  allowed is 2^15 (32768).  bgid is the buffer group ID
                       ##  associated with this ring. SQEs that select a buffer have
                       ##  a buffer group associated with them in their buf_group
                       ##  field, and the associated CQEs will have
                       ##  IORING_CQE_F_BUFFER set in their flags member, which will
                       ##  also contain the specific ID of the buffer selected. The
                       ##  rest of the fields are reserved and must be cleared to
                       ##  zero.
                       ## 
                       ##  nr_args must be set to 1.
                       ## 
                       ##  Also see io_uring_register_buf_ring(3) for more details.
                       ##  Available since 5.19.
    UNREGISTER_PBUF_RING ## Unregister a previously registered provided buffer ring.
                         ## arg must be set to the address of a struct
                         ## io_uring_buf_reg, with just the bgid field set to the
                         ## buffer group ID of the previously registered provided
                         ## buffer group.  nr_args must be set to 1. Also see
                         ## IORING_REGISTER_PBUF_RING .
                         ## 
                         ## Available since 5.19.
    REGISTER_SYNC_CANCEL ## Performs a synchronous cancelation request, which works in
                         ## a similar fashion to IORING_OP_ASYNC_CANCEL except it
                         ## completes inline. This can be useful for scenarios where
                         ## cancelations should happen synchronously, rather than
                         ## needing to issue an SQE and wait for completion of that
                         ## specific CQE.
                         ## 
                         ## arg must be set to a pointer to a struct
                         ## io_uring_sync_cancel_reg structure, with the details
                         ## filled in for what request(s) to target for cancelation.
                         ## See io_uring_register_sync_cancel(3) for details on that.
                         ## The return values are the same, except they are passed
                         ## back synchronously rather than through the CQE res field.
                         ## nr_args must be set to 1.
                         ## 
                         ## Available since 6.0.
    REGISTER_FILE_ALLOC_RANGE ## sets the allowable range for fixed file index allocations
                              ## within the kernel. When requests that can instantiate a
                              ## new fixed file are used with IORING_FILE_INDEX_ALLOC , the
                              ## application is asking the kernel to allocate a new fixed
                              ## file descriptor rather than pass in a specific value for
                              ## one. By default, the kernel will pick any available fixed
                              ## file descriptor within the range available.  This
                              ## effectively allows the application to set aside a range
                              ## just for dynamic allocations, with the remainder being
                              ## used for specific values.
                              ## 
                              ## nr_args must be set to 1 and arg must be set to a pointer
                              ## to a struct io_uring_file_index_range:
                              ## 
                              ##      struct io_uring_file_index_range {
                              ##          __u32 off;
                              ##          __u32 len;
                              ##          __u64 resv;
                              ##      };
                              ## 
                              ##  with off being set to the starting value for the range,
                              ##  and len being set to the number of descriptors. The
                              ##  reserved resv field must be cleared to zero.
                              ## 
                              ##  The application must have registered a file table first.
                              ## 
                              ##  Available since 6.0.
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
