#!/bin/bash
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SSH="sshpass -p analog ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1"
run() { label=$1; shift
  $SSH 'sync; reboot' >/dev/null 2>&1; sleep 30
  for i in $(seq 1 30); do u=$($SSH 'cut -d. -f1 /proc/uptime' 2>/dev/null); [ -n "$u" ] && [ "$u" -lt 150 ] && break; sleep 5; done; sleep 25
  [ -e /sys/bus/usb/devices/3-6.1 ] || { echo "[$label] no usb after boot"; return; }
  echo "[$label] $* -> $(cd ~/code/maia-sdr-bp/maia-hdl/hwtest && timeout 300 ~/.venvs/pluto-test/bin/python $S/tx_restart2.py "$@" 2>&1 | tail -1)"; }
run V0_repeat_original
run V1_noise_data --data noise
run V2_tone_gain_m89 --gain -89
run V3_no_verification_calls --check no
echo VTRIALS_DONE
