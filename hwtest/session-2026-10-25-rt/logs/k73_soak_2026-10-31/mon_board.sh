#!/bin/sh
D=/sys/bus/iio/devices/iio:device0
P=/sys/bus/iio/devices/iio:device1
T=$(awk -v r=$(cat $D/in_temp0_raw) -v o=$(cat $D/in_temp0_offset) -v s=$(cat $D/in_temp0_scale) 'BEGIN{printf "%.1f",(r+o)*s/1000}')
SF=$(cat $P/in_voltage_sampling_frequency 2>/dev/null || echo ERR)
echo "up=$(cut -d' ' -f1 /proc/uptime) avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)k iiod_rss=$(awk '/VmRSS/{print $2}' /proc/$(pgrep -x iiod|head -1)/status)k tempC=$T writer=$(pgrep iio_writedev | wc -l) load=$(cut -d' ' -f1 /proc/loadavg) qspi_irq=$(awk '/e000d000/{print $2}' /proc/interrupts) spi0_irq=$(awk '/e0006000/{print $2}' /proc/interrupts) sf=$SF bad=$(dmesg | grep -c -E 'BUG:|WARNING:|Oops|rcu.*stall|hung task|blocked for more|page allocation failure|Out of memory|oom-kill|Call Trace|timed out|Error -110|Read Error|Write Error')"
