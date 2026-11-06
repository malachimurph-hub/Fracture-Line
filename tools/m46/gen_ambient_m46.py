#!/usr/bin/env python3
"""Short original ambience one-shots: a chirp, a squawk, and a light breeze.
No loop, no samples. numpy + the stdlib wave module + ffmpeg libvorbis.
  python3 tools/m46/gen_ambient_m46.py
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "ambient")
rng = np.random.default_rng(46)


def lp(x, fc):
    a = np.exp(-2.0 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1.0 - a) * v + a * s
        y[i] = s
    return y


def env(n, attack, release):
    t = np.arange(n) / SR
    dur = n / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((dur - t) / max(release, 1e-4), 0, 1)
    return np.minimum(a, r)


def tone(dur, f0, f1, attack=0.01, release=0.08):
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = np.linspace(f0, f1, n)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    x = np.sin(phase) + 0.18 * np.sin(2.0 * phase + 0.4)
    return x * env(n, attack, release)


def write(name, x, peak=0.42):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    pcm = np.clip(x, -1, 1)
    pcm = (pcm * 32767.0).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav_path = os.path.join(td, "a.wav")
        with wave.open(wav_path, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dest = os.path.join(OUT, name + ".ogg")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1", "-c:a", "libvorbis", "-q:a", "3", dest],
            check=True,
        )
    print("AMBIENT", name, "%.2fs" % (len(x) / SR))


# Two short notes, a small bird.
gap = np.zeros(int(SR * 0.07))
chirp = np.concatenate([
    tone(0.09, 2400, 3400, 0.008, 0.04),
    gap,
    tone(0.13, 2800, 1900, 0.008, 0.07),
])
write("bird_chirp", chirp, 0.38)

# One rougher call, still short.
n = int(SR * 0.32)
t = np.arange(n) / SR
noise = rng.standard_normal(n)
body = np.sin(2 * np.pi * np.cumsum(np.linspace(900, 520, n)) / SR)
squawk = (0.75 * body + 0.35 * lp(noise, 1800)) * env(n, 0.015, 0.12)
# a little rasp
squawk *= 0.85 + 0.15 * np.sign(np.sin(2 * np.pi * 70 * t))
write("bird_squawk", squawk, 0.36)

# A single soft gust. Fades out. Not a bed.
d = 1.35
nb = int(SR * d)
gust = lp(rng.standard_normal(nb), 700)
gust = gust - lp(gust, 180)  # keep the low rumble out
gust *= env(nb, 0.28, 0.55)
write("breeze", gust, 0.28)
