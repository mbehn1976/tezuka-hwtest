#!/bin/bash
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SSH="sshpass -p analog ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@192.168.3.1"
P=/sys/bus/iio/devices/iio:device0
usb() { [ -e /sys/bus/usb/devices/3-6.1 ]; }
restore() { $SSH 'echo disconnect > /sys/class/udc/ci_hdrc.0/soft_connect; sleep 3; echo connect > /sys/class/udc/ci_hdrc.0/soft_connect' >/dev/null 2>&1; for i in $(seq 1 20); do usb && break; sleep 1; done; sleep 20; }
exp() { # label, command
  usb || { echo "[$1] usb not present before start, restoring"; restore; }
  sleep 15; usb || { echo "[$1] dropped while idle before the step"; restore; }
  echo "[$1] apply: $2  ($(date +%T))"; t0=$(date +%s.%N)
  timeout 30 $SSH "$2" >/dev/null 2>&1
  tdone=$(date +%s.%N); printf "   command took %.1f s\n" $(echo "$tdone - $t0" | bc)
  for i in $(seq 1 180); do
    if ! usb; then
      printf "   >>> USB DROP %.1f s after the step started\n" $(echo "$(date +%s.%N) - $t0" | bc)
      echo "   PORTSC=$($SSH 'devmem 0xE0002184 32' 2>&1)  state=$($SSH 'cat /sys/class/udc/ci_hdrc.0/state' 2>&1)"
      restore; return
    fi; sleep 0.5
  done
  echo "   stable for 90 s"
}
exp E0_control_idle "true"
exp E1_sample_rate_61p44 "echo 61440000 > $P/in_voltage_sampling_frequency"
exp E2_bandwidth "echo 49152000 > $P/in_voltage_rf_bandwidth; echo 49152000 > $P/out_voltage_rf_bandwidth"
exp E3_lo_and_gain "echo 2400000000 > $P/out_altvoltage1_TX_LO_frequency; echo 0 > $P/out_voltage0_hardwaregain; echo 2400000000 > $P/out_altvoltage0_RX_LO_frequency; echo manual > $P/in_voltage0_gain_control_mode; echo 40 > $P/in_voltage0_hardwaregain"
exp E4_start_tx_cyclic "dd if=/dev/urandom of=/tmp/rf_tx.bin bs=1024 count=16 2>/dev/null; (iio_writedev -c -b 4096 cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin > /tmp/rf_tx.log 2>&1 &) ; sleep 1"
echo EXP_DONE
