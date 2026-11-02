# Browser-like housekeeping load on the Pluto+: 2 waterfall websockets + /api polling at 5 Hz
import asyncio, sys, time
sys.path.insert(0, '/home/mb/code/maia-sdr-bp/maia-hdl/hwtest')
import hwlib as h
HOST = '192.168.3.1'; SECS = float(sys.argv[1])
async def ws(path):
    end = time.monotonic() + SECS
    while time.monotonic() < end:
        try: await h.grab_ws(HOST, path, 5)
        except Exception: await asyncio.sleep(1)
async def poll():
    end = time.monotonic() + SECS
    while time.monotonic() < end:
        for p in ('/api', '/api/ad9361', '/api/spectrometer'):
            try: await asyncio.to_thread(h.http, HOST, 'GET', p)
            except Exception: pass
        await asyncio.sleep(0.2)
async def main(): await asyncio.gather(ws('waterfall'), ws('waterfall'), poll())
asyncio.run(main())
