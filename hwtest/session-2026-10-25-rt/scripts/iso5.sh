SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
live() { $S 'pidof iiod > /dev/null || { echo IIOD_DEAD; exit; }; timeout 8 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>&1; echo $?'; }
pin() { $S "for t in /proc/\$(pidof iiod)/task/*; do taskset -p $1 \$(basename \$t) > /dev/null; done; taskset -p \$(pidof iiod)"; }
# iiod on core 1 (RR 99), eth irq + all housekeeping on core 0; cyclictest core 1 at p98 (below iiod)
pin 2; $S 'echo 1 > /proc/irq/31/smp_affinity'
for n in H_load H_load_hog; do
  echo "== $n"; echo "liveness before (0 = ok): $(live)"
  [ $n = H_load_hog ] && $S 'nohup sh -c "taskset -c 0 stress-ng --cpu 1 --timeout 400s > /tmp/stress_h.txt 2>&1" > /dev/null 2>&1 &'
  $S "nohup sh -c \"cyclictest -t1 -p98 -i250 -a1 -D 330s -m -q > /tmp/iso_cyc_$n.txt 2>&1\" > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py 420 > $SP/ws_load_$n.log 2>&1 &
  LP=$!; sleep 5
  rm -f $SP/ts_round*.npy
  NBS=32 FSL=10 RUNS=20 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso5_$n.log 2>&1
  mkdir -p $SP/ts_iso5_$n; mv $SP/ts_round*.npy $SP/ts_iso5_$n/ 2>/dev/null
  kill $LP 2>/dev/null
  for i in $(seq 40); do r=$($S "grep Max /tmp/iso_cyc_$n.txt" 2>/dev/null); [ -n "$r" ] && break; sleep 5; done
  echo "cyclictest ($n): $r"
  echo "liveness after (0 = ok): $(live)"
  $S 'pkill stress-ng; sleep 2; uptime'
  echo "DONE_$n"
done
pin 1; $S 'echo 3 > /proc/irq/31/smp_affinity'
echo ALLDONE
