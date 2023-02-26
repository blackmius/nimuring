import std/os

proc IoUringSetup(entries: uint32, params: ptr): int {.varargs, importc: "io_uring_setup", header: "<liburing.h>".}

# asmlinkage long sys_io_uring_setup(u32 entries,
# 				struct io_uring_params __user *p);
# asmlinkage long sys_io_uring_enter(unsigned int fd, u32 to_submit,
# 				u32 min_complete, u32 flags,
# 				const void __user *argp, size_t argsz);
# asmlinkage long sys_io_uring_register(unsigned int fd, unsigned int op,
# 				void __user *arg, unsigned int nr_args);

# proc syscall(arg: cint): cint {.varargs, importc: "syscall", header: "<unistd.h>".}
# var
#     NR_io_uring_setup {.importc:"__NR_io_uring_setup", header:"<sys/syscall.h>".}: cint
#     NR_io_uring_enter {.importc:"__NR_io_uring_enter", header:"<sys/syscall.h>".}: cint

{.pragma: iou_t, header: "<linux/io_uring.h>", importc.}

type
    IoUringParams = object
        sqEntries: uint32
        cqEntries: uint32
        flags: uint32

proc ioUringSetup(entries: uint32, params: ptr IoUringParams): int32 =
    result = sysIoUringSetup(entries, params)
    echo params.sqEntries, ' ', params.cqEntries
    if result < 0:
        raise newOsError osLastError()

# proc ioUringEnter(ringFD: uint64, toSubmit, minComplete, flags: uint64): int32 =
#     result = syscall(NR_io_uring_enter, ringFD, toSubmit, minComplete, flags).int32
#     if result < 0:
#         raise newOsError osLastError()

var params: IoUringParams = IoUringParams()
let fd = ioUringSetup(1, params.unsafeAddr)
echo fd