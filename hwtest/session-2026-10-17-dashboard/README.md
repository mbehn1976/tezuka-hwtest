# Session 2026-10-17: dashboard axes, peak markers, Complex I/Q page (tezuka_fw PR 500), rf_phase_check fix (maia-sdr PR 12)

State at the end of the session (all work is committed and pushed; nothing uncommitted):

| Repo / worktree | Branch | Head | Pushed to |
|---|---|---|---|
| ~/code/tezuka_fw-dash | dashboard-axes-complex-iq | 4858b40 (single commit, PR 500) | fork origin, PR F5OEO/tezuka_fw#500 |
| ~/code/tezuka_fw-all | test/allfixes-pr12-layout-main | 86a1b86 (all fixes + PR12 layout + upstream main a304a1f + dashboard) | fork origin |
| ~/code/maia-sdr-bp | test/spectrometer-backpressure | 5006f53 | fork origin/feature/spectrometer-raw-complex-capture = PR F5OEO/maia-sdr#12 |
| ~/code/maia-sdr-iqtest | test/allfixes-pr12-iqfix | 4d520ad | fork origin; source of the bitstreams and (via local.mk MAIA_HTTPD_OVERRIDE_SRCDIR) of maia-httpd in the test images |

Local backup branches in tezuka_fw-dash: dashboard-axes-complex-iq-presquash (18d302e, 17 commits), -prerebase (40b90e2), -preconsolidate (0561982), -presync (ea1a344).

Images (known_good/): pluto-allfixes-pr12-layout-main-newdash{3..7}.frm, sdimg-allfixes-pr12-layout-main-newdash{3..7}/ (newdash6 and 7 have the same dashboard bundle, md5 62753bfa1dcd1db14453cf7c093c01fd).

This folder: scripts/ (suite.sh, ref.py, sig.py, tx.py, lag.py, simphase.py, hwhalf.py, rf_phase_check_old.py, mock.py, build2.sh, rebuild.sh), logs/ (suite_*.log of every image test, build outputs), pr-texts/ (PR 500 description source pr500_body.md and the comment bodies c*.md), screenshots/ (all browser screenshots taken), index_final.html.
The scripts expect the scratchpad layout (paths inside point to the old scratchpad directory and ~/code/maia-sdr-bp/maia-hdl/hwtest); adjust before reuse.

Open: waiting for F5OEO. Question on maia-sdr PR 12 (issuecomment-6240114866) about how to deliver the Pluto/Pluto+ bitstreams and the device-tree nodes to tezuka_fw. Nothing may be sent to tezuka_fw before the answer. Full state and open items: memory note project_dashboard_axes_complex_iq.md.
