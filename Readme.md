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
  - [-] SQE Builder \
       something similar to what was done in rust
       https://docs.rs/io-uring/latest/io_uring/squeue/struct.Entry.html
       it turned out that there is not much that can be built, since the calls copy syscall, then the easiest thing is to become like them
  - [x] a simple naive way to fill the queue, as it is done in zig
        https://github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring.zig
  - [x] Extended queue \
    To avoid SQ overflow, it would be nice to come up with something like an additional dynamic queue on top of io_uring itself
    look at the implementation of async
  - [ ] Multishot ops
    not tested yet
  - [ ] zerocopy send/recv
    not tested yet
  - [x] accept/connect/send/recv compatability with net module
    see examples or benchmarks

- [ ] Register
  - [x] buffers
  - [ ] files
  - [ ] eventd

- [ ] documentation \
  compare the resulting wrappers with the great documentation
  https://unixism.net/loti/ref-liburing/submission.html

- [x] Nim async/await integration \
  couldn't integrate into asyncdispatch, so I had to write my own.
  however, it works faster than the standard in all plans from timers to real work with IO

- [-] CPS integration \
  CPS works 6 times faster, judging by benchmarks, so it makes sense to integrate io_uring into it,
  since the continuations logic fits well with io interrupts

  only until you prefer not to use inner loops....
