import sys, time, subprocess, re, numpy as np
from numpy.lib.stride_tricks import sliding_window_view as sw
sys.path.insert(0, '.')
import hwlib as h
PL, PP = '192.168.2.1', '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', 'root@' + PP]
D = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/'
BUF = 262144; B = 512
def medf(x, k): return np.median(sw(np.pad(x, k // 2, mode='edge'), k), axis=1)
def stream(fs, secs, load):
    n = int(fs * secs); dur = int(secs + 8)
    bg = subprocess.Popen(SSH + ['taskset -c 0 stress-ng --cpu 1 --vm 1 --vm-bytes 32M --timeout %ds >/dev/null 2>&1' % (dur + 2)]) if load else None
    cyc = subprocess.Popen(SSH + ['cyclictest -t1 -p98 -i250 -a0 -D %ds -m -q' % dur], stdout=subprocess.PIPE, text=True) if load else None
    time.sleep(3)
    with open(D + 'ol.bin', 'wb') as f:
        r = subprocess.run(['iio_readdev', '-u', 'ip:' + PP, '-b', str(BUF), '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1'], stdout=f, stderr=subprocess.PIPE, text=True, timeout=120)
    if cyc: cyc.communicate(timeout=60)
    if bg: bg.wait(timeout=60)
    d = np.fromfile(D + 'ol.bin', dtype='<i2'); z = d[0::2] + 1j * d[1::2]
    sp = np.abs(np.fft.fft(z[:1 << 18] * np.blackman(1 << 18))); f0 = np.fft.fftfreq(1 << 18, 1 / fs)[sp.argmax()]
    y = (z * np.exp(-2j * np.pi * f0 * np.arange(len(z)) / fs))[:len(z) // B * B].reshape(-1, B).mean(1)
    dp = np.angle(y[1:] * np.conj(y[:-1])); dev = dp - medf(dp, 101)
    idx = np.where(np.abs(dev) > .4)[0]
    amp = np.abs(y) / np.median(np.abs(y))
    out = []
    for i in idx:
        s = (i + 1) * B                                  # sample index of the discontinuity (block i+1 start)
        near = s % BUF; near = min(near, BUF - near)
        out.append((s, near, float(dev[i]), float(amp[i + 1])))
    return len(z) == n, out, f0
st = (h.save_settings(PL), h.save_settings(PP))
res = {}
try:
    fs = 10000000
    h.configure(PL, PP, fs, 4000000, 2400000000, 30, -10)
    h.start_tx(PL, h.tone(fs, h.tone_freq(fs, 1250)), 2000); time.sleep(1)
    for load in (True, False):
        allo = []; iters = 12 if load else 8
        for it in range(iters):
            full, out, f0 = stream(fs, 5, load)
            allo.append(out)
            print('load=%s iter %d full=%s outliers=%d %s' % (load, it + 1, full, len(out), [(o[0], o[1], round(o[2], 2)) for o in out]), flush=True)
        res[load] = allo
    h.stop_tx(PL)
finally:
    h.tx_cleanup(PL); h.restore_settings(PL, st[0]); h.restore_settings(PP, st[1])
for load, allo in res.items():
    flat = [o for out in allo for o in out]
    print('SUMMARY load=%s: iterations %d, outliers %d, within 1024 samples of a %d-sample buffer boundary: %d, dev rad: %s' % (
        load, len(allo), len(flat), BUF, sum(1 for o in flat if o[1] <= 1024), sorted(round(o[2], 2) for o in flat)))
print('OUTLIER_DONE')
