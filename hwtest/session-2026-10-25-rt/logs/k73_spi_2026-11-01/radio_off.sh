#!/bin/sh
P=$(dirname $(grep -l '^ad9361-phy$' /sys/bus/iio/devices/iio:device*/name))
kill $(pgrep iio_writedev) 2>/dev/null; sleep 1; echo -89 > $P/out_voltage0_hardwaregain; echo tx_muted
