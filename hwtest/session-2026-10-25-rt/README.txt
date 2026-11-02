2026-10-25 RT / network-loss session. Scripts need: ~/code/maia-sdr-bp/maia-hdl/hwtest (hwlib.py), venv ~/.venvs/pluto-test, boards Pluto 192.168.2.1 + Pluto+ 192.168.3.1.
Scripts use scratchpad paths for temp files (D=...scratchpad/); edit D before reuse. cyclictest/stress-ng must be on the Pluto+ (RT image has them; on non-RT copy from ~/code/tezuka_fw-dev/output/plutoplus/target/usr/bin + libnuma.so.1 to /usr/bin and /usr/lib).
Host libiio 1.0.0 tools: cmake build of libiio-1.0.0.tar.gz (from tezuka_fw-all/buildroot/dl/libiio) with -DWITH_ZSTD=ON -DWITH_IIOD=OFF -DLIBIIO_COMPAT=OFF -DWITH_TESTS=OFF; install prefix in the scratchpad (rebuild if gone).
Full write-up: ~/code/tezuka_fw-dev/doc/UPGRADE_REALTIME_7.3.md (branch dev/next, commits 453f975, eff4ba6 + next-steps commit).
Next steps: NEXT_STEPS.md (same text as doc section 15).
