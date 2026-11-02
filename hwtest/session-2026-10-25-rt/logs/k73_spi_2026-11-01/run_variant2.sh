#!/bin/bash
# usage: run_variant.sh NAME RUNS 'board setup command'
set -u
NAME=$1; RUNS=$2; SETUP=$3; SH=${STREAM_HOST:-192.168.4.1}; FSV=${FS:-5000000}
S=/tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad; K=$S/k73spi; O=$K/$NAME; mkdir -p $O
H=192.168.4.1
SSH="sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@$H"
log(){ echo "$(date +%H:%M:%S) $*" | tee -a $O/run.log; }
log "== variant $NAME, $RUNS rounds; reboot board"
timeout 15 $SSH 'sync; reboot' || true
sleep 25
for i in $(seq 60); do timeout 10 $SSH true 2>/dev/null && break; sleep 5; done
info=$(timeout 20 $SSH 'echo $(uname -r) $(cat /sys/kernel/config/usb_gadget/*/strings/*/serialnumber 2>/dev/null | head -1)')
log "board: $info"
case "$info" in 7.3.0-rc7*WZ5Z6HQZ6IXHI5QI*) ;; *) log "ABORT: not the Pluto+ on 7.3"; exit 1;; esac
sleep 60
timeout 20 $SSH 'cat > /tmp/prio.sh' < $K/prio.sh
timeout 20 $SSH 'cat > /tmp/mon_board.sh' < $K/mon_board.sh
timeout 30 $SSH 'cat > /tmp/rf_tx.bin' < $K/tone.bin
log "setup: $SETUP"
timeout 60 $SSH "$SETUP" >> $O/run.log 2>&1
log "radio: $(timeout 30 $SSH 'P=/sys/bus/iio/devices/iio:device1; [ "$(cat $P/name)" = ad9361-phy ] || { echo NOT_PHY; exit 9; }; echo 5000000 > $P/in_voltage_sampling_frequency; echo 1 > /sys/kernel/debug/iio/iio:device1/loopback; iio_writedev -c -b 65536 cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin > /dev/null 2>&1 & sleep 3; echo sf=$(cat $P/in_voltage_sampling_frequency) loopback=$(cat /sys/kernel/debug/iio/iio:device1/loopback) writer=$(pgrep iio_writedev | wc -l)')"
timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_before.txt
timeout 30 $SSH 'echo up=$(cut -d" " -f1 /proc/uptime); for f in control runtime_status autosuspend_delay_ms; do echo $f=$(cat /sys/bus/platform/devices/e0006000.spi/power/$f); done; echo spito=$(dmesg | grep -c "SPI transfer timed out")' > $O/state_before.txt
log "before: $(tr '\n' ' ' < $O/state_before.txt) ktimers: $(grep ktimers $O/prio_before.txt | tr '\n' ' ') spi_irq: $(grep e0006000 $O/prio_before.txt)"
( while [ ! -e $O/stop ]; do Lm=$(timeout 30 $SSH "sh /tmp/mon_board.sh" 2>&1); A=$(curl -s -m8 -o /dev/null -w "%{http_code}" http://$H/api/ad9361); echo "$(date +%H:%M:%S) $Lm api=$A" >> $O/mon.log; for j in $(seq 55); do [ -e $O/stop ] && break; sleep 1; done; done ) &
MON=$!
log "stream start (stream host $SH, fs $FSV, ping: $(ping -c5 -i0.3 -W1 $SH | tail -1))"
D=$O I1=$S/libiio1 HOSTP=$SH FS=$FSV NBS=32 RUNS=$RUNS SECS=5 python3 -u $K/drop73u.py > $O/stream.log 2>&1
log "stream end (ping: $(ping -c5 -i0.3 -W1 $SH | tail -1))"
touch $O/stop; wait $MON
rm -f $O/ol.bin
timeout 30 $SSH 'dmesg' > $O/dmesg_end.txt
timeout 30 $SSH 'sh /tmp/prio.sh' > $O/prio_after.txt
timeout 30 $SSH 'kill $(pgrep iio_writedev) 2>/dev/null; sleep 1; echo -89 > /sys/bus/iio/devices/iio:device1/out_voltage0_hardwaregain; echo tx_muted'  >> $O/run.log 2>&1
n=$(grep -c 'SPI transfer timed out' $O/dmesg_end.txt)
log "RESULT $NAME: $(grep SUMMARY $O/stream.log) | SPI timeouts $n | first: $(grep -m1 'SPI transfer timed out' $O/dmesg_end.txt)"
