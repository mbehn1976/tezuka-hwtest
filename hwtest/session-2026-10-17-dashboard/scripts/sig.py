import sys, numpy as np
sys.path.insert(0, '/home/mb/code/maia-sdr-bp/maia-hdl/hwtest')
import hwlib
tx, rx, fs, what = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
hwlib.configure(tx, rx, fs, min(int(0.8*fs), 50_000_000), 2_400_000_000, 40)
if what == 'stop':
    hwlib.tx_cleanup(tx); sys.exit()
k = [2050] if what == 'tone' else [2050, 2101]
x = sum(hwlib.tone(fs, hwlib.tone_freq(fs, kk)) for kk in k)
print('freqs Hz', [hwlib.tone_freq(fs, kk) for kk in k])
hwlib.start_tx(tx, x, 6000)
