# board side: once a second, iiod threads (comm:state:wchan), open IIO buffer fds, iiod TCP connections, RX DMA irq
rm -f /tmp/trig_mon.log
while true; do
  P=$(pidof iiod)
  th=""; for t in /proc/$P/task/*; do th="$th $(cat $t/comm | cut -c1-8):$(sed 's/.*) //' $t/stat | cut -c1):$(cat $t/wchan | cut -c1-12)"; done
  echo "$(cut -d' ' -f1 /proc/uptime) n=$(ls /proc/$P/task | wc -l) iiofd=$(ls -l /proc/$P/fd 2>/dev/null | grep -c 'iio:buffer') conn=[$(netstat -tn 2>/dev/null | grep ':30431' | tr -s ' ' | cut -d' ' -f6 | sort | uniq -c | tr '\n' ' ')] irq27=$(grep ' 27:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3) buf=$(cat /sys/bus/iio/devices/iio:device3/buffer/enable) th=[$th]" >> /tmp/trig_mon.log
  sleep 1
done
