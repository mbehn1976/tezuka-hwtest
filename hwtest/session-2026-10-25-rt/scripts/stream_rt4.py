import sys, time, subprocess, re, numpy as np
sys.path.insert(0, '.')
import hwlib as h
PL, PP = '192.168.2.1', '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', 'root@' + PP]
def run(fs, secs, load, tag):
    n = int(fs * secs)
    cyc_t = int(secs + 8)
    pre = 'cd /tmp; export LD_LIBRARY_PATH=/tmp; '
    cmds = []
    if load:
        cmds.append(subprocess.Popen(SSH + [pre + 'taskset -c 0 ./stress-ng --cpu 1 --vm 1 --vm-bytes 64M --timeout %ds >/dev/null 2>&1' % (cyc_t + 2)]))
    time.sleep(1)
    cyc = subprocess.Popen(SSH + [pre + './cyclictest -t1 -p98 -i250 -a0 -D %ds -m -q' % cyc_t], stdout=subprocess.PIPE, text=True)
    time.sleep(2)
    t0 = time.time()
    out = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad/stream_%s.bin' % tag
    with open(out, 'wb') as f:
        r = subprocess.run(['iio_readdev', '-u', 'ip:' + PP, '-b', '262144', '-s', str(n), 'cf-ad9361-lpc', 'voltage0', 'voltage1'], stdout=f, stderr=subprocess.PIPE, text=True, timeout=120)
    wall = time.time() - t0
    cout = cyc.communicate(timeout=60)[0]
    for c in cmds: c.wait(timeout=60)
    m = re.search(r'Min:\s*(\d+).*Avg:\s*(\d+)\s+Max:\s*(\d+)', cout)
    d = np.fromfile(out, dtype='<i2')
    z = d[0::2].astype(float) + 1j * d[1::2].astype(float)
    ph = np.unwrap(np.angle(z)); dph = np.diff(ph)
    res = dph - np.median(dph)
    jumps = int((np.abs(res) > 0.5).sum())
    print('%s fs=%.1f MS/s load=%s: samples %d/%d wall %.2fs (real %.2fs) phase jumps %d rc=%d  cyclictest min/avg/max us = %s  %s' % (
        tag, fs / 1e6, load, len(z), n, wall, secs, jumps, r.returncode, m.groups() if m else cout.strip()[-80:], r.stderr.strip()[:80]))
st = (h.save_settings(PL), h.save_settings(PP))
try:
    for fs in (2500000, 10000000):
        h.configure(PL, PP, fs, 2000000, 2400000000, 30, -10)
        h.start_tx(PL, h.tone(fs, h.tone_freq(fs, 2500)), 2000)
        time.sleep(1)
        for load in (False, True):
            run(fs, 5, load, '%d_%s' % (fs // 1000000, 'load' if load else 'idle'))
        h.stop_tx(PL)
finally:
    h.tx_cleanup(PL); h.restore_settings(PL, st[0]); h.restore_settings(PP, st[1])
