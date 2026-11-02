import sys, time, subprocess, re, numpy as np
from numpy.lib.stride_tricks import sliding_window_view as sw
sys.path.insert(0, '.')
import hwlib as h
PL, PP = '192.168.2.1', '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', 'root@' + PP]
D = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/'
def medf(x, k): return np.median(sw(np.pad(x, k // 2, mode='edge'), k), axis=1)
def stream(fs, secs):
    n = int(fs * secs); dur = int(secs + 8)
    bg = subprocess.Popen(SSH + ['taskset -c 0 stress-ng --cpu 1 --vm 1 --vm-bytes 32M --timeout %ds >/dev/null 2>&1' % (dur + 2)])
    time.sleep(1)
    cyc = subprocess.Popen(SSH + ['cyclictest -t1 -p98 -i250 -a0 -D %ds -m -q' % dur], stdout=subprocess.PIPE, text=True)
    time.sleep(2)
    with open(D + 'soak.bin', 'wb') as f:
        r = subprocess.run(['iio_readdev', '-u', 'ip:' + PP, '-b', '262144', '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1'], stdout=f, stderr=subprocess.PIPE, text=True, timeout=120)
    cout = cyc.communicate(timeout=60)[0]; bg.wait(timeout=60)
    m = re.search(r'Max:\s*(\d+)', cout)
    d = np.fromfile(D + 'soak.bin', dtype='<i2'); z = d[0::2] + 1j * d[1::2]
    sp = np.abs(np.fft.fft(z[:1 << 18] * np.blackman(1 << 18))); f0 = np.fft.fftfreq(1 << 18, 1 / fs)[sp.argmax()]
    B = 512; y = (z * np.exp(-2j * np.pi * f0 * np.arange(len(z)) / fs))[:len(z) // B * B].reshape(-1, B).mean(1)
    dp = np.angle(y[1:] * np.conj(y[:-1])); dev = dp - medf(dp, 101)
    return int(m.group(1)) if m else -1, int((np.abs(dev) > .4).sum()), len(z) == n, r.returncode
st = (h.save_settings(PL), h.save_settings(PP))
t_end = time.time() + 15 * 60; it = 0; worst = 0; outl = 0; short = 0; fails = 0; okc = 0
try:
    h.configure(PL, PP, 10000000, 4000000, 2400000000, 30, -10)
    h.start_tx(PL, h.tone(10000000, h.tone_freq(10000000, 1250)), 2000); time.sleep(1)
    while time.time() < t_end:
        it += 1
        mx, ou, full, rc = stream(10000000, 5)
        worst = max(worst, mx); outl += ou; short += (not full) + (rc != 0)
        print('iter %d: stream cyclictest max %d us, outliers %d, full %s rc %d' % (it, mx, ou, full, rc), flush=True)
    h.stop_tx(PL)
finally:
    h.tx_cleanup(PL); h.restore_settings(PL, st[0]); h.restore_settings(PP, st[1])
print('STREAM SOAK: iterations %d worst cyclictest max %d us outliers total %d incomplete %d' % (it, worst, outl, short))
# the check that failed once, repeated
t_end = time.time() + 6 * 60; k = 0
while time.time() < t_end:
    k += 1
    o = subprocess.run(['timeout', '600', sys.executable.replace('python3', 'python') if False else '/home/mb/.venvs/pluto-test/bin/python', 'rf_iq_check.py', '--fs', '2500000', '--tx', PP, '--rx', PL, '--rx-gain', '52'], capture_output=True, text=True).stdout
    line = [l for l in o.splitlines() if 'cw 205000' in l]
    bad = 'FAIL' in o
    fails += bad; okc += (not bad)
    print('iq_check %d: %s' % (k, 'FAIL' if bad else 'ok'), (line[0][-110:] if line else ''), flush=True)
print('IQ CHECK REPEAT: runs %d ok %d FAIL %d' % (k, okc, fails))
print('SOAK_DONE')
