# Pluto (QSPI) all-fixes firmware, 2026-10-13

known_good/pluto-v0.3.23-allfixes.frm (md5 63c7e32b), flashed by copy + user eject.

Running state matches the build: kernel with Spectre v2 branch predictor hardening (F11), maia-sdr.ko 9a944cce (F7),
maia-httpd d03803fe (F15 + race fix), no oops. FPGA image inside the frm = pluto-combined-f18 bitstream
(F1/F4, F2, F17, F5, F18; F6/N1/N2/F3 do not change it).

| Test | Result |
|---|---|
| F18 + F2: BIST tone 0 dB at 61.44 MS/s, DDC on, 8 captures (61.44 M samples) | 0 slips, 0 I/Q misalignment, 0 dropouts; only the 2 capture-edge events per capture (same as the Pluto+ after-fix baseline) |
| F5: DC bias of DDC output, BIST 6/12/18 dB | mean I/Q <= 0.0001 LSB (was -0.47) |
| CS12 layout (cs12layout.py, 30.72 MS/s) | MAGIC every 786432 B, counter +1, phase step 9 samples |
| F15 race (routingrace.sh, 1000 PATCH, extra poller) | 0 wrong, all HTTP 200 |
