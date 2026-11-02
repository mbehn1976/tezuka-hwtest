#!/bin/bash
# one 7.3 boot; ktimers at each priority in turn; 15 rounds of 4 and 32 blocks at 10 MS/s over Ethernet
set -u
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/E_eth_prio; mkdir -p $O; rm -f $O/stop
log "== E_eth_prio: ktimers 99 51 49 1, Ethernet 192.168.3.1, 10 MS/s, NBS 4,32, 15 rounds each"
reboot_verify 7.3.0-rc7
spiregs fresh_boot
log "radio: $(timeout 30 $SSH 'sh /tmp/radio_on.sh 10000000')"
mon_start
for p in 99 51 49 1; do
  log "ktimers -> $p: $(set_ktimers $p)"
  s0=$(spito); log "  ping 192.168.3.1: $(ping -c5 -i0.3 -W1 192.168.3.1 | tail -1); spito before $s0"
  D=$O I1=$S/libiio1 HOSTP=192.168.3.1 FS=10000000 NBS=4,32 RUNS=15 SECS=5 python3 -u $K/drop73u.py > $O/stream_k$p.log 2>&1
  s1=$(spito); log "  RESULT k$p: $(grep SUMMARY $O/stream_k$p.log | tr '\n' ' ') | SPI timeouts +$((s1-s0))"
done
mon_stop; rm -f $O/ol.bin
timeout 30 $SSH 'dmesg' > $O/dmesg_end.txt; timeout 30 $SSH 'sh /tmp/radio_off.sh' >> $O/run.log 2>&1
spiregs end
log "done"
