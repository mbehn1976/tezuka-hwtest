SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
OUT=$SP/soak_out; mkdir -p $OUT
echo "catcher armed? iiod=$($S 'pidof iiod; ps | grep -c "[i]iod_wrap"; ulimit -c; cat /proc/sys/kernel/core_pattern')"
$S 'rm -f /tmp/iiod_exit.log; for t in /proc/$(pidof iiod)/task/*; do taskset -p 2 $(basename $t) > /dev/null; done; echo 1 > /proc/irq/31/smp_affinity'
sshpass -p analog scp -O $O $SP/soak_mon.sh root@192.168.3.1:/tmp/
$S 'nohup sh /tmp/soak_mon.sh > /dev/null 2>&1 &'
nohup python3 $SP/ws_load.py 7300 > $OUT/ws_load.log 2>&1 &
rm -f $SP/ts_round*.npy
(NBS=32 FSL=10 RUNS=440 python3 $SD/outlier_ts.py > $OUT/outlier_ts.log 2>&1; echo STREAM_ENDED > $OUT/stream_ended) &
START=$(date +%s)
collect() { $S 'cat /tmp/soak_mon.log' > $OUT/soak_mon.log 2>/dev/null; $S 'cat /tmp/soak_cyc.log' > $OUT/soak_cyc.log 2>/dev/null; }
while [ ! -f $OUT/stream_ended ] && [ $(( $(date +%s) - START )) -lt 7500 ]; do
  sleep 60; collect
  if ! $S 'pidof iiod' > /dev/null 2>&1; then
    echo "IIOD GONE at $(date)"; $S 'cat /tmp/iiod_exit.log; ls -la /tmp/core.* ; dmesg | tail -n 40; tail -n 5 /tmp/soak_mon.log' > $OUT/iiod_death.txt 2>&1
    $S 'cp /tmp/core.* /tmp/ 2>/dev/null'; echo "death evidence in $OUT/iiod_death.txt"; break
  fi
done
collect
echo "rounds: $(grep -c '^10.0 nb32 round' $OUT/outlier_ts.log), incomplete: $(grep -c 'full=False' $OUT/outlier_ts.log), with outliers: $(grep '^10.0 nb32 round' $OUT/outlier_ts.log | grep -vc 'outliers=0')"
echo ALLDONE
