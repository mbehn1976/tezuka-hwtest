import sys, numpy as np
sys.path.insert(0, '.')
import hwlib, rf_phase_check as R
FR = 4096
br = hwlib.bitrev()
def synth(fs, f, snr_db=55, nfr=70, seed=0):
    rng = np.random.default_rng(seed)
    win = R.bh_window(FR)
    n = np.arange(FR * nfr)
    ph0 = rng.uniform(0, 2 * np.pi)
    x = np.exp(1j * (2 * np.pi * f * n / fs + ph0))
    frames = []
    for k in range(nfr):
        seg = x[k * FR:(k + 1) * FR] * win
        X = np.fft.fftshift(np.fft.fft(seg))
        sig = np.abs(X).max()
        X = X + sig * 10 ** (-snr_db / 20) * (rng.normal(size=FR) + 1j * rng.normal(size=FR)) / np.sqrt(2)
        frames.append(X)
    frames = np.array(frames)
    raw = np.concatenate([fr[br] for fr in frames])      # raw index i holds natural bin br[i]
    iq = frames[:4]
    return raw, iq
def run(fs, frac, base_bin=420, snr=55, seed=0):
    f = (base_bin + frac) * fs / FR
    raw, iq = synth(fs, f, snr, seed=seed)
    return R.analyse(fs, f, raw, iq, br)
if __name__ == '__main__':
    fs = float(sys.argv[1]) if len(sys.argv) > 1 else 2.5e6
    for snr in (55, 40):
        print('snr', snr)
        for frac in np.arange(0, 1.0, 0.05):
            r = run(fs, frac, snr=snr)
            print('frac %.2f bin %d  ph_err %7.2f amp_err %6.2f iq_vs_raw %6.1f' % (frac, r['peak_bin'], r['model_max_phase_err_deg'], r['model_max_amp_err_db'], r['iq_vs_raw_max_phase_diff_deg']))
