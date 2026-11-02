#!/bin/sh
# list scheduling policy/priority/cpu of interesting threads: pid policy(0=OTHER 1=FIFO 2=RR) rtprio cpu comm
for d in /proc/[0-9]*; do
  c=$(cat $d/comm 2>/dev/null) || continue
  case "$c" in ktimers*|ksoftirqd*|irq/*|spi*|iiod*|maia*|mosquitto*|api_contr*|rcu*|kworker*u*) ;; *) continue;; esac
  s=$(sed 's/.*) //' $d/stat 2>/dev/null) || continue
  set -- $s
  # after stripping "pid (comm) ", field 1 = state; rt_priority = stat field 40 -> here 38; policy 41 -> 39; processor 39 -> 37
  eval "rt=\${38}; pol=\${39}; cpu=\${37}"
  echo "${d#/proc/} pol=$pol rt=$rt cpu=$cpu $c"
done
