#!/bin/sh
# usage: pidglitch.sh N [auto|on]
# N reads of the AD9361 product id register (0x037, expected 0xA) through the IIO debugfs, each after 4 s of idle
# (past the SPI controller's 3 s runtime autosuspend). With 'on' the controller is kept active (power/control = on),
# so a difference between the two modes points at the runtime resume path. One summary line at the end.
N=${1:-150}; MODE=${2:-auto}
P=$(dirname $(grep -l '^ad9361-phy$' /sys/bus/iio/devices/iio:device*/name)); D=/sys/kernel/debug/iio/$(basename $P)
PM=/sys/bus/platform/devices/e0006000.spi/power
echo $MODE > $PM/control
bad=0; vals=""; i=0
while [ $i -lt $N ]; do
	sleep 4
	echo 0x037 > $D/direct_reg_access
	v=$(cat $D/direct_reg_access)
	[ "$v" = 0xA ] || { bad=$((bad + 1)); vals="$vals $i:$v:$(cat $PM/runtime_status)"; }
	i=$((i + 1))
done
echo "pidglitch mode=$MODE reads=$N off=$bad$vals spito=$(dmesg | grep -c 'SPI transfer timed out') readerr=$(dmesg | grep -c 'Read Error')"
echo auto > $PM/control
