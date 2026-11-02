#!/bin/bash
# 6.12 counter-test for the boot-fault hunt (2026-11-02 10:55). The 7.3 debug loop showed the ep0 halt bit refused on
# 4 of 119 boots (patch 0006 made it harmless). The same unbounded loop exists in 6.12; 0 faults in about 40 earlier
# 6.12 boots does not exclude the same rate. So: the shipping 6.12 build (output/plutoplus_rt, same tree as
# sdimg-rt21-sw) + patch 0006 + the debug kernel fragment + the S99bootwatch overlay, 120 boot cycles with bootloop2,
# then the card back to sdimg-rt21-sw. The rebuilt rootfs also carries S24rtprio (new since the shipping build).
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_bootloop; mkdir -p $O; D=$K/k612dbg; DB=$K/k73dbg; HW=/home/mb/tezuka-review-v0.3.23/hwtest
IMG=$HW/known_good/sdimg-rt21-dbg
L=$O/run612.log
log2(){ echo "$(date +%T) $*" >> $L; }
log2 "== 6.12 counter-test start"
while pgrep -f chain7.sh > /dev/null; do sleep 20; done
cd /home/mb/code/tezuka_fw-dev || exit 1; source sourceme.first > /dev/null 2>&1; OUT=$PWD/output/plutoplus_rt
cp -p $OUT/.config $D/br.config.orig
sed -i "s|^BR2_LINUX_KERNEL_PATCH=.*|BR2_LINUX_KERNEL_PATCH=\"$D/patches\"|; s|^BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES=\"\(.*\)\"|BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES=\"\1 $DB/linux_debug.fragment\"|; s|^BR2_ROOTFS_OVERLAY=\"\(.*\)\"|BR2_ROOTFS_OVERLAY=\"\1 $DB/overlay\"|" $OUT/.config
log2 "buildroot options: $(grep -E '^BR2_(LINUX_KERNEL_PATCH|LINUX_KERNEL_CONFIG_FRAGMENT_FILES|ROOTFS_OVERLAY)=' $OUT/.config | tr '\n' ' ')"
log2 "build start"
{ make -C buildroot O=$OUT linux-dirclean maia-kmod-dirclean && make -C buildroot O=$OUT board-fpga-dirclean board-fpga && CMAKE_POLICY_VERSION_MINIMUM=3.5 make -C buildroot O=$OUT -j16; } > $O/build612.log 2>&1
rc=$?; cp -p $D/br.config.orig $OUT/.config
[ $rc = 0 ] || { log2 "BUILD FAILED (see build612.log)"; grep -n -i -E 'error|failed' $O/build612.log | tail -8 >> $L; exit 1; }
REL=$(cat $OUT/build/linux-custom/include/config/kernel.release)
log2 "build checks: release=$REL halt patch in tree=$(grep -c 'not taken' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c) config: $(grep -E '^CONFIG_(MAGIC_SYSRQ|PRINTK_TIME|LOG_BUF_SHIFT|DEFAULT_HUNG_TASK_TIMEOUT|RCU_CPU_STALL_TIMEOUT)=' $OUT/build/linux-custom/.config | tr '\n' ' ') watcher=$(ls $OUT/target/etc/init.d/S99bootwatch 2>/dev/null | wc -l) rtprio=$(ls $OUT/target/etc/init.d/S24rtprio 2>/dev/null | wc -l) modules=$(ls $OUT/target/lib/modules/)"
grep -q 'not taken' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c && grep -q '^CONFIG_MAGIC_SYSRQ=y' $OUT/build/linux-custom/.config && [ -x $OUT/target/etc/init.d/S99bootwatch ] && [ "$REL" = 6.12.114-rt21 ] || { log2 "BUILD CHECKS FAILED"; exit 1; }
rm -rf $IMG; cp -a $OUT/images/sdimg $IMG; cp -p $OUT/images/pluto.frm $IMG.pluto.frm
log2 "image: $REL uImage $(md5sum < $IMG/uImage | cut -c1-8) ramdisk $(md5sum < $IMG/uramdisk.image.xz | cut -c1-8) (shipping: uImage 76b2f2e8 ramdisk 581772f5)"

for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh $IMG known_good/card-before-2026-11-02-bootloop612 > $O/sd_write_dbg612.log 2>&1 && log2 "card on the 6.12 debug image: $(grep -c 'checksums match' $O/sd_write_dbg612.log) match" || { log2 "SD WRITE FAILED"; tail -3 $O/sd_write_dbg612.log >> $L; exit 2; }
sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
info=$(timeout 30 $SSH 'echo "$(uname -r) sysrq=$(cat /proc/sys/kernel/sysrq) hung=$(cat /proc/sys/kernel/hung_task_timeout_secs) allcpu=$(cat /proc/sys/kernel/hung_task_all_cpu_backtrace) rcu=$(cat /sys/module/rcupdate/parameters/rcu_cpu_stall_timeout) watcher=$(pgrep -f S99bootwatch | wc -l) ts=$(dmesg | tail -1 | cut -c1-14) usb0=$(ip -br -4 addr show usb0 | awk "{print \$3}") eth0=$(ip -br -4 addr show eth0 | awk "{print \$3}")"' 2>&1 | tr '\n' ' ')
log2 "debug boot: $info"
case "$info" in 6.12.114-rt21*sysrq=1*hung=10*allcpu=1*rcu=21*) ;; *) log2 "ABORT: debug settings not active"; exit 1;; esac

$K/bootloop2.sh BL612 120 6.12.114 || log2 "bootloop ended with an error"
rm -rf $O/BL612; mv $K/BL612 $O/
grep -h 'BL612 done' $O/BL612/run.log >> $L

for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612b.log 2>&1 && log2 "card back on 6.12 shipping: $(grep -c 'checksums match' $O/sd_write_612b.log) match" || log2 "SD WRITE BACK FAILED (card still holds the 6.12 debug image)"
sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
log2 "6.12 control: $(timeout 20 $SSH 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ')"
log2 "== 6.12 counter-test done"
