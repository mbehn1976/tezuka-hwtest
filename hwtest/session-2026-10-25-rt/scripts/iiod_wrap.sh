#!/bin/sh
# run iiod in the foreground and record how it ends
ulimit -c unlimited
echo '/tmp/core.%e.%p' > /proc/sys/kernel/core_pattern
echo 1 > /proc/sys/kernel/print-fatal-signals
rm -f /tmp/iiod_exit.log
/usr/sbin/iiod -n 3 -F /dev/iio_ffs
rc=$?
echo "iiod exit rc=$rc (128+sig if signal) at uptime $(cut -d' ' -f1 /proc/uptime)" >> /tmp/iiod_exit.log
dmesg | tail -n 15 >> /tmp/iiod_exit.log
logger "iiod exit rc=$rc"
