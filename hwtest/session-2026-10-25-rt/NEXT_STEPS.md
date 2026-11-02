
## 15. Next steps (as of 2026-10-25, in recommended order)

1. **Decide the track.** (a) Network buffer losses, (b) RT latency tail and core isolation, (c) Linux 7.3. They are independent; (a) affects every user of the firmware, (b)/(c) only the RT goal.
2. **(a) Network buffer losses** (whole 262144-sample buffers lost over Ethernet at 5 to 10 MS/s and over USB at 5 MS/s, all firmware, on-board path clean).
   - Find out how many kernel blocks iiod and the client use. Client side: libiio 0.x has `iio_device_set_kernel_buffers_count()`, libiio 1.0 takes the block count in `iio_buffer_create_stream()`; the stock tools may not expose it, so use a small
     C or pylibiio test with 4, 8, 16 blocks at 10 MS/s (30 runs each, `outlier_transports.py` pattern in `session-2026-10-25-rt/scripts`). Check iiod's own setting (`iiod --help` on the board; the start line is in `S23udc:176`).
   - Try bigger socket buffers (`net.core.rmem_max`/`wmem_max`, `net.ipv4.tcp_rmem` on host and board), the GEM ring size (`ethtool -g eth0` on the board), host NIC offloads and CPU governor, and a direct cable/other host to rule out the laptop.
   - Separate stalls: log timestamps of each `iio_readdev` buffer to see whether a loss follows a long read gap.
   - USB is far worse (about 100 outliers per 30 runs at 5 MS/s); check it separately (USB 2.0 throughput, CDC-NCM vs RNDIS on the host side).
   - Gate: 0 outliers in 100 runs at 10 MS/s with the chosen setting, tone check at the end.
3. **(b) RT latency tail.** Boot `known_good/sdimg-rt21-trace`; copy `session-2026-10-25-rt/scripts/trace_board.sh` to the board and change `-a1` to `-a0`. Run `sh /tmp/trace_board.sh preemptoff 30` and `irqsoff` during 10 MS/s Ethernet streaming; for `wakeup_rt` the traced task is the highest-priority RT task, which is iiod (RR 99),
   so either stop streaming or run `cyclictest` at SCHED_FIFO 99 and look at its wakeups. Goal: find the code behind the 100 to 250 us worst case on core 0 (idle max 65 to 103 us, target 50 us).
4. **(b) Stage 4: core isolation.** Decide where iiod and the DSP threads live (iiod is pinned to core 1 at RR 99 in `S23udc:176`). Try `isolcpus=1 nohz_full=1 rcu_nocbs=1` on the SD variants in `uboot-env.txt`, `S99realtime` (draft in section 5), IRQ affinity (read the DMA IRQ names from `/proc/interrupts` first).
   Re-measure idle and streaming latency with `cyclictest` on the isolated core; keep the web UI responsive (maia-httpd and mosquitto stay on core 0).
5. **Open check on the RT image.** The CW-check FAIL (Pluto RX, Pluto+ TX, 2.5 MS/s, 205 kHz): run 30 repeats each on RT and non-RT to see whether the 1-in-6 rate on RT is real (non-RT 0 of 6 so far). Also the full suite once more after any RT config change.
6. **Not done yet on RT:** the original Pluto (needs an RT image for it; the user flashes and ejects), the USB gadget (mass storage, network) under RT, an overnight soak, the DAC tone fix under streaming load.
7. **(c) Linux 7.3.** Wait for the final 7.3 tag (newest was v7.3-rc7). Only then start stage 3 of section 3: branch from the tag in `mbehn1976/linux`, forward-port the ADI drivers and our six patches (ADI has no 7.x Zynq tree), fix compile errors per file, `make dtbs_check` on `zynq-plutoplus.dts`. Worth it only if RT on 6.12 proves insufficient or the user wants the newer kernel.
8. **Housekeeping and decisions.** Nothing here is pushed. Before any push: where the RT kernel branch lives (fork `mbehn1976/linux`, or an F5OEO repo), whether `configs/plutoplus_rt_defconfig` stays a local-tarball config or gets a hosted pin. The earlier upstream items (F5OEO PR, ADI issue, kernel hosting) are in `HANDOVER.md` section 6 and
   the memory file `project_upgrade_summary.md`. Also correct the old "10 MS/s Ethernet is drop-free" statements wherever they were made public (none were posted upstream so far).

## Update 2026-10-28 (end of day)
State: dev/next local commits 453f975, eff4ba6, ad3a1a2, c6e51cb (zynqrx 32 blocks), 2aab25a (doc 14h-14j); clean, nothing pushed. Pluto+ SD = sdimg-rt21, Pluto = non-RT g32c3.
Block count result: 4 blocks lose whole buffers over Ethernet (12 of 100 runs at 10 MS/s), 16/32 blocks 0 of 100; with 32 blocks clean up to 12.5 MS/s, above that the ~50 MB/s link limit.
Replaces step 2 above; remaining next steps in order:
 1. Block-count follow-ups: iio_ws_proxy TX (4 blocks) over a network context; zynqrx over a network context (only local smoke-tested); libiio 0.26 client with iio_device_set_kernel_buffers_count; non-RT kernel with 16/32 blocks; USB at 5 MS/s with more blocks; whether iiod can enforce a minimum block count.
 2. Steps 3 to 8 above unchanged (RT tail trace, core isolation, CW-check repeats, original Pluto/USB gadget/overnight soak, Linux 7.3 after final tag, push decisions).

## Update 2026-10-28 (RT tail trace, core 0, idle, image sdimg-rt21-trace, cyclictest -p90 -a0)
- Board rebooted once during `trace_board.sh preemptoff 30` with function tracing on and cyclictest -p98 -a0 (cause unproven; 10 s irqsoff with function tracing at -p90 survived). sd_write.sh needed MUX=/dev/sg1 (udev symlink /dev/usb-sd-mux/... was missing; scratchpad copy, repo script unchanged).
- With function tracing ON the irqsoff max (464 us) is tracer overhead (one timer tick path, 221 events at about 2 us each): no information. Use `options/function-trace = 0` (script trace_nf.sh in this folder's scripts/ dir).
- With function tracing OFF, 30 s each: irqsoff max 61 us (__schedule -> finish_task_switch, switch from cyclictest to a new `sh` in mprotect), preemptoff max 86 us (schedule -> schedule, mosquitto -> cyclictest). cyclictest max 199 / 138 us. Traces: traces/trace_core0_*.txt.
- Reading: the worst windows are inside the context switch itself on the A9 (61 to 86 us), not in a driver. Not yet known why a switch costs that much (cold caches, switch_mm/ASID, outer cache?). Not tested under 10 MS/s streaming load.

## Update 2026-10-28 (traces during 10 MS/s Ethernet streaming, RT image sdimg-rt21-trace, libiio 1.0 client, 32 blocks)
- Without a tracer, cyclictest -a0 under the stream: p98 max 261/317 us, p90 max 436/210 us, 0 lost cycles (4 x 15 s).
- irqsoff tracer (function tracing off) under the stream: irqsoff max 78 us but cyclictest saw 41 ms stalls and lost about 8000 of 120000 cycles => the irqsoff tracer perturbs the system under this load; do not trust cyclictest numbers taken with it enabled. (Idle: no such stalls.)
- wakeup_rt (function tracing off, cyclictest -p99) under the stream, 30 s: cyclictest max 682 us; the traced worst wakeup was an iiod thread: net_client_thd (SCHED_RR 99, core 1) woken by irq/31-eth (core 0) waited 67442 us; the task running on core 1 meanwhile was a SCHED_OTHER task (pid 9150, prio 120), switched out through preempt_schedule_irq/do_work_pending. Marker "started at __slab_free". Trace: traces/trace_core0_wakeup_rt_nf_stream_30s.txt. ONE sample, cause unproven (a preempt-disabled section on core 1 of that length is what the trace suggests; sched_rr_timeslice_ms=100 does not explain it because the runner was prio 120, not RR 99).
- Not yet done: repeat wakeup_rt 3 to 5 times to see if the ~67 ms recurs; wakeup_rt with function tracing on to see the path; identify pid 9150. Relevance: iiod net threads delayed by tens of ms could cost stream buffers with a shallow queue (see block count findings).
- AD9361 SPI wedge: in the boot after the watchdog reset, with traces killed by timeout, `SPI transfer timed out`/`Calibration TIMEOUT` appeared at the first rate write and reads returned junk; a reboot cleared it, 0 SPI errors in the following runs. Trigger unknown (possibly the killed preemptoff trace under streaming); watch dmesg for `SPI transfer timed out` in later RT tests.

## Update 2026-10-28 (wakeup_rt x5 under 10 MS/s streaming, function tracing off, cyclictest -p99 -a0)
Worst traced wakeup per run (core 1), traces/trace_wakeup_rt_stream_run1..5.txt: 81.0 ms (ktimers/1, rt_prio 1, delayed behind iiod buffer thread), 51.2 ms (net_client_thd behind writer-task), 60.9 ms (writer-task behind a buffer-* thread), 81.1 ms (net_client_thd behind writer-t), 66.9 ms (net_client_thd behind writer-t). cyclictest on core 0 in the same runs: max 786, 658, 994, 772, 1739 us (tracer on). 0 SPI errors, no reboot.
Reading: it recurs 5 of 5. The waits are all on core 1, where every iiod thread runs SCHED_RR 99 (S23udc:176): a woken iiod thread waits behind another busy RR-99 iiod thread (sched_rr_timeslice_ms = 100), and kernel RT threads such as ktimers/1 (rt_prio 1) wait behind iiod for the same reason. The earlier single sample with a prio-120 runner was not reproduced.
Hypothesis (not tested): the 51 to 81 ms waits are the same order as the queue depth of 4 blocks (4 x 262144 samples = 105 ms at 10 MS/s), which would explain the whole-buffer losses with 4 blocks. Test: set iiod threads to a lower RT priority (below irq threads, e.g. FIFO 40) or a different layout, re-run the 100-run 4-block loss test and wakeup_rt. Runtime `chrt` on the test board is reversible; changing S23udc is a firmware change.

## Update 2026-10-28 (iiod priority test: runtime chrt to FIFO 40 on all iiod threads, Pluto+ rt21-trace, 10 MS/s stream, wakeup_rt x3)
Hypothesis NOT supported: with iiod at FIFO 40 (new threads inherited it) cyclictest -p99 -a0 on core 0 got WORSE: max 19.1, 50.9, 19.5 ms (avg about 100 us vs 48 us at RR 99), about 1000 cycles lost per run; the worst traced wakeups were on core 0: irq/31-eth (rt 50) 25.8 ms and 20.4 ms, cyclictest 49.6 ms. Same stream, tracer config as the RR-99 runs (max 658 to 1739 us). 0 SPI errors, no reboot. Traces: traces/trace_wakeup_rt_stream_fifo40_run1..3.txt. Priorities restored to RR 99 at runtime afterwards. Cause of the core-0 stalls with iiod at 40 unknown (idea: priority inversion through a lock between the eth irq thread on core 0 and an iiod thread on core 1; not examined). The 4-block loss test was not run in this configuration.

## Update 2026-10-28 (4-block loss test with wakeup_rt on the board, 10 MS/s Ethernet, RR 99, 60 rounds; scripts/outlier_wk.py + wk_board.sh, logs/outlier_wk_nb4.log)
- 32 of 60 rounds lost a buffer (107 outliers, all on 262144-sample boundaries) vs 12 of 100 without the board-side tracer/cyclictest => the tracer plus cyclictest -p99 raises the loss rate; the test is perturbed.
- Worst wake delay on the board per round (wakeup_rt, whole 6 s window): lossy rounds min 25.5 / median 44.2 / max 72.7 ms; clean rounds min 26.2 / median 38.8 / max 110.7 ms. A clean round had the longest wait, so the max wake delay does NOT separate lossy from clean rounds. Hypothesis (iiod RR-99 waits cause the 4-block losses) not supported by this test, not refuted either: the max over a window is a poor proxy (one number per round, includes connect phase, tracer perturbation).
- Block count (32 blocks, 0 losses in 100 runs) remains the working fix. Open: whether lower-level evidence (per-buffer timestamps on the client, iiod-side timing) shows what delays a buffer.

## Update 2026-10-28 (per-buffer client timestamps, 4 blocks, 10 MS/s Ethernet, RR 99, no board tracer, 60 rounds; scripts/outlier_ts.py + iio_rwdev_ts.c, logs/ts_nb4/)
- 4 of 60 rounds lost a buffer (5 outliers, all on 262144 boundaries): same order as the 12/100 baseline, so this test does not perturb the system. 11400 block gaps: median 26.2 ms (= 262144 samples at 10 MS/s), p99 32.9, p99.9 52.4, max 71.0 ms; only 8 gaps above 60 ms (all 68.7 to 71.0 ms).
- The gaps right before/after the lost block are normal (23 to 27 ms). But every loss comes 4 blocks AFTER a long gap of about 70 ms: round 7 gap at block 144 -> lost 148; round 26 gap at 50 -> lost 54; round 30 gap at 91 -> lost 95 and 96; round 51 gap at 145 -> lost 149. 4 of 4 losses follow a 69-71 ms gap by 4 blocks (= the queue depth); of the 8 gaps at 69-71 ms, 4 were followed by a loss (the others at blocks 52, 184, 162, 178; the last three too close to the end or not lost), and none of the many 46-54 ms gaps was.
- The client waits in iio_stream_get_next_block for the full gap (wait = gap), so the stall is upstream of the client (iiod/kernel on the board, or the link), not in the client.
- Reading (observation, not proof): a stall of about 70 ms (2.7 blocks of data) is what costs the buffer when the queue holds 4 blocks; with 16 or 32 blocks it is absorbed. This fits the earlier 51 to 81 ms iiod wake delays, but the link between them is not shown: the board-side tracer test did not separate lossy from clean rounds.
- Open: what stalls for about 70 ms (board iiod threads vs network). A timestamp on the board side (iiod, or a small reader on local:) next to the client timestamps would tell whether the stall is already on the board.

## Update 2026-10-28 (board-side timestamps: scripts/tsrd.c + tsb.sh, logs/ts_board/; 4 blocks x 262144 samples, 10 MS/s, 60 rounds x 5 s per phase, RT image, iiod RR 99)
Gap between blocks (ms), 11400 gaps per case:
- A. reader on the board, local:, nothing else running: median 26.2, p99 29.2, p99.9 34.6, max 37.4; gaps >45 ms: 0.
- B. same reader on the board, local:, while the board sends zeros to the host with nc (about 40 MB/s intended, rate not measured): p99 33.1, p99.9 49.4, max 64.4; >45 ms: 29, >60 ms: 2.
- C. network client on the host (earlier run, ts_nb4): p99 32.9, p99.9 52.4, max 71.0; >45 ms: 39, >60 ms: 8.
Reading: with no network traffic the board never stalls the DMA stream by more than 37 ms; adding Ethernet transmit load on the same board produces the 45 to 64 ms gaps, close to what the network client sees (C). So the stall originates on the board when the network path is busy (NIC irq/softirq threads, TCP transmit, CPU contention), not in the DMA/kernel stream path itself, and not (only) in the host or the wire. Caveats: the nc load also costs CPU in a user process, and its real rate was not measured, so "NIC" vs "CPU contention" is not separated; B stays below the 69-71 ms of C (no iiod threads in B). Next: which core and thread the stall is on (eth irq thread priority 50 on core 0, iiod on core 1, ksoftirqd), e.g. IRQ affinity for eth and the DMA irq, or the stage 4 core isolation test.

## Update 2026-10-28 (IRQ affinity / housekeeping test; scripts/irq_cfg.sh + outlier_ts.py, logs/irq_affinity/; network client, 4 blocks, 10 MS/s, 60 rounds per case, RT image, iiod RR 99)
Findings from /proc/interrupts: all device IRQs sit on CPU0 (smp_affinity 3, in practice CPU0). The QSPI controller (irq 30, e000d000) fires about 1650 to 2400 times per second at idle because the stock /root/api_controller.sh calls fw_printenv (reads the U-Boot env flash) over and over and spawns processes (load average 3 to 4 at idle).
Results (gaps between blocks on the host, 11400 per case):
- baseline (earlier run): 4/60 rounds lost a buffer; >45 ms gaps 39, >60 ms 8, max 71.0 ms.
- Ethernet IRQ moved to CPU1 (same core as iiod, RR 99): WORSE, 39/60 rounds lost (113 outliers); >45 ms 59, >60 ms 26, max 89.3 ms.
- api_controller.sh paused with SIGSTOP (QSPI irq 0 per s, everything else unchanged): 0/60 rounds lost; >45 ms 33, >60 ms 1, max 66.8 ms.
Reading: the QSPI polling by api_controller.sh is a plausible main contributor to the ~70 ms stalls and the 4-block losses (0/60 vs 4/60 baseline and 12/100 earlier), but one 60-round run per case is thin (at a 7 to 12% loss rate 0/60 happens by chance about 1 to 2% of the time) and 33 gaps >45 ms remain, so it is not the only source. Moving the Ethernet IRQ onto iiod's core is clearly bad. Board restored afterwards (eth affinity 3, api_controller continued).
Next: repeat the paused case (and a baseline) at least once; find which part of api_controller.sh is responsible (fw_printenv calls in a loop?); a firmware fix would be to read the env once or less often (that script is tezuka_fw's, upstream-relevant, ask before any push). Check the same for other housekeeping (classifier, mqtt_pubd).

## Update 2026-10-28 (repeat of the api_controller test; scripts/rep.sh, logs/irq_affinity/; same method, 60 rounds per case)
- api_controller paused again (QSPI irq 0 per s confirmed): 4/60 rounds lost a buffer; gaps >45 ms 39, >60 ms 9, max 71.4 ms.
- api_controller running (baseline repeat): 4/60 lost; >45 ms 39, >60 ms 7, max 70.8 ms.
- Totals: paused 4/120 (0/60 and 4/60), running 8/120 (4/60 and 4/60). The first 0/60 was chance; the claim "api_controller QSPI polling is a main contributor" is NOT supported and is retracted. Gap statistics are identical with and without it. (The Ethernet IRQ on core 1 result, 39/60, stands: clearly worse.)
- Still unexplained: the ~70 ms stalls on the board when the Ethernet path is busy (see the board-side timestamp section). Housekeeping is not the cause; the open candidates are the network transmit path itself (NIC/softirq/TCP) and iiod's threads.
- Note for rep.sh style tests: `pgrep -f` over ssh matches the ssh shell itself and stops it; use the `[a]` pattern trick.

## Update 2026-10-29 (stage 4a: isolcpus=1 irqaffinity=0 on the clean RT image; no kernel rebuild)
Image: known_good/sdimg-rt21-iso = sdimg-rt21 with `isolcpus=1 irqaffinity=0` added to the sdboot_ram bootargs line of uEnv.txt (only that line differs; checked with diff/cmp). Written to the Pluto+ SD with the sg1 copy of sd_write.sh, /boot checksums matched, /sys/devices/system/cpu/isolated = 1. Kernel still has NO_HZ off and no RCU_NOCB (rebuild needed for nohz_full/rcu_nocbs; not done).
Setup: all iiod threads moved to core 0 at runtime (`taskset -p 1` per tid; new connection threads inherit it; the stock S23udc start line pins iiod to core 1, so this is a runtime change, not in the firmware); cyclictest -t1 -p99 -i250 -a1.
- core 1 isolated, idle, 120 s: min 10, avg 15, MAX 44 us (480000 cycles).
- core 1 isolated, 10 MS/s Ethernet stream (libiio 1.0, 32 blocks, iiod on core 0), 300 s: min 10, avg 15, MAX 46 us (1200000 cycles). 0 SPI errors, no reboot.
- core 0 reference, idle, 120 s: avg 23, max 50 us.
=> The 50 us target is met on the isolated core for idle and under the 10 MS/s stream (for 5 minutes). Before isolation: idle max 65-103 us, 100-250 us (up to 1-2 ms with tracer) under streaming on core 0.
Not yet shown: stress-ng load on core 0 at the same time; data integrity of the stream (client output went to /dev/null, no phase/loss check); longer soak (hours); where the real-time work (DSP thread, maia-httpd, the DMA irq handling) lives; max 46 is close to the limit, so margin is thin; a firmware change (S23udc affinity, boot args in the sd uEnv.txt) would have to be made and tested, and asked before any push.

## Update 2026-10-29 (stage 4a load test: isolcpus=1, iiod on core 0, stress-ng on core 0 + 10 MS/s stream; scripts/iso2.sh, logs/iso2.log, logs/outlier_ts_iso_load.log)
Setup: `taskset -c 0 stress-ng --cpu 1 --vm 1 --vm-bytes 32M --timeout 1020s` on core 0; cyclictest -t1 -p99 -i250 -a1 -D 1000s on core 1; at the same time outlier_ts.py (libiio 1.0 client, 32 blocks, 10 MS/s, 5 s rounds with the tone phase check).
- cyclictest on isolated core 1 for 1000 s: min 10, avg 14, MAX 53 us (4000000 cycles). Just above the 50 us target (idle and stream-only runs before: 44 and 46 us). 0 SPI errors, no reboot.
- The stream test is NOT valid in this configuration: from round 1 the median gap between blocks was 52.5 ms (expected 26.2 ms at 10 MS/s) with gaps up to 177 ms, i.e. the stream delivered about half the rate; the tone check then reported 59 to 75 phase steps per round, spread over many blocks (not on buffer boundaries only). The script crashed at round 28 (empty timestamp file, the client produced no data), so no SUMMARY. So with stress-ng cpu+vm on core 0 the board cannot sustain a 10 MS/s Ethernet stream; whether that is memory bandwidth (vm stressor, 32 MB) or core 0 being saturated (cpu stressor, iiod and the eth threads on the same core) is not separated yet.
Next: repeat with `--cpu 1` only and with `--vm 1` only (each for a few minutes with the stream) to see which one hurts throughput and latency; decide whether iiod should live on the housekeeping core at all (the 10 MS/s stream needs about half a core for iiod plus the eth softirqs on core 0).

## Update 2026-10-29 (RX stream wedged after the heavy load test)
After the stress-ng cpu+vm (core 0) + 10 MS/s stream run (iso2): the next stream attempt failed at once: libiio client `Unable to dequeue block: Connection timed out (110)`, also with a purely local reader on the board (`iio_readdev -u local:`). AD9361 state looked normal (ensm fdd, 10 MS/s, adc_clk 80 MHz, no SPI errors, no dmesg lines), the RX DMA irq (7c400000.dma, irq 27) moved only about 4 per 6 s read instead of about 150 per s; re-writing the sampling frequency did not revive it; an SSH `reboot` did (local read ok afterwards, 10 irqs for 131072 samples). The earlier iso2 stream was already degraded (half the data rate, many phase steps) before round 28 produced no data at all, so the wedge came during the loaded test. Cause unknown (candidates: DDR bandwidth starvation of the DMA by the vm stressor, a DMA/FIFO overflow state in the PL, iiod on core 0 competing with the stressor). Not reproduced on purpose yet; the CPU-only and memory-only tests are meant to tell which stressor does it. Possibly the same family as the unexplained stop at an earlier first boot (not proven).

## Update 2026-10-29: CPU-only and memory-only stressors on core 0 (isolcpus=1, iiod pinned to core 0, 32 blocks, 10 MS/s Ethernet)
- cpu (stress-ng --cpu 1, core 0): cyclictest core 1 max 47 us (avg 14) over 330 s. Stream: 20/20 complete, but EVERY round has 45-65 lost-block outliers (1133 total), block gap median 42-52 ms (idle ~26 ms), max 144-299 ms.
- vm (stress-ng --vm 1 --vm-bytes 32M, core 0): cyclictest core 1 max 74 us (avg 17). Stream: rounds 1-9 complete with 29-64 outliers each, gap median 39-55 ms; rounds 10-20 INCOMPLETE (client got no full data; ts files of those rounds are stale copies of round 9). Local liveness after the test was OK (0), no reboot needed this time.
- Conclusion: a plain CPU hog on core 0 is enough to break the network stream (not memory bandwidth). Isolating core 1 protects cyclictest (47 us) but not the stream, because iiod and network IRQs share core 0 with the load. Memory stress adds a 74 us tail on the isolated core and a later stream stall.
- Open: iiod/net placement vs priority (the hog is SCHED_OTHER yet still halves throughput), whether the earlier wedge is the same stall as vm rounds 10-20.

## Correction 2026-10-29: the vm rounds 10-20 were probably iiod dying, not a stream wedge
- At the start of the placement test (iso4.sh) `pidof iiod` returned nothing on the Pluto+ (uptime 11 h, no reboot since iso3 started). No oom/segfault/core file and nothing in dmesg or /var/log/messages. The iso3 liveness check used the LOCAL backend (iio_readdev -u local:), which does not need iiod, so it reported OK while network clients could not connect. Cause of the iiod death is unknown; most likely it died during the vm test (rounds 10-20 incomplete). Fixed by ssh reboot.
- The earlier "RX stream wedge" under the combined load may have been the same (iiod dying) - not checked at the time (local reader also failed then, so possibly different).
- iso4.sh liveness now checks `pidof iiod` first.

## Update 2026-10-29: placement test (iso4.sh), CPU hog on core 0, isolcpus=1, 32 blocks, 10 MS/s Ethernet, 20 rounds each
- A (iiod core 1, eth IRQ31 core 0): stream CLEAN, 0 outliers in 20/20 rounds, gap median 26.3 ms (= idle), max 41-124 ms. cyclictest core 1 (shares core with iiod): max 109 us (avg 18).
- B (iiod core 0 with hog, eth IRQ31 core 1): 53-81 outliers per round, gap median 52-65 ms (worse than plain hog). cyclictest max 69 us. Local reader failed after B: RX stream WEDGED again (iiod alive, `Unable to dequeue block: Connection timed out (110)`).
- C (iiod and eth IRQ both core 1): produced no data (wedge from B persisted). INVALID, not run. Board rebooted.
- Findings: iiod must not share a core with the CPU hog; with iiod alone on its core the stream survives. Cost on a dual-core board: iiod shares core 1 with cyclictest (109 us > 50 us target). Wedge reproduced (2nd time) after a long run with hog + iiod on the hog core -> wedge is real and distinct from the iiod death seen after the vm test.

## Update 2026-10-29: shippable placement with real housekeeping load (iso5.sh, ws_load.py)
- Placement: isolcpus=1 irqaffinity=0; iiod (RR 99) pinned to core 1 at runtime; eth IRQ31 + all other services on core 0; cyclictest core 1 at -p98 (below iiod). NOTE: with isolcpus=1 iiod defaults to core 0 (isolated cores are removed from the default mask), so shipping this needs an explicit `taskset -c 1` (S23udc line 176 only applies when chrt branch is used) - firmware change, not made.
- Load: stock board services (api_controller polling, maia-httpd, mosquitto, classifier) + from host 2 /waterfall websockets + /api polling at 5 Hz (load volume on the board not measured separately).
- H_load: stream 20/20 rounds, 0 outliers, gap median 26.2-27.1 ms; cyclictest core 1 max 108 us (avg 18).
- H_load_hog (+ stress-ng --cpu 1 on core 0): stream 20/20, 0 outliers, gap median 26.1-26.7 ms; cyclictest max 112 us (avg 18). No wedge, iiod alive.
- Conclusion: stream is robust with iiod on its own core. Cost: cyclictest on the iiod core is ~110 us max (iiod RR99 on same core), above 50 us. 50 us was only reached with iiod OFF the isolated core (44-47 us), which breaks the stream under load. On a dual-core Zynq 7010 both goals cannot be met together with this software layout.

## Update 2026-10-29: iiod latency tail on core 1 (iso6-iso9, traces in traces/tail_iiod_core1/)
- CORRECTION: on the isolcpus=1 boots iiod was NOT RR 99 / core 1. S23udc picks its start branch with NB_CORE=$(nproc), and nproc reports 1 under isolcpus=1, so the single-core branch ran: iiod SCHED_OTHER, no pin (default mask excludes the isolated core -> core 0). All iso1-iso5 results used SCHED_OTHER iiod (runtime-pinned by my scripts). Firmware fix needed for isolcpus configs (do not use nproc; ask before changing).
- X1/X3: iiod forced to RR 99 on core 1 (all threads): cyclictest p98 on core 1 max 63 ms / 88 ms, avg 120 us -> iiod RR99 starves cyclictest; stream stays clean. Unusable on the isolated core.
- X2: iiod SCHED_OTHER on core 1, stream + ws load: cyclictest max 80 us (140 s), earlier runs 108/112 us (330 s).
- wakeup_rt traces (Y1-Y3, Z1-Z3): cyclictest woken by the timer IRQ while iiod writer-task is in sys_io_submit -> tcp_sendmsg -> tcp_gso_segment -> skb_segment -> kmalloc/___slab_alloc (irqs off 'D' flags); reported 186-194 us but the tracer itself costs ~70 us/wakeup (avg 88 us vs 18 untraced; options/stacktrace=0 does not remove wakeup_rt stack dumps). Not trustworthy for size.
- Event trace (E1: sched/irq/hrtimer events, cyclictest -b 90): even with iiod dead and the core otherwise idle, irq->switch showed 70-90 us (tracer cost). ftrace cannot resolve a ~50 us tail on this A9; do not rely on it.
- Best attribution from untraced numbers: iiod on core 0 -> cyclictest core 1 max 44-47 us; iiod (SCHED_OTHER) on core 1 -> 80-112 us. The extra ~40-60 us is caused by iiod's TCP transmit path (skb alloc/segmentation, slab with irqs off) running on core 1.
- NEW OPEN ISSUE: iiod died AGAIN (second time; first after the vm stressor) during the E1 run (14 of 20 stream rounds incomplete, liveness IIOD_DEAD, uptime 46 min so no reboot). No oom/segv/dmesg trace. Board rebooted. Need a catcher (run iiod under a wrapper logging exit status/signal, core pattern) before trusting long runs.

## Update 2026-10-29: hunting the iiod death (catcher scripts/iiod_wrap.sh, soaks iso10-iso12)
- Checked the board: no script kills/restarts iiod (only S23udc stop; udc_handle_suspend.sh only touches AD9361 ensm_mode). No oom/segv in dmesg either time it died.
- Catcher: iiod restarted in the FOREGROUND under /tmp/iiod_wrap.sh (core dumps on, print-fatal-signals=1, writes rc/uptime/dmesg to /tmp/iiod_exit.log). Not the shipped -D daemon form.
- Runs with the catcher, iiod SCHED_OTHER pinned to core 1, ws waterfall load, cyclictest p98: (1) plain soak 70 rounds: clean, iiod alive. (2) +stress-ng --vm 32M on core 0, 40 rounds: iiod alive; stream NOT clean (30-35 outliers every round: memory stress breaks the stream, a CPU hog does not). (3) event-trace case (tev.sh, 8 tries) 30 rounds: clean, iiod alive.
- RESULT: the death did NOT reproduce in ~140 rounds / ~50 min; cause still unknown (two earlier deaths: after the vm-stress run at board uptime 11 h, and in the first event-trace run at uptime ~35 min). Catcher stays armed on this boot; next long run should check /tmp/iiod_exit.log and /tmp/core.*.

## Update 2026-10-29: long soak with the iiod catcher armed (soak.sh, soak_mon.sh; logs/soak_2026-10-29/)
- Setup: trace-iso kernel (isolcpus=1 irqaffinity=0), iiod foreground under iiod_wrap.sh (core dumps on), SCHED_OTHER pinned to core 1, eth IRQ on core 0, ws waterfall load, cyclictest p98 core 1 in 10 min segments, 10 MS/s Ethernet, 32 blocks, 440 rounds in 5212 s (87 min; the stream finished before the 2 h limit).
- Result: iiod ALIVE the whole time (no exit log, no core file, no dmesg lines). 440/440 rounds complete. Outliers in 3 rounds (154, 221, 360: 1, 2, 1 outliers), all at the LAST block (index 190 of 191) -> end-of-stream artifact, not mid-stream loss. Gap median 29.1-31.4 ms per round (a bit higher than 26 ms idle because of ws load), worst gap 146-158 ms.
- cyclictest core 1 (segments 1-8, 10 min each, 2.4M cycles): max 139, 113, 97, 129, 91, 119, 93, 98 us; avg 25-27 us. Never below 50 us max on this layout (iiod TX path on core 1).
- iiod death: NOT reproduced in ~87 min / 440 rounds (plus ~140 rounds before). Cause still unknown.

## Update 2026-10-29: iiod transmit cost on core 1 (iso13 contaminated, iso14 clean; logs/txcost/)
- iso13 INVALID: the soak's board-side soak_mon.sh kept running cyclictest segments 10-12 on core 1 through the whole experiment (second cyclictest p98 on the same core). Lesson: kill soak_mon.sh/cyclictest after a soak; iso14 checks for strays first.
- iso14 (clean board, layout B: iiod SCHED_OTHER core 1, eth IRQ + services core 0, ws load, cyclictest p98 core 1, 300 s per case = 1.2M samples, 25 stream rounds at 10 MS/s / 32 blocks each):
  | case | max us | avg us | >=50 us | >=80 us | stream |
  | B0 baseline | 126 | 26 | 0.99% | 800 | clean |
  | C1 gso off | 112 | 28 | 7.60% | 672 | clean |
  | C2 tcp_limit_output_bytes 64k | 94 | 25 | 0.89% | 49 | clean |
  | C3 gso off + 64k | 104 | 29 | 4.26% | 479 | clean |
  | B0b baseline repeat | 128 | 26 | 1.00% | 50 | clean |
- Reading: the two baselines agree on the >=50 us fraction (0.99/1.00%) but differ 16x in the >=80 us count (800/50) and max 126/128, so max and >=80 us are noise; the >=50 us fraction is the stable metric. GSO off makes the tail WORSE (4 to 8% over 50 us: more per-packet work on core 1, the NIC has no TSO). 64 KB output limit = baseline (0.89% vs 0.99/1.00%), no gain. No setting reached the 47 us of layout A. iiod stayed alive, stream clean in all cases.
- Not tried: jumbo frames (needs the host NIC and root on the host), moving TX work off core 1 (not possible while iiod's send runs in its own thread), smaller iiod send size (needs an iiod change), a kernel with local_lock irq-off sections shortened in slub (kernel work).

## Update 2026-10-29: S23udc hardening committed (dbb9f48 on dev/next) and verified on hardware
- Change: NB_CORE from /proc/cpuinfo (nproc honours the affinity mask); isolated cores read from /sys/devices/system/cpu/isolated; the chrt -r 99 taskset -c 1 branch only when 2 CPUs and none isolated, else plain iiod. Corrects section 16e: the nproc quirk accidentally gave layout A; the hazard was a core-count-only fix putting RR99 iiod on the isolated core.
- Build: plutoplus_rt_defconfig into output/plutoplus_rt (BUILD_EXIT=0), image contains the new S23udc, kernel 6.12.114-rt21 PREEMPT_RT. Saved as known_good/sdimg-rt21-s23fix (stock bootargs) and sdimg-rt21-s23fix-iso (+ isolcpus=1 irqaffinity=0, only that uEnv line differs).
- Hardware (Pluto+, SD, /boot checksums match): s23fix-iso: isolated=[1], iiod and all 4 threads mask 1 (core 0), SCHED_OTHER. s23fix (no isolcpus): isolated=[], nproc=2, iiod threads mask 2 (core 1), SCHED_RR 99 (unchanged behaviour). No BUG/lockdep lines in dmesg.

## Update 2026-10-29: latency and stream check of the shipped layout A (image sdimg-rt21-s23fix-iso, iso15.sh, logs/layoutA_s23fix/)
- Setup: isolcpus=1 irqaffinity=0, iiod from the fixed S23udc (all threads mask 1 = core 0, SCHED_OTHER, NO runtime pinning), cyclictest -p99 -a1 on core 1, 10 MS/s Ethernet, 32 blocks, 25 rounds per stream phase, 1.2M cyclictest samples.
- P1 idle 120 s: max 43 us, avg 15, 0 samples >= 50 us.
- P2 stream + housekeeping load (2 /waterfall websockets + /api polling): cyclictest max 48 us, avg 15, 0 samples >= 50 us. STREAM NOT CLEAN: 25/25 rounds with outliers (16-58 per round, 1117 total), block gap median 34-45 ms (26 ms idle).
- P3 stream + housekeeping + CPU hog on core 0: cyclictest max 44 us, 0 >= 50 us. Stream: 25/25 rounds with outliers (14-72 per round, 1294 total), gap median 31-56 ms.
- iiod alive at the end of both stream phases.
- Reading: the RT core meets 50 us (43/48/44 us) with the shipped layout, matching the hand-pinned 44-47 us. But the network stream already breaks with the web UI's waterfall websockets alone on core 0 (sections 16c/16g said "only when core 0 is loaded"; the waterfall load is enough). Layout A is therefore only suitable when nobody streams over Ethernet while the web UI is open, or when the RT task works on-board only.

## Update 2026-10-29: opt-in switch rt_isolcpus (uboot-env.txt, sdboot_ram only; UNCOMMITTED in ~/code/tezuka_fw-dev)
- Change: sdboot_ram sets `rt_args` to `isolcpus=1 irqaffinity=0` when `rt_isolcpus=1` and puts ${rt_args} into the bootargs (unset by default). Set it by adding the line `rt_isolcpus=1` to uEnv.txt on the SD card (fw_setenv would write the QSPI env: not used).
- Build: needed the known trap (post-image failed on system_top.bit; board-fpga-dirclean board-fpga, then make) -> BUILD_EXIT=0. BOOT.bin, devicetree.dtb and system_top.bin identical to the tested s23fix image; uImage/ramdisk differ only by the embedded version string. Images: known_good/sdimg-rt21-sw (default) and sdimg-rt21-sw-on (uEnv.txt + `rt_isolcpus=1`).
- Hardware (Pluto+, SD, checksums match): default: cmdline has no isolcpus, isolated=[], iiod threads mask 2, SCHED_RR 99. With rt_isolcpus=1: cmdline `... cpuidle.off=1 isolcpus=1 irqaffinity=0 uio_pdrv_genirq...`, isolated=[1], iiod threads mask 1, SCHED_OTHER. No BUG/lockdep lines. SD restored to sdimg-rt21-sw (default).
- Not done: other boot paths (qspi, usb, kuiper) unchanged; latency/stream not rerun on this image (same kernel and S23udc as the layout A check).

## Overnight soak started 2026-10-29 21:52 (scripts/soak2.sh, soak_mon2.sh; output scratchpad/soak2_out/)
- Plan: P1_default (sdimg-rt21-sw: no isolcpus, shipped iiod -D RR99 core 1) 4 h with ws waterfall load + 10 MS/s/32-block stream + cyclictest p98 -a0 in 10 min segments; then the harness writes sdimg-rt21-sw-on (rt_isolcpus=1) and runs P2_rt_isolcpus 4 h (cyclictest p99 -a1); finally restores sdimg-rt21-sw.
- Stops at the FIRST problem and leaves the board as is (no reboot): iiod gone, an incomplete stream round (RX wedge), or the client ending; writes fail_diag.txt (dmesg, interrupts, ps, ensm, local reader, messages).
- Check: soak2_out/heartbeat.log (updated every minute), summary.txt (ends with SOAK_DONE).

## Overnight soak result (2026-10-29 21:52 to 2026-10-30 02:01)
- P1_default (sdimg-rt21-sw, no isolcpus, iiod RR99 on core 1, ws_load, 10 MS/s 32-block stream): 14457 s, 1338 rounds, 0 incomplete, 0 rounds with outliers, iiod alive to the end (pid unchanged). cyclictest -p98 -a0, 24 segments of 600 s: max 343..691 us per segment (the stream and iiod are clean, but core 0 hosts all housekeeping so the tail is not 50 us).
- P2_rt_isolcpus (sdimg-rt21-sw-on, isolcpus=1, iiod SCHED_OTHER mask 1): stopped after 376 s, 16 rounds, ALL 16 with lost blocks (23-49 per round of 191). This is the known layout A result (web UI websockets alone on core 0), not a new failure. No cyclictest segment finished.
- Board left as failed (no reboot). SD holds sdimg-rt21-sw-on; harness did not restore sdimg-rt21-sw.
- Logs: logs/overnight_2026-10-29/

## Wedge hunt on the default image (2026-10-30 07:32 to 07:59, scripts/wedge_hunt.sh, logs/wedge_hunt_2026-10-30/)
- Default image (no isolcpus, iiod RR99 core 1), ws_load, 10 MS/s 32-block stream, escalating stress-ng: ws only 15 rounds, --cpu 2 40 rounds, --cpu 2 --vm 2 (48M) 40 rounds, --cpu 4 --vm 2 --hdd 1 40 rounds (load average peaked ~10.8). 135 rounds: 0 incomplete, 0 with lost blocks, iiod alive. No stall, so the DMA/register capture never fired.
- Reading: with the shipped RT-priority iiod on core 1 the stream is robust against SCHED_OTHER overload. Both earlier wedges came on isolcpus/pinned-SCHED_OTHER-iiod layouts (A/B) after long heavy runs, i.e. not the shipped mode. The wedge is not reproducible in the default mode.

## Wedge reproduced in placement variant B (2026-10-30, scripts/wedge_hunt_b.sh, logs/wedge_hunt_b1_2026-10-30, wedge_hunt_b2_2026-10-30)
- Setup: sdimg-rt21-sw-on (isolcpus=1), iiod SCHED_OTHER pinned to core 0 with stress-ng (taskset core 0), eth IRQ31 on core 1, ws_load, 10 MS/s 32-block stream.
- Run 1: wedge after 12 rounds of --cpu 1 (round 13 gave no data; outlier_ts.py then crashed with IndexError on an empty ts array, harness caught it as client ended without summary). Run 2: --cpu 1 60 rounds no wedge (all rounds with 50-80 lost blocks), then --cpu 1 --vm 1 (32M): wedge after 41 rounds. Both captured, same signature.
- State on the wedged board: iiod alive; the local reader (no iiod, no network) also gets Unable to dequeue block (110); AD9361 ensm fdd, ADC interface clock counter 0x199A/0x1999 = 10 MHz (alive); sync_start_enable disarm; DMAC (7c400000) enabled while a reader runs, transfer id 2 active, done bitmap 3, CURRENT_DEST == DEST_ADDR (nothing written to memory), IRQ27 only +3..4 per 12 s attempt (healthy: ~400/s, CURRENT_DEST advancing). X_LENGTH reads 0x1FFFF in the wedge vs 0x3FFFF healthy for the same -b 65536 request (unexplained).
- Not cured by: ensm alert->fdd, sampling_frequency rewrite, writing 0xF to ADC 0x68, ADC core RSTN 0 then 3 (0x79020040), DMAC CTRL 0 then 1. Only a reboot cures it. So the stuck state is not in the AD9361 config, the ADC core registers or the DMAC enable bit; candidates: PL data path between ADC core and DMAC (cpack/FIFO), AXI HP port, or axi-dmac/IIO buffer driver state.
- Not tried: SLCR FPGA reset (risky, driver loses its register config), zynq_rst debugfs (reboot code, not touched), TX-side DMA test, reading cpack registers.
- Board left wedged on sdimg-rt21-sw-on; SD not restored to the default image yet.

## Wedged board probe (2026-10-30, scripts/wedge_probe.sh, logs/wedge_probe_2026-10-30/wedged.txt; board still wedged)
- PL peripherals (device tree): ADC core 79020000, DDS 79024000, RX DMAC 7c400000 (irq27), TX DMAC 7c420000 (irq28), maia-sdr 7c460000. No cpack registers exist.
- Register dumps (RX/TX DMAC, ADC core), idle vs during an RX read: RX DMAC goes enabled (0x400=1), transfer id 2, done bitmap 3, active 2, nothing else changes; IRQ27 +4. ADC core registers unchanged.
- TX side works in the wedge: iio_writedev of 4 MiB zeros to the DDS core completed, IRQ28 +32, TX DMAC registers moved (TX DMA reads DDR fine).
- maia-sdr side works in the wedge: /waterfall delivers 13 frames in 5 s (configured 2.4 Hz), and /raw-capture returns 262144 samples of real noise (rms 9.06, 1315 distinct values). So the AD9361 interface delivers valid samples and maia-sdr's own DMA writes them to DDR, while cf_axi_adc's RX AXI-DMAC (7c400000) gets nothing.
- Reading: the fault is local to the RX AXI-DMAC / its PL input (cpack or FIFO handshake) or its driver state, not the AD9361, the ADC core clock, the DDR/HP path in general, or iiod. Not excluded: a shared HP port issue that only affects this DMAC's write channel.
- Open: healthy-board dump with the same script to find any differing register (X_LENGTH reads 0x1FFFF in the wedge vs 0x3FFFF healthy for the same request is the one known difference); needs a reboot.

## Healthy-board dump compared with the wedged one (2026-10-30, logs/wedge_probe_2026-10-30/healthy.txt)
- Same script after a reboot (rate 10 MS/s). Idle: the only differences are the RX DMAC registers that hold the last programmed transfer (0x40C flags, 0x410 dest, 0x418 x_length, 0x434 current dest): history, not configuration. No difference in the ADC core, TX DMAC config or DMAC identification/config registers (0x000-0x04C).
- During the read the wedged DMAC shows enabled/id 2/done 3/active 2 and x_length 0x1FFFF; the healthy one had already finished the 131072-sample read (done before the 3 s sample), x_length 0x3FFFF. TX path identical (irq28 +32).
- Reading: no static register state distinguishes the wedge. What differs is the runtime programming (128 KiB segments and no data flow) -> look in the axi-dmac / IIO dmaengine buffer driver for what halves the segment length and what the DMAC waits for. A mid-stream sample of the healthy board is not needed for that.
- Board is now healthy (rebooted), SD holds sdimg-rt21-sw-on.

## Driver source reading (2026-10-30; linux-rt-fcde289: drivers/dma/dma-axi-dmac.c, drivers/iio/buffer/industrialio-buffer-dma.c, industrialio-buffer-dmaengine.c)
- axi_dmac_probe sets max_length from the X_LENGTH register read-back (huge, 512 MiB), so the driver never splits a 256 KiB block; the idle X_LENGTH 0x7 / DEST 0x1FFFFFF8 on a fresh boot are probe leftovers.
- The 128 KiB X_LENGTH of the wedge matches the IIO DMA buffer FILEIO path: iio_dma_buffer_request_update() sizes each fileio block as bytes_per_datum * length / 2 (= 4 B * 65536 / 2 = 128 KiB) and keeps two of them. The healthy mid-stream read used 256 KiB blocks, which is the mmap/block-alloc path of libiio. So in the wedge the local reader ended up on the fileio fallback instead of the block API (or the block alloc failed). Not proven: I only have the register values, not the reader's code path.
- With only two fileio blocks, "done bitmap 3, active id 2, then idle" is what a reader that does not drain the blocks looks like, so the "DMA gets no data" reading from the register dumps may be wrong: the two 128 KiB blocks could have been filled and the consumer side (dequeue/poll) is what times out. Needs a check on the next wedge.
- Clue: in the first wedge capture `pkill iiod` did not kill iiod (pid 834 stayed, SIGTERM only) and the "iiod stopped" local-reader test was therefore invalid. iiod may be stuck in the kernel (D state) holding /dev/iio:device3 or a block queue (num_blocks leak, alloc_blocks caps at 64 - num_blocks).
- Next wedge capture should add: /proc/<iiod>/task/*/stat state and wchan (and /proc/<pid>/stack if present), ls -l /proc/<iiod>/fd for iio devices, kill -9 iiod and re-test the local reader, which libiio path the reader takes (strace if available, or LIBIIO debug), buffer0/ and scan_elements sysfs, dmesg for hung task.

## Wedge cause found: a stale iiod client session holds the IIO buffer; kill -9 iiod cures it (2026-10-30 14:16, logs/wedge_hunt_b3_2026-10-30)
- Third reproduction (placement variant B, --cpu 1, wedged after 33 rounds; round 34 gave no data). Forensics were taken before anything else touched the board.
- iiod (pid 835, alive, all threads in S state, none in D) still had the dead client's session threads: net_client_thd, writer-task, buffer-enqueue, buffer-dequeue, enqueue-worker, all in futex wait. iiod held an open IIO buffer fd (anon_inode:iio:buffer) on cf-ad9361-lpc while buffer/enable=0. No other process held an iio device. No hung-task/BUG/WARN lines in dmesg.
- A new local reader (no iiod involved in its data path) still timed out: Unable to dequeue block (110).
- After `kill -9` of iiod (a plain pkill/SIGTERM had not killed it in the earlier capture), the same local reader worked at once: rc 0, IRQ27 +10, and the DMAC programmed the normal 256 KiB (X_LENGTH 0x3FFFF). The ADC reset and DMAC enable-cycle steps of the ladder then also read fine (they ran after the kill, so they prove nothing).
- Conclusion: the RX wedge is not hardware, the AD9361, the ADC core, the DMAC or the PL. It is a leaked/stuck iiod client session (libiio 1.0 iiod) that keeps the IIO buffer open, which blocks any new reader. The earlier reading "only a reboot cures it" was wrong: restarting iiod is enough. The 128 KiB X_LENGTH seen in the wedge was the fileio fallback of a reader that could not allocate blocks while the old session held them.
- Unknown: what makes the session hang in the first place (round 34 client got no data; layout B puts iiod SCHED_OTHER on the core with the hog). The default mode has not shown it in 1338 + 135 rounds. Not tested: restarting iiod cleanly with the shipped init script and a network client afterwards (ffs ep0 is held by iiod, so a plain `iiod -D` restart is not equivalent).
- Board state: iiod killed, board needs a reboot or S23udc restart; SD still holds sdimg-rt21-sw-on.

## Wedge trigger found: a new client connects while the previous iiod session is still tearing down (2026-10-30 14:39-14:53, scripts/wedge_hunt_t.sh, trig_mon.sh, outlier_ts2.py; logs/wedge_hunt_t_2026-10-30)
- Layout B again (sdimg-rt21-sw-on, iiod SCHED_OTHER core 0 + hog, eth IRQ core 1). Wedge at round 30. The failed round's client: 0 bytes, rc TIMEOUT after 60 s, stderr Unable to dequeue block (110).
- Board monitor (trig_mon.log, one sample per ~4-5 s): normal cycle = n=4 threads idle -> client connects, n=11 (7 session threads), buffer fd 1, 2 ESTABLISHED, buffer enabled, irq27 rising -> client done: buffer disabled, session threads exit, n back to 4. Teardown from buffer=0 to n=4 took 2.3 to 2.9 s in 7 of 8 cycles and 19.9 s once.
- Stall cycle: at 736.6 buffer=0 but n=11 (old session still tearing down); 744.1 n=9 and the old connection in CLOSE_WAIT (client closed, iiod has not closed its end); 748.5 a NEW client has connected (n=16 = 9 old + 7 new, 2 ESTABLISHED + 1 CLOSE_WAIT), buffer enabled again (buf=1), irq27 frozen at 11870, and nothing changes for the next 60+ s (all session threads in futex_wait, nobody in D state, one buffer fd open). The old session never finishes, the new one never gets data.
- The harness leaves a 3 s gap before the next client, so a teardown that takes longer than that (load, iiod SCHED_OTHER) overlaps the next connect. In the default mode (iiod RR 99 on core 1, 1338 + 135 rounds clean) teardown evidently stays short.
- Conclusion: trigger = overlapping teardown of one iiod session and setup of the next (race/deadlock in libiio 1.0.0 iiod buffer handling, probably old session holds the IIO buffer while the new session enables it). It is an iiod software bug exposed by slow teardown, not hardware. Real-world analogue: a client reconnecting right after a disconnect while iiod is busy.
- Untested: back-to-back reconnects in the default mode (could the shipped image hit it with a fast reconnect?); which libiio 1.0.0 code path (iiod session close vs buffer open) holds the lock; whether a newer libiio fixes it.

## Fast reconnects on the default image (2026-10-30 14:58-15:07, scripts/fast_reconnect.sh; logs/fast_reconnect_2026-10-30)
- sdimg-rt21-sw (no isolcpus, iiod RR 99 core 1), libiio 1.0 host client (iio_rwdev), no gap between cycles, 10 MS/s. 1400 cycles, no hang:
  F1 idle, connect + read 131072 samples + disconnect: 400 cycles, max 0.14 s each.
  F2 same under stress-ng --cpu 2: 400 cycles, max 0.34 s.
  F3 client killed (SIGKILL) 0.2 to 1.2 s into a stream and the next one started at once, every 10th cycle a verifying read: 300 cycles ok, max 1.24 s.
  F4 same as F3 under stress-ng --cpu 2: 300 cycles ok, max 1.28 s.
- Reading: the default mode does not hit the session overlap race with fast reconnects (idle or CPU load). The race was seen only where iiod is SCHED_OTHER on the loaded core (layout B), where a teardown can take 3 s or more. Not shown: that the race cannot happen in the default mode under other conditions (memory stress, much slower teardown).
- Board: default image, iiod alive (pid 840), no BUG/WARN/hung lines in dmesg.
