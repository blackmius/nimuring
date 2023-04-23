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
