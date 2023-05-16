# nimlang io_uring (nimuring)

This is a pure implementation of io_uring in nim.

The library was based on several implementations of io_uring in other languages at once,
such as:
* [liubring](https://github.com/axboe/liburing) (the original library from the author of io_uring),
* the [implementation of io_uring in the Zig language](https://github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring.zig),
* as well as the [implementation in Rust](https://docs.rs/io-uring/latest/io_uring/index.html).

Mostly on liburing

## async/await

Since the nature of io_uring is different from the nature of selectors, it is not possible to combine the io_uring queue and at the same time maintain acceptable performance.

Because of this, another event loop was implemented. But the interface for using async/await from the standard library has been preserved.

moved here: https://github.com/blackmius/uasync

## Documentation

Now there is no way to display the documentation in an acceptable form, so use man and read the code.

## Examples

examples can be found in `examples` folder
see examples of udp and tcp server in [benchmark folder](./benchmark/)
and also check the usage of OPS in [./tests/ops](./tests/ops/)