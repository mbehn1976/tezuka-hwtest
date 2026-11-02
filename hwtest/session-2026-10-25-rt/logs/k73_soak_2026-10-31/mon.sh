#!/bin/bash
# board monitor: one line per minute
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/soak
SSH="sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8 root@192.168.4.1"
while [ ! -e $S/stop ]; do
  L=$($SSH "sh /tmp/mon_board.sh" 2>&1)
  A=$(curl -s -m8 -o /dev/null -w "%{http_code}" http://192.168.4.1/api/ad9361)
  echo "$(date +%H:%M:%S) $L api=$A" >> $S/mon.log
  sleep 55
done
