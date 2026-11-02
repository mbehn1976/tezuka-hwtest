"""Compare the images built from branch all-fixes-v0.3.23 with the known-good ones."""
import hashlib, os, subprocess, sys, zipfile
K = os.path.expanduser('~/tezuka-review-v0.3.23/hwtest/known_good/')
N = os.path.expanduser('~/code/tezuka_fw-all/output/')

def md5(p): return hashlib.md5(open(p, 'rb').read()).hexdigest()

def cpio_files(path, off):
    import lzma
    d = lzma.decompress(open(path, 'rb').read()[off:])
    i, out = 0, {}
    while True:
        h = d[i:i + 110]
        if h[:6] != b'070701': break
        f = lambda k: int(h[6 + 8 * k:14 + 8 * k], 16)
        size, nl = f(6), f(11)
        name = d[i + 110:i + 110 + nl - 1].decode()
        i = (i + 110 + nl + 3) & ~3
        out[name] = d[i:i + size]
        i = (i + size + 3) & ~3
        if name == 'TRAILER!!!': break
    return out

def kernel(path):
    import lzma
    return lzma.decompress(open(path, 'rb').read()[64:])

print('== plutoplus SD image: built vs known_good/sdimg-v0.3.23-all12')
nd, kd = N + 'plutoplus/images/sdimg/', K + 'sdimg-v0.3.23-all12/'
for f in sorted(os.listdir(kd)):
    if os.path.isdir(kd + f): continue
    if not os.path.exists(nd + f): print(f'  MISSING {f}'); continue
    same = md5(nd + f) == md5(kd + f)
    print(f'  {"same" if same else "DIFF"}  {f}')
    if not same and f == 'uImage':
        print('        kernel payload identical:', kernel(nd + f) == kernel(kd + f))
    if not same and f == 'uramdisk.image.xz':
        a, b = cpio_files(nd + f, 64), cpio_files(kd + f, 64)
        print('        ramdisk files:', len(a), len(b), ' differing:', sorted(n for n in a if a[n] != b.get(n)),
              ' only-new:', sorted(set(a) - set(b)), ' only-old:', sorted(set(b) - set(a)))
