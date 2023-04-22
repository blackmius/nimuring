## utility functions for sending commands to io_uring
## .. warning::
##   After filling in SQ, queue.get Sql starts returning nil,
##   and since the following functions are trying to create SQE for you,
##   they may try to write on the nil pointer and fail with an out-of-memory error
##
##   So for safety check, use `queue.sqReady < queue.params.sqEntries` before calling an op

import io_uring
import queue
import posix
import epoll
import std/endians

type SqePointer = ref Sqe or ptr Sqe
type UserData* = pointer | SomeNumber

{.push inline, discardable.}

## Prepare SQE / SQE Builder

proc setUserData*(sqe: SqePointer, userData: UserData): SqePointer =
  sqe.userData = cast[pointer](userData)
  return sqe


proc linkNext*(sqe: SqePointer): SqePointer =
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
  return sqe

proc drainPrevious*(sqe: SqePointer): SqePointer =
  ## When this flag is specified, the SQE will not be started before previously submitted SQEs have completed,
  ## and new SQEs will not be started before this one completes. Available since 5.2.
  sqe.flags.incl(SQE_IO_DRAIN)
  return sqe


proc nop*(sqe: SqePointer): SqePointer =
  sqe.opcode = OP_NOP
  return sqe


proc prepRw(sqe: SqePointer, op: Op; fd: FileHandle | SocketHandle; `addr`: pointer | SomeNumber; len: SomeNumber; offset: pointer | SomeNumber): SqePointer =
  sqe.opcode = op
  sqe.fd = cast[FileHandle](fd)
  sqe.off.off = cast[Off](offset)
  sqe.`addr`.`addr` = cast[pointer](`addr`)
  sqe.len = cast[int32](len)
  return sqe


proc fsync*(sqe: SqePointer; fd: FileHandle; flags: FsyncFlags = {}): SqePointer =
  sqe.opcode = OP_FSYNC
  sqe.fd = fd
  sqe.op_flags.fsync_flags = flags
  return sqe

proc fallocate*(sqe: SqePointer; fd: FileHandle; mode: FileMode; offset: Off; len: int): SqePointer =
  sqe.prepRw(OP_FALLOCATE, fd, len, mode.int, offset)

proc statx*(sqe: SqePointer; fd: FileHandle; path: string; flags: uint32; mask: uint32; buf: ptr Stat): SqePointer =
  sqe.op_flags.statxFlags = flags
  sqe.prepRw(OP_STATX, fd, cast[pointer](path.cstring), mask, cast[pointer](buf))


proc read*(sqe: SqePointer; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): SqePointer =
  sqe.prepRw(OP_READ, fd, buffer, len, offset)

proc read*(sqe: SqePointer; fd: FileHandle; group_id: uint16, len: int, offset: int = 0): SqePointer =
  sqe.flags.incl(SQE_BUFFER_SELECT)
  sqe.buf.buf_index = group_id
  sqe.prepRw(OP_READ, fd, 0, len, offset)

proc readv*(sqe: SqePointer; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): SqePointer =
  sqe.prepRw(OP_READV, fd, cast[pointer](iovecs[0].unsafeAddr), len(iovecs), offset)

proc read_fixed*(sqe: SqePointer; fd: FileHandle; iovec: IOVec; offset: int = 0; bufferIndex: int = 0): SqePointer =
  sqe.buf.bufIndex = bufferIndex.uint16
  sqe.prepRw(OP_READ_FIXED, fd, iovec.iov_base, iovec.iov_len, offset)

proc write*(sqe: SqePointer; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): SqePointer =
  sqe.prepRw(OP_WRITE, fd, buffer, len, offset)

proc write*(sqe: SqePointer; fd: FileHandle; str: string; offset: int = 0): SqePointer =
  sqe.prepRw(OP_WRITE, fd, cast[pointer](str.cstring), len(str), offset)

proc writev*(sqe: SqePointer; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): SqePointer =
  sqe.prepRw(OP_WRITEV, fd, cast[pointer](iovecs[0].unsafeAddr), len(iovecs), offset)

proc write_fixed*(sqe: SqePointer; fd: FileHandle; iovec: IOVec, offset: int = 0, bufferIndex: int = 0): SqePointer =
  sqe.buf.bufIndex = bufferIndex.uint16
  sqe.prepRw(OP_WRITE_FIXED, fd, iovec.iov_base, iovec.iov_len, offset)


proc accept*(sqe: SqePointer; sock: SocketHandle, `addr`: ptr SockAddr, addrLen: ptr SockLen, flags: uint16): SqePointer =
  sqe.op_flags.acceptFlags = flags
  sqe.prepRw(OP_ACCEPT, sock, cast[pointer](`addr`), 0, cast[pointer](addrLen))

proc accept_multishot*(sqe: SqePointer; sock: SocketHandle, `addr`: ref SockAddr, addrLen: ref SockLen, flags: uint16): SqePointer =
  sqe.ioprio.incl(RECVSEND_POLL_FIRST)
  sqe.accept(sock, `addr`, addrLen, flags)

proc connect*(sqe: SqePointer; sock: SocketHandle, `addr`: ptr SockAddr, addrLen: SockLen): SqePointer =
  sqe.prepRw(OP_CONNECT, sock, cast[pointer](`addr`), 0, cast[pointer](addrLen))


proc epoll_ctl*(sqe: SqePointer; epfd: FileHandle; fd: FileHandle; op: uint32; ev: ptr EpollEvent): SqePointer =
  sqe.prepRw(OP_EPOLL_CTL, epfd, cast[pointer](ev), op, fd)

proc poll_add*(sqe: SqePointer; fd: FileHandle; poll_mask: uint32): SqePointer =
  littleEndian32(addr result.op_flags.poll32Events, unsafeAddr poll_mask)
  sqe.prepRw(OP_POLL_ADD, fd, nil, 1, 0)

proc poll_multi*(sqe: SqePointer; fd: FileHandle; poll_mask: uint32): SqePointer =
  sqe.len = cast[int](PollFlags({POLL_ADD_MULTI}))
  sqe.poll_add(fd, poll_mask)

proc poll_remove*(sqe: SqePointer; targetUserData: UserData): SqePointer =
  sqe.prepRw(OP_POLL_REMOVE, -1, target_user_data, 0, 0)

proc poll_update*(sqe: SqePointer; oldUserData: UserData; newUserData: UserData; poll_mask: uint32, flags: uint32): SqePointer =
  littleEndian32(addr result.op_flags.poll32Events, unsafeAddr poll_mask)
  sqe.prepRw(OP_POLL_REMOVE, -1, oldUserData, int flags, cast[int](newUserData))


proc recv*(sqe: SqePointer; sock: SocketHandle; buffer: pointer; len: int; flags: uint32=0): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.prepRw(OP_RECV, sock, buffer, len, 0)

proc recv_multishot*(sqe: SqePointer; sock: SocketHandle; buffer: pointer; len: int; flags: uint32): SqePointer =
  sqe.ioprio.incl(RECV_MULTISHOT)
  sqe.recv(sock, buffer, len, flags)

proc send*(sqe: SqePointer; sock: SocketHandle; buffer: pointer; len: int; flags: uint32 = 0): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.prepRw(OP_SEND, sock, buffer, len, 0)

proc send_zc*(sqe: SqePointer; sock: SocketHandle; buffer: pointer; len: int; flags: uint32; zc_flags: uint; buf_index: uint): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.ioprio = cast[IoprioFlags](zc_flags)
  sqe.prepRw(OP_SENDZC, sock, buffer, len, 0)


proc recvmsg*(sqe: SqePointer; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.prepRw(OP_RECVMSG, sock, cast[pointer](msghdr), 1, 0)

proc recvmsg_multishot*(sqe: SqePointer; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): SqePointer =
  sqe.ioprio.incl(RECV_MULTISHOT)
  sqe.recvmsg(sock, msghdr, flags)

proc sendmsg*(sqe: SqePointer; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.prepRw(OP_SENDMSG, sock, cast[pointer](msghdr), 1, 0)

proc sendmsg_zc*(sqe: SqePointer; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): SqePointer =
  sqe.op_flags.msgFlags = flags
  sqe.prepRw(OP_SENDMSG_ZC, sock, cast[pointer](msghdr), 1, 0)


proc openat*(sqe: SqePointer; dfd: FileHandle; path: string; flags: uint32; mode: FileMode): SqePointer =
  sqe.op_flags.openFlags = flags
  sqe.prepRw(OP_OPENAT, dfd, cast[pointer](path.cstring), mode.int, 0)

proc close*(sqe: SqePointer; fd: FileHandle | SocketHandle): SqePointer =
  sqe.opcode = OP_CLOSE
  sqe.fd = fd
  return sqe

proc renameat*(sqe: SqePointer; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): SqePointer =
  sqe.op_flags.renameFlags = flags
  sqe.prepRw(OP_RENAMEAT, oldDirFd, cast[pointer](oldPath.cstring), newDirFd.int, cast[int](newPath.cstring))

proc unlinkat*(sqe: SqePointer; dirFd: FileHandle; path: string; flags: uint32): SqePointer =
  sqe.op_flags.unlinkFlags = flags
  sqe.prepRw(OP_UNLINKAT, dirFd, cast[pointer](path.cstring), 0, 0)

proc mkdirat*(sqe: SqePointer; dirFd: FileHandle; path: string; mode: uint32): SqePointer =
  sqe.prepRw(OP_MKDIRAT, dirFd, cast[pointer](path.cstring), mode, 0)

proc symlinkat*(sqe: SqePointer; target: string; newDirFd: FileHandle; linkPath: string): SqePointer =
  sqe.prepRw(OP_SYMLINKAT, newDirFd, cast[pointer](target.cstring), 0, cast[pointer](linkPath.cstring))

proc linkat*(sqe: SqePointer; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): SqePointer =
  result.op_flags.hardlinkFlags = flags
  sqe.prepRw(OP_LINKAT, oldDirFd, cast[pointer](oldPath.cstring), newDirFd, cast[pointer](newPath.cstring))


proc timeout*(sqe: SqePointer; ts: Timespec, count: uint32; flags: TimeoutFlags): SqePointer =
  sqe.op_flags.timeoutFlags = flags
  sqe.prepRw(OP_TIMEOUT, -1, cast[pointer](ts.unsafeAddr), 1, count)

proc timeout_remove*(sqe: SqePointer; timeout_user_data: pointer; flags: TimeoutFlags): SqePointer =
  sqe.op_flags.timeoutFlags = flags
  sqe.prepRw(OP_TIMEOUT_REMOVE, -1, timeout_user_data, 0, 0)

proc link_timeout*(sqe: SqePointer; ts: Timespec; flags: TimeoutFlags): SqePointer =
  sqe.op_flags.timeoutFlags = flags
  sqe.prepRw(OP_LINK_TIMEOUT, -1, cast[pointer](ts.unsafeAddr), 1, 0)


proc cancel*(sqe: SqePointer; cancelUserData: UserData; flags: uint32): SqePointer =
  sqe.op_flags.cancelFlags = flags
  sqe.prepRw(OP_ASYNC_CANCEL, -1, cancelUserData, 0, 0)

proc shutdown*(sqe: SqePointer; sockfd: FileHandle; how: uint32): SqePointer =
  sqe.prepRw(OP_SHUTDOWN, sockfd, nil, how.int, 0)


proc provide_buffers*(sqe: SqePointer; buffers: pointer; bufferSize: int; buffersCount: int; groupId: uint; bufferId: uint): SqePointer =
  sqe.buf.bufIndex = groupId.uint16
  sqe.prepRw(OP_PROVIDE_BUFFERS, cast[FileHandle](buffersCount), buffers, bufferSize, bufferId.int)

proc remove_buffers*(sqe: SqePointer; buffersCount: int; groupId: uint;): SqePointer =
  sqe.buf.bufIndex = groupId.uint16
  sqe.prepRw(OP_REMOVE_BUFFERS, cast[FileHandle](buffersCount), nil, 0, 0)

proc sync_file_range*(sqe: SqePointer; fd: FileHandle; len: int; flags: uint32; offset: Off = 0): SqePointer =
  sqe.op_flags.sync_range_flags = flags
  sqe.prepRw(OP_SYNC_FILE_RANGE, fd, nil, len, offset)

proc files_update*(sqe: SqePointer, fds: seq[FileHandle], offset: int = 0): SqePointer =
  sqe.prepRw(OP_FILES_UPDATE, -1, cast[pointer](fds[0].unsafeAddr), fds.len, offset)

proc fadvice*(sqe: SqePointer, fd: FileHandle, len: int, advice: int, offset: int = 0): SqePointer =
  sqe.op_flags.fadvice_advice = advice
  sqe.prepRw(OP_FADVISE, fd, nil, len, offset)

proc madvice*(sqe: SqePointer; `addr`: pointer; len: int; advice: int): SqePointer =
  sqe.op_flags.fadvice_advice = advice
  sqe.prepRw(OP_MADVISE, -1, `addr`, len, 0)

proc splice*(sqe: SqePointer; fd_in: FileHandle; off_in: int; fd_out: FileHandle; off_out: int; len: int; flags: int = 0, fixed: bool = false): SqePointer =
  sqe.opcode = OP_SPLICE
  sqe.fd = fd_out
  sqe.len = len
  sqe.off = off_out
  sqe.splice.splice_fd_in = fd_in
  sqe.`addr`.splice_off_in = off_in
  if fixed:
    flags = flags or SPLICE_F_FD_IN_FIXED
  sqe.op_flags.splice_flags = flags
  return sqe

proc tee*(sqe: SqePointer, fd_in: FileHandle, fd_out: FileHandle; len: int; flags: int = 0, fixed: bool = false): SqePointer =
  sqe.opcode = OP_TEE
  sqe.fd = fd_out
  sqe.len = len
  sqe.splice.splice_fd_in = fd_in
  if fixed:
    flags = flags or SPLICE_F_FD_IN_FIXED
  sqe.op_flags.splice_flags = flags
  return sqe

proc msg_ring*(sqe: SqePointer; ring_fd: FileHandle; res: int; user_data: uint64; user_flags: uint32 = 0; opcode_flags: uint32 = 0): SqePointer =
  sqe.op_flags.msg_ring_flags = opcode_flags
  sqe.prepRw(OP_MSG_RING, ring_fd, MSG_DATA, res, user_data)

proc fsetxattr*(sqe: SqePointer; fd: FileHandle; name: string; value: string; flags: int = 0): SqePointer =
  sqe.op_flags.xattr_flags = flags
  # TODO: which len?
  sqe.prepRw(OP_FSETXATTR, fd, cast[pointer](name.cstring), name.len, cast[pointer](value.cstring))

proc setxattr*(sqe: SqePointer, name: string; value: string; path: string; flags: int = 0): SqePointer =
  sqe.op_flags.xattr_flags = flags
  sqe.cmd.addr3 = cast[pointer](path.cstring)
  sqe.prepRw(OP_SETXATTR, 0, cast[pointer](name.cstring), name.len, cast[pointer](value.cstring))

proc fgetxattr*(sqe: SqePointer; fd: FileHandle; name: string; buf: pointer; len: int): SqePointer =
  sqe.prepRw(OP_FGETXATTR, fd, cast[pointer](name.cstring), len, buf)

proc getxattr*(sqe: SqePointer; name: string; buf: pointer; len: int; path: string;): SqePointer =
  sqe.cmd.addr3 = cast[pointer](path.cstring)
  sqe.prepRw(OP_GETXATTR, 0, cast[pointer](name.cstring), len, buf)

proc socket*(sqe: SqePointer; domain: int; `type`: int; protocol: int; flags: int = 0): SqePointer =
  sqe.op_flags.rw_flags = flags
  sqe.prepRw(OP_SOCKET, domain, nil, protocol, `type`)

  # TODO: direct

## Queue new SQE methods

proc fsync*(q: var Queue; userData: UserData; fd: FileHandle; flags: FsyncFlags = {}): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `fsync(2)`.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the SQE's `rw_flags`.
  ## N.B. While SQEs are initiated in the order in which they appear in the submission queue,
  ## operations execute in parallel and completions are unordered. Therefore, an application that
  ## submits a write followed by an fsync in the submission queue cannot expect the fsync to
  ## apply to the write, since the fsync may complete before the write is issued to the disk.
  ## You should preferably use `linkNext()` on a write's SQE to link it with an fsync,
  ## or else insert a full write barrier using `drainPrevios()` when queueing an fsync.
  q.getSqe().fsync(fd, flags).setUserData(userData)

proc nop*(q: var Queue; userData: UserData;): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a no-op.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## A no-op is more useful than may appear at first glance.
  ## For example, you could call `drainPrevios()` on the returned SQE, to use the no-op to
  ## know when the ring is idle before acting on a kill signal.
  q.getSqe().nop().setUserData(userData)

proc read*(q: var Queue; userData: UserData; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `read(2)`
  ## Reading into a `buffer` uses `read(2)`
  q.getSqe().read(fd, buffer, len, offset).setUserData(userData)

proc readv*(q: var Queue; userData: UserData; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `preadv` depending on the buffer type.
  ## Reading into a `iovecs` uses `preadv(2)`
  ## If you want to do a `preadv2()` then set `rw_flags` on the returned SQE. See https://linux.die.net/man/2/preadv.
  q.getSqe().readv(fd, iovecs, offset).setUserData(userData)

proc read*(q: var Queue; userData: UserData; fd: FileHandle; group_id: uint16, len: int, offset: int = 0): ptr Sqe =
  ## io_uring will select a buffer that has previously been provided with `provide_buffers`.
  ## The buffer group referenced by `group_id` must contain at least one buffer for the recv call to work.
  ## `len` controls the number of bytes to read into the selected buffer.
  q.getSqe().read(fd, group_id, len, offset).setUserData(userData)

proc readv_fixed*(q: var Queue; userData: UserData; fd: FileHandle; iovec: IOVec; offset: int = 0; bufferIndex: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a IORING_OP_READ_FIXED.
  ## The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
  ## The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
  ##
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  q.getSqe().read_fixed(fd, iovec, offset, bufferIndex).setUserData(userData)

proc write*(q: var Queue; userData: UserData; fd: FileHandle; buffer: pointer; len: int; offset: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `write(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().write(fd, buffer, len, offset).setUserData(userData)

proc write*(q: var Queue; userData: UserData; fd: FileHandle; str: string; offset: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `write(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().write(fd, str, offset).setUserData(userData)

proc writev*(q: var Queue; userData: UserData; fd: FileHandle; iovecs: seq[IOVec]; offset: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `pwritev()`.
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  ## For example, if you want to do a `pwritev2()` then set `rw_flags` on the returned SQE.
  ## See https://linux.die.net/man/2/pwritev.
  q.getSqe().writev(fd, iovecs, offset).setUserData(userData)

proc writev_fixed*(q: var Queue; userData: UserData; fd: FileHandle; iovec: IOVec, offset: int = 0, bufferIndex: int = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a IORING_OP_WRITE_FIXED.
  ## The `buffer` provided must be registered with the kernel by calling `register_buffers` first.
  ## The `buffer_index` must be the same as its index in the array provided to `register_buffers`.
  ##
  ## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
  q.getSqe().write_fixed(fd, iovec, offset, bufferIndex).setUserData(userData)

proc accept*(q: var Queue; userData: UserData; sock: SocketHandle, `addr`: ptr SockAddr, addrLen: ptr SockLen, flags: uint16): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
  ## Returns a pointer to the SQE.
  q.getSqe().accept(sock, `addr`, addrLen, flags).setUserData(userData)

proc accept_multishot*(q: var Queue; userData: UserData; sock: SocketHandle, `addr`: SockAddr, addrLen: SockLen, flags: uint16): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `accept4(2)` on a socket.
  ## Accept multiple new connections on a socket.
  ## Returns a pointer to the SQE.
  q.getSqe().accept_multishot(sock, `addr`, addrLen, flags).setUserData(userData)

proc connect*(q: var Queue; userData: UserData; sock: SocketHandle, `addr`: ptr SockAddr, addrLen: SockLen): ptr Sqe =
  ## Queue (but does not submit) an SQE to perform a `connect(2)` on a socket.
  ## Returns a pointer to the SQE.
  q.getSqe().connect(sock, `addr`, addrLen).setUserData(userData)

proc epoll_ctl*(q: var Queue; userData: UserData; epfd: FileHandle; fd: FileHandle; op: uint32; ev: ptr EpollEvent): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `epoll_ctl(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().epoll_ctl(epfd, fd, op, ev).setUserData(userData)

proc recv*(q: var Queue; userData: UserData; sock: SocketHandle; buffer: pointer; len: int; flags: uint32=0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `recv(2)`.
  ## Returns a pointer to the SQE.
  ## io_uring will recv directly into this buffer
  q.getSqe().recv(sock, buffer, len, flags).setUserData(userData)

proc recv_multishot*(q: var Queue; userData: UserData; sock: SocketHandle; buffer: pointer; len: int; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `recv(2)`.
  ## Returns a pointer to the SQE.
  ## Receive multiple messages from a socket
  ## io_uring will recv directly into this buffer
  q.getSqe().recv_multishot(sock, buffer, len, flags).setUserData(userData)

proc send*(q: var Queue; userData: UserData; sock: SocketHandle; buffer: pointer; len: int; flags: uint32 = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `send(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().send(sock, buffer, len, flags).setUserData(userData)

proc send_zc*(q: var Queue; userData: UserData; sock: SocketHandle; buffer: pointer; len: int; flags: uint32; zc_flags: uint; buf_index: uint): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `sendzc(2)`.
  ## zerocopy send request
  ## Returns a pointer to the SQE.
  q.getSqe().send_zc(sock, buffer, len, flags, zc_flags, buf_index).setUserData(userData)

proc recvmsg*(q: var Queue; userData: UserData; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `recvmsg(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().recvmsg(sock, msghdr, flags).setUserData(userData)

proc recvmsg_multishot*(q: var Queue; userData: UserData; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `recvmsg(2)`.
  ## Receive multiple messages on a socket,
  ## Returns a pointer to the SQE.
  q.getSqe().recvmsg_multishot(sock, msghdr, flags).setUserData(userData)

proc sendmsg*(q: var Queue; userData: UserData; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().sendmsg(sock, msghdr, flags).setUserData(userData)

proc sendmsg_zc*(q: var Queue; userData: UserData; sock: SocketHandle; msghdr: ptr Tmsghdr; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `sendmsg(2)`.
  ## zerocopy
  ## Returns a pointer to the SQE.
  q.getSqe().sendmsg_zc(sock, msghdr, flags).setUserData(userData)

proc openat*(q: var Queue; userData: UserData; dfd: FileHandle; path: string; flags: uint32; mode: FileMode): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `openat(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().openat(dfd, path, flags, mode).setUserData(userData)

# TODO: find struct open_how
# https://man7.org/linux/man-pages/man2/openat2.2.html
# теперь я понимаю что значит "курить ман"
# type OpenHow = object
#   flags: uint64  ## O_* flags
#   mode: FileMode
#   resolve: uint64 ## RESOLVE_* flags
# proc openat2*(q: var Queue; userData: UserData; dfd: FileHandle; path: string; how: OpenHow): ptr Sqe =
#   ## Queues (but does not submit) an SQE to perform an `openat2(2)`.
#   ## Returns a pointer to the SQE.
#   q.getSqe().openat2(dfd, path, how).setUserData(userData)

proc close*(q: var Queue; userData: UserData; fd: FileHandle | SocketHandle): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `close(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().close(fd).setUserData(userData)

proc timeout*(q: var Queue; userData: UserData; ts: Timespec, count: uint32; flags: TimeoutFlags): ptr Sqe =
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
  q.getSqe().timeout(ts, count, flags).setUserData(userData)

proc timeout_remove*(q: var Queue; userData: UserData; timeout_user_data: pointer; flags: TimeoutFlags): ptr Sqe =
  ## Queues (but does not submit) an SQE to remove an existing timeout operation.
  ## Returns a pointer to the SQE.
  ##
  ## The timeout is identified by its `user_data`.
  ##
  ## The completion event result will be `0` if the timeout was found and cancelled successfully,
  ## `-EBUSY` if the timeout was found but expiration was already in progress, or
  ## `-ENOENT` if the timeout was not found.
  q.getSqe().timeout_remove(timeout_user_data, flags).setUserData(userData)

proc link_timeout*(q: var Queue; userData: UserData; ts: Timespec; flags: TimeoutFlags): ptr Sqe =
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
  q.getSqe().link_timeout(ts, flags).setUserData(userData)

proc poll_add*(q: var Queue; userData: UserData; fd: FileHandle; poll_mask: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `poll(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().poll_add(fd, poll_mask).setUserData(userData)

proc poll_multi*(q: var Queue; userData: UserData; fd: FileHandle; poll_mask: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `poll(2)`.
  ## Revieve multiple poll
  ## Returns a pointer to the SQE.
  q.getSqe().poll_multi(fd, poll_mask).setUserData(userData)

proc poll_remove*(q: var Queue; userData: UserData; targetuserData: UserData): ptr Sqe =
  ## Queues (but does not submit) an SQE to remove an existing poll operation.
  ## Returns a pointer to the SQE.
  q.getSqe().poll_remove(targetUserData).setUserData(userData)

proc poll_update*(q: var Queue; userData: UserData; olduserData: UserData; newuserData: UserData; poll_mask: uint32, flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to update the user data of an existing poll
  ## operation. Returns a pointer to the SQE.
  q.getSqe().poll_update(oldUserData, newUserData, poll_mask, flags).setUserData(userData)

proc fallocate*(q: var Queue; userData: UserData; fd: FileHandle; mode: FileMode; offset: Off; len: int): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `fallocate(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().fallocate(fd, mode, offset, len).setUserData(userData)

proc statx*(q: var Queue; userData: UserData; fd: FileHandle; path: string; flags: uint32; mask: uint32; buf: ptr Stat): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform an `statx(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().statx(fd, path, flags, mask, buf).setUserData(userData)

proc cancel*(q: var Queue; userData: UserData; canceluserData: UserData; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to remove an existing operation.
  ## Returns a pointer to the SQE.
  ##
  ## The operation is identified by its `user_data`.
  ##
  ## The completion event result will be `0` if the operation was found and cancelled successfully,
  ## `-EALREADY` if the operation was found but was already in progress, or
  ## `-ENOENT` if the operation was not found.
  q.getSqe().cancel(cancelUserData, flags).setUserData(userData)

proc shutdown*(q: var Queue; userData: UserData; sockfd: FileHandle; how: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `shutdown(2)`.
  ## Returns a pointer to the SQE.
  ##
  ## The operation is identified by its `user_data`.
  q.getSqe().shutdown(sockfd, how).setUserData(userData)

proc renameat*(q: var Queue; userData: UserData; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `renameat2(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().renameat(oldDirFd, oldPath, newDirFd, newPath, flags).setUserData(userData)

proc unlinkat*(q: var Queue; userData: UserData; dirFd: FileHandle; path: string; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `unlinkat(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().unlinkat(dirFd, path, flags).setUserData(userData)

proc mkdirat*(q: var Queue; userData: UserData; dirFd: FileHandle; path: string; mode: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `mkdirat(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().mkdirat(dirFd, path, mode).setUserData(userData)

proc symlinkat*(q: var Queue; userData: UserData; target: string; newDirFd: FileHandle; linkPath: string): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `symlinkat(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().symlinkat(target, newDirFd, linkPath).setUserData(userData)

proc linkat*(q: var Queue; userData: UserData; oldDirFd: FileHandle; oldPath: string; newDirFd: FileHandle; newPath: string; flags: uint32): ptr Sqe =
  ## Queues (but does not submit) an SQE to perform a `linkat(2)`.
  ## Returns a pointer to the SQE.
  q.getSqe().linkat(oldDirFd, oldPath, newDirFd, newPath, flags).setUserData(userData)

proc provide_buffers*(q: var Queue; userData: UserData; buffers: pointer; bufferSize: int; buffersCount: int; groupId: uint; bufferId: uint): ptr Sqe =
  ## Queues (but does not submit) an SQE to provide a group of buffers used for commands that read/receive data.
  ## Returns a pointer to the SQE.
  ##
  ## Provided buffers can be used in `read`, `recv` or `recvmsg` commands via .buffer_selection.
  ##
  ## The kernel expects a contiguous block of memory of size (buffers_count * buffer_size).
  q.getSqe().provide_buffers(buffers, bufferSize, buffersCount, groupId, bufferId).setUserData(userData)

proc remove_buffers*(q: var Queue; userData: UserData; buffersCount: int; groupId: uint;): ptr Sqe =
  ## Queues (but does not submit) an SQE to remove a group of provided buffers.
  ## Returns a pointer to the SQE.
  q.getSqe().remove_buffers(buffersCount, groupId).setUserData(userData)

proc sync_file_range*(q: var Queue; userData: UserData; fd: FileHandle; len: int; flags: uint32; offset: Off = 0): ptr Sqe =
  ## Queues (but does not submit) an SQE to sync_file_range
  ## whatever it means
  ## Returns a pointer to the SQE.
  q.getSqe().sync_file_range(fd, len, flags, offset).setUserData(userData)

{.pop.}