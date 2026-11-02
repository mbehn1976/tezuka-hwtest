#!/bin/bash
# USB link experiments on both kernels (host idle, no builds meanwhile). Per kernel, on one boot:
#   base: 3 x 200 MB TCP each way over the USB link with CPU load sampling on the board
#   udc60: the UDC interrupt thread (irq/N-e0002000) at FIFO 60
#   kt1, udc60_kt1 (7.3 only): ktimers at FIFO 1, and both changes
#   ncm: the gadget swapped from RNDIS to NCM at runtime (ncm_switch.sh), throughput and a USB 5 MS/s stream of 20 rounds
# 6.12 first (card holds sdimg-rt21-sw), then sdimg-rt73-final3, then the card back to 6.12. Board control over Ethernet.
# v2 (08:55): the AD9361 SPI thread goes to FIFO 60 on 6.12 first (as the new S24rtprio does; as shipped the USB
# throughput test wedges the chip, 17n); the host profile is only ever activated on the Pluto+ interface (the first run
# put it on the original Pluto's interface and lost the link); the route to 192.168.4.1 is checked before each step.
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_usbexp; mkdir -p $O; rm -f $O/stop
HW=/home/mb/tezuka-review-v0.3.23/hwtest
SSHE=${SSH/192.168.4.1/192.168.3.1}
PIF=enx00e0220ae277   # the Pluto+ host interface (host MAC of its gadget); enx00e02248cd43 is the original Pluto, never touch it
log "== usb experiments start (v2)"
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }
for i in $(seq 30); do timeout 10 $SSHE true 2>/dev/null && break; sleep 5; done
ping -c1 -W1 192.168.3.1 >/dev/null && log "eth control link up" || { log "ABORT: no Ethernet control link"; exit 1; }

push(){ for s in prio.sh radio_on.sh radio_off.sh adcheck.sh cpu0load.sh ncm_switch.sh; do timeout 20 $SSHE "cat > /tmp/$s" < $K/$s; done; timeout 30 $SSHE 'cat > /tmp/rf_tx.bin' < $K/tone.bin; }
tp3(){ # $1 label: three 200 MB TCP transfers each way over the USB link, nc on the board driven over Ethernet
  for n in 1 2 3; do
    python3 $K/tp.py recv 5201 > $O/tp_$1_${n}_b2h.txt 2>&1 & sleep 1
    timeout 120 $SSHE "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait
    timeout 120 $SSHE "nc -l -p 5202 > /dev/null" & sleep 2
    python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp_$1_${n}_h2b.txt 2>&1; wait
    log "throughput $1 #$n: $(head -c 120 $O/tp_$1_${n}_b2h.txt | head -1) / $(head -c 120 $O/tp_$1_${n}_h2b.txt | head -1)"
  done
}
host_ok(){ [ "$(ip route get 192.168.4.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')" = "$PIF" ] && ping -c1 -W1 192.168.4.1 >/dev/null 2>&1; }
measure(){ # $1 label
  host_ok || { log "SKIP $1: no USB link to the Pluto+ ($(ip route get 192.168.4.1 2>/dev/null | head -1))"; return; }
  timeout 150 $SSHE "sh /tmp/cpu0load.sh 70" > $O/load_$1.txt 2>&1 &
  LP=$!; sleep 1; tp3 $1; wait $LP; log "load $1: $(cat $O/load_$1.txt)"
}
udc_pid(){ timeout 20 $SSHE 'grep -l -E "^irq/[0-9]+-e0002000" /proc/[0-9]*/comm 2>/dev/null | head -1 | cut -d/ -f3'; }
set_udc(){ p=$(udc_pid); timeout 20 $SSHE "chrt -f -p $1 $p >/dev/null 2>&1; echo thread $p \$(chrt -p $p | tail -1)"; }
set_spi(){ timeout 20 $SSHE "IRQ=\$(awk '/e0006000/{sub(\":\",\"\",\$1); print \$1}' /proc/interrupts); P=\$(grep -l \"^irq/\$IRQ-\" /proc/[0-9]*/comm | cut -d/ -f3); chrt -f -p $1 \$P >/dev/null 2>&1; echo spi thread \$P \$(chrt -p \$P | tail -1)"; }
set_kt(){ timeout 20 $SSHE "for p in \$(grep -l '^ktimers/' /proc/[0-9]*/comm | cut -d/ -f3); do chrt -f -p $1 \$p >/dev/null 2>&1; done; sh /tmp/prio.sh | grep ktimers | tr '\n' ' '"; }
host_wait_usb(){ # wait for the Pluto+ interface; after 30 s put the profile on it by name, never on another device
  for i in $(seq 45); do host_ok && return 0; [ $i = 15 ] && [ -e /sys/class/net/$PIF ] && nmcli connection up tezuka-usb ifname $PIF >/dev/null 2>&1; sleep 2; done; return 1
}
host_usb_info(){ echo "$(ip -br -4 addr show $PIF 2>/dev/null | awk '{print $1, $3}') route=$(ip route get 192.168.4.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}') nm=$(nmcli -t -f DEVICE,STATE,CONNECTION device status 2>/dev/null | grep "^$PIF" | cut -d: -f2-) ncm_msgs=$(journalctl -k --since -3min --no-pager -q | grep -c cdc_ncm) rndis_msgs=$(journalctl -k --since -3min --no-pager -q | grep -c rndis_host)"; }

run_kernel(){ # $1 label  $2 1 if the ktimers variants apply (7.3)
  push
  log "$1 board: $(timeout 20 $SSHE 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ') $(set_spi 60) udc $(set_udc 50) ktimers: $(set_kt ${KT0:-51})"
  log "$1 host: $(host_usb_info)"
  measure $1_base
  log "udc at 60: $(set_udc 60)"; measure $1_udc60; set_udc 50 > /dev/null
  if [ "$2" = 1 ]; then
    log "ktimers at 1: $(set_kt 1)"; measure $1_kt1
    log "udc at 60 + ktimers 1: $(set_udc 60)"; measure $1_udc60_kt1
    set_udc 50 > /dev/null; log "restored: $(set_kt 51)"
  fi
  log "ncm: $(timeout 60 $SSHE 'sh /tmp/ncm_switch.sh ncm' 2>&1 | tail -1)"
  if host_wait_usb; then
    log "host usb link up (ncm): $(host_usb_info)"
    measure $1_ncm
    timeout 30 $SSHE 'sh /tmp/radio_off.sh' > /dev/null 2>&1; r=$(timeout 30 $SSHE "sh /tmp/radio_on.sh 5000000"); log "stream $1_ncm_5M: $r"
    D=$O I1=$S/libiio1 HOSTP=192.168.4.1 FS=5000000 NBS=32 RUNS=20 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1_ncm_5M.log 2>&1
    log "  RESULT $1_ncm_5M: $(grep SUMMARY $O/stream_$1_ncm_5M.log | tr '\n' ' ') | spito=$(timeout 20 $SSHE 'dmesg | grep -c "SPI transfer timed out"')"
    timeout 30 $SSHE 'sh /tmp/radio_off.sh' > /dev/null 2>&1; rm -f $O/ol.bin
  else
    log "host usb link FAILED after the ncm switch: $(host_usb_info)"
  fi
  log "rndis: $(timeout 60 $SSHE 'sh /tmp/ncm_switch.sh rndis' 2>&1 | tail -1)"
  host_wait_usb && log "host usb link back (rndis): $(host_usb_info)" || log "host usb link FAILED after the rndis switch: $(host_usb_info)"
  log "end $1: $(timeout 60 $SSHE 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
}

KT0=1 run_kernel 612 0
cd $HW && HOST=192.168.3.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt73-final3 known_good/card-before-2026-11-02-usbexp > $O/sd_write_73.log 2>&1 && log "card on 7.3: $(grep -c 'checksums match' $O/sd_write_73.log) match" || { log "SD WRITE 7.3 FAILED"; tail -3 $O/sd_write_73.log | tee -a $O/run.log; exit 2; }
sleep 20; for i in $(seq 60); do timeout 10 $SSHE true 2>/dev/null && break; sleep 5; done
info=$(timeout 20 $SSHE 'uname -r'); case "$info" in 7.3.0*) ;; *) log "ABORT: board not on 7.3 ($info)"; exit 1;; esac
sleep 30; host_wait_usb || log "7.3 boot: host usb link not up: $(host_usb_info)"
KT0=51 run_kernel 73 1
cd $HW && HOST=192.168.3.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED"
sleep 20; for i in $(seq 60); do timeout 10 $SSHE true 2>/dev/null && break; sleep 5; done
sleep 20; host_wait_usb; log "6.12 control: $(timeout 20 $SSHE 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ') usb host: $(host_usb_info)"
log "== usb experiments done"
