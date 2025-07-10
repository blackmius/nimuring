from std/atomics import MemoryOrder

{.push stackTrace:off.}
when defined(cpp):
  {.emit: "#include <atomic>".}
  proc atomic_load_explicit*[T](location: ptr T; order: MemoryOrder): T {.inline.} =
    {.emit: ["return std::atomic_load_explicit(reinterpret_cast<const std::atomic<", T, "> *>(", location, "), ", order, ");"].}
  proc atomic_store_explicit*[T](location: ptr T; desired: T; order: MemoryOrder) {.inline.} =
    {.emit: ["std::atomic_store_explicit(reinterpret_cast<std::atomic<", T, "> *>(", location, "), ", desired, ", ", order, ");"].}
  proc atomic_thread_fence*(order: MemoryOrder) {.inline.} =
    {.emit: ["std::atomic_thread_fence(", order, ");"].}
else:
  {.emit: "#include <stdatomic.h>".}
  proc atomic_load_explicit*[T](location: ptr T; order: MemoryOrder): T {.inline.} =
    {.emit: "return atomic_load_explicit((_Atomic `T` *)(`location`), `order`);".}
  proc atomic_store_explicit*[T](location: ptr T; desired: T; order: MemoryOrder) {.inline.} =
    {.emit: ["atomic_store_explicit((_Atomic ", T, " *)(", location, "), ", desired, ", ", order, ");"].}
  proc atomic_thread_fence*(order: MemoryOrder) {.inline.} =
    {.emit: ["atomic_thread_fence(", order, ");"].}
{.pop.}

export MemoryOrder