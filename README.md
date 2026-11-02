# tezuka-hwtest

Test data, scripts and logs of the hardware qualification work on the Tezuka
firmware (tezuka_fw) for the ADALM-Pluto and the Pluto+, as run on one board
pair between 2026-10 and 2026-11. The firmware side of the same work is the
branch dev/next of https://github.com/mbehn1976/tezuka_fw; its documents
(doc/UPGRADE_REALTIME_7.3.md and the others under doc/) refer to logs by the
paths used here, hwtest/session-.../logs/..., so a path in a document resolves
in this repository.

Contents:

- hwtest/session-2026-10-25-rt: the PREEMPT_RT work, 6.12.114-rt21 and Linux
  7.3 on the Pluto+ (latency, streams, SPI timeouts, the gadget boot fault,
  QSPI writes, NCM). Each logs/ folder has a SUMMARY.txt.
- hwtest/session-2026-10-17-dashboard: the dashboard and complex I/Q tests.
- hwtest/results: RF captures and comparisons of the v0.3.23 review fixes.
- hwtest/*.py, *.c, *.sh: the probes and tools (tone tests, DC bias, SD card
  writer, kernel module race test, QSPI test, cyclictest runner, ...).

The SD card images and flash files that the logs refer to are published as
releases of the tezuka_fw fork (for example rt-2026-11-02 for the final 7.3
and 6.12 RT images of the Pluto+). The folder hwtest/known_good that the
scripts use for them is not part of this repository.

The history of this repository is one commit: the files were copied out of a
private lab repository on 2026-11-02.
