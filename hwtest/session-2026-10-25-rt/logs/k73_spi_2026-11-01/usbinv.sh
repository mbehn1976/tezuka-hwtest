#!/bin/bash
# drop investigation on the 6.12 board: USB/eth throughput, gadget type, stream slips vs rate and transport
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/U_usb_investigation; mkdir -p $O
log "== drop investigation start; board: $(timeout 20 $SSH 'uname -r; cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber' | tr '\n' ' ')"
log "gadget functions: $(timeout 20 $SSH 'ls /sys/kernel/config/usb_gadget/*/functions/ | tr "\n" " "; echo; for c in /sys/kernel/config/usb_gadget/*/configs/*/; do echo "config $(basename $c): $(ls $c | grep -v -E "^(MaxPower|bmAttributes|strings)$" | tr "\n" " ")"; done; cat /sys/class/udc/*/current_speed' | tr '\n' ' ')"
log "host usb driver: $(for i in /sys/bus/usb/devices/3-6.3.1:1.0 /sys/bus/usb/devices/3-6.3.1:1.5; do echo "$(basename $i) $(basename $(readlink $i/driver 2>/dev/null) 2>/dev/null) $(ls $i/net 2>/dev/null)"; done | tr '\n' ' ')"
for s in prio.sh mon_board2.sh radio_on.sh radio_off.sh; do timeout 20 $SSH "cat > /tmp/${s/mon_board2/mon_board}" < $K/$s; done; timeout 30 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin
tp(){ # $1 label, $2 board ip, $3 host ip
  python3 $K/tp.py recv 5201 > $O/tp_$1_b2h.txt 2>&1 & sleep 1
  timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc $3 5201" ; wait; log "throughput $1 board->host: $(cat $O/tp_$1_b2h.txt)"
  timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2
  python3 $K/tp.py send $2 5202 200 > $O/tp_$1_h2b.txt 2>&1; wait; log "throughput $1 host->board: $(cat $O/tp_$1_h2b.txt)"
}
tp usb 192.168.4.1 192.168.4.10
nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
tp eth 192.168.3.1 192.168.3.10
stream(){ # $1 label $2 host $3 fs
  timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $3"); log "stream $1 fs=$3 via $2: $r"
  D=$O I1=$S/libiio1 HOSTP=$2 FS=$3 NBS=32 RUNS=15 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1
  log "  RESULT $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ')"
}
stream usb_2p5M 192.168.4.1 2500000
stream usb_4M 192.168.4.1 4000000
stream usb_5M 192.168.4.1 5000000
stream eth_5M 192.168.3.1 5000000
stream eth_10M 192.168.3.1 10000000
stream usb_5M_b 192.168.4.1 5000000
timeout 30 $SSH 'sh /tmp/radio_off.sh; P=$(dirname $(grep -l "^ad9361-phy$" /sys/bus/iio/devices/iio:device*/name)); echo 0 > /sys/kernel/debug/iio/$(basename $P)/loopback' >/dev/null 2>&1
rm -f $O/ol.bin; nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; log "eth alias removed: $(ip -br -4 addr show eno1 | awk '{print $3, $4}')"
log "== done"
