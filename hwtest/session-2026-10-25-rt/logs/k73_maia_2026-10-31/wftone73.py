"""Spectrometer cache-coherency check: step the AD9363 BIST tone and follow the /waterfall peak.

The BIST tone replaces the ADC data (mode 2), so the spectrum is noise-free and every frame for a
given tone is bit-identical. The AD9363 offers 4 tone frequencies, (i+1) * fs/32 for i = 0..3. After
each change the peak must reach the expected bin within a frame or two, and each tone must always give
the same spectrum. Stale cache lines would show an old spectrum, or a mix, after the switch.
Usage: wftone.py <host> [ssh_host] -> JSON on stdout.
"""
import asyncio, json, struct, subprocess, sys, time
import numpy as np
import websockets

HOST = sys.argv[1]
SSH_HOST = sys.argv[2] if len(sys.argv) > 2 else HOST
SSH = ['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
       '-o', 'LogLevel=ERROR', f'root@{SSH_HOST}']
DBG = '/sys/kernel/debug/iio/iio:device1'


def sh(cmd):
    return subprocess.run(SSH + [cmd], capture_output=True, text=True, timeout=30).stdout


async def main():
    fs = int(sh('cat /sys/bus/iio/devices/iio:device1/in_voltage_sampling_frequency'))
    steps = [0, 3, 1, 2, 0, 2, 3, 1, 3, 0] * 3    # BIST tone index i: (i+1) * fs / 32
    out = {'fs': fs, 'steps': []}
    frames_all = []
    settled_specs = {}
    async with websockets.connect(f'ws://{HOST}/waterfall', max_size=None) as ws:
        async def frames(seconds):
            got, t_end = [], time.monotonic() + seconds
            while time.monotonic() < t_end:
                m = await asyncio.wait_for(ws.recv(), 5)
                if isinstance(m, bytes) and len(m) > 64:
                    got.append((time.monotonic(), m))
            return got
        await frames(1.0)
        for k in steps:
            f = (k + 1) * fs // 32
            sh(f'echo "2 {f} 6 0" > {DBG}/bist_tone')
            t_set = time.monotonic()
            got = await frames(1.5)
            frames_all += [m for _, m in got]
            peaks, specs = [], []
            for t, m in got:
                spec = np.frombuffer(m[4:], dtype='<f4')
                peaks.append((round(t - t_set, 3), int(np.argmax(spec))))
                specs.append(m[4:])
            final = peaks[-1][1]
            first_ok = next((i for i in range(len(peaks)) if all(p == final for _, p in peaks[i:])), len(peaks))
            out['steps'].append({'i': k, 'tone_hz': f, 'final_peak_bin': final,
                                 'frames_before_settled': first_ok, 'settled_after_s': peaks[first_ok][0] if first_ok < len(peaks) else None,
                                 'frames': len(peaks)})
            # settled frames for this tone, to compare with other visits of the same tone
            settled_specs.setdefault(k, set()).update(specs[first_ok:])
    sh(f'echo "0 0 0 0" > {DBG}/bist_tone')
    n = len(frames_all[0]) // 4 if frames_all else 0
    out['spectrum_floats'] = n
    finals = {}
    for st in out['steps']:
        finals.setdefault(st['i'], set()).add(st['final_peak_bin'])
    out['peak_bin_per_tone'] = {i: sorted(v) for i, v in finals.items()}
    out['distinct_settled_spectra_per_tone'] = {i: len(v) for i, v in settled_specs.items()}
    out['max_frames_before_settled'] = max(st['frames_before_settled'] for st in out['steps'])
    print(json.dumps(out))

asyncio.run(main())
