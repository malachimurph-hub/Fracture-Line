#!/usr/bin/env python3
"""Original missile launch swoosh and impact boom. Synthesised from noise and sine
partials (numpy + scipy), same method as tools/m43/gen_sfx_m43.py. No samples,
no third-party recordings. License: written for this project, no external licence.
  python3 tools/m47/gen_missile_sfx.py
Writes audio/sfx/missile_swoosh.ogg and audio/sfx/missile_impact.ogg.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "sfx")
rng = np.random.default_rng(47)


def t(d):
    return np.arange(int(SR * d)) / SR


def lp(x, f, o=4):
    return sosfilt(butter(o, f, "low", fs=SR, output="sos"), x)


def hp(x, f, o=2):
    return sosfilt(butter(o, f, "high", fs=SR, output="sos"), x)


def bp(x, a, b, o=2):
    return sosfilt(butter(o, [a, b], "band", fs=SR, output="sos"), x)


def noise(d):
    return rng.standard_normal(int(SR * d))


def brown(d):
    x = np.cumsum(noise(d))
    x = hp(x, 12)
    return x / (np.abs(x).max() + 1e-9)


def norm(x, peak=0.89):
    return x / (np.abs(x).max() + 1e-9) * peak


def reverb(x, taps, tail=1.0):
    extra = int(SR * (tail + max(dt for dt, _ in taps)))
    y = np.concatenate([x, np.zeros(extra)])
    for dt, g in taps:
        k = int(SR * dt)
        y[k:k + len(x)] += g * lp(x, 1800)
    f = int(SR * 0.35)
    y[-f:] *= np.linspace(1, 0, f)
    return y


def write(name, x):
    with tempfile.TemporaryDirectory() as td:
        w = os.path.join(td, "a.wav")
        wavfile.write(w, SR, (norm(x) * 32767).astype(np.int16))
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-ac", "1", "-c:a", "libvorbis", "-q:a", "5",
             os.path.join(OUT, name + ".ogg")],
            check=True,
        )
    print("SFX", name)


# Launch swoosh: air rush that falls in pitch as the round leaves. Short, no speech.
d = 0.85
tt = t(d)
sweep = np.sin(2 * np.pi * np.cumsum(1400 - 900 * np.clip(tt / d, 0, 1)) / SR)
body = bp(noise(d), 280, 4200) * np.clip(tt / 0.03, 0, 1) * np.exp(-tt * 2.4)
whoosh = body * (0.85 + 0.15 * sweep) + 0.12 * sweep * np.exp(-tt * 3.0)
write("missile_swoosh", reverb(whoosh, ((0.03, 0.35), (0.08, 0.22), (0.16, 0.12)), tail=0.25))

# Impact: sub-bass thump, a body crack, then a low debris rattle that tails off.
d = 2.2
ti = t(d)
thump = np.sin(2 * np.pi * 42 * ti * (1 - 0.35 * np.clip(ti, 0, 1))) * np.exp(-ti * 3.2)
sub = lp(brown(d), 90) * np.exp(-ti * 1.6)
crack = hp(noise(d), 900) * np.exp(-ti * 28)
# debris: irregular low rattles after the boom
gate = (rng.random(len(ti)) > 0.92).astype(np.float64)
debris = bp(noise(d), 180, 1400) * gate * np.clip((ti - 0.08) / 0.12, 0, 1) * np.exp(-ti * 1.7)
boom = 0.95 * thump + 0.85 * sub + 0.28 * crack + 0.55 * debris
write("missile_impact", reverb(
    boom,
    ((0.04, 0.55), (0.11, 0.42), (0.22, 0.32), (0.4, 0.22), (0.68, 0.14), (1.05, 0.08)),
    tail=1.3,
))
