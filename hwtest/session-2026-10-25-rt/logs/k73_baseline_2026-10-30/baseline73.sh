#!/bin/sh
# 7.3-rc7 PREEMPT_RT latency baseline: same cyclictest settings as the 6.12 runs
rm -f /tmp/ct_*.txt /tmp/stress_*.log /tmp/ct_done
for ph in idle cpu2 heavy; do
	case $ph in
	idle) ST="" ;;
	cpu2) ST="stress-ng --cpu 2 -t 330" ;;
	heavy) ST="stress-ng --cpu 4 --vm 2 --vm-bytes 96M --hdd 1 --hdd-bytes 32M -t 330" ;;
	esac
	echo "phase $ph start $(date +%T) up=$(cut -d' ' -f1 /proc/uptime)" >> /tmp/ct_progress.txt
	if [ -n "$ST" ]; then $ST > /tmp/stress_$ph.log 2>&1 & SP=$!; fi
	sleep 5
	cyclictest -m -t1 -p98 -i250 -a1 -D 300 -q -h 5000 > /tmp/ct_$ph.txt 2>&1
	[ -n "$ST" ] && { kill $SP 2>/dev/null; pkill stress-ng 2>/dev/null; sleep 3; }
	echo "phase $ph end $(date +%T) load=$(cut -d' ' -f1-3 /proc/loadavg)" >> /tmp/ct_progress.txt
	sleep 30
done
echo DONE > /tmp/ct_done
