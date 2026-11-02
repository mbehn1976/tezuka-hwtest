#!/bin/sh
# usage: board_trace.sh start | stop
T=/sys/kernel/debug/tracing
if [ "$1" = start ]; then
  echo 0 > $T/tracing_on; echo nop > $T/current_tracer; echo > $T/set_ftrace_filter
  echo 32768 > $T/buffer_size_kb
  for f in axi_dmac_start_transfer axi_dmac_interrupt_handler axi_dmac_issue_pending iio_dma_buffer_submit_block iio_dmaengine_buffer_submit_block iio_dma_buffer_block_done iio_dma_buffer_dequeue_block iio_dma_buffer_enqueue_block iio_dma_buffer_enqueue_dmabuf iio_buffer_signal_dmabuf_done iio_dma_buffer_query_block; do grep -qx $f $T/available_filter_functions && echo $f >> $T/set_ftrace_filter; done
  echo global > $T/trace_clock; echo function > $T/current_tracer; echo > $T/trace; echo 1 > $T/tracing_on
else
  echo 0 > $T/tracing_on; cat $T/trace > /tmp/trace.txt; echo nop > $T/current_tracer; echo > $T/set_ftrace_filter; wc -l /tmp/trace.txt
fi
