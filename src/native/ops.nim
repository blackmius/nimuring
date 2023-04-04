## Queues (but does not submit) an SQE to perform an `fsync(2)`.
## Returns a pointer to the SQE so that you can further modify the SQE for advanced use cases.
## For example, for `fdatasync()` you can set `IORING_FSYNC_DATASYNC` in the SQE's `rw_flags`.
## N.B. While SQEs are initiated in the order in which they appear in the submission queue,
## operations execute in parallel and completions are unordered. Therefore, an application that
## submits a write followed by an fsync in the submission queue cannot expect the fsync to
## apply to the write, since the fsync may complete before the write is issued to the disk.
## You should preferably use `link_with_next_sqe()` on a write's SQE to link it with an fsync,
## or else insert a full write barrier using `drain_previous_sqes()` when queueing an fsync.
pub fn fsync(self: *IO_Uring, user_data: u64, fd: os.fd_t, flags: u32) !*linux.io_uring_sqe {
    const sqe = try self.get_sqe();
    io_uring_prep_fsync(sqe, fd, flags);
    sqe.user_data = user_data;
    return sqe;
}