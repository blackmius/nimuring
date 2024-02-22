import balls
import nimuring
from posix import Sockaddr_storage, SockLen, IOvec, Tmsghdr
import net

var q = newQueue(4)

let server = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
let client = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

try:
    server.bindAddr()
    let (ip, port) = server.getLocalAddr()

    var bufferSend = ['\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00']
    var iovecSend = IOvec(iov_base: bufferSend.addr, iov_len: bufferSend.len.uint)

    var sa: Sockaddr_storage
    var sl: SockLen
    toSockAddr(ip.parseIpAddress, port, sa, sl)

    var msgSend = Tmsghdr(
        msg_name: sa.addr,
        msg_namelen: sl,
        msg_iov: iovecSend.addr,
        msg_iovlen: 1
    )

    q.sendmsg(1, client.getFd, msgSend.addr, 0).linkNext()

    var sa2: Sockaddr_storage
    var sl2: SockLen

    var bufferRecv: array[6, char]
    var iovecRecv = IOVec(iov_base: bufferRecv.addr, iov_len: bufferRecv.len.uint)
    var msgRecv = Tmsghdr(
        msg_name: sa2.addr,
        msg_namelen: sl2,
        msg_iov: iovecRecv.addr,
        msg_iovlen: 1
    )

    q.recvmsg(2, server.getFd, msgRecv.addr, 0)

    q.submit(2)

    for i in 0..<bufferRecv.len:
        check bufferSend[i] == bufferRecv[i]

finally:
    # Socket has no graceful =destroy
    server.close()
    client.close()