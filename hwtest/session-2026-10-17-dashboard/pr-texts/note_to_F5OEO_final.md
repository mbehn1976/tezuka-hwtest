Hi, one summary so you can decide what to take for the next release, instead of a comment per build.

Everything below is tested together on a Pluto and a Pluto+: a combined firmware of `refactor`, the PRs below and the original maia-sdr `main` merged in (Vivado 2023.2, timing met, IP core 0.6.2). The RF suite (I/Q, phase and frame checks at 2.5 to 61.44 MS/s on both boards) passes, with one exception: one OFDM check on the Pluto at 61.44 MS/s failed once (log correlation 0.977 against 0.98). I could not reproduce it in 23 further runs and I do not know the cause, so I am not claiming it is fixed.

Suggested order:
1. maia-sdr #12 (raw complex capture, I/Q waterfall stream, hwtest). Independent of the rest. The open question from my earlier comment is how the Pluto and Pluto+ bitstreams and the device-tree nodes should reach tezuka_fw: your rebuild from maia-sdr, or an xsa in a tezuka_fw PR with its version line. The device-tree nodes are ready as a small tezuka_fw PR (4 files) that I will open once you have answered.
2. tezuka_fw #500 (dashboard: axis scales, peak markers, Complex I/Q page, dB fix, frequency switching fix). One commit. The Complex I/Q page needs #12; the rest does not.
3. The small fixes maia-sdr #14 to #22 (and the docs in #23) and tezuka_fw #486 to #493, each independent.
4. tezuka_fw #498 (CP-OFDM detector and an I/Q continuity tool). Optional, not enabled in any defconfig.

Two more things:
- `refactor` does not have the changes of the original maia-sdr `main` since December 2024 (dependency updates, the kernel 6.4+/6.11+ module fix, cocotb 2.0). Merging them is mostly manifests, changelogs and a few lines of Rust in maia-httpd and maia-wasm; the Rust crates build and their tests pass, and the cocotb tests pass on cocotb 2.0. A resolved branch is on my fork (mbehn1976/maia-sdr, test/orig-into-refactor-pr12) if you want it. I have not proposed it as a PR.
- Which release are you aiming for? I will keep the PRs rebased until then and will not post per-build updates.

Thanks for your time.
