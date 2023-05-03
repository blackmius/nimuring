import nimuring
from posix import Sockaddr_storage, SockLen, IOvec, Tmsghdr
import std/strformat
import net

var q = newQueue(4096, {SETUP_SQPOLL})

let server = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

const BufferSize = 4096
const Pool = 8

try:
  server.bindAddr(port=Port(8000))
  let (ip, port) = server.getLocalAddr()
  echo fmt"listening on {ip}:{port}"

  let serverFd = server.getFd

  var msgs = newSeq[ptr Tmsghdr](Pool)

  for i in 0..<Pool:
    let buf = allocShared(BufferSize)
    var iov = createShared(IOVec)
    iov.iov_base = buf
    iov.iov_len = BufferSize
    var msg = createShared(Tmsghdr)
    msg.msg_name = createShared(Sockaddr_storage)
    msg.msg_namelen = sizeof(Sockaddr_storage).SockLen
    msg.msg_iov = iov
    msg.msg_iovlen = 1
    msgs[i] = msg
    q.recvmsg(i, serverFd, msg, 0)
  
  q.submit()

  while true:
    var cqes = q.copyCqes(1)
    for cqe in cqes:
      if cqe.userData < Pool:
        let prevmsg = msgs[cqe.userData]

        let buf = allocShared(cqe.res)
        var iov = createShared(IOVec)
        iov.iov_base = buf
        iov.iov_len = cqe.res.uint
        copyMem(buf, prevmsg.msg_iov.iov_base, cqe.res)

        let `addr` = createShared(Sockaddr_storage)
        copyMem(`addr`, prevmsg.msg_name, sizeof(Sockaddr_storage))

        var msg = createShared(Tmsghdr)
        msg.msg_name = `addr`
        msg.msg_namelen = prevmsg.msg_namelen
        msg.msg_iov = iov
        msg.msg_iovlen = 1

        q.sendmsg(msg, serverFd, msg, 0)
        q.recvmsg(cqe.userData, serverFd, prevmsg, 0)
      else:
        let msg = cast[ptr Tmsghdr](cqe.userData)
        dealloc(msg.msg_name)
        dealloc(msg.msg_iov.iov_base)
        dealloc(msg)
    q.submit()

  # var msgSend = Tmsghdr(
  #   msg_name: sa.addr,
  #   msg_namelen: sl,
  #   msg_iov: iovecSend.addr,
  #   msg_iovlen: 1
  # )

  # q.sendmsg(1, serverFd, msgSend.addr, 0)

  # var sa2: Sockaddr_storage
  # var sl2: SockLen

  # var bufferRecv: array[6, char]
  # var iovecRecv = IOVec(iov_base: bufferRecv.addr, iov_len: bufferRecv.len.uint)
  # var msgRecv = Tmsghdr(
  #     msg_name: sa2.addr,
  #     msg_namelen: sl2,
  #     msg_iov: iovecRecv.addr,
  #     msg_iovlen: 1
  # )

  # q.recvmsg(2, server.getFd, msgRecv.addr, 0)

finally:
  # Socket has no graceful =destroy
  server.close()