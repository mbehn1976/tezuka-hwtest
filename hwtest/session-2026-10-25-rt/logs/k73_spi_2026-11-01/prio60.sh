#!/bin/bash
# runtime check: SPI irq back on cpu0 at FIFO 60; eth 10 MS/s nb4+nb32, USB nc throughput, USB 5 MS/s; spito deltas
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/P60_check; mkdir -p $O
for i in $(seq 40); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
log "== prio60 check on $(timeout 20 $SSH 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ')"
for s in prio.sh radio_on.sh radio_off.sh adcheck.sh; do timeout 20 $SSH "cat > /tmp/$s" < $K/$s; done; timeout 30 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin
log "setup: $(timeout 30 $SSH 'IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); echo 1 > /proc/irq/$IRQ/smp_affinity; P=$(grep -l "^irq/$IRQ-" /proc/[0-9]*/comm | cut -d/ -f3); chrt -f -p 60 $P >/dev/null; sleep 1; echo "irq $IRQ aff=$(cat /proc/irq/$IRQ/smp_affinity_list) thread=$P $(chrt -p $P | tail -1)"; sh /tmp/prio.sh | grep -E "ktimers|e0006000" | tr "\n" " "')"
log "spito at start: $(spito)"
stream(){ timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $3"); log "stream $1 fs=$3 via $2: $r"; a=$(spito); D=$O I1=$S/libiio1 HOSTP=$2 FS=$3 NBS=${4:-32} RUNS=${5:-15} SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1; log "  RESULT $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ') | spito +$(( $(spito) - a ))"; }
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }
ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
stream eth_10M 192.168.3.1 10000000 4,32 15
timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1
a=$(spito); python3 $K/tp.py recv 5201 > $O/tp_b2h.txt 2>&1 & sleep 1; timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait; timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2; python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp_h2b.txt 2>&1; wait
log "USB throughput: $(cat $O/tp_b2h.txt) / $(cat $O/tp_h2b.txt) | spito +$(( $(spito) - a ))"
stream usb_5M 192.168.4.1 5000000 32 20
log "end: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; rm -f $O/ol.bin
log "== prio60 check done"
