# tx.py <tx-host> start|stop : start/stop the unequal two tones on an already configured TX (fs 10 MS/s)
import sys
sys.path.insert(0, '/home/mb/code/maia-sdr-bp/maia-hdl/hwtest')
import hwlib
tx, what, fs = sys.argv[1], sys.argv[2], 10_000_000
if what == 'stop':
    hwlib.stop_tx(tx)
    hwlib.ssh(tx, f'echo -89 > {hwlib.PHY}/out_voltage0_hardwaregain')
else:
    hwlib.ssh(tx, f'echo 0 > {hwlib.PHY}/out_voltage0_hardwaregain')
    ft = [hwlib.tone_freq(fs, k) for k in (2050, 2101)]
    hwlib.start_tx(tx, sum(a * hwlib.tone(fs, f) for a, f in zip((1.0, 0.25), ft)), 6000)
print('tx', what)
