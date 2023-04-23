import posix
import nimuring
import net

import std/[times]

const readSz = 128
const response = "HTTP/1.0 200 OK\r\nConnection: Closed\r\n\r\n"
const buf = response.cstring
const buf_len = response.len

var readBuf = allocShared0(readSz)

type
  EventType = enum
    eAccept
    eRecv
    eSend
    eClose
  Event = object
    typ: EventType
    sock: SocketHandle

proc run() =
  var q = newQueue(4096, {SETUP_SQPOLL})
  let server = newSocket()
  defer: server.close()
  server.bindAddr(Port(8080))
  server.listen()

  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  for _ in 1..16:
    # connect more than one client per cycle
    var acceptEv = create(Event)
    acceptEv.typ = eAccept
    q.accept(userData=cast[pointer](acceptEv), server.getFd, addr accept_addr, addr accept_addr_len, 0)
  q.submit()

  while true:
    let cqes = q.copyCqes(1)
    # var time = cpuTime()
    for cqe in cqes:
      let ev = cast[ptr Event](cqe.userData)
      if cqe.res < 0:
        echo "io_uring request failed ", cqe.res
        dealloc(ev)
        continue
      case ev.typ
      of eAccept:
        # next accept
        var acceptEv = create(Event)
        acceptEv.typ = eAccept
        q.accept(userData=cast[pointer](acceptEv), server.getFd, addr accept_addr, addr accept_addr_len, 0)
        # read what new connection sent
        var readEv = create(Event)
        readEv.typ = eRecv
        readEv.sock = cast[SocketHandle](cqe.res)
        q.recv(cast[pointer](readEv), readEv.sock, readBuf, readSz, 0)
      of eRecv:
        var sendEv = create(Event)
        sendEv.typ = eSend
        sendEv.sock = ev.sock
        q.send(cast[pointer](sendEv), ev.sock, buf, buf_len)
      of eSend:
        var closeEv = create(Event)
        closeEv.typ = eClose
        q.close(cast[pointer](closeEv), ev.sock)
      of eClose:
        discard
      dealloc(ev)
    # var timeEnd = cpuTime() - time
    # echo "elapsed time for ", cqes.len, " cqes was ", timeEnd*1000, "ms"
    q.submit()

run()