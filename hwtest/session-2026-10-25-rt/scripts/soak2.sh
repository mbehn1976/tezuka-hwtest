SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
OUT=$SP/soak2_out; mkdir -p $OUT
hb() { echo "$(date '+%F %T') $*" >> $OUT/heartbeat.log; }
wait_up() { for i in $(seq 60); do $S 'pidof iiod' > /dev/null 2>&1 && return 0; sleep 5; done; return 1; }
collect() { $S 'cat /tmp/soak_mon.log' > $1/soak_mon.log 2>/dev/null; $S 'cat /tmp/soak_cyc.log' > $1/soak_cyc.log 2>/dev/null; }
diag() { # dir reason
  { echo "FAIL: $2 at $(date)"; $S 'uptime; echo iiod=$(pidof iiod); cat /proc/cmdline; echo ---dmesg; dmesg | tail -n 60; echo ---interrupts; cat /proc/interrupts; echo ---ps; ps; echo ---mem; head -n 5 /proc/meminfo; echo ---ensm; cat /sys/bus/iio/devices/iio:device1/ensm_mode 2>&1; echo ---local-reader; timeout 8 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 2>&1 > /dev/null | tail -n 3; echo rc=$?; echo ---messages; tail -n 40 /var/log/messages; echo ---mon; tail -n 20 /tmp/soak_mon.log; ls -la /tmp/core* 2>&1'; } > $1/fail_diag.txt 2>&1
}
phase() { # name duration_s cyc_prio cyc_cpu
  local N=$1 DUR=$2 P=$3 C=$4 D=$OUT/$1; mkdir -p $D
  hb "phase $N start: dur=$DUR cyclictest -p$P -a$C"
  wait_up || { echo "board not up" > $D/fail_diag.txt; return 1; }
  $S "echo 'cmdline:'; cat /proc/cmdline; echo isolated=[\$(cat /sys/devices/system/cpu/isolated)]; for t in /proc/\$(pidof iiod)/task/*; do b=\$(basename \$t); echo \$(cat \$t/comm) mask=\$(taskset -p \$b | sed 's/.*: //') \$(chrt -p \$b | sed -n 1,2p | sed 's/.*: //' | tr '\n' ' '); done; ps | grep -E '[c]yclictest|[s]oak_mon|[s]tress-ng'" > $D/placement.txt 2>&1
  sshpass -p analog scp -O $O $SP/soak_mon2.sh root@192.168.3.1:/tmp/ > /dev/null 2>&1
  $S "nohup sh /tmp/soak_mon2.sh $DUR $P $C > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py $((DUR + 600)) > $D/ws_load.log 2>&1 &
  WL=$!
  rm -f $SP/ts_round*.npy
  (NBS=32 FSL=10 RUNS=3000 python3 $SD/outlier_ts.py > $D/outlier_ts.log 2>&1) &
  local START=$(date +%s) RES=ok
  while [ $(( $(date +%s) - START )) -lt $DUR ]; do
    sleep 60; collect $D; hb "phase $N $(( $(date +%s) - START )) s, rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log 2>/dev/null)"
    if ! $S 'pidof iiod' > /dev/null 2>&1; then diag $D "iiod not running (or board unreachable)"; RES=FAIL; break; fi
    if ! pgrep -f "[o]utlier_ts.py" > /dev/null; then diag $D "outlier_ts client ended early"; RES=FAIL; break; fi
    last=$(grep '^10.0 nb32 round' $D/outlier_ts.log | tail -n 1)
    case "$last" in *full=False*) diag $D "incomplete round: $last"; RES=FAIL; break;; esac
  done
  pkill -f "[o]utlier_ts.py"; kill $WL 2>/dev/null; sleep 3
  collect $D
  [ $RES = ok ] && $S 'pkill soak_mon2.sh; pkill cyclictest; true' > /dev/null 2>&1
  mkdir -p $D/ts; mv $SP/ts_round*.npy $D/ts/ 2>/dev/null
  echo "phase $N: $RES, rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log), incomplete $(grep -c 'full=False' $D/outlier_ts.log), rounds with outliers $(grep '^10.0 nb32 round' $D/outlier_ts.log | grep -vc 'outliers=0')" | tee -a $OUT/summary.txt
  hb "phase $N end: $RES"
  [ $RES = ok ]
}
H=14400
if phase P1_default $H 98 0; then
  hb "switching SD to sdimg-rt21-sw-on"
  ( cd ~/tezuka-review-v0.3.23/hwtest && HOST=192.168.3.1 NOPOWER=1 $SP/sd_write_sg1.sh known_good/sdimg-rt21-sw-on > $OUT/sd_write_on.log 2>&1 )
  if phase P2_rt_isolcpus $H 99 1; then
    hb "restoring default SD image"
    ( cd ~/tezuka-review-v0.3.23/hwtest && HOST=192.168.3.1 NOPOWER=1 $SP/sd_write_sg1.sh known_good/sdimg-rt21-sw > $OUT/sd_write_default.log 2>&1 )
  fi
fi
echo SOAK_DONE >> $OUT/summary.txt; hb done
