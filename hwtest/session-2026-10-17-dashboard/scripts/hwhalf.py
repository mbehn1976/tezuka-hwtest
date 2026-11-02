# real captures with the tone at a half-bin position: old against new analysis on the same data
import sys, asyncio, importlib.util, numpy as np
sd = '/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad'
sys.path.insert(0, '.')
import hwlib, rf_phase_check as NEW
spec = importlib.util.spec_from_file_location('rf_old', sd + '/rf_phase_check_old.py'); OLD = importlib.util.module_from_spec(spec); spec.loader.exec_module(OLD)
tx, rx, fs = sys.argv[1], sys.argv[2], int(sys.argv[3]); rxgain = int(sys.argv[4]); target = float(sys.argv[5]); n = int(sys.argv[6])
bw = min(int(0.8 * fs), 50_000_000) if fs > 2_500_000 else 2_000_000
br = hwlib.bitrev(); FR = 4096; bwid = fs / FR
tx_s, rx_s = hwlib.save_settings(tx), hwlib.save_settings(rx)
try:
    hwlib.configure(tx, rx, fs, bw, 2_400_000_000, rxgain)
    f = hwlib.tone_freq(fs, 2050)
    for _ in range(3):   # steer the received tone to the wanted fractional bin position
        hwlib.start_tx(tx, hwlib.tone(fs, f), 6000)
        ftd = hwlib.td_freq(hwlib.td_capture(rx), fs)
        frac = (2048 + ftd / bwid) % 1
        d = ((target - frac + 0.5) % 1 - 0.5) * bwid
        print('tone %.1f Hz received %.1f Hz fraction %.2f -> shift %.1f Hz' % (f, ftd, frac, d), flush=True)
        f += d
    rows = []
    for i in range(n):
        hwlib.start_tx(tx, hwlib.tone(fs, f), 6000)
        f0 = hwlib.td_freq(hwlib.td_capture(rx), fs)
        iq = hwlib.iq_words(asyncio.run(hwlib.grab_ws(rx, 'iq-waterfall', 4)))
        raw = hwlib.raw_capture(rx)
        f1 = hwlib.td_freq(hwlib.td_capture(rx), fs)
        fm = (f0 + f1) / 2
        o = OLD.analyse(fs, fm, raw, iq, br); w = NEW.analyse(fs, fm, raw, iq, br)
        rows.append((w['bin_fraction'], o['peak_bin'], o['model_max_phase_err_deg'], o['model_max_amp_err_db'], o['iq_vs_raw_max_phase_diff_deg'], w['model_max_phase_err_deg'], w['model_max_amp_err_db'], w['iq_vs_raw_max_phase_diff_deg'], w['model_bins'], w['dphi_scatter_rad'], w['f_diff_hz']))
        print('run %2d frac %.2f bin %d | OLD ph %6.2f amp %6.2f iq/raw %6.1f | NEW ph %5.2f amp %5.2f iq/raw %5.1f bins %d | scatter %.4f f_diff %.1f' % ((i,) + rows[-1]), flush=True)
    a = np.array(rows)
    print('MAX old ph %.1f amp %.1f iq/raw %.1f | new ph %.1f amp %.2f iq/raw %.1f' % (a[:, 2].max(), a[:, 3].max(), a[:, 4].max(), a[:, 5].max(), a[:, 6].max(), a[:, 7].max()))
finally:
    hwlib.tx_cleanup(tx); hwlib.restore_settings(tx, tx_s); hwlib.restore_settings(rx, rx_s)
