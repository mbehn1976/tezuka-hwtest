#!/bin/bash
# Phase C board addition (2026-11-02): the product id probe on 6.12 v2 for comparison (7.3 showed 3/150 off with runtime
# suspend on and 2/150 with it off). Card to 6.12, pidglitch 150 auto, card back to 7.3 final5. One line per step in runC.log.
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_final; HW=/home/mb/tezuka-review-v0.3.23/hwtest; L=$O/runC.log
logC(){ echo "$(date +%T) $*" >> $L; }
waitssh(){ sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && return 0; sleep 5; done; return 1; }
push(){ for s in adcheck.sh bootinfo.sh pidglitch.sh; do timeout 20 $SSH "cat > /tmp/$s" < $K/$s; done; }
card(){ # $1 image
  for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
  (cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/$1 > $O/sd_write_C_$1.log 2>&1) && logC "card on $1: $(grep -c 'checksums match' $O/sd_write_C_$1.log) match" || { logC "SD WRITE $1 FAILED"; tail -3 $O/sd_write_C_$1.log >> $L; exit 2; }
  waitssh || { logC "ABORT: no SSH after the card write"; exit 2; }
  push; logC "boot: $(timeout 30 $SSH 'sh /tmp/bootinfo.sh' 2>&1 | tr '\n' ' ')"
}
logC "== phase C start: pidglitch on 6.12"
card sdimg-rt21-v2
r=$(timeout 900 $SSH 'sh /tmp/pidglitch.sh 150 auto' 2>&1); logC "6.12 $r"
case "$r" in *" off=0 "*) r2=$(timeout 900 $SSH 'sh /tmp/pidglitch.sh 150 auto' 2>&1); logC "6.12 second run $r2";; esac
card sdimg-rt73-final5
logC "== phase C done; the card holds sdimg-rt73-final5"
