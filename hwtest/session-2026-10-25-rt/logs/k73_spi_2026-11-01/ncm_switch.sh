#!/bin/sh
# usage: ncm_switch.sh ncm|rndis
# Swap the gadget network function at runtime through configfs (same host and device MAC, address 192.168.4.1 kept).
# Nothing is written to the U-Boot environment. The USB link drops and comes back; run this over the Ethernet link.
# The gadget netdev gets its name only when the UDC binds, so the interface is configured after the bind; for NCM the
# host sees the link as connected only once the gadget interface is up (f_ncm sends the notification from ncm_open).
G=/sys/kernel/config/usb_gadget/composite_gadget
case "$1" in ncm) new=ncm.usb0;; rndis) new=rndis.0;; *) echo "usage: $0 ncm|rndis"; exit 1;; esac
cur=$(ls $G/configs/c.1 | grep -E '^(rndis|ncm|ecm)\.' | head -1)
[ -n "$cur" ] || { echo "no network function in c.1"; exit 1; }
[ "$cur" = "$new" ] && { echo "already $cur ifname=$(cat $G/functions/$cur/ifname)"; exit 0; }
ha=$(cat $G/functions/$cur/host_addr); da=$(cat $G/functions/$cur/dev_addr)
echo "" > $G/UDC
rm $G/configs/c.1/$cur
rmdir $G/functions/$cur
mkdir $G/functions/$new
echo "$ha" > $G/functions/$new/host_addr
echo "$da" > $G/functions/$new/dev_addr
ln -s $G/functions/$new $G/configs/c.1
echo ci_hdrc.0 > $G/UDC
sleep 2
ifn=$(cat $G/functions/$new/ifname)
ip addr add 192.168.4.1/24 dev "$ifn" 2>/dev/null
ip link set "$ifn" up
sleep 1
echo "switched $cur -> $new ifname=$ifn addr=$(ip -br -4 addr show "$ifn" | awk '{print $3}') host_addr=$(cat $G/functions/$new/host_addr) udc=$(cat $G/UDC)"
