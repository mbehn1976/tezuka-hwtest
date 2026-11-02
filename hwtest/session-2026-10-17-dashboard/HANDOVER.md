# Handover: Complex I/Q, dashboard, combined firmware and system upgrade (state 2026-10-25)

Sections 1 to 6 are the state of 2026-10-22. The system upgrade (Buildroot, kernel, libiio) and the current firmware on the boards are in section 7, which overrides section 3 where they differ.

Everything here was checked against GitHub and the local repositories on 2026-10-22 (PR status re-checked 2026-10-25). For the story, the
decisions and the measurements see the Claude memory notes (`~/.claude/projects/-home-mb/memory/`,
start with `project_dashboard_axes_complex_iq.md`) and the logs in this folder.

## 1. What is upstream (pull requests to F5OEO)

F5OEO has not reviewed any of them (last check 2026-10-28: no review, no merge, no new comment; tezuka_fw main still `a304a1f` and release v0.3.24 of 2026-10-17, maia-sdr refactor still `5f28808`; another contributor has tezuka_fw #495 and #496 open). His only comments are two on tezuka_fw #500 on
2026-10-17: send a PR per release rather than per build, and squash (done, #500 is one commit). One consolidation note is posted on
maia-sdr PR 12 (issuecomment-6255316422) with the suggested merge order and the open question: how the
bitstreams and the maia-sdr source reach tezuka_fw, and which release he is aiming for.

| PR | Base | Head (fork branch) | What |
|---|---|---|---|
| maia-sdr #12 | main | `65e5def` feature/spectrometer-raw-complex-capture | raw complex FFT capture + I/Q waterfall channel + hwtest scripts. Description rewritten 2026-10-22. |
| maia-sdr #14 to #22 | refactor | fix/... branches | the DDC/CS12 fixes (F2, F5, F6, F17, F18, N1, N2, provenance) |
| maia-sdr #23 | refactor | `4c322c8` | CS12 stream format documentation |
| tezuka_fw #486 to #489 | main | fix/... branches | kmod cache fix, loaddfu, routing read-modify-write, bitstream provenance |
| tezuka_fw #490 to #493 | main | | docs and small fixes |
| tezuka_fw #498 | main | `e7a16e1` | CP-OFDM detector (host tool, board app, package; not enabled in any defconfig) and `iq_continuity` |
| tezuka_fw #500 | main | `058a661` | the dashboard: axis scales, peak markers, Complex I/Q page, 10*log10 fix, frequency switching fix, wrapped Bode phase, and (since 2026-10-22) the CP-OFDM detector card on the Signal Classifier page and the demo GIF. One commit. |
| tezuka_fw #504 | main | `b39f7fa` | device-tree nodes only (raw capture 0x1a100000, I/Q waterfall 0x1a200000) for Pluto and Pluto+ |

22 PRs are open (11 maia-sdr, 11 tezuka_fw) and all report MERGEABLE (checked 2026-10-25, re-checked 2026-10-28 with no change; tezuka_fw main is still `a304a1f`, maia-sdr
refactor `5f28808`). Earlier tezuka_fw PRs #426 to #474 were merged or closed before this work.

The system upgrade (section 7) is NOT one of these PRs. It exists only as draft PR #27 on your own fork (mbehn1976/tezuka_fw);
nothing about it has been posted to F5OEO or ADI.

Rules for F5OEO's repositories: tezuka_fw commits are authored and signed off as `Mario Behn <mario.behn@gmail.com>`, no
Claude attribution, ASCII messages without quotes. maia-sdr allows the Claude trailer, pycodestyle clean under `maia-hdl/`. No
comment per build or test cycle; a meaningful tested update is fine, edit the description rather than adding result comments,
and ask before every push to a PR branch or post. Use `gh api --input file.json` for bodies with backticks.

## 2. What exists only on your fork (not proposed)

| Fork branch | What |
|---|---|
| mbehn1976/maia-sdr `test/orig-into-refactor-pr12` `415cea9c87` | refactor + PR 12 + the open fixes + the original maia-sdr main merged in + cocotb 2.0 port + #23 docs. The source of the current bitstreams, `maia-httpd` and `maia-wasm`. |
| mbehn1976/maia-sdr `test/rf-iq-check-log-corr` `65e5def` | the rf_iq_check fix (now also in PR 12) |
| mbehn1976/maia-sdr `test/combined-orig-f5oeo-pr12`, `test/merge-orig-main-into-f5oeo-main` | original main merged into F5OEO's main (integration record only; lacks refactor's 108 commits) |
| mbehn1976/tezuka_fw `test/combined-newdash9` `4b76148` | the firmware branch: upstream main (= release v0.3.24) + all tezuka_fw PRs + `cpdetect` enabled + the new bitstreams. What runs on the boards. |
| mbehn1976/tezuka_fw `feature/cpdetect-card` `944cfa2` | the cpdetect card as a separate commit; now folded into #500 (`2109b38`), kept as a record |
| older `test/*` branches | earlier builds (newdash8 etc.), records only |

## 3. Firmware on the boards (verified 2026-10-22)

(Superseded by section 7.) Both boards reported `tezuka-v0.3.24-55-g4b76`: release v0.3.24 (identical to upstream main a304a1f) plus 55 commits, `maia-httpd` 0.6.1,
IP core `maia_hdl_version` 0.6.2, fpga line `maia-sdr test/orig-into-refactor-pr12 415cea9c87 <board> vivado 2023.2`, dashboard page md5
`89d16de8101489d0649ae799ec71e31e`. Not reproducible from the PRs alone, because the bitstreams and the `maia-httpd` / `maia-wasm`
source come from the unmerged maia-sdr branch above (local override). Saved images: `~/tezuka-review-v0.3.23/hwtest/known_good/*newdash9*`.

How it was built (scripts in `scripts/`):
1. `vivado_merged.sh`: bitstreams from `~/code/maia-sdr-merge` (about 7 min per board; timing met: Pluto WNS +0.131 ns, Pluto+ +0.201 ns).
2. Copy the `.xsa` to `board/tezuka/<board>/bitstream/tezuka.xsa` in `~/code/tezuka_fw-all` and write `tezuka.version`.
3. `build_images.sh` (needs `output/<board>/local.mk` with the two override lines; dirclean httpd and wasm, they are not rebuilt otherwise).
4. Pluto+: write the SD card with `sd_write.sh` (unmount the card from the desktop first). Pluto: copy `pluto.frm` to its USB volume and
   you eject it; never eject it for the user.
5. Verify on the board: `curl http://<ip>/api/versions`, `/opt/VERSIONS`, `md5sum /root/index.html`, `/boot` checksums on the Pluto+.

## 4. Local working copies (`~/code/`)

`tezuka_fw-dash` PR 500 (+ `feature/cpdetect-card`) · `tezuka_fw-all` firmware branch · `tezuka_fw-dt` PR 504 · `maia-sdr-bp` PR 12
and hwtest · `maia-sdr-merge` the merged maia-sdr branch and the Vivado build tree · `maia-sdr-iqtest` older bitstream source (4d520ad).

## 5. Test rig and tests

Original Pluto 192.168.2.1 (USB RNDIS, hub 3-6.3.4), Pluto+ 192.168.3.1 (Ethernet) and 192.168.4.1 (USB, hub 3-6.1), 40 dB cable,
2.4 GHz. The RF suite is `scripts/suite.sh` (runs the maia-hdl `hwtest/` checks at 2.5 to 61.44 MS/s on both boards, about 25 min).
Latest result (combined firmware): 69 ok and one unexplained OFDM failure at 61.44 MS/s on the Pluto, not reproduced in 23 runs.
Details of the rig, tricks and gotchas: memory `reference_pluto_plutoplus_test_rig.md`.

Known issues:
- The Pluto+ USB link drops under high TX power plus CPU load (cause unproven, probably power). Recover with
  `ssh root@192.168.3.1 'echo disconnect > /sys/class/udc/ci_hdrc.0/soft_connect; sleep 3; echo connect > /sys/class/udc/ci_hdrc.0/soft_connect'`;
  if the board is dark after a power cycle: `uhubctl -S -l 3-6 -p 1 -a cycle -d 4`. The RF tests use Ethernet and are not affected.
  Decisive test still open: power the Pluto+ from a separate source (`scripts/usb_t5.sh`).
- The Pluto+ SD logs "Volume was not properly unmounted" at boot: harmless.

## 6. Still open

- F5OEO's answer on bitstream delivery, the target release, and any review (still none on 2026-10-28).
- System upgrade (section 7): decide whether and when to propose it to F5OEO. He asked for one PR per release, not per build, so the
  natural moment is a single PR on top of the then-current main, opened as a draft only after you say so (it notifies him). Before
  that: choose where the kernel branch lives (recommended: send the DAC fix to ADI first, then pin ADI; otherwise an F5OEO repo), post
  or drop the ADI issue text, and adjust the PR text (it is written for F5OEO, #27 on your fork uses it as is). Rerun the full RF suite
  on the exact images you want to propose (the fresh-clone build only had the quick tone test).
- The upgrade changes how the combined firmware is built: `upgrade/all-features` pins the maia-sdr tree `415cea9` on your fork, so the
  `local.mk` override from section 3 is no longer needed there (it is renamed `local.mk.disabled`). The bitstream and
  `maia-httpd` / `maia-wasm` pin bump to a maia-sdr commit that contains PR 12 still depends on F5OEO.
- After his answer: bitstreams (his rebuild or an xsa PR), the `maia-httpd` / `maia-wasm` pin bump to a maia-sdr commit that contains PR 12,
  the `refactor`-layout version of the PR 12 wiring, the offer to merge the original maia-sdr main into refactor, and enabling `cpdetect` by default.
- Only you: the Pluto+ USB power test, the F12 and F13 emails, the F8 `loaddfu` UART test.
- Done 2026-10-22: the demo GIF and the cpdetect card are in #500. Done since: the flashed images (`upgrade/all-features`, g32c3 and gb6c3) are built with the new dashboard, so the card is in the firmware now.
- Optional: a long soak test, splitting PR 12 into smaller PRs, reporting the cocotb 2.0
  `AXI4Slave` bug (immediate writes at time zero leave Icarus nets unknown; fix in `test_spectrometer.py` on the merged branch) to the original project.

## 7. System upgrade (2026-10-22 to 2026-10-25)

Buildroot 2026.08.1, kernel 6.12.114 (Pluto and Pluto+), libiio 1.0.0 (iiod, tools, library with the libiio.so.0 shim and the 0.x iiod
protocol), zynqrx / pluto_rx / iio_ws_proxy / cpdetect ported to the 1.0 stream API, other libiio users on a private 0.26 (`libiio0`),
and a kernel fix for a TX tone that stayed after the writer stopped (ADI commit 331f56730c62 dropped `indio_dev->setup_ops` in
`cf_axi_dds_buffer_stream.c`; restored in mbehn1976/linux `tezuka/6.12.114-xlnx-2026r1`, 678c4de70fdf; only checked against ADI
`xlnx/release/v6.12.y-2026r1`). Full story: memory `project_system_upgrade_plan.md`, `project_upgrade_summary.md`, and
`doc/system-upgrade-2026-10.md` in the repo.

**Fork branches (mbehn1976/tezuka_fw), all pushed:**

| Branch | What |
|---|---|
| `upgrade/all-features` `32c3a90` | the upgrade + your complex spectrometer: `maia-httpd` / `maia-wasm` pinned to maia-sdr `415cea9` on your fork (no local override, no package patches). Reproducible from GitHub alone. This is what runs on the boards. |
| `upgrade/libiio-1.0.0` `365c426`, `upgrade/kernel-stable-6.12.114`, `upgrade/kernel-adi-b486fe8`, `upgrade/buildroot-2026.08.1` | the stacked steps under it |
| `proposal/system-upgrade` `118766e` | 14 commits on F5OEO main a304a1f, cleaned up for upstream (sign-offs, order, doc). No complex spectrometer, no cpdetect enable. Draft PR #27 on YOUR fork (not upstream). |
| `proposal/system-upgrade-cpdetect` `c470ce9` | the same plus one commit enabling cpdetect in both defconfigs |
| `backup/upstream-drafts-2026-10-25` `b878bdd` | PR text, ADI issue text and patch, the 14-patch series (`doc/upstream-drafts-2026-10-25/`) |
| `backup/wip-tezuka_fw-2026-10-24`, `backup/wip-f1f4-2026-10-24` | snapshots of the uncommitted work in `~/code/tezuka_fw` and `~/code/tezuka_fw-f1f4` |

**On the boards now (2026-10-25):** both `tezuka-v0.3.17-195-g32c3` (fresh single-branch clone of `upgrade/all-features`, so older git tags;
cosmetic), kernel 6.12.114, libiio 1.0.0, `/waterfall` and `/iq-waterfall` open. Images saved in `known_good/*-fresh-g32c3*`
(`pluto-fresh-g32c3.frm` md5 3987c80cc3d6ffa6cfe95863e1f79858); the previous build `*allfeat-gb6c3*` has the same sources.

**Test status:**
- Hardware-verified: full RF suite 70 ok / 0 FAIL / 30 sections / 30 of 30 restores, on the earlier builds with the same sources (newdash18, gb6c3);
  one hour soak; host libiio 0.26 and 1.0 clients over IP and USB; TX tone fix both directions.
- Fresh-clone build g32c3: flashed and booted on both boards, quick tone test OK both directions. The full suite was NOT rerun on it.
- Proposal branch (c470ce9): built from scratch, booted both boards, tone test OK. The full suite cannot run there (F5OEO main has no
  `/iq-waterfall`, every section fails with HTTP 404). Its first Pluto boot after flashing stopped in U-Boot (USB download gadget) and needed a
  power cycle; cause unknown, not seen on later flashes.
- Build-verified only: satdump, sdr_usb_gadget, pluto_stream, DATV, plutoskyr2 and the other boards.
- Not tested: Windows and macOS USB hosts, the Pluto's own USB link under load, Pluto+ flash writes above 16 MB.

**Nothing from the upgrade has gone to F5OEO or ADI.** Open decisions: open the F5OEO PR (a draft there still notifies maintainers; the
PR text is written for F5OEO, ask first with exact title and text); where the kernel branch lives (recommended: send the DAC fix to ADI first,
then pin ADI); post the ADI issue / PR. Local only: `known_good/` images, memory notes, scratchpad. U-Boot work needs a UART adapter and
a recovery path before any QSPI write.

Build notes: `BR2_DL_DIR=/home/mb/code/tezuka_fw-all/buildroot/dl`, `source sourceme.first`, `./build.sh -j16 <board>` (about 22 min per board
from scratch); Pluto+ SD image from `build/plutoplus.zip`; after a libiio change dirclean libiio, libiio0 and every consumer.

## 8. Upstream status check, 2026-10-28

Read-only check of GitHub: all 22 of your open PRs (maia-sdr #12, #14 to #23; tezuka_fw #486 to #493, #498, #500, #504) are unchanged and mergeable; no review and no merge. F5OEO's only comments are the two on tezuka_fw #500
of 2026-10-17 (one PR per release, and squash; #500 is already one commit). No comments from anyone but you on maia-sdr #12, #14, #15, #23 or tezuka_fw #486, #488. Heads: tezuka_fw main `a304a1f` (2026-10-17), release v0.3.24 (2026-10-17),
maia-sdr refactor `5f28808` (2026-10-20), maia-sdr main `c49db1f` (2025-11-21). Draft PR #27 (system upgrade) is open on your own fork only, no comments. Nothing about the upgrade, the RT work or the network buffer-loss findings has been posted to F5OEO or ADI.
For the 2026-10-25 RT and network-loss session see the memory file `project_rt_upgrade_2026_10_25.md` and `session-2026-10-25-rt/` in this tree's parent folder.
