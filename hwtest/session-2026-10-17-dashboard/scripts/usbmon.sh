#!/bin/bash
# watch the Pluto+ USB link; capture board and host state at the moment of a drop
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SSH="sshpass -p analog ssh -o ConnectTimeout=4 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1"
snap() { # label
  echo "##### $1 $(date +%T)"
  timeout 20 $SSH '
    echo "uptime $(cut -d. -f1 /proc/uptime)  udc=$(cat /sys/class/udc/ci_hdrc.0/state)"
    for r in 140 144 148 184 1A4 1A8; do printf "reg %s=" $r; devmem 0xE0002$r 32; done
    grep e0002000.usb /proc/interrupts
    x=/sys/bus/iio/devices/iio:device1
    for f in $x/in_voltage*_raw $x/in_temp0_raw; do printf "%s=%s " $(basename $f) $(cat $f); done; echo
    echo "temp scale/offset: $(cat $x/in_temp0_scale) $(cat $x/in_temp0_offset)"
    dmesg | tail -5' 2>&1
  echo "-- host hub port:"; timeout 10 uhubctl -S -l 3-6 -p 1 2>&1 | head -4
  echo "-- host sysfs:"; ls /sys/bus/usb/devices | grep -c "^3-6.1$"
}
snap BASELINE
end=$(( $(date +%s)+3300 ))
n=0
while [ $(date +%s) -lt $end ]; do
  if [ ! -e /sys/bus/usb/devices/3-6.1 ]; then
    echo "!!!!! DROP DETECTED $(date +%T)"
    snap AT_DROP
    sleep 5; snap DROP_PLUS_5S
    echo MON_DONE_DROP; exit 0
  fi
  n=$((n+1)); [ $((n % 30)) -eq 0 ] && echo "ok $(date +%T) irq=$(timeout 6 $SSH 'grep e0002000.usb /proc/interrupts | awk "{print \$2}"' 2>&1)"
  sleep 2
done
echo MON_DONE_TIMEOUT
