#!/bin/bash
# usage: run_trace.sh <label> <nb_blocks> ; board 192.168.3.1
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad; I=$S/libiio1_host/inst
SSH="sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1"
L=$1; NB=$2
$SSH 'cat > /tmp/board_trace.sh' < $S/trc/board_trace.sh; $SSH 'chmod +x /tmp/board_trace.sh; iio_attr -c ad9361-phy voltage0 sampling_frequency 10000000 >/dev/null'
$SSH '/tmp/board_trace.sh start'
(LD_LIBRARY_PATH=$I/lib:$I/lib64 NB_BLOCKS=$NB timeout 40 $I/bin/iio_rwdev -u ip:192.168.3.1:30463 -b 262144 -s 80000000 cf-ad9361-lpc voltage0 voltage1 > $S/trc/x.bin 2>$S/trc/${L}_nb$NB.err) &
sleep 9; $SSH '/tmp/board_trace.sh stop'
wait
sshpass -p analog scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1:/tmp/trace.txt $S/trc/${L}_nb$NB.txt
wc -l $S/trc/${L}_nb$NB.txt
