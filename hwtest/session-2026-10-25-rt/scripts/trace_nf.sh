# usage: trace_nf.sh <tracer> <secs>  (function tracing off inside the latency tracer)
T=/sys/kernel/debug/tracing; cd $T
echo 0 > tracing_on; echo nop > current_tracer
echo $1 > current_tracer; echo 0 > options/function-trace; echo 0 > tracing_max_latency; echo 1 > tracing_on
cyclictest -t1 -p90 -i250 -a0 -D $2s -m -q | tail -1
echo 0 > tracing_on
echo "max_latency_us: $(cat tracing_max_latency)"
cp trace /tmp/trace_nf_$1.txt; wc -l /tmp/trace_nf_$1.txt; echo nop > current_tracer; echo 1 > options/function-trace
