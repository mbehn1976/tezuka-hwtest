"""N3 test: end-to-end RF level across the extended tuning range, over the cabled link (40 dB attenuator).

The TX board sends a single-sideband tone at LO + 960 kHz (cyclic TX DMA buffer; the DDS is compiled out), the RX board tunes to the
same LO with a fixed manual gain and captures CS16 with iio_readdev. Per frequency: tone level (dBFS), image at
the mirror frequency (dBc), SNR in a 1 MHz band, measured offset, RSSI and VCO lock on both boards.
The result includes cables, attenuator and DC block, so it shows the relative response, not dBm.
Usage: rfsweep.py <label> <tx_host> <rx_host> [rx_gain_db] [tx_atten_db] -> results/<label>-rfsweep.json
Original radio settings of both boards are restored at the end.
"""
import json, os, subprocess, sys, time
import numpy as np

LABEL, TXH, RXH = sys.argv[1:4]
RXGAIN = float(sys.argv[4]) if len(sys.argv) > 4 else 30
TXATT = float(sys.argv[5]) if len(sys.argv) > 5 else -10
FREQS_MHZ = [46.9, 50, 60, 70, 100, 150, 200, 300, 325, 433, 700, 1000, 1500, 2400, 3000, 3800,
             4200, 4600, 5000, 5400, 5800, 5990]
if os.environ.get('FREQS'):
    FREQS_MHZ = [float(v) for v in os.environ['FREQS'].split(',')]
TONE = 960000
N = 262144
HERE = os.path.dirname(os.path.abspath(__file__))
PHY = '/sys/bus/iio/devices/iio:device0'
DBG = '/sys/kernel/debug/iio/iio:device0/direct_reg_access'


def ssh(host, cmd, timeout=60, binary=False):
    r = subprocess.run(['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', '-o',
                        'UserKnownHostsFile=/dev/null', '-o', 'LogLevel=ERROR', f'root@{host}', cmd],
                       capture_output=True, timeout=timeout)
    return r.stdout if binary else r.stdout.decode().strip()


def dds_dir(host):
    return ssh(host, 'for d in /sys/bus/iio/devices/iio:device*; do grep -q dds-core $d/name && echo $d; done')


SAVE_ATTRS = ['out_altvoltage0_RX_LO_frequency', 'out_altvoltage1_TX_LO_frequency', 'in_voltage0_gain_control_mode',
              'in_voltage0_hardwaregain', 'out_voltage0_hardwaregain']


def save(host):
    return {a: ssh(host, f'cat {PHY}/{a}').split()[0] for a in SAVE_ATTRS}


def restore(host, s):
    cmds = [f'echo {s["out_altvoltage0_RX_LO_frequency"]} > {PHY}/out_altvoltage0_RX_LO_frequency',
            f'echo {s["out_altvoltage1_TX_LO_frequency"]} > {PHY}/out_altvoltage1_TX_LO_frequency',
            f'echo {s["out_voltage0_hardwaregain"]} > {PHY}/out_voltage0_hardwaregain',
            f'echo {s["in_voltage0_gain_control_mode"]} > {PHY}/in_voltage0_gain_control_mode']
    if s['in_voltage0_gain_control_mode'] == 'manual':
        cmds.append(f'echo {s["in_voltage0_hardwaregain"]} > {PHY}/in_voltage0_hardwaregain')
    ssh(host, '; '.join(cmds))


def lock(host, reg):
    return (int(ssh(host, f'echo {reg} > {DBG}; cat {DBG}'), 16) >> 1) & 1


def bh_window(n):
    k = np.arange(n) / n * 2 * np.pi
    return 0.35875 - 0.48829 * np.cos(k) + 0.14128 * np.cos(2 * k) - 0.01168 * np.cos(3 * k)


tx_saved, rx_saved = save(TXH), save(RXH)
txdds = dds_dir(TXH)
fs = int(ssh(RXH, f'cat {PHY}/in_voltage_sampling_frequency'))
out = {'tx': TXH, 'rx': RXH, 'rx_gain_db': RXGAIN, 'tx_atten_db': TXATT, 'fs': fs, 'tone_hz': TONE,
       'tx_saved': tx_saved, 'rx_saved': rx_saved, 'points': []}
try:
    # single sideband tone at +TONE through the TX DMA (the DDS is compiled out, DAC_DDS_DISABLE=1): one cyclic
    # buffer with a whole number of periods (960 kHz = 32 samples at 30.72 MS/s), so it repeats without gaps
    n = 32768
    t = np.arange(n)
    assert (TONE * n) % fs == 0, 'buffer must hold a whole number of tone periods'
    iq = np.empty(2 * n, dtype='<i2')
    iq[0::2] = np.round(16000 * np.cos(2 * np.pi * TONE * t / fs))
    iq[1::2] = np.round(16000 * np.sin(2 * np.pi * TONE * t / fs))
    subprocess.run(['sshpass', '-p', 'analog', 'ssh', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
                    '-o', 'LogLevel=ERROR', f'root@{TXH}', 'cat > /tmp/rfs_tone.bin'], input=iq.tobytes(), check=True)
    ssh(TXH, f"echo {TXATT} > {PHY}/out_voltage0_hardwaregain; printf '%s\\n' "
             f"'iio_writedev -c -b {n} cf-ad9361-dds-core-lpc voltage0 voltage1 < /tmp/rfs_tone.bin > /tmp/rfs_tx.log 2>&1 &' "
             f"> /tmp/rfs_tx.sh; sh /tmp/rfs_tx.sh")
    time.sleep(2)
    out['tx_writer'] = ssh(TXH, f'echo writers $(pidof iio_writedev | wc -w) buffer $(cat {txdds}/buffer/enable); cat /tmp/rfs_tx.log')
    print('TX', out['tx_writer'], flush=True)
    assert out['tx_writer'].startswith('writers 1 buffer 1'), 'TX writer not running'
    ssh(RXH, f'echo manual > {PHY}/in_voltage0_gain_control_mode; echo {RXGAIN} > {PHY}/in_voltage0_hardwaregain')
    got_gain = ssh(RXH, f'cat {PHY}/in_voltage0_hardwaregain')
    out['rx_gain_read'] = got_gain
    win = bh_window(N)
    for fm in FREQS_MHZ:
        f = int(fm * 1e6)
        ssh(TXH, f'echo {f} > {PHY}/out_altvoltage1_TX_LO_frequency')
        ssh(RXH, f'echo {f} > {PHY}/out_altvoltage0_RX_LO_frequency')
        time.sleep(1.0)
        txlo = int(ssh(TXH, f'cat {PHY}/out_altvoltage1_TX_LO_frequency'))
        rxlo = int(ssh(RXH, f'cat {PHY}/out_altvoltage0_RX_LO_frequency'))
        raw = ssh(RXH, f'iio_readdev -b {N} -s {N * 2} cf-ad9361-lpc voltage0 voltage1 > /tmp/rfs.bin 2>/dev/null; '
                       f'tail -c {N * 4} /tmp/rfs.bin; rm -f /tmp/rfs.bin', binary=True, timeout=60)
        d = np.frombuffer(raw, dtype='<i2').reshape(-1, 2).astype(float)
        x = (d[:, 0] + 1j * d[:, 1]) / 2048.0
        X = np.fft.fftshift(np.fft.fft(x * win)) / win.sum()
        P = np.abs(X) ** 2
        fr = np.fft.fftshift(np.fft.fftfreq(N, 1 / fs))
        sel = np.abs(fr - TONE) < 300e3                          # tone within 300 kHz of +1 MHz (ref offset)
        k = np.flatnonzero(sel)[np.argmax(P[sel])]
        tone_p = P[k - 4:k + 5].sum()
        km = np.argmin(np.abs(fr + fr[k]))                       # mirror bin
        img_p = P[km - 4:km + 5].sum()
        band = (np.abs(fr) < 1.5e6) & (np.abs(fr) > 20e3) & (np.abs(fr - fr[k]) > 50e3) & (np.abs(fr + fr[k]) > 50e3)
        noise_per_bin = np.median(P[band])
        enbw = 2.0                                               # Blackman-Harris ENBW in bins
        snr_1mhz = 10 * np.log10(tone_p / (noise_per_bin / enbw * (1e6 / (fs / N))))
        pt = {'f_mhz': fm, 'tx_lo': txlo, 'rx_lo': rxlo,
              'tx_lock': lock(TXH, '0x287'), 'rx_lock': lock(RXH, '0x247'),
              'tone_dbfs': round(10 * np.log10(tone_p), 1),
              'offset_khz': round((fr[k] - TONE) / 1e3, 1),
              'image_dbc': round(10 * np.log10(img_p / tone_p), 1),
              'snr_1mhz_db': round(snr_1mhz, 1),
              'max_abs': int(np.abs(d).max()),
              'rssi': ssh(RXH, f'cat {PHY}/in_voltage0_rssi')}
        out['points'].append(pt)
        print(json.dumps(pt), flush=True)
finally:
    ssh(TXH, 'kill $(pidof iio_writedev) 2>/dev/null; sleep 1; rm -f /tmp/rfs_tone.bin /tmp/rfs_tx.sh')
    restore(TXH, tx_saved)
    restore(RXH, rx_saved)
    out['tx_restored'], out['rx_restored'] = save(TXH), save(RXH)
    os.makedirs(f'{HERE}/results', exist_ok=True)
    json.dump(out, open(f'{HERE}/results/{LABEL}-rfsweep.json', 'w'), indent=1)
    print('restored TX', out['tx_restored'], '\nrestored RX', out['rx_restored'])
