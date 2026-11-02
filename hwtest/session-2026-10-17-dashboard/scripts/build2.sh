#!/bin/bash
cd ~/code/tezuka_fw-all
for b in pluto plutoplus; do
  echo "=== $b $(date +%T)"
  make -C buildroot O=$PWD/output/$b board-fpga-dirclean board-fpga >/dev/null 2>&1
  ./build.sh -j16 $b > /tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/build_$b.log 2>&1; echo "exit $b $? $(date +%T)"
done
echo BUILD_DONE
