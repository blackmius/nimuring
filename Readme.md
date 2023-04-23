# nimlang io_uring (nimuring)

this library base on liburing as source of truth about io_uring.

# TODO

- [ ] Queue
  - [x] passing flags and read internal state
  - [ ] features
    - [x] IO_SQPOLL
    - [ ] IO_WQ (multithreading)
  - [x] Sqe batching
  - [x] getting a CQEs in a convenient form (batching)

- [ ] OPS
  - [ ] SQE Builder \
       something similar to what was done in rust
       https://docs.rs/io-uring/latest/io_uring/squeue/struct.Entry.html
  - [x] a simple naive way to fill the queue, as it is done in zig
        https://github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring.zig
  - [ ] Extended queue \
    To avoid SQ overflow, it would be nice to come up with something like an additional dynamic queue on top of io_uring itself
  - [ ] Multishot ops
  - [ ] zerocopy send/recv
  - [ ] accept/connect/send/recv compatability with net module

- [ ] Register
  - [x] buffers
  - [ ] files
  - [ ] eventd

- [ ] documentation \
  compare the resulting wrappers with the great documentation
  https://unixism.net/loti/ref-liburing/submission.html

- [ ] Nim asyncdispatch integration \
  so far, there are not even any ideas how this could be done.
  On the first reading of its sources, I did not find a place,
  such as in libuv.prepare, which is executed every tick of the cycle

