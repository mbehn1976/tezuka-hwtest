#!/bin/bash
# Pluto+ power test: TX on at 0 dB gain + local CPU bursts, board side only. Finds the Pluto+ by USB serial, so it works on any port.
# usage: usb_t5.sh [seconds=300] [gain=0]
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SER=WZ5Z6HQZ6IXHI5QI
SECS=${1:-300}; GAIN=${2:-0}
SSHO="-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SSH="sshpass -p analog ssh $SSHO root@192.168.3.1"
usbpath() { for d in /sys/bus/usb/devices/*; do [ "$(cat $d/serial 2>/dev/null)" = "$SER" ] && { basename $d; return; }; done; }
usb() { [ -n "$(usbpath)" ]; }
$SSH 'sync; reboot' >/dev/null 2>&1; sleep 30
for i in $(seq 1 30); do u=$($SSH 'cut -d. -f1 /proc/uptime' 2>/dev/null); [ -n "$u" ] && [ "$u" -lt 150 ] && break; sleep 5; done
sleep 25
usb || { echo "Pluto+ not visible on USB after boot"; exit 1; }
echo "Pluto+ on USB path $(usbpath), gain $GAIN dB, $SECS s ($(date +%T))"
P=/sys/bus/iio/devices/iio:device0
$SSH "echo 61440000 > $P/in_voltage_sampling_frequency; echo 49152000 > $P/in_voltage_rf_bandwidth; echo 49152000 > $P/out_voltage_rf_bandwidth; echo 2400000000 > $P/out_altvoltage1_TX_LO_frequency; echo 2400000000 > $P/out_altvoltage0_RX_LO_frequency; dd if=/dev/urandom of=/tmp/rf_tx.bin bs=1024 count=100 2>/dev/null" >/dev/null 2>&1
cat > /tmp/t5_body.sh <<EOF
for i in \$(seq 1 1000); do
  echo $GAIN > $P/out_voltage0_hardwaregain
  pidof iio_writedev >/dev/null || (iio_writedev -c -b 25000 cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin > /dev/null 2>&1 &)
  (timeout 1 sh -c 'while :; do :; done' &); timeout 1 sh -c 'while :; do :; done'; sleep 1
done
EOF
sshpass -p analog ssh $SSHO root@192.168.3.1 'cat > /tmp/t5.sh' < /tmp/t5_body.sh
$SSH 'nohup sh /tmp/t5.sh > /tmp/t5.log 2>&1 &'
t0=$(date +%s)
while [ $(( $(date +%s)-t0 )) -lt $SECS ]; do
  usb || { echo ">>> USB DROP after $(( $(date +%s)-t0 )) s"; $SSH 'kill $(pidof sh) $(pidof iio_writedev) 2>/dev/null' >/dev/null 2>&1; exit 0; }
  sleep 0.5
done
$SSH 'kill $(pidof sh) $(pidof iio_writedev) 2>/dev/null' >/dev/null 2>&1
echo "no drop in $SECS s at TX gain $GAIN dB"
