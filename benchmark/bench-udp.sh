#!/bin/bash
echo $(uname -a)

if [ "$#" -ne 1 ]; then
    echo "Please give port where echo server is running: $0 [port]"
    exit
fi

for bytes in 1 128 512 1000
do
	for connections in 1 50 150 300 500 1000
	do
    ./udp_client 0.0.0.0 $1 $connections $bytes
   	sleep 4
	done
done