# N3: RF level across the extended tuning range (2026-10-12)

Cabled link, 40 dB attenuator per direction (forward also has a DC block). TX: cyclic DMA tone at LO + 960 kHz, TX attenuation 10 dB;
RX: same LO, manual gain 30 dB, 30.72 MS/s, 262144-sample capture, Blackman-Harris window. Levels include cables and attenuators,
so they show the relative response of each path, not dBm. Tool: hwtest/rfsweep.py. Raw: n3-fwd/n3-rev-rfsweep.json.

Lock: all PLLs locked. The three lock=0 entries in the JSON are read glitches of the shared debugfs address (api_controller.sh polls
the same file); repeated reads at those settings show lock, and 2.5 % of reads glitch even at 2.45 GHz.

| LO MHz | fwd tone dBFS | fwd image dBc | fwd SNR dB/MHz | rev tone dBFS | rev image dBc | rev SNR dB/MHz | offset kHz fwd/rev |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 46.9 | -31.1 | -59.4 | 37.2 | -68.4 | -27.5 | -1.8 | -0.9/1.1 |
| 50 | -30.4 | -60.7 | 37.7 | -67.5 | -20.6 | -0.3 | -1.1/1.1 |
| 60 | -28.7 | -65.8 | 39.6 | -64.6 | -31.9 | 2.6 | -1.3/1.3 |
| 70 | -27.3 | -64.7 | 41.0 | -63.1 | -21.4 | 5.1 | -1.5/1.5 |
| 100 | -24.6 | -68.2 | 44.2 | -58.3 | -24.2 | 10.6 | -2.1/2.1 |
| 150 | -22.2 | -72.8 | 47.0 | -52.7 | -28.4 | 16.2 | -3.2/3.2 |
| 200 | -21.0 | -72.0 | 48.4 | -49.0 | -34.2 | 20.1 | -4.1/4.2 |
| 300 | -19.6 | -74.4 | 50.2 | -45.6 | -42.5 | 23.6 | -6.2/6.2 |
| 325 | -19.3 | -81.0 | 50.4 | -45.1 | -47.2 | 24.4 | -6.8/6.8 |
| 433 | -18.3 | -77.8 | 51.5 | -43.6 | -56.9 | 25.9 | -9.0/9.0 |
| 700 | -17.3 | -75.6 | 52.2 | -42.5 | -45.1 | 27.0 | -14.5/14.5 |
| 1000 | -18.2 | -79.4 | 51.4 | -40.2 | -56.5 | 29.4 | -20.7/20.7 |
| 1500 | -22.0 | -76.4 | 53.0 | -31.4 | -65.9 | 44.9 | -31.1/31.1 |
| 2400 | -23.5 | -74.0 | 51.4 | -34.4 | -65.0 | 42.1 | -49.7/49.7 |
| 3000 | -26.3 | -68.2 | 48.2 | -28.8 | -70.0 | 46.1 | -62.1/62.1 |
| 3800 | -26.6 | -75.2 | 48.1 | -36.4 | -62.0 | 39.8 | -78.8/78.8 |
| 4200 | -21.1 | -77.8 | 49.7 | -32.8 | -66.7 | 40.8 | -87.1/87.1 |
| 4600 | -23.7 | -74.6 | 47.5 | -31.3 | -63.3 | 41.7 | -95.4/95.4 |
| 5000 | -27.3 | -67.1 | 44.6 | -31.9 | -68.8 | 40.9 | -103.7/103.6 |
| 5400 | -26.9 | -71.4 | 44.4 | -31.6 | -69.1 | 40.8 | -112.0/111.9 |
| 5800 | -28.3 | -69.6 | 43.0 | -32.6 | -70.3 | 39.9 | -120.4/120.2 |
| 5990 | -29.1 | -69.1 | 42.4 | -29.8 | -68.3 | 41.9 | -124.3/124.2 |

Forward = Pluto TX -> Pluto+ RX, reverse = Pluto+ TX -> Pluto RX. The offsets are equal and opposite and scale with frequency
(20.7 ppm reference difference between the boards), which also settles the open forward-offset question from 2026-10-04.
