import sys, time, subprocess, re, numpy as np
sys.path.insert(0, '.')
import hwlib as h
PL, PP = '192.168.2.1', '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', 'root@' + PP]
D = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/'
def medf(x, k):
    from numpy.lib.stride_tricks import sliding_window_view as sw
    return np.median(sw(np.pad(x, k // 2, mode='edge'), k), axis=1)
def run(fs, n, load, tag):
    pre = 'cd /tmp; export LD_LIBRARY_PATH=/tmp; '
    secs = n / fs
    dur = int(secs + 10)
    bg = []
    if load:
        bg.append(subprocess.Popen(SSH + [pre + 'taskset -c 0 ./stress-ng --cpu 1 --vm 1 --vm-bytes 32M --timeout %ds >/dev/null 2>&1' % (dur + 2)]))
    time.sleep(1)
    cyc = subprocess.Popen(SSH + [pre + './cyclictest -t1 -p98 -i250 -a1 -D %ds -m -q' % dur], stdout=subprocess.PIPE, text=True)
    time.sleep(3)
    t0 = time.time()
    r = subprocess.run(SSH + [pre + 'iio_readdev -u local: -b 262144 -s %d cf-ad9361-lpc voltage0 voltage1 > /tmp/loc.bin 2>/tmp/loc.err; echo rc=$?; ls -l /tmp/loc.bin | cut -d" " -f5; cat /tmp/loc.err | head -3' % n], capture_output=True, text=True, timeout=120)
    wall = time.time() - t0
    cout = cyc.communicate(timeout=90)[0]
    for b in bg: b.wait(timeout=90)
    m = re.search(r'Min:\s*(\d+).*Avg:\s*(\d+)\s+Max:\s*(\d+)', cout)
    with open(D + 'loc_%s.bin' % tag, 'wb') as f:
        subprocess.run(SSH + ['cat /tmp/loc.bin; rm -f /tmp/loc.bin'], stdout=f, timeout=120)
    d = np.fromfile(D + 'loc_%s.bin' % tag, dtype='<i2')
    z = d[0::2] + 1j * d[1::2]
    if len(z) < 1 << 18:
        print(tag, 'too few samples', len(z), r.stdout.strip().replace('\n', ' | ')); return
    sp = np.abs(np.fft.fft(z[:1 << 18] * np.blackman(1 << 18))); f = np.fft.fftfreq(1 << 18, 1 / fs)[sp.argmax()]
    snr = 20 * np.log10(sp.max() / np.median(sp))
    B = 512
    y = (z * np.exp(-2j * np.pi * f * np.arange(len(z)) / fs))[:len(z) // B * B].reshape(-1, B).mean(1)
    dp = np.angle(y[1:] * np.conj(y[:-1])); dev = dp - medf(dp, 101)
    print('%s fs=%.2f MS/s load=%s: %d/%d samples, read %.2fs (signal %.2fs), tone %.0f kHz snr %.0f dB, incr std %.3f, outliers>0.4rad %d, >0.8rad %d, amp min/med %.2f | cyclictest min/avg/max us %s | %s' % (
        tag, fs / 1e6, load, len(z), n, wall - 0, secs, f / 1e3, snr, dev.std(), int((np.abs(dev) > .4).sum()), int((np.abs(dev) > .8).sum()), np.abs(y).min() / np.median(np.abs(y)), m.groups() if m else cout.strip()[-60:], r.stdout.strip().replace('\n', ' ')))
    import os; os.remove(D + 'loc_%s.bin' % tag)
st = (h.save_settings(PL), h.save_settings(PP))
try:
    for fs, n in ((10000000, 25000000), (20000000, 25000000), (30720000, 25000000), (61440000, 25000000)):
        try:
            h.configure(PL, PP, fs, 4000000, 2400000000, 30, -10)
        except AssertionError as e:
            print('cannot set', fs, e); continue
        k = int(500e3 * h.TONE_PERIOD / fs)
        h.start_tx(PL, h.tone(fs, h.tone_freq(fs, k)), 2000)
        time.sleep(1)
        for load in (False, True):
            run(fs, n, load, '%d_%s' % (fs // 1000000, 'load' if load else 'idle'))
        h.stop_tx(PL)
finally:
    h.tx_cleanup(PL); h.restore_settings(PL, st[0]); h.restore_settings(PP, st[1])
