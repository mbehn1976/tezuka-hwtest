#!/bin/bash
# usage: qspi_test.sh DUMP FRM   (host side, board over USB 192.168.4.1, 7.3 with patch 0007)
# QSPI write tests on the Pluto+ (W25Q256, 32 MiB; mtd0 boot 0-1 MiB, mtd1 env 1 MiB-1.125 MiB, mtd2 nvmfs, mtd3 linux 2-32 MiB).
# A write with the wrong bank selected lands 16 MiB lower, so every test write stays in flash 18-32 MiB (mtd3 offset 16 MiB
# and up): its mirror, flash 2-16 MiB, is inside mtd3 too and the dump restores it. mtd0 is never written; mtd1 only by
# fw_setenv (its normal use). DUMP = mtd3 read on 6.12 (30 MiB), FRM = the 7.3 pluto.frm (test payload).
#   1. env round trip over a reboot   2. one 64 KiB block at mtd3+16 MiB: erase, pattern, read back, restore
#   3. 14 MiB of the frm at mtd3+16 MiB: erase, program, read back, restore   4. whole mtd3 md5 against the dump, reboot
# Each step logs one line; the first failure ends the script with exit 1 and the board as it is.
DUMP=$1; FRM=$2
. /tmp/claude-1000/-home-mb/cef86cb2-5b49-4a37-971c-ce5a3edb4ed1/scratchpad/k73spi/common.sh
O=$K/Q_final/qspi; mkdir -p $O
q(){ echo "qspi: $*"; }
fail(){ q "FAIL: $*"; exit 1; }
waitssh(){ sleep 20; for i in $(seq 60); do timeout 10 $SSH true 2> /dev/null && return 0; sleep 5; done; return 1; }
DM=$(md5sum < $DUMP | cut -c1-32); [ $(stat -c %s $DUMP) = 31457280 ] || fail "dump size $(stat -c %s $DUMP)"
q "tools: $(timeout 20 $SSH 'ls /dev/mtd[0-3] | tr "\n" " "; which flash_erase dd fw_setenv | tr "\n" " "; cat /sys/class/mtd/mtd3/erasesize /sys/class/mtd/mtd3/size | tr "\n" " "' 2>&1)"
[ "$(timeout 20 $SSH 'cat /sys/class/mtd/mtd3/erasesize')" = 65536 ] || fail "mtd3 erase size is not 64 KiB"

# 1. env round trip
timeout 30 $SSH 'fw_setenv qspi_test hello73 2>&1'; v=$(timeout 20 $SSH 'fw_printenv -n qspi_test 2>&1'); [ "$v" = hello73 ] || fail "env write: read back [$v]"
timeout 15 $SSH 'sync; reboot' > /dev/null 2>&1; waitssh || fail "no SSH after the env reboot"
v=$(timeout 20 $SSH 'fw_printenv -n qspi_test 2>&1'); [ "$v" = hello73 ] || fail "env after reboot: [$v]"
timeout 30 $SSH 'fw_setenv qspi_test 2>&1'; v=$(timeout 20 $SSH 'fw_printenv -n qspi_test 2>&1'); q "env round trip: ok (hello73 survived the reboot; after delete: [$v]) up=$(timeout 10 $SSH 'cut -d" " -f1 /proc/uptime')"

# 2. one block at mtd3 + 16 MiB (flash 18 MiB, bank 1)
head -c 65536 /dev/urandom > $O/pat.bin; PM=$(md5sum < $O/pat.bin | cut -c1-32)
timeout 30 $SSH 'cat > /tmp/pat.bin' < $O/pat.bin
dd if=$DUMP bs=65536 skip=256 count=1 2> /dev/null > $O/dump_blk.bin; timeout 30 $SSH 'cat > /tmp/dump_blk.bin' < $O/dump_blk.bin
r=$(timeout 60 $SSH 'flash_erase -q /dev/mtd3 0x1000000 1 2>&1 && dd if=/tmp/pat.bin of=/dev/mtd3 bs=65536 seek=256 count=1 2>&1 | tail -1; dd if=/dev/mtd3 bs=65536 skip=256 count=1 2>/dev/null | md5sum | cut -c1-32; dmesg | grep -c -E "bank register|refused|timed out"')
m=$(echo "$r" | tail -2 | head -1); e=$(echo "$r" | tail -1); [ "$m" = "$PM" ] && [ "$e" = 0 ] || fail "block write: md5 $m (pattern $PM), driver errors $e: $(echo "$r" | head -2 | tr '\n' ' ')"
r=$(timeout 60 $SSH 'flash_erase -q /dev/mtd3 0x1000000 1 2>&1 && dd if=/tmp/dump_blk.bin of=/dev/mtd3 bs=65536 seek=256 count=1 2>&1 | tail -1; dd if=/dev/mtd3 bs=1M 2>/dev/null | md5sum | cut -c1-32')
m=$(echo "$r" | tail -1); [ "$m" = "$DM" ] || fail "block restore: mtd3 md5 $m, dump $DM"
q "block at mtd3+16 MiB: pattern written and read back, block restored, mtd3 equals the dump"

# 3. 14 MiB of the frm at mtd3 + 16 MiB (flash 18-32 MiB)
head -c 14680064 $FRM > $O/frm14.bin; FM=$(md5sum < $O/frm14.bin | cut -c1-32)
timeout 120 $SSH 'cat > /tmp/frm14.bin' < $O/frm14.bin
dd if=$DUMP bs=1M skip=16 2> /dev/null > $O/dump14.bin; timeout 120 $SSH 'cat > /tmp/dump14.bin' < $O/dump14.bin
t0=$(date +%s)
r=$(timeout 600 $SSH 'flash_erase -q /dev/mtd3 0x1000000 224 2>&1 && dd if=/tmp/frm14.bin of=/dev/mtd3 bs=65536 seek=256 2>&1 | tail -1; dd if=/dev/mtd3 bs=65536 skip=256 count=224 2>/dev/null | md5sum | cut -c1-32; dmesg | grep -c -E "bank register|refused|timed out"')
m=$(echo "$r" | tail -2 | head -1); e=$(echo "$r" | tail -1); t1=$(date +%s); [ "$m" = "$FM" ] && [ "$e" = 0 ] || fail "frm write: md5 $m (file $FM), driver errors $e: $(echo "$r" | head -2 | tr '\n' ' ')"
r=$(timeout 600 $SSH 'flash_erase -q /dev/mtd3 0x1000000 224 2>&1 && dd if=/tmp/dump14.bin of=/dev/mtd3 bs=65536 seek=256 2>&1 | tail -1; dd if=/dev/mtd3 bs=1M 2>/dev/null | md5sum | cut -c1-32; rm -f /tmp/frm14.bin /tmp/dump14.bin')
m=$(echo "$r" | tail -1); t2=$(date +%s); [ "$m" = "$DM" ] || fail "frm restore: mtd3 md5 $m, dump $DM"
q "14 MiB at mtd3+16 MiB: written and read back in $((t1 - t0)) s, restored in $((t2 - t1)) s, mtd3 equals the dump"

# 4. reboot, read everything again
timeout 15 $SSH 'sync; reboot' > /dev/null 2>&1; waitssh || fail "no SSH after the final reboot"
r=$(timeout 120 $SSH 'for i in 0 1 2 3; do dd if=/dev/mtd$i bs=1M 2>/dev/null | md5sum | cut -c1-8; done | tr "\n" " "; fw_printenv -n ipaddr 2>&1; dmesg | grep -c -E "bank register|refused"')
q "after reboot: mtd0-3 md5 $(echo "$r" | head -1) env ipaddr=$(echo "$r" | sed -n 2p) driver errors $(echo "$r" | tail -1) up=$(timeout 10 $SSH 'cut -d" " -f1 /proc/uptime')"
q "ALL PASSED"
