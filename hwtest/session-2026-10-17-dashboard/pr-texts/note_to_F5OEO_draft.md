DRAFT, not posted. Intended place: maia-sdr PR 12 (or tezuka_fw#494), one note instead of per-build comments.

Hi, one summary so you can decide what to take for the next release. Everything below is tested together on a Pluto and a Pluto+ (combined firmware: refactor + the PRs below + the original maia-sdr main merged in, Vivado 2023.2, timing met; the RF suite passes on both boards at 2.5 to 61.44 MS/s).

Suggested order:
1. maia-sdr #12 (raw complex capture, I/Q waterfall stream, hwtest). Independent of the rest. The open question is how the Pluto/Pluto+ bitstreams and the device-tree nodes should reach tezuka_fw (your rebuild from maia-sdr, or an xsa in a tezuka_fw PR with its version line). The device-tree nodes are ready as a 4-file tezuka_fw PR, waiting for this answer.
2. tezuka_fw #500 (dashboard: axis scales, peak markers, Complex I/Q page, dB fix, frequency switching fix). One commit, independent of #12 apart from the Complex I/Q page needing it.
3. The small fixes maia-sdr #14 to #22 (and the docs in #23) and tezuka_fw #486 to #493, each independent.
4. tezuka_fw #498 (CP-OFDM detector, optional feature, not enabled in any defconfig).

Two things you may care about:
- Your refactor branch does not have the changes of the original maia-sdr main since December 2024 (dependency updates, the kernel 6.4+/6.11+ module fix, cocotb 2.0). Merging it into refactor has 8 conflicts, all in maia-httpd and maia-wasm; I have a resolved branch on my fork (mbehn1976/maia-sdr, test/orig-into-refactor-pr12) if you want it.
- Which release are you aiming for? I will keep the PRs rebased until then and will not post per-build updates.

Thanks for your time.
