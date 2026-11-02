# usage: tev.sh <count> <thresh_us> <secs-per-try>: event trace (no stacks), cyclictest -b breaks the trace on the first latency > thresh
T=/sys/kernel/debug/tracing; cd $T
echo nop > current_tracer; echo 0 > tracing_on; echo 8192 > buffer_size_kb
echo 0 > events/enable
for e in sched/sched_switch sched/sched_wakeup irq/irq_handler_entry irq/irq_handler_exit irq/softirq_entry irq/softirq_exit timer/hrtimer_expire_entry timer/hrtimer_expire_exit; do echo 1 > events/$e/enable; done
i=1
while [ $i -le $1 ]; do
  echo > trace; echo 1 > tracing_on
  cyclictest -t1 -p98 -i250 -a1 -D $3s -m -q -b $2 --tracemark > /tmp/tev_cyc_$i.txt 2>&1
  echo 0 > tracing_on
  grep -E "^ *.*\[001\]" trace | tail -n 120 > /tmp/tev_$i.txt
  echo "try $i: $(grep -E 'Max|Latency|exceeded|stopped' /tmp/tev_cyc_$i.txt | tail -1)"
  i=$((i+1))
done
echo 0 > events/enable
