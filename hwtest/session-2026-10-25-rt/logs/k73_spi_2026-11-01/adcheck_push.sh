#!/bin/sh
# AD9361 control-path health: product id regs via debugfs, sf write+readback, kernel log counters
P=$(dirname $(grep -l '^ad9361-phy$' /sys/bus/iio/devices/iio:device*/name)); N=$(basename $P); D=/sys/kernel/debug/iio/$N
r(){ echo $1 > $D/direct_reg_access; cat $D/direct_reg_access; }
echo "regs 0x037=$(r 0x037) 0x002=$(r 0x002) 0x003=$(r 0x003) 0x017=$(r 0x017)"
b=$(dmesg | grep -c -E 'Calibration TIMEOUT|Failed to set|Error -110')
echo "sf_read=$(cat $P/in_voltage_sampling_frequency)"
echo 5000000 > $P/in_voltage_sampling_frequency 2>&1; echo "sf_after_write=$(cat $P/in_voltage_sampling_frequency) ensm=$(cat $P/ensm_mode)"
echo "spito=$(dmesg | grep -c 'SPI transfer timed out') errlines_before_write=$b errlines_now=$(dmesg | grep -c -E 'Calibration TIMEOUT|Failed to set|Error -110')"
PM=/sys/bus/platform/devices/e0006000.spi/power; echo on > $PM/control; sleep 0.2; echo "ISR=$(devmem 0xE0006004 32)"; echo auto > $PM/control
