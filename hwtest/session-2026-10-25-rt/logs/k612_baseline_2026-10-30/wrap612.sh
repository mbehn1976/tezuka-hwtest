#!/bin/sh
# run A: the default image as shipped; run B: services reduced to roughly the 7.3 test set
rm -f /tmp/wrap_done
sh /tmp/baseline73.sh
mkdir -p /tmp/A; mv /tmp/ct_*.txt /tmp/stress_*.log /tmp/A/ 2>/dev/null; rm -f /tmp/ct_done
echo "services stopped $(date +%T)" >> /tmp/A/ct_progress.txt
pkill -f "[c]lassifier -f"
pkill -f "[m]aia-httpd"
pkill -f "[a]pi_controller"
pkill -f "[m]qtt_pubd"
pkill -f "[m]osquitto_sub"
pkill -f "[w]atchconsoletx"
pkill -f "[w]atchdatveasy"
pkill -f "[w]atchconsolefreq"
pkill inotifywait
sleep 60
ps w > /tmp/ps_B.txt
sh /tmp/baseline73.sh
mkdir -p /tmp/B; mv /tmp/ct_*.txt /tmp/stress_*.log /tmp/B/ 2>/dev/null
echo DONE > /tmp/wrap_done
