SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
echo "kernel: $($S 'uname -r; echo isolated=[$(cat /sys/devices/system/cpu/isolated)]')"
echo "iiod (shipped start, no runtime pinning): $($S 'for t in /proc/$(pidof iiod)/task/*; do b=$(basename $t); echo $(cat $t/comm):mask=$(taskset -p $b | sed "s/.*: //"):$(chrt -p $b | sed -n 1p | sed "s/.*policy: //"); done' | tr '\n' ' ')"
echo "stray processes (must be empty): $($S 'ps | grep -E "[c]yclictest|[s]oak_mon|[s]tress-ng"')"
stats() { $S "grep -E 'Max Lat|Avg Lat' /tmp/hist_$1.txt | tr -s ' ' | tr '\n' ' '; awk '\$1 ~ /^[0-9]+\$/ {t+=\$2; if (\$1+0>=50) a+=\$2} END {printf \"samples %d, >=50us %d (%.4f%%)\\n\", t, a, 100*a/t}' /tmp/hist_$1.txt"; }
# P1 idle
echo "== P1 idle 120 s"
$S 'cyclictest -t1 -p99 -i250 -a1 -D 120s -h 400 -q > /tmp/hist_P1.txt 2>&1'; stats P1
# P2 stream + housekeeping load, P3 same + CPU hog on core 0
for n in P2_stream P3_stream_hog; do
  echo "== $n"
  [ $n = P3_stream_hog ] && $S 'nohup sh -c "taskset -c 0 stress-ng --cpu 1 --timeout 340s > /tmp/stress_p3.txt 2>&1" > /dev/null 2>&1 &'
  $S "nohup sh -c \"cyclictest -t1 -p99 -i250 -a1 -D 300s -h 400 -q > /tmp/hist_$n.txt 2>&1\" > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py 330 > $SP/ws_load_$n.log 2>&1 &
  LP=$!; sleep 3; rm -f $SP/ts_round*.npy
  NBS=32 FSL=10 RUNS=25 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso15_$n.log 2>&1
  mkdir -p $SP/ts_iso15_$n; mv $SP/ts_round*.npy $SP/ts_iso15_$n/ 2>/dev/null
  kill $LP 2>/dev/null
  for i in $(seq 40); do r=$($S "grep -c 'Max Latencies' /tmp/hist_$n.txt" 2>/dev/null); [ "$r" = 1 ] && break; sleep 5; done
  stats $n
  echo "stream: $(grep SUMMARY $SP/outlier_ts_iso15_$n.log | sed 's/SUMMARY //')"
  echo "iiod alive: $($S 'pidof iiod; pkill stress-ng; true')"
done
echo ALLDONE
