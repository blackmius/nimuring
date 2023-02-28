import posix, epoll

# compatability with c2nim types
type
  KernelTimespec* = Timespec
  SigsetT* = Sigset
  Msghdr* = TMsghdr
  SocklenT* = SockLen
  OffT* = Off
  ModeT* = Mode
  Statx* {.importc: "struct statx", header: "<sys/stat.h>", nodecl.} = object
  Cmsghdr* {.importc: "struct cmsghdr", header: "<sys/socket.h>", nodecl.} = object
  CpuSetT* {.importc: "struct cpu_set_t", header: "<sched.h>", nodecl.} = object
  OpenHow* {.importc: "struct open_how", header: "<linux/openat2.h>", nodecl.} = object
  
  U64* = uint64
  U32* = uint32
  U16* = uint16
  U8* = uint8

  S32* = int32

  SsizeT* = int

export IOVec
export SockAddr
export EpollEvent