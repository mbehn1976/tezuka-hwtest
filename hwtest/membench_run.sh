#!/bin/sh
# run on the board: idle membench, then membench while the DMA streams 184 MB/s, then CPU load of each iiocap mode
cpu() { awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5+$6}' /proc/stat; }
echo "== membench, DMA idle"; /tmp/membench
echo "== membench while DMA streams (iiocap none, refill only, 61.44 MS/s)"
/tmp/iiocap 1048576 8 4000 none > /tmp/dma.log 2>&1 &
sleep 2; /tmp/membench; wait; cat /tmp/dma.log | tail -1
for m in none predict copy scan; do
  set -- $(cpu); t0=$1; i0=$2
  r=$(/tmp/iiocap 1048576 8 400 $m 2>&1 | tail -1)
  set -- $(cpu); t1=$1; i1=$2
  busy=$(( 100 - 100 * (i1 - i0) / (t1 - t0) ))
  echo "iiocap $m: $(echo "$r" | sed 's/.*seconds=\([0-9.]*\) MBps=\([0-9.]*\).*frames_missing=\([0-9]*\)/\1 s, \2 MB\/s, frames_missing=\3/') ; both cores busy ${busy}% (100% = 2 cores saturated)"
done
