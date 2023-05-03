# Throughput

Using NOP, we determine the upper bound of the number of operations processed by the queue

running on Intel(R) Core(TM) i7-10850H CPU @ 2.70GHz

Let's check for different queue sizes to see through how many operations it is best to do submit

``` sh
dterlyakhin@dterlyakhin-nix:~/projects/nimuring$ gcc -O3 benchmark/throughput.c -luring
dterlyakhin@dterlyakhin-nix:~/projects/nimuring$ ./a.out 
entries=64 rps=10084304.788028
entries=128 rps=11346487.694734
entries=256 rps=11341468.947058
entries=512 rps=11668339.128608
entries=1024 rps=11855505.103795
entries=2048 rps=11851992.319909
entries=4096 rps=11816420.097367
```

``` sh
dterlyakhin@dterlyakhin-nix:~/projects/nimuring$ nim r -d:release benchmark/throughput.nim 
Hint: used config file '/home/dterlyakhin/.choosenim/toolchains/nim-1.6.10/config/nim.cfg' [Conf]
Hint: used config file '/home/dterlyakhin/.choosenim/toolchains/nim-1.6.10/config/config.nims' [Conf]
Hint: used config file '/home/dterlyakhin/projects/nimuring/benchmark/config.nims' [Conf]
Hint: gc: refc; opt: speed; options: -d:release
19462 lines; 0.019s; 16.52MiB peakmem; proj: /home/dterlyakhin/projects/nimuring/benchmark/throughput.nim; out: /home/dterlyakhin/.cache/nim/throughput_r/throughput_46CDA17435264008A949F5BB7B38583BC9030269 [SuccessX]
Hint: /home/dterlyakhin/.cache/nim/throughput_r/throughput_46CDA17435264008A949F5BB7B38583BC9030269  [Exec]
entries=64 rps=25591082.3471895
entries=128 rps=27040365.96647622
entries=256 rps=26398882.03902431
entries=512 rps=28281618.74369938
entries=1024 rps=28808638.07422781
entries=2048 rps=28769110.99678264
entries=4096 rps=29134602.94357967
```

``` sh
dterlyakhin@dterlyakhin-nix:~/projects/nimuring$ nim r -d:release -d:userdata benchmark/throughput.nim 
Hint: used config file '/home/dterlyakhin/.choosenim/toolchains/nim-1.6.10/config/nim.cfg' [Conf]
Hint: used config file '/home/dterlyakhin/.choosenim/toolchains/nim-1.6.10/config/config.nims' [Conf]
Hint: used config file '/home/dterlyakhin/projects/nimuring/benchmark/config.nims' [Conf]
.............................................................................................
CC: throughput.nim
Hint:  [Link]
Hint: gc: refc; opt: speed; options: -d:release
60695 lines; 0.737s; 75.961MiB peakmem; proj: /home/dterlyakhin/projects/nimuring/benchmark/throughput.nim; out: /home/dterlyakhin/.cache/nim/throughput_r/throughput_3157E4ECA3E6BF0233791624812ABD41D9719D43 [SuccessX]
Hint: /home/dterlyakhin/.cache/nim/throughput_r/throughput_3157E4ECA3E6BF0233791624812ABD41D9719D43  [Exec]
64 21479252.49194232
128 22401733.78666677
256 21962621.11232505
512 22781437.6663643
1024 23111091.22530106
2048 22954974.59779554
4096 22840167.00090588
```

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

``` sh
dterlyakhin@dterlyakhin-nix:~/projects/rust_echo_bench-master$ ~/projects/nimuring/benchmark/bench-tcp.sh 8080
Linux dterlyakhin-nix 5.15.0-69-generic #76~20.04.1-Ubuntu SMP Mon Mar 20 15:54:19 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
pid 103720's current affinity list: 0-11
pid 103720's new affinity list: 0
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1 --duration 60 --length 1`
Benchmarking: localhost:8080
1 clients, running 1 bytes, 60 sec.

Speed: 90209 request/sec, 90209 response/sec
Requests: 5412587
Responses: 5412587
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 50 --duration 60 --length 1`
Benchmarking: localhost:8080
50 clients, running 1 bytes, 60 sec.

Speed: 286532 request/sec, 286532 response/sec
Requests: 17191950
Responses: 17191949
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 150 --duration 60 --length 1`
Benchmarking: localhost:8080
150 clients, running 1 bytes, 60 sec.

Speed: 259486 request/sec, 259486 response/sec
Requests: 15569175
Responses: 15569175
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 300 --duration 60 --length 1`
Benchmarking: localhost:8080
300 clients, running 1 bytes, 60 sec.

Speed: 235694 request/sec, 235694 response/sec
Requests: 14141668
Responses: 14141667
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 500 --duration 60 --length 1`
Benchmarking: localhost:8080
500 clients, running 1 bytes, 60 sec.

Speed: 203969 request/sec, 203969 response/sec
Requests: 12238153
Responses: 12238152
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1000 --duration 60 --length 1`
Benchmarking: localhost:8080
1000 clients, running 1 bytes, 60 sec.

Speed: 212724 request/sec, 212724 response/sec
Requests: 12763442
Responses: 12763441
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1 --duration 60 --length 128`
Benchmarking: localhost:8080
1 clients, running 128 bytes, 60 sec.

Speed: 94324 request/sec, 94324 response/sec
Requests: 5659485
Responses: 5659485
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 50 --duration 60 --length 128`
Benchmarking: localhost:8080
50 clients, running 128 bytes, 60 sec.

Speed: 288035 request/sec, 288035 response/sec
Requests: 17282124
Responses: 17282124
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 150 --duration 60 --length 128`
Benchmarking: localhost:8080
150 clients, running 128 bytes, 60 sec.

Speed: 279301 request/sec, 279301 response/sec
Requests: 16758097
Responses: 16758095
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 300 --duration 60 --length 128`
Benchmarking: localhost:8080
300 clients, running 128 bytes, 60 sec.

Speed: 239588 request/sec, 239588 response/sec
Requests: 14375288
Responses: 14375287
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 500 --duration 60 --length 128`
Benchmarking: localhost:8080
500 clients, running 128 bytes, 60 sec.

Speed: 207864 request/sec, 207863 response/sec
Requests: 12471840
Responses: 12471839
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1000 --duration 60 --length 128`
Benchmarking: localhost:8080
1000 clients, running 128 bytes, 60 sec.

Speed: 169701 request/sec, 169701 response/sec
Requests: 10182100
Responses: 10182099
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1 --duration 60 --length 512`
Benchmarking: localhost:8080
1 clients, running 512 bytes, 60 sec.

Speed: 91143 request/sec, 91143 response/sec
Requests: 5468637
Responses: 5468636
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 50 --duration 60 --length 512`
Benchmarking: localhost:8080
50 clients, running 512 bytes, 60 sec.

Speed: 285589 request/sec, 285589 response/sec
Requests: 17135381
Responses: 17135380
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 150 --duration 60 --length 512`
Benchmarking: localhost:8080
150 clients, running 512 bytes, 60 sec.

Speed: 272248 request/sec, 272248 response/sec
Requests: 16334901
Responses: 16334899
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 300 --duration 60 --length 512`
Benchmarking: localhost:8080
300 clients, running 512 bytes, 60 sec.

Speed: 252011 request/sec, 252011 response/sec
Requests: 15120697
Responses: 15120696
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 500 --duration 60 --length 512`
Benchmarking: localhost:8080
500 clients, running 512 bytes, 60 sec.

Speed: 244735 request/sec, 244735 response/sec
Requests: 14684159
Responses: 14684158
    Finished release [optimized] target(s) in 0.02s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1000 --duration 60 --length 512`
Benchmarking: localhost:8080
1000 clients, running 512 bytes, 60 sec.

Speed: 189226 request/sec, 189226 response/sec
Requests: 11353572
Responses: 11353571
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1 --duration 60 --length 1000`
Benchmarking: localhost:8080
1 clients, running 1000 bytes, 60 sec.

Speed: 79439 request/sec, 79439 response/sec
Requests: 4766378
Responses: 4766378
    Finished release [optimized] target(s) in 0.01s
     Running `target/release/echo_bench --address 'localhost:8080' --number 50 --duration 60 --length 1000`
Benchmarking: localhost:8080
50 clients, running 1000 bytes, 60 sec.

Speed: 273390 request/sec, 273390 response/sec
Requests: 16403456
Responses: 16403453
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 150 --duration 60 --length 1000`
Benchmarking: localhost:8080
150 clients, running 1000 bytes, 60 sec.

Speed: 258438 request/sec, 258438 response/sec
Requests: 15506327
Responses: 15506325
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 300 --duration 60 --length 1000`
Benchmarking: localhost:8080
300 clients, running 1000 bytes, 60 sec.

Speed: 258248 request/sec, 258248 response/sec
Requests: 15494893
Responses: 15494891
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 500 --duration 60 --length 1000`
Benchmarking: localhost:8080
500 clients, running 1000 bytes, 60 sec.

Speed: 242632 request/sec, 242632 response/sec
Requests: 14557927
Responses: 14557926
    Finished release [optimized] target(s) in 0.00s
     Running `target/release/echo_bench --address 'localhost:8080' --number 1000 --duration 60 --length 1000`
Benchmarking: localhost:8080
1000 clients, running 1000 bytes, 60 sec.

Speed: 182753 request/sec, 182753 response/sec
Requests: 10965211
Responses: 10965210
```

| clients | 1      | 50      | 150     | 300     | 500     | 1000    |
|---------|--------|---------|---------|---------|---------|---------|
| 1       | 90 209 | 286 532 | 259 486 | 235 694 | 203 969 | 212 724 |
| 128     | 94 324 | 288 035 | 279 301 | 239 588 | 207 864 | 169 701 |
| 512     | 91 143 | 285 589 | 272 248 | 252 011 | 244 735 | 189 226 |
| 1000    | 79 439 | 273 390 | 258 438 | 258 248 | 242 632 | 182 753 |

# UDP

1 thread client sending as much as possible udp packets to another socket
maybe multithreaded support would increase the limits

```
dterlyakhin@dterlyakhin-nix:~/projects/nimuring/benchmark$ ./bench-udp.sh 8000
Linux dterlyakhin-nix 5.15.0-69-generic #76~20.04.1-Ubuntu SMP Mon Mar 20 15:54:19 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
clients: 1 buffer_size: 1
sent: 2526040 recieved: 2526039
rps:   84201.3 data sent:      2.41MB
clients: 50 buffer_size: 1
sent: 10076359 recieved: 10076310
rps:    335877 data sent:      9.61MB
clients: 150 buffer_size: 1
sent: 10223414 recieved: 10223270
rps:    340776 data sent:      9.75MB
clients: 300 buffer_size: 1
sent: 10270877 recieved: 10270586
rps:    342353 data sent:      9.80MB
clients: 500 buffer_size: 1
sent: 10469118 recieved: 10468624
rps:    348954 data sent:      9.98MB
clients: 1000 buffer_size: 1
sent: 9939208 recieved: 9938224
rps:    331274 data sent:      9.48MB
clients: 1 buffer_size: 128
sent: 2654863 recieved: 2654863
rps:   88495.4 data sent:    324.08MB
clients: 50 buffer_size: 128
sent: 10038313 recieved: 10038264
rps:    334609 data sent:   1225.38MB
clients: 150 buffer_size: 128
sent: 10069157 recieved: 10069024
rps:    335634 data sent:   1229.15MB
clients: 300 buffer_size: 128
sent: 10103235 recieved: 10102949
rps:    336765 data sent:   1233.31MB
clients: 500 buffer_size: 128
sent: 10258355 recieved: 10257869
rps:    341929 data sent:   1252.24MB
clients: 1000 buffer_size: 128
sent: 9923498 recieved: 9922502
rps:    330750 data sent:   1211.36MB
clients: 1 buffer_size: 512
sent: 2647308 recieved: 2647308
rps:   88243.6 data sent:   1292.63MB
clients: 50 buffer_size: 512
sent: 9678361 recieved: 9678319
rps:    322611 data sent:   4725.76MB
clients: 150 buffer_size: 512
sent: 9471166 recieved: 9471024
rps:    315701 data sent:   4624.59MB
clients: 300 buffer_size: 512
sent: 9927062 recieved: 9926769
rps:    330892 data sent:   4847.20MB
clients: 500 buffer_size: 512
sent: 9984720 recieved: 9984226
rps:    332808 data sent:   4875.35MB
clients: 1000 buffer_size: 512
sent: 10115218 recieved: 10114225
rps:    337141 data sent:   4939.07MB
clients: 1 buffer_size: 1000
sent: 2543449 recieved: 2543448
rps:   84781.6 data sent:   2425.62MB
clients: 50 buffer_size: 1000
sent: 9105423 recieved: 9105376
rps:    303513 data sent:   8683.61MB
clients: 150 buffer_size: 1000
sent: 9318986 recieved: 9318837
rps:    310628 data sent:   8887.28MB
clients: 300 buffer_size: 1000
sent: 9264962 recieved: 9264668
rps:    308822 data sent:   8835.76MB
clients: 500 buffer_size: 1000
sent: 9398076 recieved: 9397581
rps:    313253 data sent:   8962.70MB
clients: 1000 buffer_size: 1000
sent: 9549964 recieved: 9548971
rps:    318299 data sent:   9107.56MB
```

| clients | 1      | 50      | 150     | 300     | 500     | 1000    |
|---------|--------|---------|---------|---------|---------|---------|
| 1       | 84 201 | 335 877 | 340 776 | 342 353 | 348 954 | 331 274 |
| 128     | 88 495 | 334 609 | 335 634 | 336 765 | 341 929 | 330 750 |
| 512     | 88 243 | 322 611 | 315 701 | 330 892 | 332 808 | 337 141 |
| 1000    | 84 781 | 303 513 | 310 628 | 308 822 | 313 253 | 318 299 |

peak bandwidth is 300 MB/s with 1000 clients sending 1000 bytes each

trying maximize this value

``` sh
dterlyakhin@dterlyakhin-nix:~/projects/nimuring/benchmark$ ./udp_client 0.0.0.0 8000 1000 8192
clients: 1000 buffer_size: 8192
sent: 5266980 recieved: 5265981
rps:    175533 data sent:   1371.61MB/s
dterlyakhin@dterlyakhin-nix:~/projects/nimuring/benchmark$ ./udp_client 0.0.0.0 8000 1000 16384
clients: 1000 buffer_size: 16384
sent: 4353558 recieved: 4352559
rps:    145085 data sent:   2267.48MB/s
dterlyakhin@dterlyakhin-nix:~/projects/nimuring/benchmark$ ./udp_client 0.0.0.0 8000 1000 32768
clients: 1000 buffer_size: 32768
sent: 3050508 recieved: 3049509
rps:    101650 data sent:   3177.61MB/s
```

as buffer size increased, total rps decreasing but bandwidth increasing too

```
dterlyakhin@dterlyakhin-nix:~/projects/nimuring/benchmark$ ./udp_client 0.0.0.0 8000 1000 60000
clients: 1000 buffer_size: 60000
sent: 1522395 recieved: 1521395
rps:   50713.2 data sent:   2903.74MB/s
```

hmm, it has some maximum point

one more remark. An increase in the simultaneously expected recvmsgs on the server also leads to an increase in the number of processed packets

``` sh
clients: 1000 buffer_size: 1
sent: 10554258 recieved: 10553331
rps:    351778 data sent:      0.34MB/s
```