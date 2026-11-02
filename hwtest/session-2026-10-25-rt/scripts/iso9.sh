SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
live() { $S 'pidof iiod > /dev/null || { echo IIOD_DEAD; exit; }; timeout 8 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>&1; echo $?'; }
setpol() { $S "for t in /proc/\$(pidof iiod)/task/*; do b=\$(basename \$t); taskset -p 2 \$b > /dev/null; $1 \$b; done; for t in /proc/\$(pidof iiod)/task/*; do b=\$(basename \$t); echo \$(cat \$t/comm) \$(chrt -p \$b | tail -2 | tr '\n' ' '); done"; }
$S 'echo 1 > /proc/irq/31/smp_affinity'
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $SP/tev.sh root@192.168.3.1:/tmp/ 2>/dev/null || sshpass -p analog scp -O $O $SP/tev.sh root@192.168.3.1:/tmp/
$S "mount -t debugfs none /sys/kernel/debug 2>/dev/null; ls /sys/kernel/debug/tracing | head -3"
for v in "E1_events x 1"; do
  set -- $v; n=$1
  echo "== $n"
  case $n in *) POL='chrt -o -p 0';; esac
  setpol "$POL"
  echo "liveness before (0 = ok): $(live)"
  if [ $3 = 1 ]; then CMD="sh /tmp/tev.sh 6 90 50 > /tmp/iso_cyc_$n.txt 2>&1"; else CMD="cyclictest -t1 -p98 -i250 -a1 -D 140s -m -q > /tmp/iso_cyc_$n.txt 2>&1"; fi
  $S "nohup sh -c \"$CMD\" > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py 400 > $SP/ws_load_$n.log 2>&1 &
  LP=$!; sleep 4
  rm -f $SP/ts_round*.npy
  NBS=32 FSL=10 RUNS=20 python3 $SD/outlier_ts.py > $SP/outlier_ts_iso9_$n.log 2>&1
  mkdir -p $SP/ts_iso9_$n; mv $SP/ts_round*.npy $SP/ts_iso9_$n/ 2>/dev/null
  kill $LP 2>/dev/null
  for i in $(seq 40); do r=$($S "grep -E 'try 6' /tmp/iso_cyc_$n.txt" 2>/dev/null); [ -n "$r" ] && break; sleep 5; done
  echo "cyclictest ($n): $($S "cat /tmp/iso_cyc_$n.txt")"
  [ $3 = 1 ] && mkdir -p $SP/tev; sshpass -p analog scp -O $O "root@192.168.3.1:/tmp/tev_*.txt" $SP/tev/
  echo "liveness after (0 = ok): $(live)"
  echo "DONE_$n"
done
$S "for t in /proc/\$(pidof iiod)/task/*; do b=\$(basename \$t); chrt -o -p 0 \$b; taskset -p 1 \$b > /dev/null; done"; $S 'echo 3 > /proc/irq/31/smp_affinity'
echo ALLDONE
