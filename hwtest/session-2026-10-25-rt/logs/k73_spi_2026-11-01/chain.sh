#!/bin/bash
# 1) 7.3 USB soak with ktimers at 51; 2) card -> sdimg-rt21-sw; 3) 6.12 USB control soak
K=/tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi
echo "$(date +%H:%M:%S) chain start"
$K/run_variant3.sh F_usb_ktimers51 160 'for p in $(grep -l "^ktimers/" /proc/[0-9]*/comm | cut -d/ -f3); do chrt -f -p 51 $p; done' || { echo "F failed"; exit 1; }
echo "$(date +%H:%M:%S) writing 6.12 image"
cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw known_good/card-before-2026-11-01-612control > $K/sd_write_612.log 2>&1
rc=$?; tail -4 $K/sd_write_612.log; [ $rc = 0 ] || { echo "SD WRITE FAILED rc=$rc - stopping"; exit 2; }
KPAT=6.12.114-rt21 $K/run_variant3.sh G_usb_612_control 215 'echo 6.12 control: no change' || { echo "G failed"; exit 3; }
echo "$(date +%H:%M:%S) chain done"
