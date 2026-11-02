# CS12 capture loss at 61.44 MS/s (184 MB/s), 2026-10-13

Pluto+ (all12 image, 192.168.3.1) and original Pluto (allfixes image, 192.168.2.1), AD9363 set to 61.44 MS/s for the run and restored
to 30.72 MS/s afterwards. Probe: hwtest/cs12loss.py (iio_readdev on the board, output to /tmp tmpfs, 183 MB free); lossless = every sync
gap 786432 bytes and counter +1. iiocap: zero-copy libiio, 1 MiB blocks x 8, 400 MB.

| Reader | Pluto+ | original Pluto |
|---|---|---|
| iio_readdev -b 65536 (128 KiB), 4 periods | 0/20 lossless | 0/20 |
| -b 262144 (512 KiB), 4 periods | 10/20 | 9/20 |
| -b 1048576 (2 MiB), 4 periods (3.1 MB) | 20/20 | 20/20 |
| -b 2097152 (4 MiB), 4 periods | 20/20 | 20/20 |
| -b 1048576, 40 periods (32 MB) | 2/10 (a second run: 3/8) | 2/10 |
| -b 2097152, 40 periods (32 MB) | 4/10 | 4/10 |
| iiocap predict (DMA blocks in place, reads only the expected sync position), 400 MB | 184.3 MB/s, 508 regular syncs, 0 jumps, 0 frames missing | identical |
| iiocap scan (reader touches every byte), 400 MB | 157.5 MB/s, 75 jumps, 84 frames missing | 153.9 MB/s, 71 jumps, 95 missing |

Reading: the DMA path and the gateware do not lose data at 61.44 MS/s (400 MB, 0 missing). A reader that copies or scans every byte cannot
sustain 184 MB/s on the Zynq for long: short captures (3 MB) are fine with a buffer of 1 MiB or more; 32 MB captures through a file lose
periods in most runs, and a scanning zero-copy reader falls behind (about 155 MB/s). The 128 KiB buffer fails at once.
