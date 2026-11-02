#!/bin/sh
# usage: radio_on.sh <sample rate>
P=$(dirname $(grep -l '^ad9361-phy$' /sys/bus/iio/devices/iio:device*/name)); N=$(basename $P)
echo $1 > $P/in_voltage_sampling_frequency
echo 1 > /sys/kernel/debug/iio/$N/loopback
iio_writedev -c -b 65536 cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin > /dev/null 2>&1 &
sleep 3
echo "phy=$N sf=$(cat $P/in_voltage_sampling_frequency) loopback=$(cat /sys/kernel/debug/iio/$N/loopback) writer=$(pgrep iio_writedev | wc -l)"
