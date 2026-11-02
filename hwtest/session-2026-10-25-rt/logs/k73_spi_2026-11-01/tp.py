# usage: tp.py recv PORT   |  tp.py send HOST PORT MB   -> prints MB/s
import socket, sys, time
if sys.argv[1] == 'recv':
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(('0.0.0.0', int(sys.argv[2]))); s.listen(1); s.settimeout(60)
    c, _ = s.accept(); n = 0; t0 = None
    while True:
        d = c.recv(1 << 20)
        if t0 is None: t0 = time.time()
        if not d: break
        n += len(d)
    t = time.time() - t0; print('recv %.1f MB in %.2f s = %.1f MB/s' % (n / 1e6, t, n / 1e6 / t))
else:
    h, p, mb = sys.argv[2], int(sys.argv[3]), int(sys.argv[4]); b = b'\0' * (1 << 20)
    s = socket.create_connection((h, p), timeout=30); t0 = time.time()
    for _ in range(mb): s.sendall(b)
    s.close(); t = time.time() - t0; print('send %d MB in %.2f s = %.1f MB/s' % (mb, t, mb / t))
