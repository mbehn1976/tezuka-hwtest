SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
run() { rm -f $SP/ts_round*.npy; NBS=4 FSL=10 RUNS=60 python3 $SD/outlier_ts.py > $SP/outlier_ts_$1.log 2>&1; mkdir -p $SP/ts_$1; mv $SP/ts_round*.npy $SP/ts_$1/; }
echo "== paused (2)"
$S 'kill -STOP $(ps | grep "[a]pi_controller" | awk "{print \$1}")'; sleep 5
$S 'a=$(grep " 30:" /proc/interrupts | awk "{print \$2}"); sleep 3; b=$(grep " 30:" /proc/interrupts | awk "{print \$2}"); echo irq30/s $(( (b-a)/3 ))'
run paused2
$S 'kill -CONT $(ps | grep "[a]pi_controller" | awk "{print \$1}")'; echo P_DONE
sleep 10
echo "== baseline (2)"
$S 'a=$(grep " 30:" /proc/interrupts | awk "{print \$2}"); sleep 3; b=$(grep " 30:" /proc/interrupts | awk "{print \$2}"); echo irq30/s $(( (b-a)/3 ))'
run baseline2
echo B_DONE; $S 'dmesg | grep -c "SPI transfer timed out"; uptime'; echo ALLDONE
