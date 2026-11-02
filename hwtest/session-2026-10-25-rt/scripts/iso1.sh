SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
I1=$SP/libiio1_host/inst
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
iio_attr -u ip:192.168.3.1 -i -c ad9361-phy voltage0 sampling_frequency 10000000 > /dev/null
export LD_LIBRARY_PATH=$I1/lib:$I1/lib64 NB_BLOCKS=32
echo "== core 1 isolated, iiod on core 0, 10 MS/s stream (32 blocks), 300 s"
timeout 330 $I1/bin/iio_rwdev -u ip:192.168.3.1 -b 262144 -s 1000000000 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2> $SP/iso1_stream.err &
sleep 5
$S 'for t in /proc/$(pidof iiod)/task/*; do taskset -p $(basename $t); done | sort | uniq -c; cyclictest -t1 -p99 -i250 -a1 -D 300s -m -q | tail -1'
kill %1 2>/dev/null; sleep 1
echo "== core 0 reference, idle, 120 s"
$S 'cyclictest -t1 -p99 -i250 -a0 -D 120s -m -q | tail -1; dmesg | grep -c "SPI transfer timed out"; uptime'
echo ALLDONE
