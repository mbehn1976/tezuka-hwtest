# Pluto+ USB gadget drops, 2026-10-11

## Symptom
The Pluto+ (hub 3-6 port 1) drops off USB: RNDIS, mass storage and ACM all disappear from the host.
- The board stays up and is reachable on Ethernet at 192.168.3.1.
- Its UDC still reports `configured`, and the ci_hdrc interrupt counter (IRQ 53) stops moving.
- A board-side `soft_connect` disconnect/connect re-enumerates it, but it drops again 2-8 s later.

## Timeline (host kernel log)
| Time | Event |
|---|---|
| 09:22:24-29 | Pluto, Pluto+ and SD mux hub (3-1) all disconnect at once, right as a 61.44 MS/s Pluto run starts |
| 17:41:43 | Pluto+ up (F2 image) |
| 17:53:07 | USB drop; Ethernet stays up |
| 17:56:00 | Pluto eject; its update.sh starts writing flash |
| 17:56:45 | Pluto+ resets by itself (Ethernet down, U-Boot gadget); nobody power-cycled it |
| 17:57:14 | Pluto+ up |
| 17:59:39 | USB drop, during the Pluto flash write |
| 18:17:51 | Pluto+ up after an 8 s hub power cycle; USB drop 18:21:36 |
| 18:23:01, 18:24:54, 18:34:20 | re-enumerations (soft connect, sd_write reboot) drop after 2-8 s |
| 18:35:37-18:45:37 | hub port off (10 min) |
| 18:46:06-19:11 | cold boot, USB up 25 min, no drop; the Pluto was idle |

## Ruled out
- **Bitstream:** the bf83f60 image (no USB drops 07:14-09:22) drops the same way; drops seen on both bf83f60 and F2 (ac9b3c7).
- **USB PHY reset from the PL:** `xlnx,phy-reset-gpio` is MIO 46.
- **Mass storage traffic as the trigger:** it dropped with the LUN force-ejected.
- **Heat as the sole cause:** USB held for 25 min at 66-68 °C Zynq, versus 70 °C when failing.
  Pluto at the same time: Zynq 60 °C, AD9363 37 °C. Pluto+ AD9363 40 °C.
- **Supplies:** XADC rails normal (VCCINT 1.02 V, VCCAUX 1.83 V, VCCO_DDR 1.46 V).

## Load experiments (Pluto+ on bf83f60, monitor `plutoplus-mon-expA.log`, 2 s ping + XADC + IRQ count)
- **A, 19:11-19:14:** 61.44 MS/s tonetest on the Pluto (30 x 12 MB over its USB) gave no Pluto+ drop.
- **B, 19:15-19:18:** 61.44 MS/s tonetest on the Pluto+ over USB RNDIS (about 370 MB) gave no drop. Zynq reached 70 °C.
  Q slips were found as expected, since bf83f60 has the old DDC crossing.
- **Uptime:** USB has been up since 18:46:06 with 0 DOWN samples.

## Other checks
- **Suspend settings:** `udc_handle_suspend=0` on both boards, and host `power/control=on` for both Pluto devices.
- **Host log:** no xHCI or over-current errors at any drop.
- **09:22:** hub 3-6 itself stayed enumerated while all its downstream devices dropped. A self-powered hub
  whose external supply fails keeps its logic on host VBUS but loses downstream port power, so this
  points to the hub's supply (the SD mux on 3-1 also dropped, 5 s later).
- **SD mux re-enumerations:** the SD mux came back on 3-3 at 17:27 and on 3-1 at 18:37, when cables were re-seated.

## Open lead
Load on its own does not reproduce it (A, B). Remaining candidates: the hub 3-6 power supply (09:22, 17:56:45 reset), or a board state that clears only after a long power-off (after 8-10 s power cycles USB lasted 8 s to 11 min; after the 10 min one it has held).

Raw log of the cold-boot run: `plutoplus-thermal-1835.log`.
