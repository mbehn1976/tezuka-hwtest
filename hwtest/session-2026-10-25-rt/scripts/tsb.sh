SP=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
O="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"
S="sshpass -p analog ssh $O root@192.168.3.1"
for i in $(seq 60); do
  $S 'cd /tmp; ./tsrd local: 4 262144 5 /tmp/ts_l.txt' && sshpass -p analog scp -O $O root@192.168.3.1:/tmp/ts_l.txt $SP/tsb/A_$i.txt
done
echo PHASE_A_DONE
nc -l -p 5555 > /dev/null 2>&1 &
NCPID=$!
sleep 1
$S 'nohup sh -c "nc 192.168.3.10 5555 < /dev/zero" > /dev/null 2>&1 &'
sleep 3
for i in $(seq 60); do
  $S 'cd /tmp; ./tsrd local: 4 262144 5 /tmp/ts_l.txt' && sshpass -p analog scp -O $O root@192.168.3.1:/tmp/ts_l.txt $SP/tsb/B_$i.txt
done
$S 'pkill nc'; kill $NCPID 2>/dev/null
echo PHASE_B_DONE
$S 'dmesg | grep -c "SPI transfer timed out"; uptime'
echo ALLDONE
