import balls
import nimuring
import posix
import net

var q = newQueue(4)

proc findCqe(cqes: var seq[Cqe]; userData: UserData): Cqe =
    for cqe in cqes:
        if cqe.userData == userData.uint64:
            return cqe

const
    ACCEPT = 1
    CONNECT = 2
    SEND = 3
    RECV = 4


let server = newSocket()
let client = newSocket()

var listener: Socket
try:
    server.bindAddr(Port(1234))
    server.listen()

    var accept_addr: SockAddr
    var accept_addr_len: SockLen
    check accept_addr_len.int == 0
    q.accept(userData=ACCEPT, server.getFd, addr accept_addr, addr accept_addr_len, 0)

    var sa: Sockaddr_storage
    var sl: SockLen
    toSockAddr("127.0.0.1".parseIpAddress, Port(1234), sa, sl)

    q.connect(userData=CONNECT, client.getFd, cast[ptr SockAddr](sa.addr), sl)

    q.submit()
    var cqes = q.copyCqes(1)
    let acceptCqe = cqes.findCqe(ACCEPT)
    listener = newSocket(cast[SocketHandle](acceptCqe.res))

    check accept_addr_len.int == 16

    var bufferSend = ['\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00']
    var bufferRecv: array[6, char]

    q.send(SEND, client.getFd, bufferSend.addr, bufferSend.len).linkNext()
    q.recv(RECV, listener.getFd, bufferRecv.addr, bufferRecv.len)
    q.submit(2)

    for i in 0..<bufferRecv.len:
        check bufferSend[i] == bufferRecv[i]
    
finally:
    # Socket has no graceful =destroy
    server.close()
    client.close()