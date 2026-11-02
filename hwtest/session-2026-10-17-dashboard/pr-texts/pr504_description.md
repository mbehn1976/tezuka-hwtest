## What

Reserve two regions of RAM and bind them to the maia-sdr drivers, for the Pluto and the Pluto+ (maia-iio builds), in both the u-boot and the kernel copy of the device tree (4 files):

| Region | Address | Size | Node |
|---|---|---|---|
| raw complex FFT capture | `0x1a100000` | 1 MiB | `maia-sdr-raw-capture`, `maia-sdr,recording` |
| I/Q waterfall | `0x1a200000` | 128 KiB (16 KiB per buffer: 4096 bins of 4 bytes) | `maia-sdr-iq-waterfall`, `maia-sdr,rxbuffer` |

Same style as the existing magnitude waterfall nodes. Addresses and sizes match the defaults of maia-hdl `MaiaSDRConfig` (`raw_capture_address_range`, `iq_waterfall_address_range`).

## Why

maia-sdr PR 12 (https://github.com/F5OEO/maia-sdr/pull/12) adds an optional raw complex capture and a continuous I/Q waterfall channel, with new maia-httpd endpoints (`/api/raw-capture`, `/raw-capture`, `/iq-waterfall`). They read these buffers through the two drivers. The Complex I/Q page of #500 needs the I/Q channel.

## Effect

Harmless with a bitstream that does not have the two DMA masters: the regions are only reserved (about 1.1 MiB of RAM, `no-map`). Nothing else changes.

## Checked

- All four files compile with `dtc` (kernel and u-boot copy, Pluto and Pluto+); the new nodes are in the resulting blobs.
- On hardware: the same nodes, with a bitstream that has the two DMA masters and maia-httpd from maia-sdr PR 12, are in images that run on an original Pluto and a Pluto+, where the raw capture and the I/Q waterfall work (tests in maia-sdr PR 12, `maia-hdl/hwtest`). Those images also contain other changes; this PR is only the device-tree part.

## Not included

- The bitstreams and the maia-httpd / maia-wasm pin: they depend on maia-sdr PR 12 being merged and on how the bitstreams should be delivered (your rebuild from maia-sdr, or an xsa in tezuka_fw). I asked in the PR 12 comments and will open that part once you have decided.
- Other boards: only the Pluto and Pluto+ maia-iio builds have the two DMA masters wired.

Based on current main (a304a1f), one commit.
