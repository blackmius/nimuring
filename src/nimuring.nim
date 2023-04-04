when defined(nimuringUseLiburing):
    import liburing/[io_uring, liburing, types]
    export io_uring, liburing, types
else:
    import native/[io_uring, queue, ops]
    export io_uring, queue, ops