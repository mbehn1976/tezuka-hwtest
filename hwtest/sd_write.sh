#!/usr/bin/env bash
# Write a Pluto+ sdimg directory to the SD card behind the USB-SD-Mux, boot it, verify.
# Usage: sd_write.sh <sdimg-dir> [backup-dir]
set -euo pipefail
SDIMG=$1; BACKUP=${2:-}
MUX=/dev/usb-sd-mux/id-00048.02035
PART=/dev/disk/by-id/usb-LinuxAut_sdFST_HS-SD_MMC_00048.02035-0:0-part1
HOST=${HOST:-192.168.4.1}
SSH="sshpass -p analog ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 root@$HOST"
[ -f "$SDIMG/BOOT.bin" ] || { echo "not an sdimg dir: $SDIMG" >&2; exit 1; }

echo "== board: sync, /boot read-only"
if [ "$NOPOWER" = 1 ]; then
  # The hub cannot really cut the Pluto+'s power (port off only resets it). Keep Linux running from its
  # RAM rootfs with /boot read-only, swap the card under it, then reboot over SSH.
  $SSH 'sync; mount -o remount,ro /boot && sync' || { echo "NOPOWER needs the board running with /boot read-only" >&2; exit 1; }
else
$SSH 'sync; mount -o remount,ro /boot 2>/dev/null; sync' || echo "(board not reachable, continuing)"
echo "== power off Pluto+ (hub 3-6 port 1)"
uhubctl -S -l 3-6 -p 1 -a off >/dev/null; sleep 3
# the hub has failed to cut power once (board came back in U-Boot 1-2 s later): make sure it is dark
dark=0
for i in $(seq 10); do
    if [ ! -e /sys/bus/usb/devices/3-6.1 ] && ! ping -c1 -W1 192.168.3.1 >/dev/null 2>&1; then dark=$((dark+1)); else dark=0; fi
    [ $dark -ge 3 ] && break
    sleep 1
done
[ $dark -ge 3 ] || { echo "Pluto+ still powered after port off - not switching the SD card (try NOPOWER=1)"; uhubctl -S -l 3-6 -p 1 -a on >/dev/null; exit 1; }
fi
echo "== mux -> host"
usbsdmux $MUX host
for i in $(seq 20); do [ -e "$PART" ] && break; sleep 1; done
[ -e "$PART" ] || { echo "card partition did not appear" >&2; exit 1; }
DEV=$(readlink -f "$PART"); echo "card partition: $DEV ($(lsblk -no LABEL,SIZE "$DEV"))"
# the desktop auto-mounter races with us: re-check the mount point after each attempt
MP=""
for i in $(seq 5); do
  MP=$(lsblk -no MOUNTPOINT "$DEV" | head -1); [ -n "$MP" ] && break
  udisksctl mount -b "$DEV" >/dev/null 2>&1 || true; sleep 1
done
[ -n "$MP" ] || { echo "card did not mount" >&2; exit 1; }
echo "mounted at $MP"
if [ -n "$BACKUP" ] && [ ! -e "$BACKUP" ]; then
  echo "== backup card -> $BACKUP"; mkdir -p "$BACKUP"; rsync -a "$MP"/ "$BACKUP"/
fi
echo "== rsync $SDIMG"
rsync -a --delete "$SDIMG"/ "$MP"/; sync
(cd "$SDIMG" && find . -type f -print0 | sort -z | xargs -0 md5sum) > /tmp/sdimg.md5.$$
(cd "$MP" && md5sum -c --quiet /tmp/sdimg.md5.$$) && echo "host-side checksums OK"
udisksctl unmount -b "$DEV" >/dev/null; sync; sleep 1
echo "== mux -> dut, power on"
usbsdmux $MUX dut; sleep 2
if [ "$NOPOWER" = 1 ]; then
  echo "== reboot over SSH"; $SSH 'reboot' || true; sleep 15
else
  uhubctl -S -l 3-6 -p 1 -a on >/dev/null
fi
for i in $(seq 60); do $SSH true 2>/dev/null && break; sleep 3; done
$SSH true || { echo "board did not come back on $HOST - needs a manual power cycle" >&2; exit 2; }
echo "== board up; verifying /boot"
$SSH 'cd /boot && find . -type f | sort | xargs md5sum' > /tmp/board.md5.$$
if diff <(sort -k2 /tmp/sdimg.md5.$$) <(sort -k2 /tmp/board.md5.$$); then echo "board /boot checksums match image"; else echo "BOARD /boot MISMATCH" >&2; exit 3; fi
$SSH 'dmesg | grep -i "not properly unmounted\|FAT-fs.*error" || true'
rm -f /tmp/sdimg.md5.$$ /tmp/board.md5.$$
