#!/bin/bash
# usage: [KPAT=..] [STREAM_HOST=..] [FS=..] [NBS=..] run_variant3.sh NAME RUNS 'board setup command'
set -u; NAME=$1; RUNS=$2; SETUP=$3
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
KP=${KPAT:-7.3.0-rc7}; SH=${STREAM_HOST:-192.168.4.1}; FSV=${FS:-5000000}; NB=${NBS:-32}
O=$K/$NAME; mkdir -p $O; rm -f $O/stop
log "== $NAME: $RUNS rounds, kernel $KP, stream host $SH, fs $FSV, blocks $NB"
reboot_verify $KP
spiregs fresh_boot
log "setup: $SETUP"; timeout 60 $SSH "$SETUP" >> $O/run.log 2>&1
log "radio: $(timeout 30 $SSH "sh /tmp/radio_on.sh $FSV")"
timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_before.txt
[ -n "${PRECMD:-}" ] && log "pre: $(timeout 60 $SSH "$PRECMD" 2>&1 | tr "\n" " ")"
log "before: up=$(timeout 20 $SSH 'cut -d" " -f1 /proc/uptime') spito=$(spito) ktimers: $(grep ktimers $O/prio_before.txt | tr '\n' ' ') spi_irq: $(grep e0006000 $O/prio_before.txt)"
mon_start
log "stream start (ping $SH: $(ping -c5 -i0.3 -W1 $SH | tail -1))"
D=$O I1=$S/libiio1 HOSTP=$SH FS=$FSV NBS=$NB RUNS=$RUNS SECS=5 python3 -u $K/drop73u.py > $O/stream.log 2>&1
log "stream end"
mon_stop; rm -f $O/ol.bin
[ -n "${POSTCMD:-}" ] && log "post: $(timeout 90 $SSH "$POSTCMD" 2>&1 | tr "\n" " ")"
timeout 30 $SSH 'dmesg' > $O/dmesg_end.txt; timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_after.txt
timeout 30 $SSH 'sh /tmp/radio_off.sh' >> $O/run.log 2>&1
spiregs end
log "RESULT $NAME: $(grep SUMMARY $O/stream.log | tr '\n' ' ') | SPI timeouts $(grep -a -c 'SPI transfer timed out' $O/dmesg_end.txt)"
