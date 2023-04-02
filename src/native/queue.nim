import io_uring

from atomics import MemoryOrder
{.push, header: "<stdatomic.h>", importc.}
proc atomic_load_explicit[T](location: ptr T; order: MemoryOrder): T
proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent)
proc atomic_thread_fence(order: MemoryOrder)
{.pop.}

type
  Queue* = object
    params*: ptr Params
    fd: FileHandle
    cq: CqRing
    sq: SqRing
    sqes: pointer

  # convenience typeclass
  Offsets = SqringOffsets or CqringOffsets

  Ring = object of RootObj
    head: pointer
    tail: pointer
    ring_mask: pointer
    ring_entries: pointer
    size: uint32
    ring: pointer

  SqRing = object of Ring
    flags: SqringFlags
    dropped: pointer
    array: pointer

  CqRing = object of Ring
    flags: CqringFlags
    overflow: pointer
    cqes: pointer

const
  defaultFlags: SetupFlags = {}

proc init(ring: var Ring, offset: ptr Offsets) =
  ## setup common properties of a Ring given a struct of Offsets
  ring.head = ring.ring + offset.head
  ring.tail = ring.ring + offset.tail
  ring.ring_mask = ring.ring + offset.ring_mask
  ring.ring_entries = ring.ring + offset.ring_entries
  assert offset.ring_entries > 0

proc newRing(fd: FileHandle; offset: ptr CqringOffsets; size: uint32): CqRing =
  ## mmap a Cq ring from the given file-descriptor, using the size spec'd
  result = CqRing(size: size)
  let ring = OffCqRing.uringMap(fd, offset.cqes, size, Cqe)
  result.ring = ring
  result.cqes = ring + offset.cqes
  result.overflow = ring + offset.overflow
  result.init offset

proc newRing(fd: FileHandle; offset: ptr SqringOffsets; size: uint32): SqRing =
  ## mmap a Sq ring from the given file-descriptor, using the size spec'd
  result = SqRing(size: size)
  let ring = OffSqRing.uringMap(fd, offset.array, size, pointer)
  result.size = size
  result.ring = ring
  result.dropped = ring + offset.dropped
  result.array = ring + offset.array
  result.init offset

proc `=destroy`(queue: var Queue) =
  ## tear down the queue
  uringUnmap(queue.sqes, queue.params.sqEntries.int)
  uringUnmap(queue.cq.ring, queue.params.cqEntries.int * sizeof(Cqe))
  uringUnmap(queue.sq.ring, queue.params.sqEntries.int * sizeof(pointer))

proc isPowerOfTwo(x: uint32): bool = (x != 0) and ((x and (x - 1)) == 0)

proc newQueue*(entries: uint32; flags = defaultFlags, sqThreadCpu = false, sqThreadIdle = false): Queue =
  assert entries.isPowerOfTwo
  var params = cast[ptr Params](allocShared(sizeof Params))
  params.flags = flags
  params.sqThreadCpu = sqThreadCpu.uint32
  params.sqThreadIdle = sqThreadIdle.uint32
  # ask the kernel for the file-descriptor to a ring pair of the spec'd size
  # this also populates the contents of the params object
  result.fd = setup(entries.cint, params)
  # save that
  result.params = params
  # setup the two rings
  result.cq = newRing(result.fd, addr params.cqOff, params.cqEntries)
  result.sq = newRing(result.fd, addr params.sqOff, params.sqEntries)
  # setup sqe array
  result.sqes = OffSqes.uringMap(result.fd, params.sqOff.array, params.sqEntries, uint32)
