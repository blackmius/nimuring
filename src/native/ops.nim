import io_uring
import queue
import posix
import epoll
import std/endians

proc linkNext*(sqe: ptr Sqe) =
  ## When this flag is specified, it forms a link with the next SQE in the submission ring.
  ## That next SQE will not be started before this one completes.
  ## This, in effect, forms a chain of SQEs, which can be arbitrarily long.
  ## The tail of the chain is denoted by the first SQE that does not have this flag set.
  ## This flag has no effect on previous SQE submissions, nor does it impact SQEs that are outside of the chain tail.
  ## This means that multiple chains can be executing in parallel, or chains and individual SQEs.
  ## Only members inside the chain are serialized. A chain of SQEs will be broken, if any request in that chain ends in error.
  ## io_uring considers any unexpected result an error.
  ## This means that, eg, a short read will also terminate the remainder of the chain.
  ## If a chain of SQE links is broken, the remaining unstarted part of the chain
  ## will be terminated and completed with -ECANCELED as the error code. Available since 5.3.
  sqe.flags.incl(SQE_IO_LINK)

proc drainPrevious*(sqe: ptr Sqe) =
  ## When this flag is specified, the SQE will not be started before previously submitted SQEs have completed,
  ## and new SQEs will not be started before this one completes. Available since 5.2.
  sqe.flags.incl(SQE_IO_DRAIN)

proc fsync*(q: var Queue; userData: pointer; fd: FileHandle; flags: FsyncFlags = {}): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform an `fsync(2)`.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the SQE's `rw_flags`.
  ## N.B. While SQEs are initiated in the order in which they appear in the submission queue,
  ## operations execute in parallel and completions are unordered. Therefore, an application that
  ## submits a write followed by an fsync in the submission queue cannot expect the fsync to
  ## apply to the write, since the fsync may complete before the write is issued to the disk.
  ## You should preferably use `linkNext()` on a write's SQE to link it with an fsync,
  ## or else insert a full write barrier using `drainPrevios()` when queueing an fsync.
  result = q.getSqe()
  result.opcode = OP_FSYNC
  result.fd = fd
  result.fsync_flags = flags
  result.userData = userData

proc nop*(q: var Queue; userData: pointer): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a no-op.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## A no-op is more useful than may appear at first glance.
  ## For example, you could call `drainPrevios()` on the returned SQE, to use the no-op to
  ## know when the ring is idle before acting on a kill signal.
  result = q.getSqe()
  result.opcode = OP_NOP
  result.userData = userData


proc prepRw(sqe: ptr Sqe; op: Op; fd: FileHandle; `addr`: pointer; len: int; offset: int = 0) {.inline.} =
  # utility to fill rw operators
  sqe.opcode = op
  sqe.fd = fd
  sqe.off = offset
  sqe.`addr` = `addr`
  sqe.len = len

proc read*(q: var Queue; userData: pointer; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `read(2)`
  ## Reading into a `buffer` uses `read(2)`
  result = q.getSqe()
  result.prepRw(OP_READ, fd, buffer, len, offset)
  result.userData = userData

proc readv*(q: var Queue; userData: pointer; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `preadv` depending on the buffer type.
  ## Reading into a `iovecs` uses `preadv(2)`
  ## If you want to do a `preadv2()` then set `rw_flags` on the returned SQE. See https://linux.die.net/man/2/preadv.
  result = q.getSqe()
  result.prepRw(OP_READV, fd, iovecs[0].unsafeAddr, len(iovecs), offset)
  result.userData = userData

proc read*(q: var Queue; userData: pointer; fd: FileHandle; group_id: uint16, len: int, offset: int = 0): ptr Sqe {.discardable.} =
  ## io_uring will select a buffer that has previously been provided with `provide_buffers`.
  ## The buffer group referenced by `group_id` must contain at least one buffer for the recv call to work.
  ## `len` controls the number of bytes to read into the selected buffer.
  result = q.getSqe()
  result.prepRw(OP_READ, fd, cast[pointer](0), len, offset)
  result.flags.incl(SQE_BUFFER_SELECT)
  result.buf_index = group_id
  result.userData = userData

proc readv_fixed*(q: var Queue; userData: pointer; fd: FileHandle; iovecs: seq[IOVec]; bufferIndex: uint16; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a IORING_OP_READ_FIXED.
  ## The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
  ## The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
  ##
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  result = q.getSqe()
  result.prepRw(OP_READ_FIXED, fd, iovecs[0].unsafeAddr, len(iovecs), offset)
  result.bufIndex = bufferIndex
  result.userData = userData

proc write*(q: var Queue; userData: pointer; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `write(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_WRITE, fd, buffer, len, offset)
  result.userData = userData

proc write*(q: var Queue; userData: pointer; fd: FileHandle; str: string; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `write(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_WRITE, fd, str.cstring, len(str), offset)
  result.userData = userData

proc writev*(q: var Queue; userData: pointer; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `pwritev()`.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## For example, if you want to do a `pwritev2()` then set `rw_flags` on the returned SQE.
  ## See https://linux.die.net/man/2/pwritev.
  result = q.getSqe()
  result.prepRw(OP_WRITEV, fd, iovecs[0].unsafeAddr, len(iovecs), offset)
  result.userData = userData

proc writev_fixed*(q: var Queue; userData: pointer; fd: FileHandle; iovecs: seq[IOVec]; bufferIndex: uint16; offset: int = 0): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a IORING_OP_WRITE_FIXED.
  ## The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
  ## The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
  ##
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  result = q.getSqe()
  result.prepRw(OP_WRITE_FIXED, fd, iovecs[0].unsafeAddr, len(iovecs), offset)
  result.bufIndex = bufferIndex
  result.userData = userData

proc accept*(q: var Queue; userData: pointer; fd: FileHandle, `addr`: SockAddr, addrLen: SockLen, flags: uint16): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_ACCEPT, fd, `addr`.unsafeAddr, 0, addrLen.int)
  result.user_data = user_data;

proc connect*(q: var Queue; userData: pointer; fd: FileHandle, `addr`: SockAddr, addrLen: SockLen): ptr Sqe {.discardable.} =
  ## Queue (but does not submit) an SQE to perform a `connect(2)` on a socket.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_CONNECT, fd, `addr`.unsafeAddr, 0, addrLen.int)
  result.user_data = user_data;

proc epoll_ctl*(q: var Queue; userData: pointer; epfd: FileHandle; fd: FileHandle; op: uint32; ev: ptr EpollEvent): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `epoll_ctl(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_EPOLL_CTL, epfd, ev, op.int, fd)
  result.user_data = user_data;

proc recv*(q: var Queue; userData: pointer; fd: FileHandle; buffer: pointer; len: int; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `recv(2)`.
  ## Returns a pointer to the SQE.
  ## io_uring will recv directly into this buffer
  result = q.getSqe()
  result.prepRw(OP_RECV, fd, buffer, len, 0)
  result.msgFlags = flags
  result.user_data = user_data;

proc send*(q: var Queue; userData: pointer; fd: FileHandle; buffer: pointer; len: int; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `send(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_SEND, fd, buffer, len, 0)
  result.msgFlags = flags
  result.user_data = user_data;

proc recvmsg*(q: var Queue; userData: pointer; fd: FileHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `recvmsg(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_RECVMSG, fd, msghdr, 1, 0)
  result.msgFlags = flags
  result.user_data = user_data;

proc sendmsg*(q: var Queue; userData: pointer; fd: FileHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_SENDMSG, fd, msghdr, 1, 0)
  result.msgFlags = flags
  result.user_data = user_data;

proc openat*(q: var Queue; userData: pointer; fd: FileHandle; path: string; mode: FileMode): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform an `openat(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_OPENAT, fd, path.cstring, mode.int, 0)
  result.user_data = user_data;

proc close*(q: var Queue; userData: pointer; fd: FileHandle): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `close(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.opcode = OP_CLOSE
  result.fd = fd
  result.user_data = user_data;

proc timeout*(q: var Queue; userData: pointer; ts: Timespec, count: uint32; flags: TimeoutFlags): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to register a timeout operation.
  ## Returns a pointer to the SQE.
  ##
  ## The timeout will complete when either the timeout expires, or after the specified number of
  ## events complete (if `count` is greater than `0`).
  ##
  ## `flags` may be `0` for a relative timeout, or `IORING_TIMEOUT_ABS` for an absolute timeout.
  ##
  ## The completion event result will be `-ETIME` if the timeout completed through expiration,
  ## `0` if the timeout completed after the specified number of events, or `-ECANCELED` if the
  ## timeout was removed before it expired.
  ##
  ## io_uring timeouts use the `CLOCK.MONOTONIC` clock source.
  result = q.getSqe()
  result.prepRw(OP_TIMEOUT, -1, ts.unsafeAddr, 1, count.Off)
  result.timeoutFlags = flags
  result.user_data = user_data;

proc timeout_remove*(q: var Queue; userData: pointer; timeout_user_data: pointer; flags: TimeoutFlags): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to remove an existing timeout operation.
  ## Returns a pointer to the SQE.
  ##
  ## The timeout is identified by its `user_data`.
  ##
  ## The completion event result will be `0` if the timeout was found and cancelled successfully,
  ## `-EBUSY` if the timeout was found but expiration was already in progress, or
  ## `-ENOENT` if the timeout was not found.
  result = q.getSqe()
  result.prepRw(OP_TIMEOUT_REMOVE, -1, timeout_user_data, 0, 0)
  result.timeoutFlags = flags
  result.user_data = user_data;

proc link_timeout*(q: var Queue; userData: pointer; ts: Timespec; flags: TimeoutFlags): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to add a link timeout operation.
  ## Returns a pointer to the SQE.
  ##
  ## You need to set linux.IOSQE_IO_LINK to flags of the target operation
  ## and then call this method right after the target operation.
  ## See https://lwn.net/Articles/803932/ for detail.
  ##
  ## If the dependent request finishes before the linked timeout, the timeout
  ## is canceled. If the timeout finishes before the dependent request, the
  ## dependent request will be canceled.
  ##
  ## The completion event result of the link_timeout will be
  ## `-ETIME` if the timeout finishes before the dependent request
  ## (in this case, the completion event result of the dependent request will
  ## be `-ECANCELED`), or
  ## `-EALREADY` if the dependent request finishes before the linked timeout.
  result = q.getSqe()
  result.prepRw(OP_LINK_TIMEOUT, -1, ts.unsafeAddr, 1, 0)
  result.timeoutFlags = flags
  result.user_data = user_data;

proc poll_add*(q: var Queue; userData: pointer; fd: FileHandle; poll_mask: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `poll(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_POLL_ADD, fd, nil, 1, 0)
  littleEndian32(addr result.poll32Events, unsafeAddr poll_mask)
  result.user_data = user_data;

proc poll_remove*(q: var Queue; userData: pointer; targetUserData: pointer): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to remove an existing poll operation.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_POLL_REMOVE, -1, target_user_data, 0, 0)
  result.user_data = user_data

proc poll_update*(q: var Queue; userData: pointer; oldUserData: pointer; newUserData: pointer; poll_mask: uint32, flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to update the user data of an existing poll
  ## operation. Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_POLL_REMOVE, -1, oldUserData, int flags, cast[int](newUserData))
  littleEndian32(addr result.poll32Events, unsafeAddr poll_mask)
  result.user_data = user_data

proc fallocate*(q: var Queue; userData: pointer; fd: FileHandle; mode: FileMode; offset: Off; len: int): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform an `fallocate(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_FALLOCATE, fd, cast[pointer](len), mode.int, offset)
  result.user_data = user_data

proc statx*(q: var Queue; userData: pointer; fd: FileHandle; path: string; flags: uint32; mask: uint32; buf: ptr Stat): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform an `statx(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_STATX, fd, path.cstring, mask.int, cast[int](buf))
  result.statxFlags = flags
  result.user_data = user_data

proc cancel*(q: var Queue; userData: pointer; cancelUserData: pointer; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to remove an existing operation.
  ## Returns a pointer to the SQE.
  ##
  ## The operation is identified by its `user_data`.
  ##
  ## The completion event result will be `0` if the operation was found and cancelled successfully,
  ## `-EALREADY` if the operation was found but was already in progress, or
  ## `-ENOENT` if the operation was not found.
  result = q.getSqe()
  result.prepRw(OP_ASYNC_CANCEL, -1, cancelUserData, 0, 0)
  result.cancelFlags = flags
  result.user_data = user_data

proc shutdown*(q: var Queue; userData: pointer; sockfd: FileHandle; how: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `shutdown(2)`.
  ## Returns a pointer to the SQE.
  ##
  ## The operation is identified by its `user_data`.
  result = q.getSqe()
  result.prepRw(OP_SHUTDOWN, sockfd, nil, how.int, 0)
  result.user_data = user_data

proc renameat*(q: var Queue; userData: pointer; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `renameat2(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_RENAMEAT, oldDirFd, oldPath.cstring, newDirFd.int, cast[int](newPath.cstring))
  result.renameFlags = flags
  result.user_data = user_data

proc unlinkat*(q: var Queue; userData: pointer; dirFd: FileHandle; path: string; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `unlinkat(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_UNLINKAT, dirFd, path.cstring, 0, 0)
  result.renameFlags = flags
  result.user_data = user_data

proc mkdirat*(q: var Queue; userData: pointer; dirFd: FileHandle; path: string; mode: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `mkdirat(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_MKDIRAT, dirFd, path.cstring, mode.int, 0)
  result.user_data = user_data

proc symlinkat*(q: var Queue; userData: pointer; target: string; newDirFd: FileHandle; linkPath: string): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `symlinkat(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_SYMLINKAT, newDirFd, target.cstring, 0, cast[int](linkPath.cstring))
  result.user_data = user_data

proc linkat*(q: var Queue; userData: pointer; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to perform a `linkat(2)`.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_LINKAT, oldDirFd, oldPath.cstring, newDirFd.int, cast[int](newPath.cstring))
  result.hardlinkFlags = flags
  result.user_data = user_data

proc provide_buffers*(q: var Queue; userData: pointer; buffers: pointer; bufferSize: int; buffersCount: int; groupId: uint; bufferId: uint): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to provide a group of buffers used for commands that read/receive data.
  ## Returns a pointer to the SQE.
  ##
  ## Provided buffers can be used in `read`, `recv` or `recvmsg` commands via .buffer_selection.
  ##
  ## The kernel expects a contiguous block of memory of size (buffers_count * buffer_size).
  result = q.getSqe()
  result.prepRw(OP_PROVIDE_BUFFERS, cast[FileHandle](buffersCount), buffers, bufferSize, bufferId.int)
  result.bufIndex = groupId.uint16
  result.user_data = user_data

proc provide_buffers*(q: var Queue; userData: pointer; buffersCount: int; groupId: uint;): ptr Sqe {.discardable.} =
  ## Queues (but does not submit) an SQE to remove a group of provided buffers.
  ## Returns a pointer to the SQE.
  result = q.getSqe()
  result.prepRw(OP_REMOVE_BUFFERS, cast[FileHandle](buffersCount), nil, 0, 0)
  result.bufIndex = groupId.uint16
  result.user_data = user_data
