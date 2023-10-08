# nimlang io_uring (nimuring)

This is a pure implementation of io_uring in nim.

The library was based on several implementations of io_uring in other languages at once,
such as:
* [liubring](https://github.com/axboe/liburing) (the original library from the author of io_uring),
* the [implementation of io_uring in the Zig language](https://github.com/ziglang/zig/blob/master/lib/std/os/linux/io_uring.zig),
* as well as the [implementation in Rust](https://docs.rs/io-uring/latest/io_uring/index.html).

Mostly on liburing

## Documentation

I inserted lines from man for convenience into the binding to the io_uring kernel, but the documentation generator could not display it in normal form, so use man and read the code.

The library consists of 3 modules:
1. actual ABI to kernel io_uring [src/io_uring.nim](./src/nimuring/io_uring.nim)
2. interface for easy usage [src/queue.nim](./src/nimuring/queue.nim)
3. and builder pattern for making SQE [src/ops.nim](./src/nimuring/ops.nim)

also there is [utility module](./src/nimuring/barrier.nim) to make atomic reads/writes but I concidering it belongs to queue.

### Creating Submition and Completion queues

To start submitting commands to the io_uring subsystem and then recieve completion, a convenient wrapper was made that creates and manages both rings.

``` nim
import nimuring

let queue = newQueue(2, { SETUP_SQPOLL })
```

we have created sqe/cqe queue with ability to submiting 2 entries
and revieving 4 complitions

by default completion ring is 2x size of submition ring to survive overflows
(remark if overflow is actually happened you cannot submit more sqe's but it's advanced usage)
There is examples/sqOverflow.nim to see an example of how to bypass this

second parameter is io_uring flags. List of available flags you can see in [src/io_uring.nim](./src/nimuring/io_uring.nim)

There are others parameters you can use but it's also is advanced theme.

### Submitting OPS

after creating queue you can submit operations to it. The library provides the following API:
1. you asks queue to allocate SQE in submission ring
2. and after getting pointer to it filling it with parameters you need
3. to not remembering all ops parameters theris utility templates to fill it.

``` nim
import nimuring

let queue = newQueue(2, { SETUP_SQPOLL })
let sqe = queue.getSqe()
sqe.write(stdout.getFileHandle, "Hello world\n")
# proc write*(sqe: SqePointer; fd: FileHandle; str: string; offset: int = 0): SqePointer

queue.submit()
# all alocated previosly sqes will be submited

echo q.copyCqes(1)
# waits until completing
```

as you can see every op returning SqePointer back and by this builder pattern can be made

``` nim
queue.getSqe().write(stdout.getFileHandle, "Hello world\n").setUserData(0)
```

every op utility is just set of commands which filling sqe with right converted values.
so setUserData is setting sqe.userData field with given value.


### Recieving Completions

io_uring completion is fully parallel. But if you wish to await completion you can wait for them blocking current thread.

1. you can await completion when submiting
``` nim
queue.getSqe().write(stdout.getFileHandle, "Hello world\n")
queue.submit(1)
## proc submit*(queue: var Queue; waitNr: uint = 0): int
# submit will wait until waitNr count of completions
```

2. waiting for completions then copying them
``` nim
queue.getSqe().write(stdout.getFileHandle, "Hello world\n")
queue.submit()
echo queue.copyCqes(1)
## proc copyCqes*(queue: var Queue; waitNr: uint = 0): seq[Cqe]
# waiting waitNr the same as submit(waitNr=1)
```

3. dont wait just check for completions (convenient when implementing your own event loop)
``` nim
queue.getSqe().write(stdout.getFileHandle, "Hello world\n")
queue.submit()
echo queue.copyCqes()
# maybe empty @[]

# also can copy to prealocated array

let cqes = newSeq[Cqe](16)
queue.copyCqes(cqes)
## will not allocate new seq but copy to specified one
```

### That's all the api

There are of course more but it all documented in man files like registering fd/buffers/files
and many flags and ops

### async/await

There is a way to trigger event fd when result is added into CQring. And if it is registered in asyncdispatch loop it will be dispatched in callback, which should read CQring and do something upon results

example in c: https://unixism.net/loti/tutorial/register_eventfd.html

But since the nature of io_uring is different from the nature of selectors, i don't think it is possible to combine the io_uring queue and at the same time maintain acceptable performance.

Because of this, I tried to implement another event loop, which preserve same async/await api from the standard library.
https://github.com/blackmius/uasync

## Examples

examples can be found in `examples` folder
see examples of udp and tcp server in [benchmark folder](./benchmark/)
and also check the usage of OPS in [./tests/ops](./tests/ops/)