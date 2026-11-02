#!/bin/bash
# usage: usb_trial_host.sh <label> <host-side loop command>  (reboots the Pluto+ first; host command runs while USB is watched)
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SSHO="-o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
SSH="sshpass -p analog ssh $SSHO root@192.168.3.1"
label=$1; cmd=$2
$SSH 'sync; reboot' >/dev/null 2>&1; sleep 30
for i in $(seq 1 30); do u=$($SSH 'cut -d. -f1 /proc/uptime' 2>/dev/null); [ -n "$u" ] && [ "$u" -lt 150 ] && break; sleep 5; done
sleep 25
[ -e /sys/bus/usb/devices/3-6.1 ] || { echo "[$label] no usb after boot"; exit 1; }
head -c 100000 /dev/urandom > /tmp/blob100k
( eval "$cmd" ) > /dev/null 2>&1 &
cp=$!
t0=$(date +%s)
while [ $(( $(date +%s)-t0 )) -lt 150 ]; do
  if [ ! -e /sys/bus/usb/devices/3-6.1 ]; then
    echo "[$label] >>> USB DROP after $(( $(date +%s)-t0 )) s (PORTSC $($SSH 'devmem 0xE0002184 32' 2>&1))"; kill $cp 2>/dev/null; exit 0
  fi; sleep 0.5
done
kill $cp 2>/dev/null; echo "[$label] no drop in 150 s"
