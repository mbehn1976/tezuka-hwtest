#!/bin/bash
cd /home/mb/code/tezuka_fw-dev || exit 1
export BR2_DL_DIR=/home/mb/code/tezuka_fw-all/buildroot/dl
[ -d buildroot ] || ./getbuildroot.sh || { echo GETBR_FAIL; exit 2; }
source sourceme.first
make -C buildroot O=$PWD/output/plutoplus plutoplus_maiasdr_defconfig || exit 3
printf 'BR2_PACKAGE_RT_TESTS=y\nBR2_PACKAGE_STRESS_NG=y\n' >> output/plutoplus/.config
make -C buildroot O=$PWD/output/plutoplus olddefconfig || exit 4
grep -E 'BR2_PACKAGE_(RT_TESTS|STRESS_NG)=' output/plutoplus/.config
make -C buildroot O=$PWD/output/plutoplus -j16 rt-tests stress-ng || exit 5
echo STAGE1_BUILD_DONE
