## Summary

Investigating a matched-filter-capable signal classifier for a downstream project (`tezuka_fw`'s `app/classifier/`), which currently only has access to magnitude-only spectrometer output. Traced where phase is actually discarded:

`FFT` (`re_out`/`im_out`, complex, 22-bit) → `SpectrumIntegrator`'s `IQToFloatingPoint` (still complex) → `MakeCommonExponent` (still complex, `re_a_out`/`im_a_out`) → **`CpwrPeak`** — this is the module that collapses to a single real value (power/peak-hold) for the BRAM accumulator. Everything upstream of `CpwrPeak` is genuinely complex and reachable.

This PR now has two complementary complex-data features, both tapping `fft.re_out`/`fft.im_out` the same way (same truncation, same numeric representation, so they're directly comparable):

1. **Triggered raw capture** (`raw_capture`): a single-shot burst of one FFT frame's complex bins, reusing the existing `Recorder16IQ` module unmodified.
2. **Continuous I/Q waterfall** (`iq_dma`): a second, small, low-rate channel that latches the *last* frame's complex bins once per integration epoch — same cadence as the existing magnitude waterfall — via a dedicated ping-pong buffer and a second small `DmaBRAMWrite`. Not a continuous full-rate stream (that would be far higher bandwidth than the integrated waterfall); this gives a live phase/I-Q view at the same refresh rate the magnitude waterfall already uses.

27 commits (the original feature commits, the fixes and the hardware tests found along the way, and the `hwtest/` scripts). The register-map additions for `iq_dma` went onto the *existing* `sdr_registers['spectrometer']`/`interrupts` registers as new fields, not a new block — I'd first assumed there was free address-decode space from the `raw_capture` commit, but there wasn't (no further decode on those bits), so this is the simpler, correct approach.

## What has been verified

**Simulation**

- A new `test_cocotb/spectrometer/` testbench (none existed for `Spectrometer` as a whole). It finds the peak bin of a constant DC tone empirically (scan every address, take the maximum) and caught two real bugs in the `iq_dma` work that Verilog generation alone did not: the DMA read-data mux selected the ping-pong buffer that was not being read (every I/Q sample read back as zero), and the write-address counter reset value put the tone's peak at a different address than the magnitude channel. The reset constant (`2**(order_log2-1) + 1`) was found by trial against this test, not derived from `fft.py`'s pipeline timing, and is flagged as such in a code comment; it is worth a second look from someone who knows that pipeline. The testbench now has 7 tests: 5 run by default, and the 2 exact comparisons against the recorded FFT stream run separately with `make exact` (each passes when run alone). It needs `COCOTB_RESOLVE_X=ZEROS`, documented in the test and the Makefile.
- Full Verilog generation succeeds for the whole `MaiaSDR` core, with `raw_capture` and `iq_dma` enabled, under all 3 existing configs.
- maia-httpd (Rust): `cargo check`, `clippy` and `cargo test -p maia-httpd` pass; new `src/httpd/raw_capture.rs` and `src/iq_waterfall.rs` with the `/api/raw-capture`, `/raw-capture` and `/iq-waterfall` endpoints. `maia-pac`'s SVD and bindings were regenerated for each register-map change and compile clean.

**Hardware** (details, tables and the bugs the hardware tests found: `maia-hdl/hwtest/README.md`)

- Vivado 2023.2 bitstreams for `pluto_iio` and `plutoplus_iio` with the two DMA masters wired (HP3 for the raw capture, HP0 for the I/Q waterfall): timing met, WNS +0.189 ns, WHS +0.017 ns, no failing endpoints.
- `hwtest/` runs on an original Pluto and a Pluto+ over a cable (BIST tone, CW tones, CP-OFDM, a phase check, and the phase between consecutive I/Q frames) at 2.5, 10, 20, 30.72 and 61.44 MS/s. The magnitude, I/Q and raw-capture peaks agree. The phase against a windowed-FFT model is within about 2 degrees, and the frame-to-frame phase matches its prediction within 0.0023 rad.
- The same I/Q and raw-capture path also runs on a combined firmware (F5OEO's `refactor`, this PR's changes, the open fix PRs and the original maia-sdr `main` merged in) on both boards. The full suite there passes except for one OFDM check on the Pluto at 61.44 MS/s that failed once (log correlation 0.977 against 0.98); I could not reproduce it in 23 further runs and do not know the cause.
- `hwtest/rf_iq_check.py` (commit 65e5def): the raw-capture versus magnitude comparison correlates the log spectra over the nine bins around the magnitude peak. The earlier linear correlation over the whole spectrum fell to about 0.7 when a tone near a half-bin position split the single-frame peak, although the raw peak was the expected one. The full suite on both boards gives 0.9993 to 1.0 with the new comparison, and 0.998 or better in 20 repeated runs at 61.44 MS/s on the original Pluto.

## What is not verified or not done

- Other boards: the two DMA masters are wired only for `pluto_iio` and `plutoplus_iio`. The other projects (e200, fishball, libre and so on) still leave them unconnected and are untested.
- This PR targets `main`, but the current development line is `refactor`, where the projects are laid out differently (there the DMA wiring is in the shared `projects/common` files). The wiring that is verified on hardware with `refactor` is on my fork (`mbehn1976/maia-sdr`, branch `test/orig-into-refactor-pr12`). I have not proposed it as a PR; I asked in my comments how you want this delivered.
- The cocotb tests in this PR are written for cocotb 1.8. The original maia-sdr `main` has moved to cocotb 2.0; with its `AXI4Slave` the spectrometer tests need a small port (its immediate writes at time zero leave Icarus nets unknown). The port is on the same fork branch.
- One unexplained intermittent OFDM check failure at 61.44 MS/s (see above).
- `MaiaSDR`'s AXI4-Lite address width grows from 4 to 5 bits, an API-breaking HDL interface change for anyone instantiating it directly (noted in the CHANGELOG). I did not bump `_version` or the `pyproject.toml` version; that is the maintainer's call at release time.
- Downstream, the tezuka_fw device-tree nodes for the Pluto and Pluto+ are ready as a small separate PR (4 files). I have not opened it, because it depends on this PR and on how the bitstreams are delivered.

Happy to iterate based on review.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
