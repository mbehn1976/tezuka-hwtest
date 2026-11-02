#!/bin/bash
# 7.3 final qualification: rebuild image with the shipped S24rtprio, boot cycles, USB 2.5/4 MS/s, eth 10 MS/s nb4/nb32,
# USB throughput wedge test, 2 h eth soak, 1 h USB 4 MS/s soak, then card back to 6.12.
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_73final; mkdir -p $O; rm -f $O/stop
IMG=/home/mb/tezuka-review-v0.3.23/hwtest/known_good/sdimg-rt73-final3
KP=7.3.0
log "== qualification start"

# 1. rebuild (rootfs overlay changed: S24rtprio), board-fpga first (post-image trap)
cd /home/mb/code/tezuka_fw-dev; source sourceme.first >/dev/null 2>&1; OUT=$PWD/output/plutoplus_rt73
{ make -C buildroot O=$OUT board-fpga-dirclean board-fpga && CMAKE_POLICY_VERSION_MINIMUM=3.5 make -C buildroot O=$OUT -j16; } > $O/build.log 2>&1 || { log "BUILD FAILED (see build.log)"; exit 1; }
grep -q 'chrt -f -p 51' $OUT/target/etc/init.d/S24rtprio && grep -q 'chrt -f -p 60' $OUT/target/etc/init.d/S24rtprio || { log "BUILD: S24rtprio not in target"; exit 1; }
rm -rf $IMG; cp -a $OUT/images/sdimg $IMG; cp -p $OUT/images/pluto.frm $IMG.pluto.frm
log "image built: $(cat $OUT/build/linux-custom/include/config/kernel.release) uImage $(md5sum < $IMG/uImage | cut -c1-8) ramdisk $(md5sum < $IMG/uramdisk.image.xz | cut -c1-8)"
cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh $IMG known_good/card-before-2026-11-01-q73b > $O/sd_write_73.log 2>&1 || { log "SD WRITE FAILED"; tail -3 $O/sd_write_73.log; exit 2; }
log "card written: $(grep -c 'checksums match' $O/sd_write_73.log) match"
ip -br -4 addr show eno1 | grep -q 192.168.3.10 || { nmcli device modify eno1 +ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; sleep 2; }

bootcheck(){ # one line of evidence per boot; label in $lbl
  local b h
  b=$(timeout 60 $SSH 'echo "up=$(cut -d" " -f1 /proc/uptime) usb0=$(ip -br -4 addr show usb0 | awk "{print \$3}") eth0=$(ip -br -4 addr show eth0 | awk "{print \$3}") rcu=$(dmesg | grep -c -i "rcu.*stall") trace=$(dmesg | grep -c "Call trace") bugwarn=$(dmesg | grep -c -E "BUG:|WARNING:|Oops") spito=$(dmesg | grep -c "SPI transfer timed out") kt=$(for c in /proc/[0-9]*/comm; do [ "$(cat $c 2>/dev/null)" = ktimers/0 ] && { s=$(sed "s/.*) //" ${c%comm}stat); set -- $s; echo ${38}; }; done) spiprio=$(for c in /proc/[0-9]*/comm; do case "$(cat $c 2>/dev/null)" in irq/*e0006000*) s=$(sed "s/.*) //" ${c%comm}stat); set -- $s; echo "${38}cpu${37}";; esac; done) $(sh /tmp/adcheck.sh 2>/dev/null | head -1)"' 2>&1 | tr '\n' ' ')
  h=$(journalctl -k --since "-3 min" --no-pager 2>/dev/null | grep -c -E 'rndis.*-110|probe with driver rndis_host failed|device descriptor read.*error')
  log "boot $lbl: $b host_rndis_errors=$h"
  echo "$b host_rndis_errors=$h" >> $O/boots.txt
}

# 2. boot cycles (reboot_verify pushes the board scripts each time)
for i in $(seq 1 15); do
  reboot_verify $KP || { log "boot $i: board did not come back"; exit 3; }
  timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh
  lbl=$i bootcheck
done
log "boot cycles done: stalls=$(awk '{for(i=1;i<=NF;i++) if($i~/^rcu=/){split($i,a,"="); s+=a[2]}} END{print s+0}' $O/boots.txt) traces=$(awk '{for(i=1;i<=NF;i++) if($i~/^trace=/){split($i,a,"="); s+=a[2]}} END{print s+0}' $O/boots.txt) host_rndis_errors=$(awk '{for(i=1;i<=NF;i++) if($i~/^host_rndis_errors=/){split($i,a,"="); s+=a[2]}} END{print s+0}' $O/boots.txt) wrong_usb0=$(grep -vc 'usb0=192.168.4.1/24' $O/boots.txt) wrong_eth0=$(grep -vc 'eth0=192.168.3.1/24' $O/boots.txt)"

stream(){ # $1 label $2 host $3 fs $4 nbs
  timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1; r=$(timeout 30 $SSH "sh /tmp/radio_on.sh $3"); log "stream $1 fs=$3 nbs=$4 via $2: $r"
  case "$r" in *"sf=$3 "*) ;; *) log "  SKIP $1: rate readback wrong"; return;; esac
  D=$O I1=$S/libiio1 HOSTP=$2 FS=$3 NBS=$4 RUNS=15 SECS=5 python3 -u $K/drop73u.py > $O/stream_$1.log 2>&1
  log "  RESULT $1: $(grep SUMMARY $O/stream_$1.log | tr '\n' ' ') | spito=$(spito)"
}
tp(){ python3 $K/tp.py recv 5201 > $O/tp_b2h.txt 2>&1 & sleep 1; timeout 120 $SSH "dd if=/dev/zero bs=65536 count=3200 2>/dev/null | nc 192.168.4.10 5201"; wait; timeout 120 $SSH "nc -l -p 5202 > /dev/null" & sleep 2; python3 $K/tp.py send 192.168.4.1 5202 200 > $O/tp_h2b.txt 2>&1; wait; log "USB throughput: $(cat $O/tp_b2h.txt) / $(cat $O/tp_h2b.txt)"; }

# 3-5. short tests on the last boot (shipped settings)
ping -c1 -W1 192.168.3.1 >/dev/null && log "eth alias up" || log "eth alias FAILED"
stream usb_2p5M 192.168.4.1 2500000 32
stream usb_4M 192.168.4.1 4000000 32
stream eth_10M 192.168.3.1 10000000 4,32
timeout 30 $SSH 'sh /tmp/radio_off.sh' >/dev/null 2>&1
s0=$(spito); tp; log "after USB throughput test: spito=$(spito) (was $s0); $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"

# 6. soaks (run_variant3.sh reboots, monitors once a minute, adcheck before and after)
export KPAT=$KP PRECMD='sh /tmp/adcheck.sh' POSTCMD='sh /tmp/adcheck.sh'
STREAM_HOST=192.168.3.1 FS=10000000 NBS=32 $K/run_variant3.sh Q_eth10M_soak 720 'cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
echo shipped settings' || log "eth soak runner failed"
STREAM_HOST=192.168.4.1 FS=4000000 NBS=32 $K/run_variant3.sh Q_usb4M_soak 340 'cat > /tmp/adcheck.sh <<"EOS"
'"$(cat $K/adcheck.sh)"'
EOS
echo shipped settings' || log "usb soak runner failed"
for v in Q_eth10M_soak Q_usb4M_soak; do mv $K/$v $O/ 2>/dev/null; log "$v: $(grep RESULT $O/$v/run.log | sed 's/.*RESULT //') | post: $(grep 'post:' $O/$v/run.log | sed 's/.*post: //')"; done

# 7. back to 6.12
cd /home/mb/tezuka-review-v0.3.23/hwtest && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED"
for i in $(seq 30); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
log "6.12 control: $(timeout 20 $SSH 'uname -r') spito=$(spito)"
timeout 30 $SSH 'IRQ=$(awk "/e0006000/{sub(\":\",\"\",\$1); print \$1}" /proc/interrupts); P=$(grep -l "^irq/$IRQ-" /proc/[0-9]*/comm | cut -d/ -f3); chrt -f -p 60 $P; chrt -p $P | tail -1' | tee -a $O/run.log
timeout 20 $SSH 'cat > /tmp/adcheck.sh' < $K/adcheck.sh
a=$(spito); tp; log "6.12 with SPI thread at FIFO 60, after USB throughput test: spito +$(( $(spito) - a )); $(timeout 60 $SSH 'sh /tmp/adcheck.sh' | tr '\n' ' ')"
timeout 30 $SSH 'sh /tmp/radio_off.sh 2>/dev/null; P=$(dirname $(grep -l "^ad9361-phy$" /sys/bus/iio/devices/iio:device*/name)); echo 0 > /sys/kernel/debug/iio/$(basename $P)/loopback' >/dev/null 2>&1
rm -f $O/ol.bin; nmcli device modify eno1 -ipv4.addresses 192.168.3.10/24 >/dev/null 2>&1; log "eth alias removed: $(ip -br -4 addr show eno1 | awk '{print $3, $4}')"
log "== qualification done"
