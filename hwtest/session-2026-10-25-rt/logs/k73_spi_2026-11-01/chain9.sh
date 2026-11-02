#!/bin/bash
# The fix for real (2026-11-02 12:25, user: can we fix it): patch 0006 (bounded ep0 halt loop; the warning now also
# prints ENDPTSETUPSTAT) in the release builds of both kernels.
#  1. 6.12 RT release build with the patch (configs/plutoplus_rt_defconfig selects patches/linux/6.12-rt) -> known_good/sdimg-rt21-halt
#  2. 7.3 release build, patches 0001-0006, no debug fragment, no watcher -> known_good/sdimg-rt73-final4
#  3. after chain8 has restored the card: card -> sdimg-rt21-halt, bootloop2 BL612h 120 cycles, the card STAYS on sdimg-rt21-halt
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_bootloop; mkdir -p $O; HW=/home/mb/tezuka-review-v0.3.23/hwtest; L=$O/run9.log
log9(){ echo "$(date +%T) $*" >> $L; }
log9 "== release builds with the halt fix + 6.12 verification loop: start"
cd /home/mb/code/tezuka_fw-dev || exit 1; source sourceme.first > /dev/null 2>&1
build(){ # $1 output dir  $2 expected kernel release  $3 image name  $4 BR2_LINUX_KERNEL_PATCH value to set (empty: keep)
  local OUT=$PWD/output/$1 REL IMG
  rm -f $OUT/target/etc/init.d/S99bootwatch
  [ -n "$4" ] && sed -i "s|^BR2_LINUX_KERNEL_PATCH=.*|BR2_LINUX_KERNEL_PATCH=\"$4\"|" $OUT/.config
  log9 "$1 options: $(grep -E '^BR2_(LINUX_KERNEL_PATCH|LINUX_KERNEL_CONFIG_FRAGMENT_FILES|ROOTFS_OVERLAY)=' $OUT/.config | tr '\n' ' ')"
  log9 "$1 build start"
  { make -C buildroot O=$OUT linux-dirclean maia-kmod-dirclean && make -C buildroot O=$OUT board-fpga-dirclean board-fpga && CMAKE_POLICY_VERSION_MINIMUM=3.5 make -C buildroot O=$OUT -j16; } > $O/build_$1.log 2>&1 || { log9 "BUILD $1 FAILED (build_$1.log)"; grep -n -i -E 'error|failed' $O/build_$1.log | tail -5 >> $L; return 1; }
  REL=$(cat $OUT/build/linux-custom/include/config/kernel.release)
  log9 "$1 checks: release=$REL halt_patch=$(grep -c 'ENDPTSETUPSTAT 0x' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c) sysrq=$(grep -c '^CONFIG_MAGIC_SYSRQ=y' $OUT/build/linux-custom/.config) printk_time=$(grep -c '^CONFIG_PRINTK_TIME=y' $OUT/build/linux-custom/.config) watcher=$(ls $OUT/target/etc/init.d/S99bootwatch 2>/dev/null | wc -l) rtprio=$(ls $OUT/target/etc/init.d/S24rtprio 2>/dev/null | wc -l) modules=$(ls $OUT/target/lib/modules/)"
  [ "$REL" = "$2" ] && grep -q 'ENDPTSETUPSTAT 0x' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c && ! grep -q '^CONFIG_MAGIC_SYSRQ=y' $OUT/build/linux-custom/.config && [ ! -e $OUT/target/etc/init.d/S99bootwatch ] || { log9 "BUILD CHECKS $1 FAILED"; return 1; }
  IMG=$HW/known_good/$3; rm -rf $IMG; cp -a $OUT/images/sdimg $IMG; cp -p $OUT/images/pluto.frm $IMG.pluto.frm
  log9 "image $3: $REL uImage $(md5sum < $IMG/uImage | cut -c1-8) ramdisk $(md5sum < $IMG/uramdisk.image.xz | cut -c1-8)"
}
build plutoplus_rt 6.12.114-rt21 sdimg-rt21-halt '${BR2_EXTERNAL_PLUTOSDR_PATH}/board/tezuka/common/patches/linux/6.12-rt' || exit 1
build plutoplus_rt73 7.3.0 sdimg-rt73-final4 '' || log9 "7.3 build failed, the 6.12 loop goes on"

while pgrep -f chain8.sh > /dev/null; do sleep 20; done
grep -q '6.12 counter-test done' $O/run612.log || log9 "warning: chain8 did not log its end"
log9 "chain8 finished; 6.12 counter-test: $(grep -h 'BL612 done' $O/run612.log | cut -c10-)"
for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-halt known_good/card-before-2026-11-02-halt > $O/sd_write_halt.log 2>&1 && log9 "card on sdimg-rt21-halt: $(grep -c 'checksums match' $O/sd_write_halt.log) match" || { log9 "SD WRITE FAILED"; tail -3 $O/sd_write_halt.log >> $L; exit 2; }
sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
timeout 20 $SSH 'cat > /tmp/bootinfo.sh' < $K/bootinfo.sh
info=$(timeout 30 $SSH 'sh /tmp/bootinfo.sh' 2>&1 | tr '\n' ' ')
log9 "first boot: $info"
case "$info" in 6.12.114-rt21*prio=60*) ;; *) log9 "ABORT: not the expected image state"; exit 1;; esac

$K/bootloop2.sh BL612h 120 6.12.114 || log9 "bootloop ended with an error"
rm -rf $O/BL612h; mv $K/BL612h $O/
B=$O/BL612h
log9 "== BL612h: $(grep -c . $B/boots.txt) boots, clean $(grep -c ' faultlines=0 hostusb=0' $B/boots.txt), halt refused $(grep -a -l 'not taken' $B/logs/boot_*.dmesg 2>/dev/null | wc -l) ($(grep -a -h 'not taken' $B/logs/boot_*.dmesg 2>/dev/null | grep -o 'ENDPTSETUPSTAT 0x[0-9a-f]*' | sort | uniq -c | tr '\n' ' ')), other fault lines $(grep -a -c -E 'blocked for more|rcu: INFO|BUG:|Oops|Read Error|SPI transfer timed out' $B/logs/boot_*.dmesg 2>/dev/null | grep -vc ':0$'), host usb events $(grep -vc ' hostusb=0' $B/boots.txt), product id $(grep -o '0x037=0x[0-9A-F]*' $B/boots.txt | sort | uniq -c | tr '\n' ' '), no SSH $(grep -c NOSSH $B/boots.txt)"
for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
log9 "board after the loop: $(timeout 30 $SSH 'sh /tmp/bootinfo.sh' 2>&1 | tr '\n' ' ')"
log9 "== done; the card holds sdimg-rt21-halt"
