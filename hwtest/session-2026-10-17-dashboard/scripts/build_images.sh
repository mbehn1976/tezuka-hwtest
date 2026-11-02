#!/bin/bash
# Build the Pluto and Pluto+ images from the tezuka_fw test branch with maia-httpd and maia-wasm taken from a local maia-sdr tree.
# output/<board>/local.mk must contain:
#   MAIA_HTTPD_OVERRIDE_SRCDIR = /home/mb/code/maia-sdr-merge
#   MAIA_WASM_OVERRIDE_SRCDIR = /home/mb/code/maia-sdr-merge
# Buildroot does NOT rebuild override packages by itself: dirclean them first, and rebuild board-fpga after a new xsa.
cd ~/code/tezuka_fw-all
for b in pluto plutoplus; do
  echo "=== $b $(date +%T)"
  make -C buildroot O=$PWD/output/$b board-fpga-dirclean board-fpga maia-httpd-dirclean maia-wasm-dirclean > dirclean_$b.log 2>&1
  ./build.sh -j16 $b > build_$b.log 2>&1; echo "exit $b $? $(date +%T)"
done
# Pluto: copy build/pluto.zip flash/pluto.frm to the Pluto's USB volume and let the user eject it.
# Pluto+: ~/tezuka-review-v0.3.23/hwtest/sd_write.sh <sdimg dir> (card unmounted from the desktop first; HOST=192.168.3.1 NOPOWER=1).
