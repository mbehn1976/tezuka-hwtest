#!/bin/bash
# Phase A builds (plan 2026-11-02): 7.3 final5 = v7.3 + patches 0001-0007 (0007 = QSPI program/erase through the bank register)
# + NCM default (uEnv.txt usb_ethernet_mode=ncm passed on the command line, S23udc override); 6.12 v2 = 6.12.114-rt21 + 6.12-rt
# 0001 (halt) + 0002 (SPI recovery) + the same NCM default. Release configs, no debug fragment, no watcher.
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_final; mkdir -p $O; HW=/home/mb/tezuka-review-v0.3.23/hwtest; L=$O/runA.log
logA(){ echo "$(date +%T) $*" >> $L; }
logA "== phase A: builds start"
cd /home/mb/code/tezuka_fw-dev || exit 1; source sourceme.first > /dev/null 2>&1
build(){ # $1 output dir  $2 expected release  $3 image name  $4 kind (73|612)
  local OUT=$PWD/output/$1 REL S IMG chk
  rm -f $OUT/target/etc/init.d/S99bootwatch
  logA "$1 build start: $(grep '^BR2_LINUX_KERNEL_PATCH=' $OUT/.config)"
  if [ "${SKIP_MAKE:-}" = "$1" ]; then logA "$1: make skipped (already built), checking only"; else
  { make -C buildroot O=$OUT linux-dirclean maia-kmod-dirclean && make -C buildroot O=$OUT board-fpga-dirclean board-fpga && CMAKE_POLICY_VERSION_MINIMUM=3.5 make -C buildroot O=$OUT -j16; } > $O/build_$1.log 2>&1 || { logA "BUILD $1 FAILED (build_$1.log)"; grep -n -i -E 'error|failed' $O/build_$1.log | tail -6 >> $L; return 1; }
  fi
  REL=$(cat $OUT/build/linux-custom/include/config/kernel.release); S=$OUT/build/linux-custom
  chk="release=$REL halt=$(grep -c 'ENDPTSETUPSTAT 0x' $S/drivers/usb/chipidea/udc.c) recovery=$(grep -c cdns_spi_handle_err $S/drivers/spi/spi-cadence.c) qspi_write=$(grep -c zynq_qspi_wait_ready $S/drivers/spi/spi-zynq-qspi.c) qspi_ro=$(grep -c 'read-only: op' $S/drivers/spi/spi-zynq-qspi.c) sysrq=$(grep -c '^CONFIG_MAGIC_SYSRQ=y' $S/.config) watcher=$(ls $OUT/target/etc/init.d/S99bootwatch 2>/dev/null | wc -l) rtprio=$(ls $OUT/target/etc/init.d/S24rtprio 2>/dev/null | wc -l) udc_override=$(grep -c CMDLINE_ETH_MODE $OUT/target/etc/init.d/S23udc) uenv_ncm=$(grep -c '^usb_ethernet_mode=ncm' $OUT/images/sdimg/uEnv.txt) uenv_args=$(grep -c 'usb_args' $OUT/images/sdimg/uEnv.txt) modules=$(ls $OUT/target/lib/modules/)"
  logA "$1 checks: $chk"
  case "$chk" in "release=$2 halt=1 recovery="[1-9]*" sysrq=0 watcher=0 rtprio=1 udc_override="[1-9]" uenv_ncm=1 uenv_args="[2-9]*) ;; *) logA "BUILD CHECKS $1 FAILED"; return 1;; esac
  if [ "$4" = 73 ]; then case "$chk" in *"qspi_write="[1-9]*" qspi_ro=0 "*) ;; *) logA "QSPI WRITE CHECKS $1 FAILED"; return 1;; esac; fi
  IMG=$HW/known_good/$3; rm -rf $IMG; cp -a $OUT/images/sdimg $IMG; cp -p $OUT/images/pluto.frm $IMG.pluto.frm
  logA "image $3: $REL uImage $(md5sum < $IMG/uImage | cut -c1-8) ramdisk $(md5sum < $IMG/uramdisk.image.xz | cut -c1-8) frm $(md5sum < $IMG.pluto.frm | cut -c1-8) $(stat -c %s $IMG.pluto.frm) bytes"
}
build plutoplus_rt73 7.3.0 sdimg-rt73-final5 73 || { logA "== phase A FAILED (7.3)"; exit 1; }
build plutoplus_rt 6.12.114-rt21 sdimg-rt21-v2 612 || { logA "== phase A FAILED (6.12)"; exit 1; }
logA "== phase A done"
