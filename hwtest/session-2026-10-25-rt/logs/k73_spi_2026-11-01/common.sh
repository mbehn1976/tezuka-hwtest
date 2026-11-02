S=/tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad; K=$S/k73spi
H=192.168.4.1
SSH="sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$H"
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $O/run.log; }
reboot_verify(){  # $1 = expected kernel prefix
  log "reboot board"; timeout 15 $SSH 'sync; reboot' || true; sleep 25
  for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
  info=$(timeout 20 $SSH 'echo $(uname -r) $(cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber 2>/dev/null | head -1)')
  log "board: $info"
  case "$info" in $1*WZ5Z6HQZ6IXHI5QI*) ;; *) log "ABORT: not the Pluto+ on $1"; exit 1;; esac
  sleep 60
  timeout 20 $SSH 'cat > /tmp/prio.sh' < $K/prio.sh; timeout 20 $SSH 'cat > /tmp/mon_board.sh' < $K/mon_board2.sh
  timeout 20 $SSH 'cat > /tmp/radio_on.sh' < $K/radio_on.sh; timeout 20 $SSH 'cat > /tmp/radio_off.sh' < $K/radio_off.sh
  timeout 30 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin
}
mon_start(){ ( while [ ! -e $O/stop ]; do Lm=$(timeout 30 $SSH "sh /tmp/mon_board.sh" 2>&1); A=$(curl -s -m8 -o /dev/null -w "%{http_code}" http://$H/api/ad9361); echo "$(date +%H:%M:%S) $Lm api=$A" >> $O/mon.log; for j in $(seq 55); do [ -e $O/stop ] && break; sleep 1; done; done ) & MON=$!; }
mon_stop(){ touch $O/stop; wait $MON; }
spito(){ timeout 20 $SSH 'dmesg | grep -c "SPI transfer timed out"'; }
set_ktimers(){ timeout 20 $SSH "for p in \$(grep -l '^ktimers/' /proc/[0-9]*/comm | cut -d/ -f3); do chrt -f -p $1 \$p; done; sh /tmp/prio.sh | grep ktimers | tr '\n' ' '"; }
spiregs(){  # $1 = label; keeps the controller powered while reading (no bus hang), never reads RXD (0x20)
  timeout 40 $SSH 'which devmem >/dev/null || exit 0; PM=/sys/bus/platform/devices/e0006000.spi/power; echo on > $PM/control; sleep 0.2; printf "pm=%s " $(cat $PM/runtime_status); for o in 0x00:CR 0x04:ISR 0x10:IMR 0x14:ER 0x28:TXWR 0x2C:RXTHR; do a=$((0xE0006000 + ${o%%:*})); printf "%s=%s " ${o##*:} $(devmem $a 32); done; echo auto > $PM/control; echo' | sed "s/^/$1: /" >> $O/spiregs.txt
  log "spiregs $1: $(tail -1 $O/spiregs.txt | cut -d: -f2-)"
}
