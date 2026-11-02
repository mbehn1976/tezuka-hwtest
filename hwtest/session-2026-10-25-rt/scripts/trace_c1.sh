# usage: trace_c1.sh <secs> <tag>: wakeup_rt tracer (function tracing off), cyclictest p98 on core 1
T=/sys/kernel/debug/tracing; cd $T
echo 0 > tracing_on; echo nop > current_tracer
echo wakeup_rt > current_tracer; echo 0 > options/stacktrace; echo 0 > options/function-trace; echo 0 > tracing_max_latency; echo 1 > tracing_on
cyclictest -t1 -p98 -i250 -a1 -D $1s -m -q | tail -1
echo 0 > tracing_on
echo "max_latency_us: $(cat tracing_max_latency)"
cp trace /tmp/trace_c1_$2.txt; wc -l /tmp/trace_c1_$2.txt; echo nop > current_tracer; echo 1 > options/function-trace
