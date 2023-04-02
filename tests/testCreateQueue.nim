import native/queue

let q = newQueue(64)
echo q.params.features

var sqe = q.getSqe()
echo repr(sqe)