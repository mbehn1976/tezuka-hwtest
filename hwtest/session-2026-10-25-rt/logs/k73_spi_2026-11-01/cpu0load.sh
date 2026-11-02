#!/bin/sh
# usage: cpu0load.sh SECONDS
# Busy share of cpu0 and cpu1 over the window, and the CPU time (percent of one core) used by the UDC interrupt
# thread, ktimers/0, the Ethernet interrupt thread and iiod.
S=${1:-30}
pid(){ grep -l -E "$1" /proc/[0-9]*/comm 2>/dev/null | head -1 | cut -d/ -f3; }
U=$(pid '^irq/[0-9]+-e0002000'); T=$(pid '^ktimers/0$'); E=$(pid '^irq/[0-9]+-eth'); I=$(pidof iiod | cut -d' ' -f1)
snap(){
	awk '/^cpu[01] /{print $1, $5+$6, $2+$3+$4+$5+$6+$7+$8+$9}' /proc/stat
	for n in udc:$U ktimers0:$T eth:$E iiod:$I; do
		p=${n#*:}; [ -n "$p" ] && [ -r /proc/$p/stat ] && awk -v n=${n%%:*} '{print n, $14+$15}' /proc/$p/stat
	done
}
snap > /tmp/cl1; sleep "$S"; snap > /tmp/cl2
paste -d' ' /tmp/cl1 /tmp/cl2 | awk -v S="$S" '
	$1 ~ /^cpu/ { printf "%s busy=%.0f%% ", $1, 100 * (1 - ($5 - $2) / ($6 - $3)) }
	$1 !~ /^cpu/ { printf "%s=%.1f%% ", $1, ($4 - $2) / S }
	END { print "" }'
