#!/bin/bash
# 7.3 boot-fault hunt (user go 2026-11-02 08:00):
#  1. build the 7.3 DEBUG image: patches 0001-0006 (0006 = bounded hw_ep_set_halt, uncommitted), kernel fragment (sysrq,
#     printk time, 512 KB log buffer, hung task 10 s, RCU stall 21 s) and the S99bootwatch overlay. The two Buildroot
#     options are changed in output/plutoplus_rt73/.config for the build and restored afterwards (the kernel build dir
#     keeps the debug config until the next linux-dirclean).
#  2. card -> the debug image (backup of the card in known_good/card-before-2026-11-02-bootloop), check the watcher
#  3. bootloop.sh BL1 200 (about 6.5 h), 4. card back to sdimg-rt21-sw
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_bootloop; mkdir -p $O; D=$K/k73dbg; HW=/home/mb/tezuka-review-v0.3.23/hwtest
IMG=$HW/known_good/sdimg-rt73-dbg
log "== boot-fault hunt start"
cd /home/mb/code/tezuka_fw-dev || exit 1; source sourceme.first > /dev/null 2>&1; OUT=$PWD/output/plutoplus_rt73
cp -p $OUT/.config $D/br.config.orig
sed -i "s|^BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES=.*|BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES=\"$D/linux_debug.fragment\"|; s|^BR2_ROOTFS_OVERLAY=\"\(.*\)\"|BR2_ROOTFS_OVERLAY=\"\1 $D/overlay\"|" $OUT/.config
log "buildroot options: $(grep -E '^BR2_(LINUX_KERNEL_CONFIG_FRAGMENT_FILES|ROOTFS_OVERLAY)=' $OUT/.config | tr '\n' ' ')"
log "build start"
{ make -C buildroot O=$OUT linux-dirclean maia-kmod-dirclean && make -C buildroot O=$OUT board-fpga-dirclean board-fpga && CMAKE_POLICY_VERSION_MINIMUM=3.5 make -C buildroot O=$OUT -j16; } > $O/build.log 2>&1
rc=$?; cp -p $D/br.config.orig $OUT/.config
[ $rc = 0 ] || { log "BUILD FAILED (see build.log)"; grep -n -i -E 'error|failed' $O/build.log | tail -8 | tee -a $O/run.log; exit 1; }
log "build checks: halt patch in tree=$(grep -c 'not taken' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c) config: $(grep -E '^CONFIG_(MAGIC_SYSRQ|PRINTK_TIME|LOG_BUF_SHIFT|DEFAULT_HUNG_TASK_TIMEOUT|RCU_CPU_STALL_TIMEOUT)=' $OUT/build/linux-custom/.config | tr '\n' ' ') watcher=$(ls $OUT/target/etc/init.d/S99bootwatch 2>/dev/null | wc -l) rtprio60=$(grep -c 'chrt -f -p 60' $OUT/target/etc/init.d/S24rtprio) modules=$(ls $OUT/target/lib/modules/)"
grep -q 'not taken' $OUT/build/linux-custom/drivers/usb/chipidea/udc.c && grep -q '^CONFIG_MAGIC_SYSRQ=y' $OUT/build/linux-custom/.config && [ -x $OUT/target/etc/init.d/S99bootwatch ] || { log "BUILD CHECKS FAILED"; exit 1; }
rm -rf $IMG; cp -a $OUT/images/sdimg $IMG; cp -p $OUT/images/pluto.frm $IMG.pluto.frm
log "image: $(cat $OUT/build/linux-custom/include/config/kernel.release) uImage $(md5sum < $IMG/uImage | cut -c1-8) ramdisk $(md5sum < $IMG/uramdisk.image.xz | cut -c1-8)"

# 2. card
for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh $IMG known_good/card-before-2026-11-02-bootloop > $O/sd_write_dbg.log 2>&1 && log "card on the debug image: $(grep -c 'checksums match' $O/sd_write_dbg.log) match" || { log "SD WRITE FAILED"; tail -3 $O/sd_write_dbg.log | tee -a $O/run.log; exit 2; }
sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
info=$(timeout 30 $SSH 'echo "$(uname -r) sysrq=$(cat /proc/sys/kernel/sysrq) hung=$(cat /proc/sys/kernel/hung_task_timeout_secs) allcpu=$(cat /proc/sys/kernel/hung_task_all_cpu_backtrace) rcu=$(cat /sys/module/rcupdate/parameters/rcu_cpu_stall_timeout) watcher=$(pgrep -f S99bootwatch | wc -l) ts=$(dmesg | tail -1 | cut -c1-14) usb0=$(ip -br -4 addr show usb0 | awk "{print \$3}") eth0=$(ip -br -4 addr show eth0 | awk "{print \$3}")"' 2>&1 | tr '\n' ' ')
log "debug boot: $info"
case "$info" in 7.3.0*sysrq=1*hung=10*allcpu=1*rcu=21*) ;; *) log "ABORT: debug settings not active"; exit 1;; esac

# 3. loop
$K/bootloop.sh BL1 200 7.3.0 || log "bootloop ended with an error"
rm -rf $O/BL1; mv $K/BL1 $O/
grep -h 'BL1 done' $O/BL1/run.log | tee -a $O/run.log

# 4. back to 6.12
for i in $(seq 30); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
cd $HW && HOST=192.168.4.1 NOPOWER=1 ./sd_write.sh known_good/sdimg-rt21-sw > $O/sd_write_612.log 2>&1 && log "card back on 6.12: $(grep -c 'checksums match' $O/sd_write_612.log) match" || log "SD WRITE BACK FAILED (board may be unreachable; card still holds the debug image)"
sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && break; sleep 5; done
log "6.12 control: $(timeout 20 $SSH 'uname -r; cut -d" " -f1 /proc/uptime' | tr '\n' ' ')"
log "== boot-fault hunt done"
