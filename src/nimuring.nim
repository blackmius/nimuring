when defined(liburing):
    import nimuring/liburing/[io_uring, liburing, types]
    export io_uring, liburing, types
else:
    import nimuring/native/[io_uring, queue, ops]
    export io_uring, queue, ops