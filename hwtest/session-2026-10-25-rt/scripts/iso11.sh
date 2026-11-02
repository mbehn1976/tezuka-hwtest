SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
$S 'for t in /proc/$(pidof iiod)/task/*; do taskset -p 2 $(basename $t) > /dev/null; done; echo 1 > /proc/irq/31/smp_affinity; nohup sh -c "taskset -c 0 stress-ng --vm 1 --vm-bytes 32M --timeout 700s > /tmp/stress_vm.txt 2>&1" > /dev/null 2>&1 & nohup sh -c "cyclictest -t1 -p98 -i250 -a1 -D 700s -m -q > /tmp/soak_cyc.txt 2>&1" > /dev/null 2>&1 &'
nohup python3 $SP/ws_load.py 700 > $SP/ws_load_soak.log 2>&1 &
LP=$!
rm -f $SP/ts_round*.npy
NBS=32 FSL=10 RUNS=40 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso11.log 2>&1
kill $LP 2>/dev/null
echo "rounds done: $(grep -c '^10.0 nb32 round' $SP/outlier_ts_iso11.log), incomplete: $(grep -c 'full=False' $SP/outlier_ts_iso11.log)"
echo "pid iiod: $($S 'pidof iiod')"
$S 'pkill stress-ng; free | head -2; cat /tmp/iiod_exit.log 2>&1; ls /tmp/core.* 2>&1'
echo ALLDONE
