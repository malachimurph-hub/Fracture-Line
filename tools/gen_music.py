#!/usr/bin/env python3
"""FRACTURE LINE: composes and renders the two ORIGINAL music tracks (menu, battle) by
additive/subtractive synthesis in numpy. Written for this project; no samples.
Run: python3 tools/gen_music.py"""
import numpy as np, subprocess, os
R = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")
rng = np.random.default_rng(7)

def fftfilt(x, lo=0.0, hi=None, slope=4):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / R)
    g = np.ones_like(f)
    if hi: g *= 1 / (1 + (f / hi) ** slope)
    if lo: g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** slope)
    return np.fft.irfft(X * g, len(x))
def env(n, a, d, s=0.0, r=0.05, hold=None):
    x = np.arange(n) / R; hold = hold if hold is not None else n / R
    e = np.where(x < a, x / max(a, 1e-4), s + (1 - s) * np.exp(-(x - a) * 4 / max(d, 1e-4)))
    rel = np.clip(1 - (x - hold) / r, 0, 1); return e * np.where(x > hold, rel, 1)
def saw(f, d, det=0.0):
    tt = np.arange(int(d * R)) / R
    y = 0
    for k, dd in enumerate([-det, 0, det] if det else [0]):
        ph = (f * (1 + dd) * tt + rng.uniform()) % 1
        y = y + (2 * ph - 1)
    return y / (3 if det else 1)
def sine(f, d): return np.sin(2 * np.pi * f * np.arange(int(d * R)) / R)
def noise(d): return rng.uniform(-1, 1, int(d * R))
def hz(n): return 440 * 2 ** ((n - 69) / 12)
def put(buf, x, at, pan=0.0, g=1.0):
    s = int(at * R); e = min(len(buf), s + len(x)); x = x[:e - s] * g
    buf[s:e, 0] += x * np.sqrt(0.5 * (1 - pan)); buf[s:e, 1] += x * np.sqrt(0.5 * (1 + pan))
def reverb(buf, size=1.8, wet=0.25):
    n = int(size * R); ir = rng.uniform(-1, 1, (n, 2)) * np.exp(-np.arange(n) / R * 5 / size)[:, None]
    ir[:, 0] = fftfilt(ir[:, 0], 200, 5000); ir[:, 1] = fftfilt(ir[:, 1], 200, 5000)
    out = np.zeros_like(buf)
    L = len(buf) + n
    for c in range(2):
        y = np.fft.irfft(np.fft.rfft(buf[:, c], L) * np.fft.rfft(ir[:, c], L), L)
        y = y[:len(buf)] + y[len(buf):len(buf) + len(buf)].sum() * 0 if False else y
        # wrap the tail so the loop point stays seamless
        wrapped = y[:len(buf)].copy(); tail = y[len(buf):]
        wrapped[:len(tail)] += tail[:len(buf)]
        out[:, c] = wrapped
    out /= np.max(np.abs(out)) + 1e-9
    return buf * (1 - wet) + out * wet * np.max(np.abs(buf))
def save(name, buf, q=2):
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * 0.85
    pcm = (np.clip(buf, -1, 1) * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(R), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name)], input=pcm, check=True)
    print(name, round(len(buf) / R, 1), "s")

# drums
def kick(): d = 0.45; f = np.linspace(120, 42, int(d * R)); return np.sin(2 * np.pi * np.cumsum(f) / R) * env(int(d * R), 0.002, 0.25)
def snare(): d = 0.3; return fftfilt(noise(d), 900, 7000) * env(int(d * R), 0.001, 0.12) * 0.8 + sine(190, d) * env(int(d * R), 0.001, 0.06) * 0.5
def tom(f): d = 0.6; ff = np.linspace(f * 1.4, f, int(d * R)); return np.sin(2 * np.pi * np.cumsum(ff) / R) * env(int(d * R), 0.002, 0.35) + fftfilt(noise(d), 80, 900) * env(int(d * R), 0.001, 0.08) * 0.5
def hat(): d = 0.06; return fftfilt(noise(d), 7000) * env(int(d * R), 0.0005, 0.025) * 0.35
def taiko(): d = 0.9; return tom(62) * 1.3

# ---------------------------------------------------------------- BATTLE: "Steel Rain" (D minor, 112 bpm)
bpm = 112; beat = 60 / bpm; bars = 36; L = bars * 4 * beat
B = np.zeros((int(L * R) + 1, 2))
prog = [(50, "m"), (46, "M"), (48, "M"), (45, "m")]   # Dm Bb C Am (roots, midi)
for bar in range(bars):
    t0 = bar * 4 * beat
    root, q = prog[(bar // 2) % 4]
    sect = 0 if bar < 4 else (1 if bar < 20 else (2 if bar < 32 else 3))
    # drums
    if sect >= 1:
        for b in range(4):
            put(B, kick(), t0 + b * beat, 0, 0.9 if b % 2 == 0 else 0.6)
            if b % 2 == 1: put(B, snare(), t0 + b * beat, 0.1, 0.7)
            for h in range(2): put(B, hat(), t0 + b * beat + h * beat / 2, 0.4, 0.8)
        if bar % 4 == 3:
            for k in range(8): put(B, snare(), t0 + 3 * beat + k * beat / 8, -0.1, 0.25 + k * 0.06)
    for b in [0, 1.5, 2.5] if sect != 3 else [0, 0.75, 1.5, 2, 2.5, 3.25]:
        put(B, taiko(), t0 + b * beat, -0.2, 0.7)
    # bass ostinato (16ths)
    pat = [0, 0, 12, 0, 0, 7, 0, 10] * 2
    for k, iv in enumerate(pat):
        f = hz(root - 12 + iv)
        n = fftfilt(saw(f, beat / 4 * 0.95), 30, 900) * env(int(beat / 4 * 0.95 * R), 0.003, 0.12, 0.3)
        put(B, n, t0 + k * beat / 4, 0, 0.42 if sect else 0.3)
    # low strings pad
    third = 3 if q == "m" else 4
    chord = [root, root + third, root + 7, root + 12]
    for i, nn in enumerate(chord):
        p = fftfilt(saw(hz(nn), 4 * beat, 0.006), 80, 1800) * env(int(4 * beat * R), 0.5, 3, 0.7, 0.3, 4 * beat - 0.3)
        put(B, p, t0, -0.5 + i * 0.33, 0.12)
    # brass stabs / lead motif in sections 2-3
    if sect >= 2:
        motif = [(0, 12, 1.5), (1.5, 10, 0.5), (2, 15, 1.0), (3, 14, 1.0)] if bar % 2 == 0 else [(0, 12, 1.0), (1, 7, 1.0), (2, 10, 2.0)]
        for st, iv, du in motif:
            d = du * beat * 0.9; n = saw(hz(root + iv), d, 0.004)
            bright = fftfilt(n, 150, 3200); dark = fftfilt(n, 150, 900)
            e = env(len(n), 0.03, 0.4, 0.6, 0.1, d - 0.1)
            put(B, (dark + (bright - dark) * env(len(n), 0.02, 0.25)) * e, t0 + st * beat, 0.2, 0.32)
    # intro pulse
    if sect == 0:
        for k in range(8):
            put(B, fftfilt(saw(hz(root + 24), 0.1), 400, 2500) * env(int(0.1 * R), 0.002, 0.06), t0 + k * beat / 2, 0.3, 0.2)
save("battle_steel_rain.ogg", reverb(B, 1.6, 0.22))

# ---------------------------------------------------------------- MENU: "Dust Over Varno" (A minor, slow)
bpm = 76; beat = 60 / bpm; bars = 20; L = bars * 4 * beat
M = np.zeros((int(L * R) + 1, 2))
prog = [(45, "m"), (41, "M"), (43, "M"), (40, "m")]   # Am F G Em
for bar in range(bars):
    t0 = bar * 4 * beat; root, q = prog[bar % 4]; third = 3 if q == "m" else 4
    for i, nn in enumerate([root, root + 7, root + 12, root + 12 + third, root + 19]):
        p = fftfilt(saw(hz(nn), 4 * beat + 0.6, 0.008), 100, 1400) * env(int((4 * beat + 0.6) * R), 1.2, 4, 0.8, 0.6, 4 * beat)
        put(M, p, t0, -0.6 + i * 0.3, 0.1)
    put(M, fftfilt(saw(hz(root - 12), 4 * beat, 0.003), 30, 400) * env(int(4 * beat * R), 0.2, 3, 0.7, 0.3, 4 * beat - 0.3), t0, 0, 0.35)
    if bar >= 4:
        for b in range(4):
            put(M, tom(55), t0 + b * beat, -0.2, 0.35 if b % 2 == 0 else 0.2)
        for k in range(8):   # ticking pulse
            put(M, fftfilt(noise(0.03), 3000, 9000) * env(int(0.03 * R), 0.001, 0.01), t0 + k * beat / 2, 0.5, 0.25)
    if bar >= 8:   # sparse bell-ish melody
        mel = [12, 15, 19, 17] if bar % 2 == 0 else [19, 17, 15, 14]
        for k, iv in enumerate(mel):
            n = sine(hz(root + 12 + iv), 1.6) * env(int(1.6 * R), 0.005, 0.9) + sine(hz(root + 24 + iv) * 1.0, 1.6) * env(int(1.6 * R), 0.003, 0.4) * 0.3
            put(M, n, t0 + k * beat, 0.25, 0.18)
save("menu_dust_over_varno.ogg", reverb(M, 2.4, 0.35))
