SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
echo "== config"; $S 'cat /sys/devices/system/cpu/isolated; for t in /proc/$(pidof iiod)/task/*; do taskset -p $(basename $t); done | sort | uniq -c | head -3; which stress-ng'
$S 'nohup sh -c "taskset -c 0 stress-ng --cpu 1 --vm 1 --vm-bytes 32M --timeout 1020s > /tmp/stress.txt 2>&1" > /dev/null 2>&1 &'
sleep 3
$S 'nohup sh -c "cyclictest -t1 -p99 -i250 -a1 -D 1000s -m -q > /tmp/iso_cyc.txt 2>&1" > /dev/null 2>&1 &'
sleep 2
$S 'ps | grep -E "[s]tress-ng|[c]yclictest" | head -5'
rm -f $SP/ts_round*.npy
NBS=32 FSL=10 RUNS=60 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso_load.log 2>&1
mkdir -p $SP/ts_iso_load; mv $SP/ts_round*.npy $SP/ts_iso_load/
echo "== stream test done"
sleep 30
$S 'cat /tmp/iso_cyc.txt; tail -3 /tmp/stress.txt; dmesg | grep -c "SPI transfer timed out"; uptime'
echo ALLDONE
