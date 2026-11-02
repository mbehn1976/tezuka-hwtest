#!/bin/sh
T=/sys/kernel/debug/tracing
if [ "$1" = start ]; then
  echo 0 > $T/tracing_on; echo nop > $T/current_tracer; echo > $T/set_ftrace_filter; echo 0 > $T/events/enable
  echo 40000 > $T/buffer_size_kb
  for f in axi_dmac_interrupt_handler iio_dma_buffer_block_done iio_dma_buffer_enqueue_dmabuf iio_dma_buffer_enqueue_block iio_buffer_signal_dmabuf_done iio_dma_buffer_dequeue_block sock_sendmsg tcp_sendmsg sock_recvmsg; do grep -qx $f $T/available_filter_functions && echo $f >> $T/set_ftrace_filter; done
  echo 1 > $T/events/sched/sched_switch/enable; echo 1 > $T/events/sched/sched_wakeup/enable
  echo global > $T/trace_clock; echo function > $T/current_tracer; echo > $T/trace; echo 1 > $T/tracing_on
else
  echo 0 > $T/tracing_on; cat $T/trace > /tmp/trace.txt; echo 0 > $T/events/enable; echo nop > $T/current_tracer; echo > $T/set_ftrace_filter; wc -l /tmp/trace.txt
fi
