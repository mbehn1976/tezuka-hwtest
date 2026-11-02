#!/bin/bash
# usage: [KPAT=..] [STREAM_HOST=..] [FS=..] [NBS=..] run_variant4.sh NAME RUNS 'board setup command'
# v4 (2026-11-02): PRECMD runs BEFORE radio_on. In v3 it ran after it, and adcheck.sh writes 5 MS/s as its rate-write
# test, so every v3 run with PRECMD=adcheck streamed at 5 MS/s whatever FS said (Q_eth10M_soak, Q_usb4M_soak, Q_usbctl).
# v4 also aborts when the rate readback after radio_on differs from FS and logs the monitor's rate readings at the end.
set -u; NAME=$1; RUNS=$2; SETUP=$3
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
KP=${KPAT:-7.3.0}; SH=${STREAM_HOST:-192.168.4.1}; FSV=${FS:-5000000}; NB=${NBS:-32}
O=$K/$NAME; mkdir -p $O; rm -f $O/stop
log "== $NAME: $RUNS rounds, kernel $KP, stream host $SH, fs $FSV, blocks $NB (v4: pre-check before radio_on)"
reboot_verify $KP
spiregs fresh_boot
log "setup: $SETUP"; timeout 60 $SSH "$SETUP" >> $O/run.log 2>&1
[ -n "${PRECMD:-}" ] && log "pre: $(timeout 60 $SSH "$PRECMD" 2>&1 | tr "\n" " ")"
r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $FSV"); log "radio: $r"
case "$r" in *"sf=$FSV "*) ;; *) log "ABORT $NAME: rate readback is not $FSV"; exit 1;; esac
timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_before.txt
log "before: up=$(timeout 20 $SSH 'cut -d" " -f1 /proc/uptime') spito=$(spito) ktimers: $(grep ktimers $O/prio_before.txt | tr '\n' ' ') spi_irq: $(grep e0006000 $O/prio_before.txt)"
mon_start
log "stream start (ping $SH: $(ping -c5 -i0.3 -W1 $SH | tail -1))"
D=$O I1=$S/libiio1 HOSTP=$SH FS=$FSV NBS=$NB RUNS=$RUNS SECS=5 python3 -u $K/drop73u.py > $O/stream.log 2>&1
log "stream end"
mon_stop; rm -f $O/ol.bin
log "rate seen by the monitor: $(grep -o 'sf=[0-9A-Z]*' $O/mon.log | sort | uniq -c | tr '\n' ' ')"
[ -n "${POSTCMD:-}" ] && log "post: $(timeout 90 $SSH "$POSTCMD" 2>&1 | tr "\n" " ")"
timeout 30 $SSH 'dmesg' > $O/dmesg_end.txt; timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_after.txt
timeout 30 $SSH 'sh /tmp/radio_off.sh' >> $O/run.log 2>&1
spiregs end
log "RESULT $NAME: $(grep SUMMARY $O/stream.log | tr '\n' ' ') | SPI timeouts $(grep -a -c 'SPI transfer timed out' $O/dmesg_end.txt)"
