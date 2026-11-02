import os, sys, time, argparse
sys.path.insert(0, os.path.expanduser('~/code/maia-sdr-bp/maia-hdl/hwtest'))
import hwlib, numpy as np
ap = argparse.ArgumentParser()
ap.add_argument('--data', default='tone'); ap.add_argument('--gain', type=int, default=0)
ap.add_argument('--check', default='yes'); ap.add_argument('--secs', type=int, default=150)
a = ap.parse_args()
TX = '192.168.3.1'; fs = 61_440_000
usb = lambda: os.path.exists('/sys/bus/usb/devices/3-6.1')
hwlib.configure(TX, '192.168.2.1', fs, 49_152_000, 2_400_000_000, 52, tx_gain=a.gain)
if a.check == 'no':
    # same as hwlib.start_tx without the two verification ssh calls
    import subprocess
    def start_tx(x, rms):
        x = x / np.sqrt(np.mean(np.abs(x) ** 2)) * rms
        iq = np.empty(2 * len(x), '<i2'); iq[0::2] = np.round(x.real); iq[1::2] = np.round(x.imag)
        hwlib.stop_tx(TX)
        hwlib.ssh(TX, 'cat > /tmp/rf_tx.bin', stdin=iq.tobytes())
        hwlib.ssh(TX, f"printf '%s\\n' 'iio_writedev -c -b {len(x)} cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rf_tx.bin > /tmp/rf_tx.log 2>&1 &' > /tmp/rf_tx.sh; sh /tmp/rf_tx.sh")
        time.sleep(2.5)
else:
    start_tx = lambda x, rms: hwlib.start_tx(TX, x, rms)
rng = np.random.default_rng(1)
t0 = time.time(); n = 0
while time.time() - t0 < a.secs:
    f0 = hwlib.tone_freq(fs, 2050 if n % 2 == 0 else -6000)
    x = hwlib.tone(fs, f0) if a.data == 'tone' else (rng.standard_normal(25000) + 1j * rng.standard_normal(25000))
    start_tx(x, 6000)
    n += 1
    if not usb():
        print(f'>>> USB DROP after {n} TX restarts, {time.time()-t0:.0f} s', flush=True); break
else:
    print(f'no drop in {n} TX restarts / {a.secs} s', flush=True)
hwlib.stop_tx(TX)
