#!/bin/sh
# Run on the board: Spectre v2 state, ctxbench, iio_readdev CS16 throughput, maia-httpd CPU with the waterfall open.
# Usage: spectrebench.sh  (expects /tmp/ctxbench; a /waterfall client should be connected for the CPU part)
echo "kernel: $(uname -v)"
echo "spectre_v2: $(cat /sys/devices/system/cpu/vulnerabilities/spectre_v2 2>/dev/null || echo 'no vulnerabilities dir')"
dmesg | grep -i "spectre" | head -3
/tmp/ctxbench 2
for i in 1 2 3; do
    t0=$(cut -d' ' -f1 /proc/uptime)
    iio_readdev -b 1048576 -s 40000000 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>/tmp/e
    t1=$(cut -d' ' -f1 /proc/uptime)
    echo "iio_readdev CS16 160 MB: $(echo "$t0 $t1" | awk '{printf "%.1f MB/s", 160/($2-$1)}')"
done
pid=$(pidof maia-httpd)
a=$(awk '{print $14+$15}' /proc/$pid/stat); sleep 20; b=$(awk '{print $14+$15}' /proc/$pid/stat)
hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
echo "maia-httpd CPU over 20 s: $(echo "$a $b $hz" | awk '{printf "%.1f %%", ($2-$1)/$3/20*100}')"
