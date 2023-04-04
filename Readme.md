# nimlang io_uring (nimuring)

This library consists of two parts.
initially, liburing and all its methods were migrated without modification.
And secondly, this is the native implementation of the io_uring queue, because the extra dependence on liburing seemed too much

the native implementation is based on the implementation of the same functionality in zig
mostly comments fair enough to nim and just copied https://github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring.zig

# using liburing

there is a define to enable liburing bindings `nimuringUseLiburing`

``` bash
nim compile -d:nimuringUseLiburing program.nim
```

maybe it would better to move liburing wrapper in separate library, because i am not very excited to support it