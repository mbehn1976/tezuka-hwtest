#!/bin/bash
cd /home/mb/code/tezuka_fw-dev || exit 1
export BR2_DL_DIR=/home/mb/code/tezuka_fw-all/buildroot/dl
source sourceme.first
make -C buildroot O=$PWD/output/plutoplus plutoplus_maiasdr_defconfig || { echo DEFCONFIG_FAIL; exit 3; }
make -C buildroot O=$PWD/output/plutoplus linux-dirclean maia-kmod-dirclean || { echo CLEAN_FAIL; exit 4; }
make -C buildroot O=$PWD/output/plutoplus -j16 || { echo MAKE_FAIL; exit 5; }
grep -E '^CONFIG_(PREEMPT_RT|FTRACE|IRQSOFF_TRACER|PREEMPT_TRACER|SCHED_TRACER|FUNCTION_TRACER)=' output/plutoplus/build/linux-custom/.config
echo STAGE2T_BUILD_DONE
