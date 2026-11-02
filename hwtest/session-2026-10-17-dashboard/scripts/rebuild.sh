#!/bin/bash
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
cd ~/code/tezuka_fw-dash/Dashboard && python3 bundle.py $S/index_dash.html 2>&1 | grep -i "error\|✘" ; 
for b in pluto:192.168.2.1 plutoplus:192.168.3.1; do n=${b%%:*}; h=${b##*:}; sed "s#MQTT_DEV_HOST=null#MQTT_DEV_HOST=\"$h\"#" $S/index_dash.html > $S/web/$n.html; done
echo rebuilt
