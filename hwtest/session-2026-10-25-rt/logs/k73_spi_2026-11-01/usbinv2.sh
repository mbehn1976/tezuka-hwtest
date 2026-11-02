#!/bin/bash
# USB drop investigation, take 2 (6.12 board). Fresh boot, then:
#  1. USB throughput test while watching for SPI timeouts (the first take wedged the chip here)
#  2. if it timed out: reboot, move the SPI irq to cpu1, repeat the throughput test
#  3. stream series (USB 2.5/4/5 MS/s, eth 5/10 MS/s, USB 5 again) in the state that stayed clean
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/U2_usb_investigation; mkdir -p $O; rm -f $O/stop
push_adcheck(){ timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh; }
spi_cpu1(){ timeout 20 $SSH 'IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); echo 2 > /proc/irq/$IRQ/smp_affinity; sleep 1; echo "spi irq $IRQ affinity=$(cat /proc/irq/$IRQ/smp_affinity_list)"'; }
tp(){ # $1 label, $2 board ip, $3 host ip
  python3 $K/tp.py recv 5201 > $O/tp_$1_b2h.txt 2>&1 & sleep 1
  timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc $3 5201"; wait; log "throughput $1 board->host: $(cat $O/tp_$1_b2h.txt)"
  timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2
  python3 $K/tp.py send $2 5202 200 > $O/tp_$1_h2b.txt 2>&1; wait; log "throughput $1 host->board: $(cat $O/tp_$1_h2b.txt)"
}
stream(){ # $1 label $2 host $3 fs
  timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $3"); log "stream $1 fs=$3 via $2: $r"
  case "$r" in *"sf=$3 "*) ;; *) log "  SKIP $1: rate readback wrong (chip not healthy)"; return;; esac
  D=$O I1=$S/libiio1 HOSTP=$2 FS=$3 NBS=32 RUNS=15 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1
  log "  RESULT $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ') | spito=$(spito)"
}
log "== take 2 start"
reboot_verify 6.12.114-rt21; push_adcheck
log "fresh: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
tp usb1 192.168.4.1 192.168.4.10
s=$(spito); log "after USB throughput test: spito=$s; $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
if [ "$s" != 0 ]; then
  log "== SPI timeout on 6.12 under the USB throughput test; reboot, SPI irq -> cpu1, repeat"
  reboot_verify 6.12.114-rt21; push_adcheck; log "setup: $(spi_cpu1)"
  tp usb2 192.168.4.1 192.168.4.10
  s=$(spito); log "after USB throughput test with SPI irq on cpu1: spito=$s; $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
fi
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }
ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
tp eth 192.168.3.1 192.168.3.10
stream usb_2p5M 192.168.4.1 2500000
stream usb_4M 192.168.4.1 4000000
stream usb_5M 192.168.4.1 5000000
stream eth_5M 192.168.3.1 5000000
stream eth_10M 192.168.3.1 10000000
stream usb_5M_b 192.168.4.1 5000000
log "end: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
timeout 30 $SSH 'sh /tmp/radio_off.sh; P=$(dirname $(grep -l "^ad9361-phy$" /sys/bus/iio/devices/iio:device*/name)); echo 0 > /sys/kernel/debug/iio/$(basename $P)/loopback' >/dev/null 2>&1
timeout 30 $SSH 'dmesg' > $O/dmesg_end.txt
rm -f $O/ol.bin; nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; log "eth alias removed: $(ip -br -4 addr show eno1 | awk '{print $3, $4}')"
log "== take 2 done"
