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

| Entries | Liburing   | NIM        |
|---------|------------|------------|
| 64      | 10 084 304 | 25 591 082 |
| 128     | 11 346 487 | 27 040 365 |
| 256     | 11 341 468 | 26 398 882 |
| 512     | 11 668 339 | 28 281 618 |
| 1024    | 11 855 505 | 28 808 638 |
| 2048    | 11 851 992 | 28 769110  |
| 4096    | 11 816 420 | 29 134 602 |
