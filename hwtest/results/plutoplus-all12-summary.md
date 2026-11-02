# Pluto+ all-fixes (12-board build) bitstream retest, 2026-10-13

Bitstream: tz_plutoplus build of all-fixes-build (refactor 9c1cd64 + maia-sdr #14-#23, built before the #14 XDC fix c8c7e4a; the
fix only touches other boards' XDCs). known_good/plutoplus-all12-9c1cd64plus.xsa (md5 afa8ed95), image known_good/sdimg-v0.3.23-all12.
Not byte-identical to plutoplus-combined-f18 (43222 bytes differ; only source difference is #19 removing the stale manual_decim
false path). Image vs f15v2: kernel payload identical, only bitstream files, etc/shadow and opt/vfat.img differ.
Board: 192.168.3.1, /boot checksums match the image, maia-httpd d03803fe, Spectre hardening on, mode 1r1t, no oops in dmesg.

| Test | Result |
|---|---|
| F1 CS12 with DDC routing on, 30.72 and 61.44 MS/s | regular 786432 sync gaps, 3.9 MB captures; routing reg 0xBC 0 -> 1 -> 0 |
| F4 EN_AGC pad, GPIO 66 forced output-low, 10 s | 0 rising edges; CTRL_IN1..3 all 8 profiles; /waterfall profile +1 per frame (47/47) |
| F2/F18 BIST tone at 0 dB and 6 dB, 61.44 MS/s, DDC on, 20 captures each (61.44 M samples each) | 0 q/i lag/lead, 0 dropouts, 0 other |
| F5 DC bias, BIST 6/12/18 dB | mean I/Q <= 0.0002 LSB |
| CS12 layout (cs12layout.py, 4 periods) | runs 2 and 3: gaps 786432 only, counter +1, phase step 9.0 (replace). Run 1 and the 10-period run lost data in the capture tool (iio_readdev limit, counter steps of 2), tone periods that arrived are exact (amp 1024, residual 0.0007) |
| F15 routing race (routingrace.sh, image maia-httpd, 1000 toggles, extra poller) | 0 wrong, 0 non-200 |
