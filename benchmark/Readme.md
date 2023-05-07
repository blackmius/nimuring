# Throughput

Using NOP, we determine the upper bound of the number of operations processed by the queue

running on Intel(R) Core(TM) i7-10850H CPU @ 2.70GHz

Let's check for different queue sizes to see through how many operations it is best to do submit

| Entries | Liburing   | NIM        | using UserData |
|---------|------------|------------|----------------|
| 64      | 10 084 304 | 25 591 082 | 21 479 252     |
| 128     | 11 346 487 | 27 040 365 | 22 401 733     |
| 256     | 11 341 468 | 26 398 882 | 21 962 621     |
| 512     | 11 668 339 | 28 281 618 | 22 781 437     |
| 1024    | 11 855 505 | 28 808 638 | 23 111 091     |
| 2048    | 11 851 992 | 28 769110  | 22 954 974     |
| 4096    | 11 816 420 | 29 134 602 | 22 840 167     |

# TCP

benchmark using https://github.com/haraldh/rust_echo_bench
repetition of liburing bench https://github.com/frevib/io_uring-echo-server/blob/io-uring-feat-fast-poll/benchmarks/benchmarks.md

| clients | 1      | 50      | 150     | 300     | 500     | 1000    |
|---------|--------|---------|---------|---------|---------|---------|
| 1       | 90 209 | 286 532 | 259 486 | 235 694 | 203 969 | 212 724 |
| 128     | 94 324 | 288 035 | 279 301 | 239 588 | 207 864 | 169 701 |
| 512     | 91 143 | 285 589 | 272 248 | 252 011 | 244 735 | 189 226 |
| 1000    | 79 439 | 273 390 | 258 438 | 258 248 | 242 632 | 182 753 |

# UDP

1 thread client sending as much as possible udp packets to another socket
maybe multithreaded support would increase the limits

| clients | 1      | 50      | 150     | 300     | 500     | 1000    |
|---------|--------|---------|---------|---------|---------|---------|
| 1       | 84 201 | 335 877 | 340 776 | 342 353 | 348 954 | 331 274 |
| 128     | 88 495 | 334 609 | 335 634 | 336 765 | 341 929 | 330 750 |
| 512     | 88 243 | 322 611 | 315 701 | 330 892 | 332 808 | 337 141 |
| 1000    | 84 781 | 303 513 | 310 628 | 308 822 | 313 253 | 318 299 |

peak bandwidth is 300 MB/s with 1000 clients sending 1000 bytes each

trying maximize this value. as buffer size increased, total rps decreasing but bandwidth increasing too

Best run for bandwidth:
``` sh
clients: 1000 buffer_size: 32768
sent: 3050508 recieved: 3049509
rps:    101650 data sent:   3177.61MB/s
```

Best run for rps:
``` sh
clients: 1000 buffer_size: 1
sent: 10554258 recieved: 10553331
rps:    351778 data sent:      0.34MB/s
```

one more remark. An increase in the simultaneously expected recvmsgs on the server also leads to an increase in the number of processed packets