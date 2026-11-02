# Provoke the RX stream wedge on the default image with escalating CPU/memory load and capture the state at the first stall.
# Board stays as it is after a stall (no reboot).
SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
OUT=$SP/wedge_out; rm -rf $OUT; mkdir -p $OUT
hb() { echo "$(date '+%F %T') $*" >> $OUT/heartbeat.log; }
REGS='for a in 0x7c400080 0x7c400084 0x7c400088 0x7c400400 0x7c400404 0x7c400408 0x7c40040c 0x7c400410 0x7c400414 0x7c400418 0x7c40041c 0x7c400420 0x7c400424 0x7c400428 0x7c40042c 0x7c400430 0x7c400434 0x7c400438 0x79020000 0x79020004 0x79020040 0x79020044 0x79020048 0x7902005c 0x79020060 0x79020064 0x79020068; do echo $a $(devmem $a 32); done'
diag() { # dir reason
  { echo "STALL: $2 at $(date)"
    $S "uptime; echo iiod=\$(pidof iiod); echo ---dmesg; dmesg | tail -n 40; echo ---irq1; grep -E ' 27:| 28:| 31:' /proc/interrupts; echo ---regs1; $REGS; sleep 3; echo ---irq2; grep -E ' 27:| 28:| 31:' /proc/interrupts; echo ---regs2; $REGS; echo ---ps; ps | grep -E '[i]iod|[s]tress|[m]aia'; echo ---mem; head -n 5 /proc/meminfo; grep -E 'Dirty|Slab|CmaFree' /proc/meminfo; echo ---ensm; cat /sys/bus/iio/devices/iio:device1/ensm_mode; echo ---dmaengine; ls /sys/kernel/debug/dmaengine; cat /sys/kernel/debug/dmaengine/summary 2>&1 | head -n 20"
    echo ---stress-stop; $S 'pkill stress-ng; sleep 2; echo stopped'
    echo ---local-reader-iiod-alive; $S 'timeout 15 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 2>&1 > /dev/null | tail -n 3; echo rc=$?'
    echo ---network-reader-load-gone; timeout 40 python3 - <<'EOF'
import subprocess
r=subprocess.run(['iio_readdev','-u','ip:192.168.3.1','-b','65536','-s','262144','cf-ad9361-lpc','voltage0','voltage1'],capture_output=True,timeout=35)
print('rc',r.returncode,len(r.stdout),r.stderr[-200:])
EOF
    echo ---iiod-stopped-local-reader; $S 'pkill iiod; sleep 2; echo iiod=$(pidof iiod); timeout 15 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 2>&1 > /dev/null | tail -n 3; echo rc=$?; grep -E " 27:" /proc/interrupts; dmesg | tail -n 8'
  } > $1/stall_diag.txt 2>&1
}
stage() { # name rounds stress-args
  local N=$1 R=$2 ST=$3 D=$OUT/$1; mkdir -p $D
  hb "stage $N start: rounds=$R stress-ng $ST"
  $S 'pidof iiod' > /dev/null 2>&1 || { echo "iiod not running at stage start" > $D/stall_diag.txt; return 1; }
  [ -n "$ST" ] && $S "nohup stress-ng $ST -t 0 > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py $((R * 15 + 600)) > $D/ws_load.log 2>&1 & local WL=$!
  rm -f $SP/ts_round*.npy
  (NBS=32 FSL=10 RUNS=$R python3 $SD/outlier_ts.py > $D/outlier_ts.log 2>&1) & local CL=$!
  local RES=ok
  while kill -0 $CL 2>/dev/null; do
    sleep 20
    hb "stage $N rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log) incomplete $(grep -c 'full=False' $D/outlier_ts.log)"
    if ! $S 'pidof iiod' > /dev/null 2>&1; then RES=FAIL; diag $D "iiod not running"; break; fi
    case "$(grep '^10.0 nb32 round' $D/outlier_ts.log | tail -n 1)" in *full=False*) RES=FAIL; diag $D "incomplete round"; break;; esac
  done
  [ $RES = ok ] && ! grep -q SUMMARY $D/outlier_ts.log && { RES=FAIL; diag $D "client ended without summary"; }
  pkill -f "[o]utlier_ts.py"; kill $WL 2>/dev/null; sleep 3
  [ $RES = ok ] && $S 'pkill stress-ng; true' > /dev/null 2>&1
  mkdir -p $D/ts; mv $SP/ts_round*.npy $D/ts/ 2>/dev/null
  echo "stage $N: $RES, rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log), incomplete $(grep -c 'full=False' $D/outlier_ts.log), rounds with outliers $(grep '^10.0 nb32 round' $D/outlier_ts.log | grep -vc 'outliers=0')" | tee -a $OUT/summary.txt
  hb "stage $N end: $RES"
  [ $RES = ok ]
}
stage S0_ws_only 15 "" &&
stage S1_cpu2 40 "--cpu 2" &&
stage S2_cpu2_vm2 40 "--cpu 2 --vm 2 --vm-bytes 48M" &&
stage S3_cpu4_vm2_hdd 40 "--cpu 4 --vm 2 --vm-bytes 48M --hdd 1 --hdd-bytes 32M"
echo HUNT_DONE >> $OUT/summary.txt; hb done
