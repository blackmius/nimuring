#include <stdio.h>   
#include <stdlib.h> 
#include <liburing.h>

#define repeat 1000000

void run(int entries) {
    struct io_uring ring;
    io_uring_queue_init(entries, &ring, 0);

    int count = 0;

    clock_t start, end;
    start = clock();
    while (count < repeat) {
        for (int i = 0; i < entries; i++) {
            struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
            io_uring_prep_nop(sqe);
            io_uring_sqe_set_data(sqe, (void*) (intptr_t) i);
        }
        io_uring_submit(&ring);
        struct io_uring_cqe **cqes = malloc(sizeof(struct io_uring_cqe) * entries);
        io_uring_peek_batch_cqe(&ring, cqes, entries);
        count += entries;
    }
    end = clock();
    double time_taken = (double)(end - start) / (double)(CLOCKS_PER_SEC);
    double rps = repeat / time_taken;
    printf("entries=%d rps=%f\n", entries, rps);
}

int main() {
    // from 64 to 4096
    for (int i = 5; i < 12; i++) {
        run(2 << i);
    }
    return 0;
}