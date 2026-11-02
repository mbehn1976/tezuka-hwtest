#!/bin/sh
# F15 follow-up: does PATCH /api/ddc/config {"enabled": ...} keep bits 1-3 of the axi_ad9361 GPIO register 0xBC
# while other processes use the cf-ad9361-lpc debugfs register file? Runs on the board.
# Usage: routingrace.sh <maia-httpd binary> [toggles]   (stops the system maia-httpd and restarts it at the end)
# Sets 0xBC to 0xE (other bits live), starts an extra iio_attr poller of 0x80000088 (as api_controller.sh does,
# but continuously), toggles routing, and checks 0xBC with devmem after each call: expect 0xF / 0xE.
BIN=$1; N=${2:-500}
D=$(for d in /sys/bus/iio/devices/iio:device*; do [ "$(cat $d/name)" = cf-ad9361-lpc ] && basename $d; done)
R=/sys/kernel/debug/iio/$D/direct_reg_access
ORIG=$(devmem 0x790200BC 32)
/etc/init.d/S60maia-httpd stop >/dev/null 2>&1; sleep 1
cd / && $BIN --listen 0.0.0.0:80 --ssl-cert /mnt/jffs2/maia-httpd.crt --ssl-key /mnt/jffs2/maia-httpd.key \
    --ca-cert /mnt/jffs2/maia-sdr-ca.crt > /tmp/routingrace-httpd.log 2>&1 &
HP=$!
sleep 4
echo "0x800000BC 0xE" > $R
echo "binary $(md5sum $BIN | cut -c1-8), 0xBC start $(devmem 0x790200BC 32), toggles $N"
cat > /tmp/routingrace-poll.sh <<EOF
while true; do iio_attr -D cf-ad9361-lpc direct_reg_access 0x80000088 >/dev/null 2>&1; done
EOF
sh /tmp/routingrace-poll.sh & PP=$!
bad=0; err=0; i=0
while [ $i -lt $N ]; do
    for e in true false; do
        r=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH -H 'Content-Type: application/json' \
            -d "{\"enabled\":$e}" http://127.0.0.1/api/ddc/config)
        [ "$r" = 200 ] || err=$((err + 1))
        v=$(devmem 0x790200BC 32)
        if [ $e = true ]; then x=0x0000000F; else x=0x0000000E; fi
        if [ "$v" != "$x" ]; then
            bad=$((bad + 1)); [ $bad -le 5 ] && echo "  toggle $i enabled=$e: 0xBC=$v expected $x (http $r)"
            echo "0x800000BC 0xE" > $R
        fi
    done
    i=$((i + 1))
done
kill $PP; wait $PP 2>/dev/null
echo "result: $((2 * N)) PATCH calls, wrong 0xBC after $bad, non-200 replies $err"
kill $HP; sleep 1
echo "0x800000BC $ORIG" > $R
echo "0xBC restored to $(devmem 0x790200BC 32)"
rm -f /tmp/routingrace-poll.sh
/etc/init.d/S60maia-httpd start >/dev/null 2>&1; sleep 3; echo "system maia-httpd pid $(pidof maia-httpd)"
