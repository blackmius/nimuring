import std/net
import nimuring
import os

var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
socket.bindAddr(Port(3000))

var
    params: ref IoUringParams = (ref IoUringParams)()
    ring: ref IoUring = (ref IoUring)()

if ioUringQueueInitParams(4096, ring, params) < 0:
    raiseOSError osLastError()

if (params.features and IORING_FEAT_FAST_POLL) == 0:
    echo "IORING_FEAT_FAST_POLL not available in the kernel, quiting...\n"
    quit 0

proc addRecv() =
    var sqe = ioUringGetSqe(ring)
    var buf: array[100, char]
    ioUringPrepRecv(sqe, socket.getFd.cint, buf[0].addr, 100, 0)
    ioUringSqeSetData(sqe, buf.addr)
    discard ioUringSubmit(ring)

addRecv()

var cqe: ptr IoUringCqe
while true:
    if ioUringWaitCqe(ring, cqe.addr) != 0:
        raiseOsError osLastError()

    var cqes: array[64, ptr IoUringCqe]
    let cqeCount = ioUringPeekBatchCqe(ring, cast[ptr ptr IoUringCqe](cqes.addr), 64)

    for i in 0..<cqeCount:
        cqe = cqes[i]
        let userData = ioUringCqeGetData(cqe)
        let msg = cast[ptr array[100, char]](userData)[]
        echo msg
        if (cqe.flags and IORING_CQE_F_MORE) == 0:
            addRecv()
        ioUringCqeSeen(ring, cqe)