#!/bin/bash
# 7.3 FINAL image: I = control (ktimers 51, recovery patch under test), H = SPI irq on cpu1; then card back to 6.12
K=/tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi; . $K/common.sh
IMG=/home/mb/tezuka-review-v0.3.23/hwtest/known_good/sdimg-rt73-final
PRE='sh /tmp/adcheck.sh'; POST='sh /tmp/adcheck.sh'
echo "$(date +%H:%M:%S) chain2 start"
cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh $IMG known_good/card-before-2026-11-01-k73final > $K/sd_write_73final.log 2>&1; rc=$?; tail -3 $K/sd_write_73final.log; [ $rc = 0 ] || { echo "SD WRITE FAILED rc=$rc"; exit 2; }
# push adcheck with the other board scripts (reboot_verify copies the standard set; adcheck is extra)
export KPAT=7.3.0 PRECMD="$PRE" POSTCMD="$POST"
cp $K/adcheck.sh $K/adcheck_push.sh
SETUP_I='cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
for p in $(grep -l "^ktimers/" /proc/[0-9]*/comm | cut -d/ -f3); do chrt -f -p 51 $p; done; echo setup_I_done'
SETUP_H="$SETUP_I"'; IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); echo 2 > /proc/irq/$IRQ/smp_affinity; sleep 1; echo "spi irq $IRQ affinity=$(cat /proc/irq/$IRQ/smp_affinity_list)"'
$K/run_variant3.sh I_73final_ktimers51 80 "$SETUP_I" || { echo "I failed"; exit 3; }
$K/run_variant3.sh H_73final_spiirq_cpu1 160 "$SETUP_H" || { echo "H failed"; exit 4; }
echo "$(date +%H:%M:%S) writing 6.12 image back"
cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $K/sd_write_612b.log 2>&1; rc=$?; tail -3 $K/sd_write_612b.log; [ $rc = 0 ] || { echo "SD WRITE BACK FAILED rc=$rc"; exit 5; }
timeout 30 $SSH 'sh /tmp/radio_off.sh; echo 0 > /sys/kernel/debug/iio/$(basename $(dirname $(grep -l "^ad9361-phy$" /sys/bus/iio/devices/iio:device*/name)))/loopback' 2>/dev/null
echo "$(date +%H:%M:%S) chain2 done"
