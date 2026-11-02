# Cabled RF sweep with the Pluto+ on the all12 image, 2026-10-13

Same method and settings as n3-rfsweep-summary.md (2026-10-12): 22 LOs 46.9-5990 MHz, TX tone at LO + 960 kHz, TX attenuation 10 dB,
RX manual gain 30 dB, 30.72 MS/s, 40 dB attenuator per direction (forward also has the DC block), cabling unchanged since 2026-10-12.
Pluto = original Pluto (allfixes QSPI image), Pluto+ = known_good/sdimg-v0.3.23-all12 (bitstream from the 12-board build).
Raw: all12-fwd-rfsweep.json, all12-rev-rfsweep.json.

| Check | Result vs the 2026-10-12 baseline |
|---|---|
| PLL lock (TX and RX, all 22 LOs, both directions) | all locked (the baseline had 3 read glitches of the shared debugfs address) |
| Forward tone level (Pluto TX -> Pluto+ RX) | +0.1 dB at nearly every LO, max +0.3 dB (5000 MHz) |
| Reverse tone level (Pluto+ TX -> Pluto RX) | +0.4 to +0.8 dB at every LO |
| SNR in 1 MHz | within +0.9 dB everywhere (rev, low LOs), usually +0.1 |
| Image (dBc) | -20 to -81 dBc as before; point-to-point scatter of a few dB, no trend |
| Offset (kHz) | forward and reverse still equal and opposite; 2.4 GHz: -47.5 / +47.6 (baseline -49.7 / +49.7), i.e. 19.8 ppm instead of 20.7 ppm |

The small level rise in reverse and the 1 ppm change of the board reference difference affect both boards and both directions
equally (a thermal or crystal drift between two days), so they are not caused by the bitstream. The DDC and CS12 changes are not in the RF path
of this test (DDC routing off, CS16 capture), so this is a regression check of the RF chain and the tuning range on the new Pluto+ image: no regression.
