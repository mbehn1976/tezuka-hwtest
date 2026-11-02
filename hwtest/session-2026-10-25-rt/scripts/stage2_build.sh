#!/bin/bash
cd /home/mb/code/tezuka_fw-dev || exit 1
export BR2_DL_DIR=/home/mb/code/tezuka_fw-all/buildroot/dl
source sourceme.first
make -C buildroot O=$PWD/output/plutoplus plutoplus_maiasdr_defconfig || { echo DEFCONFIG_FAIL; exit 3; }
grep -E '^CONFIG_|^BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION' output/plutoplus/.config | grep -E 'TARBALL_LOCATION|FRAGMENT' | head -3
make -C buildroot O=$PWD/output/plutoplus -j16 || { echo MAKE_FAIL; exit 5; }
grep -E '^CONFIG_(PREEMPT|HZ_|NO_HZ|HIGH_RES|CPU_IDLE|CPU_FREQ)' output/plutoplus/build/linux-*/.config
ls -l output/plutoplus/images/sdimg
echo STAGE2_BUILD_DONE
