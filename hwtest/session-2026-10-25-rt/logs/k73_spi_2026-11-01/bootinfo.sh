#!/bin/sh
# one line of board state after a boot (release images, no debug config)
IRQ=$(awk '/e0006000/{sub(":","",$1); print $1}' /proc/interrupts)
P=$(grep -l "^irq/$IRQ-" /proc/[0-9]*/comm 2>/dev/null | head -1 | cut -d/ -f3)
KT=$(pgrep -x ktimers/0)
echo "$(uname -r) up=$(cut -d' ' -f1 /proc/uptime) sysrq=$(cat /proc/sys/kernel/sysrq 2>/dev/null || echo none) usb0=$(ip -br -4 addr show usb0 | awk '{print $3}') eth0=$(ip -br -4 addr show eth0 | awk '{print $3}') spi_thread=$P prio=$(chrt -p $P 2>/dev/null | awk '/priority/{print $NF}') ktimers0=$(chrt -p $KT 2>/dev/null | awk '/priority/{print $NF}') watcher=$(pgrep -f S99bootwatch | wc -l) halt_warn=$(dmesg | grep -c 'not taken') rtprio=$(ls /etc/init.d/S24rtprio 2>/dev/null | wc -l)"
