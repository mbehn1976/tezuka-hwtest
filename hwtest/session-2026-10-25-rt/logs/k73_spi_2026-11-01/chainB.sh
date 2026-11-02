#!/bin/bash
# Phase B (plan 2026-11-02): the board. 6.12 v2 first (NCM boot, SPI recovery test, NCM 20 rounds, cyclictest, mtd3 dump),
# then 7.3 final5 (NCM boot, flash read md5s, QSPI write tests, product id probe, cyclictest, NCM 20 rounds + 20 min soak).
# The card stays on sdimg-rt73-final5. One line per step in Q_final/runB.log.
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_final; mkdir -p $O; HW=/home/mb/tezuka-review-v0.3.23/hwtest; L=$O/runB.log
SSHE=${SSH/192.168.4.1/192.168.3.1}; PIF=enx00e0220ae277
logB(){ echo "$(date +%T) $*" >> $L; }
host_ok(){ [ "$(ip route get 192.168.4.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')" = "$PIF" ] && ping -c1 -W1 192.168.4.1 >/dev/null 2>&1; }
host_wait_usb(){ for i in $(seq 60); do host_ok && return 0; [ $i = 15 ] && [ -e /sys/class/net/$PIF ] && nmcli connection up tezuka-usb ifname $PIF >/dev/null 2>&1; sleep 2; done; return 1; }
host_usb(){ echo "driver=$(basename $(readlink /sys/class/net/$PIF/device/driver 2>/dev/null) 2>/dev/null) $(ip -br -4 addr show $PIF 2>/dev/null | awk '{print $3}') route_dev=$(ip route get 192.168.4.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')"; }
waitssh(){ sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && return 0; sleep 5; done; return 1; }
push(){ for s in radio_on.sh radio_off.sh adcheck.sh bootinfo.sh pidglitch.sh; do timeout 20 $SSH "cat > /tmp/$s" < $K/$s; done; timeout 60 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin; }
set_spi(){ timeout 20 $SSH "IRQ=\$(awk '/e0006000/{sub(\":\",\"\",\$1); print \$1}' /proc/interrupts); P=\$(grep -l \"^irq/\$IRQ-\" /proc/[0-9]*/comm | cut -d/ -f3); chrt -f -p $1 \$P >/dev/null 2>&1; echo spi thread \$P \$(chrt -p \$P | tail -1)"; }
card(){ # $1 image  $2 backup name
  for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
  (cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/$1 ${2:+known_good/$2} > $O/sd_write_$1.log 2>&1) && logB "card on $1: $(grep -c 'checksums match' $O/sd_write_$1.log) match" || { logB "SD WRITE $1 FAILED"; tail -3 $O/sd_write_$1.log >> $L; exit 2; }
  waitssh || { logB "ABORT: no SSH after the card write"; exit 2; }
  host_wait_usb || logB "warning: host USB link not up after boot: $(host_usb)"
  push; logB "boot: $(timeout 30 $SSH 'sh /tmp/bootinfo.sh' 2>&1 | tr '\n' ' ') cmdline_mode=$(timeout 10 $SSH 'grep -o "usb_ethernet_mode=[a-z]*" /proc/cmdline') gadget=$(timeout 10 $SSH 'ls /sys/kernel/config/usb_gadget/composite_gadget/configs/c.1 | grep -E "^(rndis|ncm|ecm)"') host: $(host_usb) cdc_ncm_msgs=$(journalctl -k --since -3min --no-pager -q | grep -c cdc_ncm)"
}
ncm20(){ # $1 label
  timeout 30 $SSH 'sh /tmp/radio_off.sh' > /dev/null 2>&1; r=$(timeout 30 $SSH 'sh /tmp/radio_on.sh 5000000'); logB "radio: $r"
  D=$O I1=$S/libiio1 HOSTP=192.168.4.1 FS=5000000 NBS=32 RUNS=20 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1
  logB "NCM 5 MS/s 20 rounds $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ') spito=$(timeout 20 $SSH 'dmesg | grep -c "SPI transfer timed out"')"
  timeout 30 $SSH 'sh /tmp/radio_off.sh' > /dev/null 2>&1
}
logB "== phase B start"
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }

# ---------- B1: 6.12 v2 ----------
card sdimg-rt21-v2 card-before-2026-11-02-final
logB "6.12 recovery test: $(set_spi 50)"
for n in 1 2; do python3 $K/tp.py recv 5201 > $O/tp612_${n}_b2h.txt 2>&1 & sleep 1; timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait; timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2; python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp612_${n}_h2b.txt 2>&1; wait; done
logB "6.12 after 2 x 200 MB each way at FIFO 50: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ') | $(set_spi 60) | throughput $(head -1 $O/tp612_1_b2h.txt | cut -c1-40) / $(head -1 $O/tp612_1_h2b.txt | cut -c1-40)"
ncm20 612
$K/cyc.sh 612 >> $L 2>&1
timeout 300 $SSH 'dd if=/dev/mtd3 bs=1M 2>/dev/null' > $O/mtd3_612.bin; timeout 300 $SSH 'for i in 0 1 2 3; do dd if=/dev/mtd$i bs=1M 2>/dev/null | md5sum | cut -c1-8; done | tr "\n" " "' > $O/mtd_md5_612.txt
logB "6.12 flash: mtd3 dump $(stat -c %s $O/mtd3_612.bin) bytes md5 $(md5sum < $O/mtd3_612.bin | cut -c1-8); mtd0-3 md5 $(cat $O/mtd_md5_612.txt)"
[ $(stat -c %s $O/mtd3_612.bin) = 31457280 ] || { logB "ABORT: mtd3 dump incomplete"; exit 3; }

# ---------- B2: 7.3 final5 ----------
card sdimg-rt73-final5 ""
m73=$(timeout 300 $SSH 'for i in 0 1 2 3; do dd if=/dev/mtd$i bs=1M 2>/dev/null | md5sum | cut -c1-8; done | tr "\n" " "')
logB "7.3 flash reads: mtd0-3 md5 $m73 (6.12: $(cat $O/mtd_md5_612.txt))"
[ "$m73" = "$(cat $O/mtd_md5_612.txt)" ] || { logB "ABORT: 7.3 reads the flash differently, no write test"; exit 4; }
$K/qspi_test.sh $O/mtd3_612.bin $HW/known_good/sdimg-rt73-final5.pluto.frm >> $L 2>&1 || logB "QSPI TESTS FAILED, see above; going on with the other tests"
push
r=$(timeout 900 $SSH 'sh /tmp/pidglitch.sh 150 auto' 2>&1); logB "$r"
case "$r" in *" off=0 "*) ;; *) r2=$(timeout 900 $SSH 'sh /tmp/pidglitch.sh 150 on' 2>&1); logB "$r2";; esac
$K/cyc.sh 73 >> $L 2>&1
ncm20 73
timeout 30 $SSH 'sh /tmp/radio_off.sh' > /dev/null 2>&1; r=$(timeout 30 $SSH 'sh /tmp/radio_on.sh 5000000'); logB "radio for the soak: $r"
mon_start 2>/dev/null
D=$O I1=$S/libiio1 HOSTP=192.168.4.1 FS=5000000 NBS=32 RUNS=240 SECS=5 python3 -u $K/drop73u.py > $O/stream_73_soak.log 2>&1
mon_stop 2>/dev/null
logB "NCM 5 MS/s soak 240 rounds 7.3: $(grep SUMMARY $O/stream_73_soak.log | tr '\n' ' ') spito=$(timeout 20 $SSH 'dmesg | grep -c "SPI transfer timed out"') rate seen by the monitor: $(grep -o 'sf=[0-9A-Z]*' $O/mon.log 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
timeout 30 $SSH 'sh /tmp/radio_off.sh' > /dev/null 2>&1
logB "final: $(timeout 30 $SSH 'sh /tmp/bootinfo.sh' 2>&1 | tr '\n' ' ') halt_warnings=$(timeout 10 $SSH 'dmesg | grep -c "not taken"') adcheck: $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | head -1)"
nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 > /dev/null 2>&1
logB "== phase B done; the card holds sdimg-rt73-final5"
