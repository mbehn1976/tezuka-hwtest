SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
$S 'rm -f /tmp/iiod_exit.log; for t in /proc/$(pidof iiod)/task/*; do taskset -p 2 $(basename $t) > /dev/null; done; echo 1 > /proc/irq/31/smp_affinity'
echo "stray processes on board (must be empty): $($S 'ps | grep -E "[c]yclictest|[s]oak_mon|[s]tress-ng"')"
set_cfg() { # gso limit
  $S "ethtool -K eth0 gso $1 2>&1 | tail -1; sysctl -w net.ipv4.tcp_limit_output_bytes=$2 > /dev/null; echo gso=\$(ethtool -k eth0 | grep '^generic-segmentation' ) limit=\$(sysctl -n net.ipv4.tcp_limit_output_bytes)"
}
for v in "B0 on 1048576" "C1_gso_off off 1048576" "C2_limit64k on 65536" "C3_both off 65536" "B0b on 1048576"; do
  set -- $v; n=$1
  echo "== $n: $(set_cfg $2 $3)"
  $S "nohup sh -c \"cyclictest -t1 -p98 -i250 -a1 -D 300s -h 400 -q > /tmp/hist_$n.txt 2>&1\" > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py 330 > $SP/ws_load_$n.log 2>&1 &
  LP=$!; sleep 3
  rm -f $SP/ts_round*.npy
  NBS=32 FSL=10 RUNS=25 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso14_$n.log 2>&1
  mkdir -p $SP/ts_iso14_$n; mv $SP/ts_round*.npy $SP/ts_iso14_$n/ 2>/dev/null
  kill $LP 2>/dev/null
  for i in $(seq 40); do r=$($S "grep -c 'Max Latencies' /tmp/hist_$n.txt" 2>/dev/null); [ "$r" = 1 ] && break; sleep 5; done
  $S "grep -E 'Total|Max Lat|Avg Lat' /tmp/hist_$n.txt | tr -s ' '; awk '\$1 ~ /^[0-9]+\$/ {t+=\$2; if (\$1+0>=50) a+=\$2; if (\$1+0>=80) b+=\$2} END {printf \"samples %d, >=50us %d (%.4f%%), >=80us %d\\n\", t, a, 100*a/t, b}' /tmp/hist_$n.txt"
  echo "stream: $(grep SUMMARY $SP/outlier_ts_iso14_$n.log | sed 's/SUMMARY //')"
  echo "iiod alive: $($S 'pidof iiod'), exit log: $($S 'cat /tmp/iiod_exit.log 2>&1 | head -2')"
  echo "DONE_$n"
done
$S 'ethtool -K eth0 gso on; sysctl -w net.ipv4.tcp_limit_output_bytes=1048576'
echo ALLDONE
