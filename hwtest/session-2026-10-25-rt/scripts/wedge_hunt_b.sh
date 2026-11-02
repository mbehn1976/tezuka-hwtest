# Provoke the RX stream wedge on the default image with escalating CPU/memory load and capture the state at the first stall.
# Board stays as it is after a stall (no reboot).
SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
SD=/home/mb/tezuka-review-v0.3.23/hwtest/session-2026-10-25-rt/scripts
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
cd /home/mb/code/maia-sdr-bp/maia-hdl/hwtest; . /home/mb/.venvs/pluto-test/bin/activate
OUT=$SP/wedgeB_out; rm -rf $OUT; mkdir -p $OUT
hb() { echo "$(date '+%F %T') $*" >> $OUT/heartbeat.log; }
REGS='for a in 0x7c400080 0x7c400084 0x7c400088 0x7c400400 0x7c400404 0x7c400408 0x7c40040c 0x7c400410 0x7c400414 0x7c400418 0x7c40041c 0x7c400420 0x7c400424 0x7c400428 0x7c40042c 0x7c400430 0x7c400434 0x7c400438 0x79020000 0x79020004 0x79020040 0x79020044 0x79020048 0x7902005c 0x79020060 0x79020064 0x79020068; do echo $a $(devmem $a 32); done'
forensics() { # dir: first thing at a stall, before diag touches anything
  { echo "=== forensics $(date)"
    $S '
P=$(pidof iiod); echo "iiod pid=$P"
for t in /proc/$P/task/*; do echo "tid $(basename $t) $(cat $t/comm) state=$(sed "s/.*) //" $t/stat | cut -d" " -f1) wchan=$(cat $t/wchan) syscall=$(cut -d" " -f1,2 $t/syscall 2>/dev/null)"; done
echo "--- iiod stacks (if available)"; for t in /proc/$P/task/*; do [ -r $t/stack ] && { echo "tid $(basename $t)"; cat $t/stack; }; done 2>&1 | head -n 60
echo "--- processes holding iio devices"; for p in /proc/[0-9]*; do l=$(ls -l $p/fd 2>/dev/null | grep -i "iio"); [ -n "$l" ] && { echo "pid $(basename $p) $(cat $p/comm)"; echo "$l"; }; done
echo "--- sysfs buffer state"; for f in /sys/bus/iio/devices/iio:device3/buffer/* /sys/bus/iio/devices/iio:device3/buffer0/* /sys/bus/iio/devices/iio:device3/scan_elements/*_en; do [ -f $f ] && echo "$f=$(cat $f 2>&1 | head -n 1)"; done
echo "--- hung task / warnings"; dmesg | grep -iE "hung|blocked for|BUG|WARN|rcu|oom|stall" | tail -n 10
echo "--- reader: where does a new local reader wait?"
( timeout 8 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>/tmp/rd0.err ) &
sleep 2; R=$(pidof iio_readdev | cut -d" " -f1); echo "reader pid=$R"
for t in /proc/$R/task/*; do echo "tid $(basename $t) wchan=$(cat $t/wchan) syscall=$(cut -d" " -f1-3 $t/syscall 2>/dev/null)"; done
ls -l /proc/$R/fd 2>/dev/null | grep -i iio; [ -r /proc/$R/stack ] && cat /proc/$R/stack; wait
tail -n 2 /tmp/rd0.err; which strace ltrace 2>&1 | head -n 2
echo "--- kill -9 iiod, then local reader again"
kill -9 $P; sleep 2; echo "iiod after kill -9: [$(pidof iiod)]"; grep " 27:" /proc/interrupts
( timeout 10 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>/tmp/rd1.err; echo rc=$? >> /tmp/rd1.err ) & wait; tail -n 3 /tmp/rd1.err; grep " 27:" /proc/interrupts; dmesg | tail -n 4'
  } > $1/forensics.txt 2>&1
}
diag() { # dir reason
  { echo "STALL: $2 at $(date)"
    $S "uptime; echo iiod=\$(pidof iiod); echo ---dmesg; dmesg | tail -n 40; echo ---irq1; grep -E ' 27:| 28:| 31:' /proc/interrupts; echo ---regs1; $REGS; sleep 3; echo ---irq2; grep -E ' 27:| 28:| 31:' /proc/interrupts; echo ---regs2; $REGS; echo ---ps; ps | grep -E '[i]iod|[s]tress|[m]aia'; echo ---mem; head -n 5 /proc/meminfo; grep -E 'Dirty|Slab|CmaFree' /proc/meminfo; echo ---ensm; cat /sys/bus/iio/devices/iio:device0/ensm_mode; echo ---dmaengine; ls /sys/kernel/debug/dmaengine; cat /sys/kernel/debug/dmaengine/summary 2>&1 | head -n 20"
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
ladder() { # dir: recovery attempts on the wedged board, after diag; every step is followed by a local reader and a DMAC sample
  { echo "=== ladder $(date)"
    $S '
rd() { a=$(grep " 27:" /proc/interrupts | tr -s " " | cut -d" " -f3); ( timeout 10 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 2>&1 >/dev/null | tail -n 1 ) & sleep 3; echo "  during read: ctrl=$(devmem 0x7c400400 32) xlen=$(devmem 0x7c400418 32) dest=$(devmem 0x7c400410 32) cur=$(devmem 0x7c400434 32) done=$(devmem 0x7c400428 32) active=$(devmem 0x7c40042c 32)"; wait; b=$(grep " 27:" /proc/interrupts | tr -s " " | cut -d" " -f3); echo "  irq27 delta $((b-a))"; }
echo "L0 state: rate=$(iio_attr -q -c ad9361-phy voltage0 sampling_frequency) clk=$(devmem 0x79020054 32) st5c=$(devmem 0x7902005c 32) st68=$(devmem 0x79020068 32) rstn=$(devmem 0x79020040 32)"
iio_attr -q -c ad9361-phy voltage0 sampling_frequency 10000000
echo "L1 base read"; rd
echo "L2 clear ADC DMA status (write 0xF to 0x68)"; devmem 0x79020068 32 0xF; echo "  st68=$(devmem 0x79020068 32)"; rd
echo "L3 ADC core reset: RSTN 0 then 3 at 0x79020040"; devmem 0x79020040 32 0; sleep 0.2; devmem 0x79020040 32 3; sleep 0.5; echo "  rstn=$(devmem 0x79020040 32)"; rd
echo "L4 DMAC disable/enable cycle (write 0 then 1 to ctrl 0x7c400400)"; devmem 0x7c400400 32 0; sleep 0.2; devmem 0x7c400400 32 1; rd
dmesg | tail -n 5'
  } >> $1/stall_diag.txt 2>&1
}
stage() { # name rounds stress-args
  local N=$1 R=$2 ST=$3 D=$OUT/$1; mkdir -p $D
  hb "stage $N start: rounds=$R stress-ng $ST"
  $S 'pidof iiod' > /dev/null 2>&1 || { echo "iiod not running at stage start" > $D/stall_diag.txt; return 1; }
  [ -n "$ST" ] && $S "nohup taskset -c 0 stress-ng $ST -t 0 > /dev/null 2>&1 &"
  nohup python3 $SP/ws_load.py $((R * 15 + 600)) > $D/ws_load.log 2>&1 & local WL=$!
  rm -f $SP/ts_round*.npy
  (NBS=32 FSL=10 RUNS=$R python3 $SD/outlier_ts.py > $D/outlier_ts.log 2>&1) & local CL=$!
  local RES=ok
  while kill -0 $CL 2>/dev/null; do
    sleep 20
    hb "stage $N rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log) incomplete $(grep -c 'full=False' $D/outlier_ts.log)"
    if ! $S 'pidof iiod' > /dev/null 2>&1; then RES=FAIL; forensics $D; diag $D "iiod not running"; ladder $D; break; fi
    case "$(grep '^10.0 nb32 round' $D/outlier_ts.log | tail -n 1)" in *full=False*) RES=FAIL; forensics $D; diag $D "incomplete round"; ladder $D; break;; esac
  done
  [ $RES = ok ] && ! grep -q SUMMARY $D/outlier_ts.log && { RES=FAIL; forensics $D; diag $D "client ended without summary"; ladder $D; }
  pkill -f "[o]utlier_ts.py"; kill $WL 2>/dev/null; sleep 3
  [ $RES = ok ] && $S 'pkill stress-ng; true' > /dev/null 2>&1
  mkdir -p $D/ts; mv $SP/ts_round*.npy $D/ts/ 2>/dev/null
  echo "stage $N: $RES, rounds $(grep -c '^10.0 nb32 round' $D/outlier_ts.log), incomplete $(grep -c 'full=False' $D/outlier_ts.log), rounds with outliers $(grep '^10.0 nb32 round' $D/outlier_ts.log | grep -vc 'outliers=0')" | tee -a $OUT/summary.txt
  hb "stage $N end: $RES"
  [ $RES = ok ]
}
# placement variant B from iso4.sh: iiod (SCHED_OTHER) on core 0 with the hog, Ethernet IRQ 31 on core 1
$S 'for t in /proc/$(pidof iiod)/task/*; do taskset -p 1 $(basename $t) > /dev/null; done; echo 2 > /proc/irq/31/smp_affinity; taskset -p $(pidof iiod); cat /proc/irq/31/smp_affinity; cat /sys/devices/system/cpu/isolated' > $OUT/placement.txt 2>&1
stage B1_cpu1 60 "--cpu 1" &&
stage B2_cpu1_vm1 60 "--cpu 1 --vm 1 --vm-bytes 32M" &&
stage B3_cpu1_again 120 "--cpu 1"
echo HUNT_DONE >> $OUT/summary.txt; hb done
