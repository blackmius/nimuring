import nimuring
from posix import Sockaddr_storage, SockLen, IOvec, Tmsghdr
import std/[strformat, strutils, monotimes]
import net

import os

if paramCount() < 4:
  echo "usage: ./client HOST PORT CLIENTS BUFF_SIZE"
  quit 0

let host = paramStr(1)
let port = paramStr(2).parseInt.Port
let clientsCount = paramStr(3).parseInt
let bufferSize = paramStr(4).parseInt

var clients = newSeq[Socket](clientsCount)
for i in 0..<clientsCount:
  clients[i] = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

var sa: Sockaddr_storage
var sl: SockLen
toSockAddr(host.parseIpAddress, port, sa, sl)

var msgs = newSeq[ptr Tmsghdr](clientsCount)
for i in 0..<clientsCount:
  var msg = createShared(Tmsghdr)
  msg.msg_name = sa.addr
  msg.msg_namelen = sl
  var iov = createShared(IOVec)
  iov.iov_base = alloc(bufferSize)
  iov.iov_len = bufferSize.uint
  msg.msg_iov = iov
  msg.msg_iovlen = 1
  msgs[i] = msg

var q = newQueue(4096, {SETUP_SQPOLL})

for i in 0..<clientsCount:
  let socket = clients[i]
  q.sendmsg(i+1, socket.getFd, msgs[i], 0)
  q.recvmsg((i+1) shl 16, socket.getFd, msgs[i], 0)

var
  sent = 0
  recieved = 0
  bytesTransfered = 0


var timeStart = getMonoTime().ticks

let
  time = 30
  waitDuration = time * 1_000_000_000

echo fmt"clients: {clientsCount} buffer_size: {bufferSize}"

try:
  while true:
    q.submit()
    for cqe in q.copyCqes(1):
      if cqe.userData > 65535:
        # RECV
        let i = (cqe.userData shr 16) - 1
        let socket = clients[i]
        recieved += 1
        q.sendmsg(i+1, socket.getFd, msgs[i], 0)
        q.recvmsg((i+1) shl 16, socket.getFd, msgs[i], 0)
      else:
        # SEND
        sent += 1
        bytesTransfered += cqe.res
    let duration = getMonoTime().ticks - timeStart
    if duration > waitDuration:
      echo fmt"sent: {sent} recieved: {recieved}"
      echo fmt"rps: {recieved / time:9} data sent: {bytesTransfered/1024/1024:9.2f}MB"
      quit 0
      # timeStart = getMonoTime().ticks
finally:
  for i in 0..<clientsCount:
    clients[i].close()