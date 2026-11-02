# board side: usage soak_mon2.sh <duration_s> <cyclictest_prio> <cyclictest_cpu>
DUR=$1; P=$2; C=$3
echo 1 > /proc/sys/kernel/print-fatal-signals
rm -f /tmp/soak_mon.log /tmp/soak_cyc.log
( while true; do
    echo "$(cut -d' ' -f1 /proc/uptime) iiod=$(pidof iiod | tr ' ' ',') load=$(cut -d' ' -f1-3 /proc/loadavg) memavail=$(grep MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2) dmesg_lines=$(dmesg | wc -l) irq27=$(grep ' 27:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3,4) eth31=$(grep ' 31:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3,4)"
    sleep 10
  done >> /tmp/soak_mon.log 2>&1 ) &
( n=$((DUR / 600)); i=1; while [ $i -le $n ]; do
    echo "seg $i uptime $(cut -d' ' -f1 /proc/uptime): $(cyclictest -t1 -p$P -i250 -a$C -D 600s -m -q | grep Max)"
    i=$((i+1))
  done >> /tmp/soak_cyc.log 2>&1 ) &
