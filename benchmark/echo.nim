## https://github.com/frevib/io_uring-echo-server/blob/io-uring-feat-fast-poll/benchmarks/benchmarks.md

import posix
import nimuring
import net
import nativesockets

import std/[times]

const readSz = 2048

type
  EventType = enum
    eAccept
    eRecv
    eSend
    eClose
  Event = object
    typ: EventType
    sock: SocketHandle
    iov: IOVec
    time: float

proc run() =
  var q = newQueue(4096, {SETUP_SQPOLL})
  let server = newSocket()
  defer: server.close()
  server.bindAddr(Port(8080))
  server.listen()
  server.getFd().setSockOptInt(SOL_SOCKET, SO_REUSEADDR, 1)

  var accept_addr: SockAddr
  var accept_addr_len: SockLen
  for _ in 1..16:
    # connect more than one client per cycle
    var acceptEv = create(Event)
    acceptEv.typ = eAccept
    acceptEv.time = cpuTime()
    q.accept(userData=cast[pointer](acceptEv), server.getFd, addr accept_addr, addr accept_addr_len, O_NONBLOCK)
  q.submit()

  while true:
    let cqes = q.copyCqes(1)
    var time = cpuTime()
    for cqe in cqes:
      let ev = cast[ptr Event](cqe.userData)
      # echo ev.typ, " ", 1/(cpuTime() - ev.time)
      if cqe.res < 0:
        echo "io_uring request failed ", cqe.res
        dealloc(ev)
        continue
      case ev.typ
      of eAccept:
        # next accept
        var acceptEv = create(Event)
        acceptEv.typ = eAccept
        acceptEv.time = cpuTime()
        q.accept(userData=cast[pointer](acceptEv), server.getFd, addr accept_addr, addr accept_addr_len, O_NONBLOCK)
        # read what new connection sent
        var readEv = create(Event)
        readEv.typ = eRecv
        readEv.sock = cast[SocketHandle](cqe.res)
        readEv.time = cpuTime()
        readEv.iov.iov_base = allocShared0(readSz)
        readEv.iov.iov_len = readSz
        q.recv(cast[pointer](readEv), readEv.sock, readEv.iov.iov_base, readEv.iov.iov_len.int)
      of eRecv:
        if cqe.res <= 0:
          # no bytes disconnect!
          var closeEv = create(Event)
          closeEv.typ = eClose
          closeEv.time = cpuTime()
          q.close(cast[pointer](closeEv), ev.sock)
        else:
          var sendEv = create(Event)
          sendEv.typ = eSend
          sendEv.sock = ev.sock
          sendEv.time = cpuTime()
          sendEv.iov.iov_len = cqe.res.uint
          sendEv.iov.iov_base = allocShared(sendEv.iov.iov_len)
          copyMem(sendEv.iov.iov_base, ev.iov.iov_base, sendEv.iov.iov_len)
          q.send(cast[pointer](sendEv), ev.sock, sendEv.iov.iov_base, sendEv.iov.iov_len.int)
      of eSend:
        var readEv = create(Event)
        readEv.typ = eRecv
        readEv.sock = ev.sock
        readEv.time = cpuTime()
        readEv.iov.iov_base = allocShared0(readSz)
        readEv.iov.iov_len = readSz
        q.recv(cast[pointer](readEv), readEv.sock, readEv.iov.iov_base, readEv.iov.iov_len.int)
        # var closeEv = create(Event)
        # closeEv.typ = eClose
        # closeEv.time = cpuTime()
        # q.close(cast[pointer](closeEv), ev.sock)
      of eClose:
        discard
      if ev.iov.iov_len != 0:
        deallocShared(ev.iov.iov_base)
      dealloc(ev)
    var timeTaken = cpuTime() - time
    # echo "elapsed time for ", cqes.len, " cqes was ", timeEnd*1000, "ms"
    # echo cqes.len.float * (1/timeTaken)
    q.submit()

run()