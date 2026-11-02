# measure how many /waterfall frames after an MQTT retune still show the old LO position
import sys, asyncio, time, subprocess, json
import numpy as np, websockets
RX = '192.168.3.1'
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'LogLevel=ERROR', f'root@{RX}']
async def main():
    frames = []   # (t_arrival, peak_bin)
    async with websockets.connect(f'ws://{RX}/waterfall', max_size=None) as ws:
        async def reader():
            async for m in ws:
                if isinstance(m, bytes) and len(m) >= 16384:
                    a = np.frombuffer(m, '<f4')[1:].copy(); a[2040:2056] = 0
                    frames.append((time.time(), int(a.argmax())))
        task = asyncio.create_task(reader())
        await asyncio.sleep(4)
        events = []
        for i, lo in enumerate([2400500000, 2400000000, 2400500000, 2400000000, 2400500000, 2400000000]):
            t0 = time.time()
            await asyncio.to_thread(subprocess.run, SSH + [f'mosquitto_pub -h 127.0.0.1 -t cmd/rx/frequency -m {lo}'])
            t1 = time.time()
            events.append((t0, t1, lo))
            await asyncio.sleep(6)
        task.cancel()
    # classify
    base = {}
    for (t0, t1, lo), nxt in zip(events, events[1:] + [(1e18, 1e18, 0)]):
        pre = [b for t, b in frames if t < t0][-3:]
        post = [(round(t - t1, 2), b) for t, b in frames if t1 <= t < nxt[0]]
        print(f'LO -> {lo/1e6:.1f}: pre peak bins {pre}; frames after publish (s, bin):', post[:6])
asyncio.run(main())
