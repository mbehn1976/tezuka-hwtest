#!/bin/bash
# resume of chain3.sh after the boot-cycle phase: short tests, USB throughput, soaks, card back to 6.12, 6.12 FIFO-60 check
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_73final; mkdir -p $O; rm -f $O/stop
KP=7.3.0
log "== resume (chain3b) start"
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
info=$(timeout 20 $SSH 'echo $(uname -r) $(cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber 2>/dev/null | head -1)')
log "board: $info"; case "$info" in $KP*WZ5Z6HQZ6IXHI5QI*) ;; *) log "ABORT: not the Pluto+ on $KP"; exit 1;; esac
timeout 20 $SSH 'cat > /tmp/prio.sh' < $K/prio.sh; timeout 20 $SSH 'cat > /tmp/mon_board.sh' < $K/mon_board2.sh
timeout 20 $SSH 'cat > /tmp/radio_on.sh' < $K/radio_on.sh; timeout 20 $SSH 'cat > /tmp/radio_off.sh' < $K/radio_off.sh
timeout 30 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin; timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh
log "settings: $(timeout 30 $SSH 'sh /tmp/prio.sh' | grep -E 'ktimers|e0006000' | tr '\n' ' ')"
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }

stream(){ # $1 label $2 host $3 fs $4 nbs
  timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $3"); log "stream $1 fs=$3 nbs=$4 via $2: $r"
  case "$r" in *"sf=$3 "*) ;; *) log "  SKIP $1: rate readback wrong"; return;; esac
  D=$O I1=$S/libiio1 HOSTP=$2 FS=$3 NBS=$4 RUNS=15 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1
  log "  RESULT $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ') | spito=$(spito)"
}
tp(){ python3 $K/tp.py recv 5201 > $O/tp_b2h.txt 2>&1 & sleep 1; timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait; timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2; python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp_h2b.txt 2>&1; wait; log "USB throughput: $(cat $O/tp_b2h.txt) / $(cat $O/tp_h2b.txt)"; }

ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
stream usb_2p5M 192.168.4.1 2500000 32
stream usb_4M 192.168.4.1 4000000 32
stream eth_10M 192.168.3.1 10000000 4,32
timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1
s0=$(spito); tp; log "after USB throughput test: spito=$(spito) (was $s0); $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"

export KPAT=$KP PRECMD='sh /tmp/adcheck.sh' POSTCMD='sh /tmp/adcheck.sh'
SETUP='cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
echo shipped settings'
STREAM_HOST=192.168.3.1 FS=10000000 NBS=32 $K/run_variant3.sh Q_eth10M_soak 720 "$SETUP" || log "eth soak runner failed"
STREAM_HOST=192.168.4.1 FS=4000000 NBS=32 $K/run_variant3.sh Q_usb4M_soak 340 "$SETUP" || log "usb soak runner failed"
for v in Q_eth10M_soak Q_usb4M_soak; do rm -rf $O/$v; mv $K/$v $O/ 2>/dev/null; log "$v: $(grep RESULT $O/$v/run.log | sed 's/.*RESULT //') | post: $(grep 'post:' $O/$v/run.log | sed 's/.*post: //')"; done

cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED"
for i in $(seq 30); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
log "6.12 control: $(timeout 20 $SSH 'uname -r') spito=$(spito)"
timeout 30 $SSH 'IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); P=$(grep -l "^irq/$IRQ-" /proc/[0-9]*/comm | cut -d/ -f3); chrt -f -p 60 $P; chrt -p $P | tail -1' | tee -a $O/run.log
timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh
a=$(spito); tp; log "6.12 with SPI thread at FIFO 60, after USB throughput test: spito +$(( $(spito) - a )); $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
timeout 30 $SSH 'sh /tmp/radio_off.sh 2>/dev/null; P=$(dirname $(grep -l "^ad9361-phy$" /sys/bus/iio/devices/iio:device*/name)); echo 0 > /sys/kernel/debug/iio/$(basename $P)/loopback' >/dev/null 2>&1
rm -f $O/ol.bin; nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; log "eth alias removed: $(ip -br -4 addr show eno1 | awk '{print $3, $4}')"
log "== qualification done"
