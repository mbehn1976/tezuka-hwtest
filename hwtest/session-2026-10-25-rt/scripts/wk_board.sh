# board side: wait for the stream to start, then trace wakeup_rt for the stream window; result in /tmp/wk_max, /tmp/wk_trace
T=/sys/kernel/debug/tracing; cd $T
echo 0 > tracing_on; echo nop > current_tracer; echo wakeup_rt > current_tracer; echo 0 > options/function-trace
echo 8192 > saved_cmdlines_size
sleep 3
echo 0 > tracing_max_latency; echo 1 > tracing_on
cyclictest -t1 -p99 -i250 -a0 -D 6s -m -q > /tmp/wk_cyc 2>&1
echo 0 > tracing_on
cat tracing_max_latency > /tmp/wk_max; cp trace /tmp/wk_trace; echo nop > current_tracer
