# Back-to-back iiod client cycles with no gap, default image. Stops at the first hang and leaves the board as is.
SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
I1=$SP/libiio1_host/inst
export LD_LIBRARY_PATH=$I1/lib:$I1/lib64
OUT=$SP/fastrc_out; rm -rf $OUT; mkdir -p $OUT
hb() { echo "$(date '+%F %T') $*" >> $OUT/heartbeat.log; }
$S 'iio_attr -q -c ad9361-phy voltage0 sampling_frequency 10000000' > /dev/null
sshpass -p analog scp -O $O $SD/trig_mon.sh root@192.168.3.1:/tmp/ > /dev/null 2>&1
$S 'pkill -f [t]rig_mon.sh'; $S 'nohup sh /tmp/trig_mon.sh > /dev/null 2>&1 &'
snap() { $S 'cat /tmp/trig_mon.log' > $OUT/trig_mon_$1.log 2>/dev/null
  $S 'P=$(pidof iiod); for t in /proc/$P/task/*; do echo "$(cat $t/comm) $(sed "s/.*) //" $t/stat | cut -c1) $(cat $t/wchan)"; done; netstat -tn | grep 30431; grep " 27:" /proc/interrupts' > $OUT/threads_$1.txt 2>&1; }
cycle() { # name n mode(full|kill) ; no gap between cycles
  local N=$1 R=$2 M=$3 bad=0
  hb "phase $N start: $R cycles, mode $M"
  for i in $(seq $R); do
    t0=$(date +%s.%N)
    if [ $M = kill ]; then
      timeout -s KILL $(awk "BEGIN{print 0.2+($RANDOM%100)/100}") $I1/bin/iio_rwdev -u ip:192.168.3.1 -b 262144 -s 100000000 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>&1; rc=$?
      # next cycle follows at once; every 10th is a verifying read
      if [ $((i % 10)) -eq 0 ]; then timeout 20 $I1/bin/iio_rwdev -u ip:192.168.3.1 -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2> $OUT/err_$N.txt; rc=$?; else rc=0; fi
    else
      timeout 20 $I1/bin/iio_rwdev -u ip:192.168.3.1 -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2> $OUT/err_$N.txt; rc=$?
    fi
    t1=$(date +%s.%N)
    echo "$N $i rc=$rc dt=$(awk "BEGIN{printf \"%.2f\", $t1-$t0}")" >> $OUT/cycles.log
    if [ $rc -ne 0 ]; then bad=1; hb "phase $N HANG/FAIL at cycle $i rc=$rc"; snap $N; echo "$N: FAIL at cycle $i (rc $rc)" | tee -a $OUT/summary.txt; return 1; fi
    [ $((i % 100)) -eq 0 ] && hb "phase $N cycle $i ok"
  done
  echo "$N: ok, $R cycles" | tee -a $OUT/summary.txt; return 0
}
LOADCMD='nohup stress-ng --cpu 2 -t 0 > /dev/null 2>&1 &'
cycle F1_idle 400 full &&
{ $S "$LOADCMD"; cycle F2_cpu2 400 full; r=$?; $S 'pkill stress-ng'; [ $r = 0 ]; } &&
cycle F3_kill_idle 300 kill &&
{ $S "$LOADCMD"; cycle F4_kill_cpu2 300 kill; r=$?; $S 'pkill stress-ng'; [ $r = 0 ]; }
echo FAST_DONE >> $OUT/summary.txt; hb done
