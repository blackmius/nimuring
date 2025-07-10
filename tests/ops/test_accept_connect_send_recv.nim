import unittest2
import nimuring
import posix
import net

template withSockets(body: untyped) =
  let server {.inject.} = newSocket()
  let client {.inject.} = newSocket()
  var listener {.inject.}: Socket = nil
  try:
    `body`
  finally:
    server.close()
    client.close()
    if listener != nil:
      listener.close()

template setupServer(server: Socket, port: Port, accept_addr: var SockAddr, accept_addr_len: var SockLen, q: var Queue) =
  server.bindAddr(port)
  server.listen()
  accept_addr_len = 0.SockLen
  q.accept(userData=1, server.getFd, addr accept_addr, addr accept_addr_len, 0)

template setupClientConnect(client: Socket, port: Port, q: var Queue) =
  var sa: Sockaddr_storage = default(Sockaddr_storage)
  var sl: SockLen = 0
  toSockAddr("127.0.0.1".parseIpAddress, port, sa, sl)
  q.connect(userData=2, client.getFd, cast[ptr SockAddr](sa.addr), sl)

proc findCqe(cqes: var seq[Cqe]; userData: UserData): Cqe =
  result = default(Cqe)
  for cqe in cqes:
    if cqe.userData == userData.uint64:
      return cqe

suite "accept, connect, send, recv":
  test "accept/connect":
    withSockets:
      var q = newQueue(4)
      var accept_addr: SockAddr
      var accept_addr_len: SockLen
      setupServer(server, Port(1234), accept_addr, accept_addr_len, q)
      setupClientConnect(client, Port(1234), q)
      q.submit()
      var cqes = q.copyCqes(1)
      let acceptCqe = cqes.findCqe(1)
      listener = newSocket(cast[SocketHandle](acceptCqe.res))
      check accept_addr_len.int == 16

  test "send/recv":
    withSockets:
      var q = newQueue(4)
      var accept_addr: SockAddr
      var accept_addr_len: SockLen
      setupServer(server, Port(1234), accept_addr, accept_addr_len, q)
      setupClientConnect(client, Port(1234), q)
      q.submit()
      var cqes = q.copyCqes(1)
      let acceptCqe = cqes.findCqe(1)
      listener = newSocket(cast[SocketHandle](acceptCqe.res))

      var bufferSend = ['\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00', '\x01', '\x00']
      var bufferRecv: array[6, char] = ['\0', '\0', '\0', '\0', '\0', '\0']

      q.send(3, client.getFd, bufferSend.addr, bufferSend.len).linkNext()
      q.recv(4, listener.getFd, bufferRecv.addr, bufferRecv.len)
      q.submit(2)

      for i in 0..<bufferRecv.len:
        check bufferSend[i] == bufferRecv[i]