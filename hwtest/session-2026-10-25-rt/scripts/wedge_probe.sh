# board side, read-only register dumps plus a TX-side DMA test; usage: sh wedge_probe.sh
dump() { # base start end
  a=$2; while [ $a -le $3 ]; do printf "%s+%03X=%s\n" $1 $a $(devmem $(( $4 + a )) 32); a=$((a+4)); done; }
RXD=$((0x7c400000)); TXD=$((0x7c420000)); ADC=$((0x79020000)); MAIA=$((0x7c460000))
dumpall() { echo "## $1"
  echo "# RX DMAC"; dump RXD 0 $((0x4c)) $RXD; dump RXD $((0x80)) $((0x88)) $RXD; dump RXD $((0x400)) $((0x45c)) $RXD
  echo "# TX DMAC"; dump TXD 0 $((0x4c)) $TXD; dump TXD $((0x80)) $((0x88)) $TXD; dump TXD $((0x400)) $((0x45c)) $TXD
  echo "# ADC core"; dump ADC 0 $((0x7c)) $ADC; dump ADC $((0x400)) $((0x47c)) $ADC
  echo "irq27=$(grep ' 27:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3) irq28=$(grep ' 28:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3)"; }
echo "pidof iiod: $(pidof iiod)"
dumpall idle
echo "## during RX read (3 s in)"
( timeout 8 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 > /dev/null 2>/tmp/rd.err ) & sleep 3
dumpall rx_reading; wait; cat /tmp/rd.err | tail -n 2
echo "## TX test: iio_writedev zeros, 8 s timeout"
i27=$(grep ' 28:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3)
( timeout 8 sh -c 'head -c 4194304 /dev/zero | iio_writedev -u local: -b 65536 cf-ad9361-dds-core-lpc voltage0 voltage1' > /tmp/wr.out 2>&1; echo "wr rc=$?" >> /tmp/wr.out ) & sleep 2
dumpall tx_writing; wait; cat /tmp/wr.out | tail -n 3
echo "irq28 before=$i27 after=$(grep ' 28:' /proc/interrupts | tr -s ' ' | cut -d' ' -f3)"
echo "RX again after TX (does RX still fail?)"; timeout 10 iio_readdev -u local: -b 65536 -s 131072 cf-ad9361-lpc voltage0 voltage1 2>&1 >/dev/null | tail -n 1; echo rc=$?
dmesg | tail -n 5
