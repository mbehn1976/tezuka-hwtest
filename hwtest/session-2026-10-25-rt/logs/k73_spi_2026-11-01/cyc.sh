#!/bin/bash
# usage: cyc.sh LABEL   (host side; board over Ethernet 192.168.3.1 for control, the stream over Ethernet too)
# Four cyclictest runs of 140 s on the board, the command of the 6.12 reference runs (session-2026-10-25-rt/scripts/iso*.sh):
#   core 0 idle, core 1 idle, core 0 under a 10 MS/s Ethernet stream (32 blocks), core 1 under the stream.
# Prints one line per run: label core load min/avg/max us.
LABEL=$1
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
SSHE=${SSH/192.168.4.1/192.168.3.1}; O=$K/Q_final/cyc_$LABEL; mkdir -p $O
run(){ # $1 core  $2 load (idle|stream)
  timeout 200 $SSHE "cyclictest -t1 -p98 -i250 -a$1 -D 140s -m -q > /tmp/cyc.txt 2>&1" &
  CP=$!
  if [ "$2" = stream ]; then
    sleep 2; D=$O I1=$S/libiio1 HOSTP=192.168.3.1 FS=10000000 NBS=32 RUNS=1 SECS=135 python3 -u $K/drop73u.py > $O/stream_core$1.log 2>&1
  fi
  wait $CP
  timeout 20 $SSHE 'cat /tmp/cyc.txt' > $O/cyc_core$1_$2.txt 2>&1
  r=$(grep '^T:' $O/cyc_core$1_$2.txt | sed 's/.*Min: *\([0-9]*\).*Avg: *\([0-9]*\).*Max: *\([0-9]*\).*/min \1 avg \2 max \3/')
  echo "cyclictest $LABEL core $1 $2: ${r:-FAILED $(head -c 100 $O/cyc_core$1_$2.txt)} $( [ "$2" = stream ] && grep -o 'SUMMARY.*' $O/stream_core$1.log | head -1 | cut -c1-80)"
}
run 0 idle; run 1 idle
r=$(timeout 30 $SSHE 'sh /tmp/radio_on.sh 10000000'); echo "radio for the stream: $r"
run 0 stream; run 1 stream
timeout 30 $SSHE 'sh /tmp/radio_off.sh' > /dev/null 2>&1
