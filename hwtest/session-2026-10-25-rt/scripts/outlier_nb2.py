import sys, time, subprocess, re, numpy as np
from numpy.lib.stride_tricks import sliding_window_view as sw
sys.path.insert(0, '.')
import hwlib as h
PL, PP = '192.168.2.1', '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', 'root@' + PP]
D = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/'
BUF = 262144; B = 512
def medf(x, k): return np.median(sw(np.pad(x, k // 2, mode='edge'), k), axis=1)
I1 = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/libiio1_host/inst'
def stream(fs, secs, mode):
    n = int(fs * secs)
    time.sleep(3)
    path = D + 'ol.bin'
    if False:
        r = subprocess.run(SSH + ['iio_readdev -u local: -b %d -s %d cf-ad9361-lpc voltage0 voltage1 > /tmp/loc.bin 2>/tmp/loc.err; echo rc=0' % (BUF, n)], capture_output=True, text=True, timeout=120)
        with open(path, 'wb') as f:
            subprocess.run(SSH + ['cat /tmp/loc.bin; rm -f /tmp/loc.bin'], stdout=f, timeout=120)
    else:
        env = None; cmd = None
        if mode == 'eth':
            cmd = ['iio_readdev', '-u', 'ip:' + PP, '-b', str(BUF), '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1']
        elif mode == 'usb':
            cmd = ['iio_readdev', '-u', 'ip:192.168.4.1', '-b', str(BUF), '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1']
        elif mode.startswith('nb'):
            import os
            env = dict(os.environ, LD_LIBRARY_PATH=I1 + '/lib:' + I1 + '/lib64', NB_BLOCKS=mode[2:])
            cmd = [I1 + '/bin/iio_rwdev', '-u', 'ip:' + PP, '-b', str(BUF), '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1']
        with open(path, 'wb') as f:
            r = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, timeout=120, env=env)
    d = np.fromfile(path, dtype='<i2'); z = d[0::2] + 1j * d[1::2]
    if len(z) < 1 << 19:
        return False, [], 0.0
    sp = np.abs(np.fft.fft(z[:1 << 18] * np.blackman(1 << 18))); f0 = np.fft.fftfreq(1 << 18, 1 / fs)[sp.argmax()]
    y = (z * np.exp(-2j * np.pi * f0 * np.arange(len(z)) / fs))[:len(z) // B * B].reshape(-1, B).mean(1)
    dp = np.angle(y[1:] * np.conj(y[:-1])); dev = dp - medf(dp, 101)
    out = []
    for i in np.where(np.abs(dev) > .4)[0]:
        s = (i + 1) * B; near = s % BUF; near = min(near, BUF - near)
        out.append((s, near, float(dev[i]), 0.0))
    return len(z) == n, out, f0
import random
st = (h.save_settings(PL), h.save_settings(PP))
res = {}
import os
modes = ['nb' + x for x in os.environ.get('NBS', '4,16').split(',')]
FSL = [int(float(x) * 1e6) for x in os.environ.get('FSL', '10').split(',')]
RUNS = int(os.environ.get('RUNS', '30'))
try:
    for fs in FSL:
        h.configure(PL, PP, fs, 4000000, 2400000000, 30, -10)
        h.start_tx(PL, h.tone(fs, h.tone_freq(fs, 1250)), 2000); time.sleep(1)
        for m in modes: res[(fs, m)] = []
        for it in range(RUNS):
            order = modes[:]; random.shuffle(order)
            for mode in order:
                full, out, f0 = stream(fs, 5, mode)
                res[(fs, mode)].append((full, out))
                print('%.1f %s round %d full=%s outliers=%d' % (fs / 1e6, mode, it + 1, full, len(out)), flush=True)
        h.stop_tx(PL)
finally:
    h.tx_cleanup(PL); h.restore_settings(PL, st[0]); h.restore_settings(PP, st[1])
for (fs, mode), allo in res.items():
    flat = [o for full, out in allo for o in out]
    print('SUMMARY %.1f MS/s %s blocks: runs %d, incomplete %d, runs with outliers %d, outliers %d, on a 262144 boundary: %d' % (fs / 1e6, mode, len(allo), sum(1 for full, out in allo if not full), sum(1 for full, out in allo if out), len(flat), sum(1 for o in flat if o[1] <= 1024)))
print('OUTLIER_DONE')
