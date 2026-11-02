#!/bin/bash
# Ethernet soaks at the REAL 10 MS/s (run_variant4: pre-check before radio_on), after the finding that every
# run_variant3 run with the AD9361 pre-check streamed at 5 MS/s (Q_eth10M_soak, Q_usb4M_soak, the Q_usbctl runs):
#  1. 6.12 as shipped (card holds sdimg-rt21-sw): fresh boot, 330 rounds Ethernet 10 MS/s, 32 blocks, monitor once a minute
#  2. card -> sdimg-rt73-final3 (7.3 final, shipped settings): 330 rounds Ethernet 10 MS/s, then 100 rounds USB 4 MS/s
#  3. card back to sdimg-rt21-sw, host eno1 alias removed
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_eth; mkdir -p $O; rm -f $O/stop
HW=/home/mb/tezuka-review-v0.3.23/hwtest
log "== eth soaks start"
for i in $(seq 30); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
info=$(timeout 20 $SSH 'echo $(uname -r) $(cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber 2>/dev/null | head -1)')
log "board: $info"; case "$info" in 6.12.114-rt21*WZ5Z6HQZ6IXHI5QI*) ;; *) log "ABORT: not the Pluto+ on 6.12"; exit 1;; esac
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }
ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
ADC='cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
'
export PRECMD='sh /tmp/adcheck.sh' POSTCMD='sh /tmp/adcheck.sh'
finish(){ rm -rf $O/$1; mv $K/$1 $O/ 2>/dev/null; log "$1: $(grep RESULT $O/$1/run.log | sed 's/.*RESULT //') | $(grep 'rate seen' $O/$1/run.log | sed 's/.*rate seen/rate seen/') | post: $(grep 'post:' $O/$1/run.log | sed 's/.*post: //')"; }

# 1. 6.12 as shipped
KPAT=6.12.114-rt21 STREAM_HOST=192.168.3.1 FS=10000000 NBS=32 $K/run_variant4.sh Q_eth10M_612 330 "${ADC}echo as shipped" || log "612 eth runner failed"
finish Q_eth10M_612

# 2. 7.3 final3
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt73-final3 known_good/card-before-2026-11-02-eth > $O/sd_write_73.log 2>&1 && log "card on 7.3: $(grep -c 'checksums match' $O/sd_write_73.log) match" || { log "SD WRITE 7.3 FAILED"; tail -3 $O/sd_write_73.log | tee -a $O/run.log; exit 2; }
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
KPAT=7.3.0 STREAM_HOST=192.168.3.1 FS=10000000 NBS=32 $K/run_variant4.sh Q_eth10M_73 330 "${ADC}echo shipped settings" || log "73 eth runner failed"
finish Q_eth10M_73
KPAT=7.3.0 STREAM_HOST=192.168.4.1 FS=4000000 NBS=32 $K/run_variant4.sh Q_usb4M_73 100 "${ADC}echo shipped settings" || log "73 usb runner failed"
finish Q_usb4M_73

# 3. back to 6.12
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED"
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
log "6.12 control: $(timeout 20 $SSH 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ') spito=$(spito)"
rm -f $O/ol.bin; nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; log "eth alias removed: $(ip -br -4 addr show eno1 | awk '{print $3, $4}')"
log "== eth soaks done"
