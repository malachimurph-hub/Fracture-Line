#!/usr/bin/env python3
"""M2.9: seamless terrain macro-variation map (assets/textures/terrain/terrain_macro.png).
The M2 map was not tileable, which showed as straight seams every 64 m. This one is periodic by
construction (FFT-filtered noise), keeps each channel's old mean / spread, and is smooth (no grain).
R = brightness, G = hue shift, B = dry/lush. Run: python3 tools/gen_terrain_macro_m29.py"""
import numpy as np, os
from PIL import Image
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "terrain", "terrain_macro.png")
old = np.asarray(Image.open(P).convert("RGB")).astype(float) / 255.0
N = 512
rng = np.random.default_rng(29)
fx = np.fft.fftfreq(N)[:, None]; fy = np.fft.fftfreq(N)[None, :]
f = np.sqrt(fx ** 2 + fy ** 2) * N        # cycles per tile
out = np.zeros((N, N, 3))
for c, (lo, hi) in enumerate([(1.0, 10.0), (0.8, 6.0), (1.5, 14.0)]):
    x = np.zeros((N, N))
    for k, (a, b, wgt) in enumerate([(lo, lo * 2.5, 1.0), (lo * 2.5, hi, 0.45)]):   # two octaves, no high frequencies
        spec = np.fft.fft2(rng.standard_normal((N, N)))
        band = np.exp(-((np.log(np.maximum(f, 1e-3)) - np.log(np.sqrt(a * b))) ** 2) / 0.5)
        band[f > hi * 1.5] = 0
        x += np.real(np.fft.ifft2(spec * band)) * wgt
    x = (x - x.mean()) / (x.std() + 1e-9)
    out[:, :, c] = np.clip(old[:, :, c].mean() + x * old[:, :, c].std(), 0, 1)
Image.fromarray((out * 255 + 0.5).astype(np.uint8)).save(P)
a = out
print("seam L/R %.4f  inner %.4f" % (abs(a[:, 0] - a[:, -1]).mean(), abs(a[:, 1] - a[:, 2]).mean()))
