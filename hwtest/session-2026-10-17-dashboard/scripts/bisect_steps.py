import asyncio, os, sys, time
sys.path.insert(0, os.path.expanduser('~/code/maia-sdr-bp/maia-hdl/hwtest'))
import hwlib, numpy as np
TX, RX = '192.168.3.1', '192.168.2.1'
fs = 61_440_000
bw = min(int(0.8 * fs), 50_000_000)
usb = lambda: os.path.exists('/sys/bus/usb/devices/3-6.1')
t0 = time.time()
def step(name, fn):
    if not usb():
        print(f'[{time.time()-t0:5.1f}s] USB ALREADY GONE before: {name}', flush=True); sys.exit(2)
    fn()
    for _ in range(8):           # dwell 4 s after each step
        time.sleep(0.5)
        if not usb():
            print(f'[{time.time()-t0:5.1f}s] >>> USB DROP right after step: {name}', flush=True); sys.exit(1)
    print(f'[{time.time()-t0:5.1f}s] ok: {name}', flush=True)
step('configure both boards', lambda: hwlib.configure(TX, RX, fs, bw, 2_400_000_000, 52))
f0 = hwlib.tone_freq(fs, 2050)
step('start TX tone on Pluto+', lambda: hwlib.start_tx(TX, hwlib.tone(fs, f0), 6000))
y = []
step('td_capture on Pluto (libiio over USB net)', lambda: y.append(hwlib.td_capture(RX)))
async def ws():
    mag, iq = await asyncio.gather(hwlib.grab_ws(RX, 'waterfall', 5), hwlib.grab_ws(RX, 'iq-waterfall', 5))
step('websocket /waterfall + /iq-waterfall on Pluto', lambda: asyncio.run(ws()))
step('raw_capture on Pluto', lambda: hwlib.raw_capture(RX))
step('second td_capture', lambda: hwlib.td_capture(RX))
hwlib.stop_tx(TX)
print('ALL STEPS OK, no drop', flush=True)
