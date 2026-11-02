# Can the Zynq CPU consume the 61.44 MS/s CS12 stream (184 MB/s)? 2026-10-13

Tool: hwtest/membench.c (cacheable memory, 64 MiB cold pool, 1 MiB blocks, 3 s per test, one thread) and hwtest/iiocap.c, on both boards
(2 x ARMv7 Cortex-A9, 366 MB RAM), AD9363 at 61.44 MS/s so the DMA streams 184 MB/s into DDR in the "while DMA" rows.
(A first membench run was invalid: the compiler removed the unused copies and scans, giving impossible numbers; fixed with a volatile sink
and rerun. Only the tmpfs rows of that first run are real, and they differ by up to 70 MB/s from the second run: run-to-run variance is large.)

| MB/s (one thread, bytes through the block once) | Pluto+ idle | Pluto+ DMA streaming | Pluto idle | Pluto DMA streaming |
|---|---|---|---|---|
| memcpy 1 MiB -> private buffer | 227 | 192 | 207 | 159 |
| memchr scan (random data) | 203 | 212 | 222 | 233 |
| memcpy + scan | 117 | 91 | 99 | 85 |
| write() to tmpfs (/tmp) | 244 | 243 | 237 | 204 |

First run (invalid for the first three rows) of the tmpfs write: 214 idle and 172 with DMA on the Pluto+, 211 and 168 on the Pluto.

iiocap on the real DMA buffers at 61.44 MS/s, 400 MB, with both-core load from /proc/stat:

| iiocap mode | Pluto+ | Pluto |
|---|---|---|
| none (refill only) | 184.3 MB/s, 0 missing, 51 % busy | 184.3, 0 missing, 67 % |
| predict (reads only the expected sync) | 184.4, 0 missing, 63 % | 184.3, 0 missing, 49 % |
| copy (memcpy + scan) | 85.6 MB/s, 540 frames missing, 97 % | 77.6, 683 missing, 97 % |
| scan | 125.5 MB/s, 235 missing, 96 % | 141.6, 152 missing, 94 % |

Reading: one core copies about 160-230 MB/s and scans about 200-230 MB/s, so either step alone has at most 10-30 % headroom over 184 MB/s,
and often none while the DMA competes for DDR (memcpy 159 and 192 MB/s). Copy plus scan, which is what iio_readdev -> /tmp or a
decoder does, reaches only 85-117 MB/s, so it cannot keep up. Writing to tmpfs (204-244 MB/s) leaves little margin, so a 32 MB capture
stalls now and then (losses mid-capture). On the real DMA buffers both cores are 94-97 % busy at 78-142 MB/s. The claim is supported;
"cannot copy or scan 184 MB/s" is true for copy+scan and marginal for either step alone.
