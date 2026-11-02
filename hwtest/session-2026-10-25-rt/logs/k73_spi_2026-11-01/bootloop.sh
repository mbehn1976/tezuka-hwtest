#!/bin/bash
# usage: bootloop.sh NAME CYCLES [KERNEL_PREFIX]
# Reboot the Pluto+ CYCLES times and keep every kernel log. Per boot: reboot over SSH (ACM console as fallback), wait up
# to 3 min for SSH, fetch dmesg and the watcher's fault dumps, check the addresses and the AD9361, count fault lines in
# the kernel log and USB events in the host journal. A boot without SSH is read over the ACM console instead.
# touch $O/stop to end the loop early.
NAME=$1; N=$2; KP=${3:-7.3.0}
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/$NAME; mkdir -p $O/logs; rm -f $O/stop
ACM=/dev/ttyACM0; AP=$S/acm.py
FAULT='blocked for more than|rcu: INFO|not taken|error: _ep_set_halt|BUG:|Oops|WARNING:'
HOSTEV='rndis.*-110|probe with driver rndis_host failed|device descriptor read.*error|reset high-speed|tx timeout|Tx timeout'
log "== $NAME: $N boot cycles, kernel $KP"
for i in $(seq 1 $N); do
  [ -e $O/stop ] && { log "stop file seen after $((i - 1)) cycles"; break; }
  t0=$(date +%s)
  timeout 15 $SSH 'sync; reboot' > /dev/null 2>&1 || ACM_READ=2 timeout 30 python3 $AP $ACM 'reboot' > /dev/null 2>&1 || log "boot $i: no way to reboot the board"
  sleep 25
  up=0; for j in $(seq 36); do timeout 10 $SSH true 2> /dev/null && { up=1; break; }; sleep 5; done
  if [ $up = 1 ]; then
    timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh
    timeout 60 $SSH 'dmesg' > $O/logs/boot_$i.dmesg 2> /dev/null
    info=$(timeout 60 $SSH 'echo "up=$(cut -d" " -f1 /proc/uptime) kernel=$(uname -r) usb0=$(ip -br -4 addr show usb0 | awk "{print \$3}") eth0=$(ip -br -4 addr show eth0 | awk "{print \$3}") dumps=$(ls /tmp/fault_dmesg_*_post.txt 2>/dev/null | wc -l) $(sh /tmp/adcheck.sh 2>/dev/null | head -1)"' 2>&1 | tr '\n' ' ')
    for f in $(timeout 20 $SSH 'ls /tmp/fault_dmesg_*.txt /tmp/fault_log.txt 2>/dev/null'); do timeout 60 $SSH "cat $f" > $O/logs/boot_${i}_$(basename $f) 2> /dev/null; done
    src=$O/logs/boot_$i.dmesg
  else
    log "boot $i: no SSH after 3 min, reading the ACM console"
    ACM_READ=8 timeout 90 python3 $AP $ACM 'dmesg | tail -n 300' > $O/logs/boot_$i.acm 2>&1 || log "boot $i: ACM console FAILED"
    ACM_READ=3 timeout 60 python3 $AP $ACM 'echo up=$(cut -d" " -f1 /proc/uptime) kernel=$(uname -r) usb0=$(ip -br -4 addr show usb0 | awk "{print \$3}") eth0=$(ip -br -4 addr show eth0 | awk "{print \$3}")' 'cat /tmp/fault_log.txt' >> $O/logs/boot_$i.acm 2>&1
    info="NOSSH acm_bytes=$(wc -c < $O/logs/boot_$i.acm 2>/dev/null) $(grep -o 'up=[^ ]* kernel=[^ ]* usb0=[^ ]* eth0=[^ ]*' $O/logs/boot_$i.acm | tail -1)"
    src=$O/logs/boot_$i.acm
  fi
  pat=$(grep -a -c -E "$FAULT" $src 2> /dev/null); pat=${pat:-0}
  h=$(journalctl -k --since "@$t0" --no-pager -q 2> /dev/null | grep -c -E "$HOSTEV")
  log "boot $i: $info faultlines=$pat hostusb=$h"
  echo "boot $i: $info faultlines=$pat hostusb=$h" >> $O/boots.txt
  [ "$pat" != 0 ] || [ "$h" != 0 ] || [ $up = 0 ] && journalctl --since "@$t0" --no-pager -q > $O/logs/boot_$i.hostjournal 2> /dev/null
done
log "== $NAME done: $(grep -c ' faultlines=0 hostusb=0' $O/boots.txt) clean of $(grep -c . $O/boots.txt); with fault lines: $(grep -vc ' faultlines=0 ' $O/boots.txt); without SSH: $(grep -c NOSSH $O/boots.txt)"
