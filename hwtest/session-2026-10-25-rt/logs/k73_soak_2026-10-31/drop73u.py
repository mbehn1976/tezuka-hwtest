import sys, time, subprocess, os, random, numpy as np
from numpy.lib.stride_tricks import sliding_window_view as sw
D = os.environ['D']; I1 = os.environ['I1']
PP = os.environ.get('HOSTP', '192.168.3.1'); BUF = 262144; B = 512; FS = int(os.environ.get("FS", "10000000"))
def medf(x, k): return np.median(sw(np.pad(x, k // 2, mode='edge'), k), axis=1)
def stream(secs, nb):
    n = int(FS * secs); time.sleep(3)
    path = D + '/ol.bin'
    env = dict(os.environ, LD_LIBRARY_PATH=I1 + '/lib:' + I1 + '/lib64', NB_BLOCKS=str(nb))
    cmd = [I1 + '/bin/iio_rwdev', '-u', 'ip:' + PP, '-b', str(BUF), '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1']
    with open(path, 'wb') as f:
        r = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, timeout=120, env=env)
    d = np.fromfile(path, dtype='<i2'); z = d[0::2] + 1j * d[1::2]
    if len(z) < 1 << 19: return False, [], 0.0, r.returncode
    sp = np.abs(np.fft.fft(z[:1 << 18] * np.blackman(1 << 18))); f0 = np.fft.fftfreq(1 << 18, 1 / FS)[sp.argmax()]
    y = (z * np.exp(-2j * np.pi * f0 * np.arange(len(z)) / FS))[:len(z) // B * B].reshape(-1, B).mean(1)
    dp = np.angle(y[1:] * np.conj(y[:-1])); dev = dp - medf(dp, 101)
    out = [int((i + 1) * B) for i in np.where(np.abs(dev) > .4)[0]]
    return len(z) == n, out, f0, r.returncode
modes = [int(x) for x in os.environ.get('NBS', '4,32').split(',')]
RUNS = int(os.environ.get('RUNS', '30')); SECS = float(os.environ.get('SECS', '5'))
res = {m: [] for m in modes}
for it in range(RUNS):
    order = modes[:]; random.shuffle(order)
    for m in order:
        full, out, f0, rc = stream(SECS, m)
        res[m].append((full, out))
        print('nb%d round %d full=%s outliers=%d f0=%.4f rc=%d' % (m, it + 1, full, len(out), f0 / 1e6, rc), flush=True)
for m in modes:
    allo = res[m]; flat = [o for full, out in allo for o in out]
    print('SUMMARY nb%d: runs %d, incomplete %d, runs with outliers %d, outliers %d' % (m, len(allo), sum(1 for full, out in allo if not full), sum(1 for full, out in allo if out), len(flat)))
print('DROP_DONE')
