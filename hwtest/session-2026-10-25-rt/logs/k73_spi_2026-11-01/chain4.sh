#!/bin/bash
# USB 4 MS/s control after the Q_73final soak slipped in 137/340 rounds (the 15-round short test was clean):
#  1. 6.12 as shipped (card holds sdimg-rt21-sw, no S24rtprio): 3 link throughput measurements, then a fresh boot and
#     100 rounds USB 4 MS/s with the per-minute board monitor (the soak method)
#  2. card -> sdimg-rt73-final3 (7.3 final, ktimers 51 + spi irq FIFO 60 shipped): fresh boot, 100 rounds, 3 throughput
#     measurements, then another fresh boot with ktimers lowered to FIFO 1, 100 rounds
#  3. card back to sdimg-rt21-sw
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_usbctl; mkdir -p $O; rm -f $O/stop
HW=/home/mb/tezuka-review-v0.3.23/hwtest
log "== usb control start"
for i in $(seq 30); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
info=$(timeout 20 $SSH 'echo $(uname -r) $(cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber 2>/dev/null | head -1)')
log "board: $info"; case "$info" in 6.12.114-rt21*WZ5Z6HQZ6IXHI5QI*) ;; *) log "ABORT: not the Pluto+ on 6.12"; exit 1;; esac
timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh

tp3(){ # $1 label; three 200 MB TCP transfers each way over the USB link
  for n in 1 2 3; do
    python3 $K/tp.py recv 5201 > $O/tp_$1_${n}_b2h.txt 2>&1 & sleep 1
    timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait
    timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2
    python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp_$1_${n}_h2b.txt 2>&1; wait
    log "throughput $1 #$n: $(cat $O/tp_$1_${n}_b2h.txt) / $(cat $O/tp_$1_${n}_h2b.txt)"
  done
  log "after throughput $1: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
}
ADC='cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
'
export PRECMD='sh /tmp/adcheck.sh' POSTCMD='sh /tmp/adcheck.sh'
export STREAM_HOST=192.168.4.1 FS=4000000 NBS=32

# 1. 6.12
log "6.12 spi irq thread: $(timeout 20 $SSH 'IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); P=$(grep -l "^irq/$IRQ-" /proc/[0-9]*/comm | cut -d/ -f3); chrt -p $P | tail -1')"
tp3 612
KPAT=6.12.114-rt21 $K/run_variant3.sh Q_usb4M_612ctl 100 "${ADC}echo as shipped" || log "612 runner failed"
rm -rf $O/Q_usb4M_612ctl; mv $K/Q_usb4M_612ctl $O/

# 2. 7.3 final3
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt73-final3 known_good/card-before-2026-11-02-usbctl > $O/sd_write_73.log 2>&1 && log "card on 7.3: $(grep -c 'checksums match' $O/sd_write_73.log) match" || { log "SD WRITE 7.3 FAILED"; tail -3 $O/sd_write_73.log | tee -a $O/run.log; exit 2; }
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
KPAT=7.3.0 $K/run_variant3.sh Q_usb4M_73ship 100 "${ADC}echo shipped settings" || log "73ship runner failed"
rm -rf $O/Q_usb4M_73ship; mv $K/Q_usb4M_73ship $O/
tp3 73
KPAT=7.3.0 $K/run_variant3.sh Q_usb4M_73kt1 100 "${ADC}"'for p in $(grep -l "^ktimers/" /proc/[0-9]*/comm | cut -d/ -f3); do chrt -f -p 1 $p; done; echo ktimers set to FIFO 1' || log "73kt1 runner failed"
rm -rf $O/Q_usb4M_73kt1; mv $K/Q_usb4M_73kt1 $O/
for v in Q_usb4M_612ctl Q_usb4M_73ship Q_usb4M_73kt1; do log "$v: $(grep RESULT $O/$v/run.log | sed 's/.*RESULT //') | before: $(grep '^[0-9:]* before:' $O/$v/run.log | sed 's/.*before: //') | post: $(grep 'post:' $O/$v/run.log | sed 's/.*post: //')"; done

# 3. back to 6.12
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED"
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
log "6.12 control: $(timeout 20 $SSH 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ') spito=$(spito)"
rm -f $O/ol.bin
log "== usb control done"
