#!/bin/bash
cd ~/code/maia-sdr-bp/maia-hdl/hwtest
PY=~/.venvs/pluto-test/bin/python
run_board() {  # name rxhost txhost rxgain offset
  echo "######## RX=$1"
  for fs in 2500000 10000000 20000000 30720000 61440000; do
    echo "== $1 iq $fs"; timeout 600 $PY rf_iq_check.py --fs $fs --tx $3 --rx $2 --rx-gain $4 2>&1 | tail -5 | cut -c1-400
    echo "== $1 phase $fs"; timeout 900 $PY rf_phase_check.py --fs $fs --tx $3 --rx $2 --rx-gain $4 2>&1 | tail -4 | cut -c1-420
    echo "== $1 frame $fs"; timeout 300 $PY rf_iq_frame_phase_check.py --fs $fs --tx $3 --rx $2 --rx-gain $4 2>&1 | tail -2 | cut -c1-600
  done
}
run_board Pluto 192.168.2.1 192.168.3.1 52 48900
run_board Pluto+ 192.168.3.1 192.168.2.1 40 -49500
echo SUITE_DONE
