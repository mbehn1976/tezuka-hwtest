#!/bin/sh
echo "== DMA idle"; /tmp/membench
echo "== while the DMA streams 184 MB/s into DDR (iiocap none)"
/tmp/iiocap 1048576 8 4000 none > /tmp/dma.log 2>&1 &
sleep 2; /tmp/membench; wait
