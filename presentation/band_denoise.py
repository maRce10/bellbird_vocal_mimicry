# spectral subtraction of a stationary noise band: per-frequency median magnitude (over the
# whole file) times alpha is subtracted inside [lo, hi] Hz, with a spectral floor
import sys, numpy as np, soundfile as sf
from scipy.signal import stft, istft
inp, out, lo, hi, alpha = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
x, sr = sf.read(inp, always_2d=True)
y = np.zeros_like(x)
for c in range(x.shape[1]):
    f, t, Z = stft(x[:, c], fs=sr, nperseg=2048, noverlap=1536)
    mag, ph = np.abs(Z), np.angle(Z)
    noise = np.median(mag, axis=1, keepdims=True)
    band = (f >= lo) & (f <= hi)
    # smooth taper at the band edges (300 Hz) so no hard spectral step
    w = np.clip(np.minimum(f - lo + 300, hi + 300 - f) / 300, 0, 1)[:, None]
    new = np.maximum(mag - alpha * noise * w, 0.05 * mag)
    _, xr = istft(new * np.exp(1j * ph), fs=sr, nperseg=2048, noverlap=1536)
    y[:, c] = xr[:x.shape[0]]
sf.write(out, y, sr, subtype="PCM_16")
