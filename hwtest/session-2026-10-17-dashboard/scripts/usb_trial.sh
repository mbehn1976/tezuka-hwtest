#!/bin/bash
# usage: usb_trial.sh <label> <board-side shell loop body>   (reboots the Pluto+ first)
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SSH="sshpass -p analog ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1"
label=$1; body=$2
$SSH 'sync; reboot' >/dev/null 2>&1; sleep 30
for i in $(seq 1 30); do u=$($SSH 'cut -d. -f1 /proc/uptime' 2>/dev/null); [ -n "$u" ] && [ "$u" -lt 150 ] && break; sleep 5; done
sleep 25
[ -e /sys/bus/usb/devices/3-6.1 ] || { echo "[$label] no usb after boot"; exit 1; }
P=/sys/bus/iio/devices/iio:device0
$SSH "echo 61440000 > $P/in_voltage_sampling_frequency; echo 49152000 > $P/in_voltage_rf_bandwidth; echo 49152000 > $P/out_voltage_rf_bandwidth; echo 2400000000 > $P/out_altvoltage1_TX_LO_frequency; echo 2400000000 > $P/out_altvoltage0_RX_LO_frequency; dd if=/dev/urandom of=/tmp/rf_tx.bin bs=1024 count=100 2>/dev/null" >/dev/null 2>&1
printf '%s\n' "for i in \$(seq 1 200); do $body; done" > /tmp/trial_body.sh
sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1 'cat > /tmp/trial.sh' < /tmp/trial_body.sh
$SSH 'nohup sh /tmp/trial.sh > /tmp/trial.log 2>&1 &'
t0=$(date +%s)
while [ $(( $(date +%s)-t0 )) -lt 150 ]; do
  if [ ! -e /sys/bus/usb/devices/3-6.1 ]; then
    echo "[$label] >>> USB DROP after $(( $(date +%s)-t0 )) s (PORTSC $($SSH 'devmem 0xE0002184 32' 2>&1))"; $SSH 'kill $(pidof sh) 2>/dev/null' >/dev/null 2>&1; exit 0
  fi; sleep 0.5
done
echo "[$label] no drop in 150 s"
