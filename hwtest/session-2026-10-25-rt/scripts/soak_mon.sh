# board side: health line every 10 s, cyclictest in 10 min segments (max per segment)
( while true; do
    echo "$(cut -d' ' -f1 /proc/uptime) iiod=$(pidof iiod | tr ' ' ',') load=$(cut -d' ' -f1-3 /proc/loadavg) memfree=$(grep MemAvailable /proc/meminfo | tr -s ' ' | cut -d' ' -f2) irq27=$(grep ' 27:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3,4) eth31=$(grep ' 31:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3,4)"
    sleep 10
  done > /tmp/soak_mon.log 2>&1 ) &
( for i in $(seq 12); do
    echo "seg $i uptime $(cut -d' ' -f1 /proc/uptime): $(cyclictest -t1 -p98 -i250 -a1 -D 600s -m -q | grep 'Max')"
  done > /tmp/soak_cyc.log 2>&1 ) &
