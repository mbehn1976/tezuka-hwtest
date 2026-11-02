#!/bin/sh
T=/sys/kernel/debug/tracing
if [ "$1" = start ]; then
  echo 0 > $T/tracing_on; echo nop > $T/current_tracer; echo > $T/set_ftrace_filter; echo 0 > $T/events/enable
  echo 30000 > $T/buffer_size_kb
  echo 1 > $T/events/timer/timer_expire_entry/enable; echo 1 > $T/events/timer/hrtimer_expire_entry/enable
  echo global > $T/trace_clock; echo > $T/trace; echo 1 > $T/tracing_on
else
  echo 0 > $T/tracing_on; cat $T/trace > /tmp/trace.txt; echo 0 > $T/events/enable; wc -l /tmp/trace.txt
fi
