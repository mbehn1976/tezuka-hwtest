#!/bin/bash
# Build the Pluto and Pluto+ bitstreams from the merged maia-sdr branch (refactor layout, tezuka project).
# Needs: Vivado 2023.2, the maia-hdl python venv (~/.venvs/maia-hdl), and maia-hdl/adi-hdl checked out
# (copy it from another checkout if the worktree has no submodule). About 2 min for the IP cores, 7 min per board.
source /tools/Xilinx/Vivado/2023.2/settings64.sh >/dev/null
export LD_LIBRARY_PATH=/home/mb/.local/lib/compat:$LD_LIBRARY_PATH
export ADI_IGNORE_VERSION_CHECK=1
export PATH=$HOME/.venvs/maia-hdl/bin:$PATH
cd ~/code/maia-sdr-merge/maia-hdl/projects/tezuka || exit 1
make ip_cores > vivado_ip.log 2>&1; echo "ip_cores exit $?"
for b in pluto plutoplus; do
  d=../tz_$b; mkdir -p $d
  cp Makefile hold_fix.tcl system_bd.tcl system_project.tcl reset_timing.xdc $d/
  (cd $d && PROJECT_NAME=$b make -o ip_cores $b.sdk/system_top.xsa > vivado_$b.log 2>&1; echo "$b exit $?"; ls -la $b.sdk/system_top.xsa)
done
# then: cp tz_<board>/<board>.sdk/system_top.xsa to tezuka_fw board/tezuka/<board>/bitstream/tezuka.xsa and write tezuka.version
