#!/usr/bin/env python3
"""M2.9 rock soundtrack: four ORIGINAL tracks composed and rendered in numpy for this game
(same approach as tools/gen_music.py: pure synthesis, no samples, no third-party audio).

  menu_breach_point.ogg    "Breach Point"      menu banger, E minor, 150 bpm, chugging riffs + lead
  battle_iron_convoy.ogg   "Iron Convoy"       battle shuffle, D minor, 132 bpm, driving hard rock
  battle_dust_devils.ogg   "Dust Devils"       battle shuffle, A minor, 168 bpm, fast punk-rock
  battle_last_light.ogg    "Last Light Rising" battle shuffle, C# minor, 96 bpm, heavy groove

Guitar = detuned saws summed as power chords (root/5th/octave) through tanh overdrive and a
cabinet-style band-limit; palm mutes are short + darker. Licence: original work for the project.
Run: python3 tools/gen_music_m29.py [track...]
"""
import numpy as np, subprocess, os, sys
R = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")
rng = np.random.default_rng(29)

def fftfilt(x, lo=0.0, hi=None, slope=4):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / R)
    g = np.ones_like(f)
    if hi: g *= 1 / (1 + (f / hi) ** slope)
    if lo: g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** slope)
    return np.fft.irfft(X * g, len(x))
def peak(x, f0, q, gain):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / R)
    return np.fft.irfft(X * (1 + gain * np.exp(-((f - f0) / (f0 / q)) ** 2)), len(x))
def env(n, a, d, s=0.0, r=0.05, hold=None):
    x = np.arange(n) / R; hold = hold if hold is not None else n / R
    e = np.where(x < a, x / max(a, 1e-4), s + (1 - s) * np.exp(-(x - a) * 4 / max(d, 1e-4)))
    rel = np.clip(1 - (x - hold) / r, 0, 1); return e * np.where(x > hold, rel, 1)
def saw(f, d, det=0.0, vib=0.0):
    tt = np.arange(int(d * R)) / R
    y = 0
    for dd in ([-det, 0, det] if det else [0]):
        fm = f * (1 + dd) * (1 + vib * np.sin(2 * np.pi * 5.5 * tt) * np.clip(tt * 2 - 0.3, 0, 1))
        ph = (np.cumsum(fm) / R + rng.uniform()) % 1
        y = y + (2 * ph - 1)
    return y / (3 if det else 1)
def sine(f, d): return np.sin(2 * np.pi * f * np.arange(int(d * R)) / R)
def noise(d): return rng.uniform(-1, 1, int(d * R))
def hz(n): return 440 * 2 ** ((n - 69) / 12)
def put(buf, x, at, pan=0.0, g=1.0):
    s = int(at * R); e = min(len(buf), s + len(x))
    if e <= s: return
    x = x[:e - s] * g
    buf[s:e, 0] += x * np.sqrt(0.5 * (1 - pan)); buf[s:e, 1] += x * np.sqrt(0.5 * (1 + pan))
def room(buf, size=0.9, wet=0.14):
    n = int(size * R); out = np.zeros_like(buf); L = len(buf) + n
    for c in range(2):
        ir = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / R * 6 / size); ir = fftfilt(ir, 250, 6000)
        y = np.fft.irfft(np.fft.rfft(buf[:, c], L) * np.fft.rfft(ir, L), L)
        w = y[:len(buf)].copy(); w[:n] += y[len(buf):len(buf) + n][:len(buf)]
        out[:, c] = w
    out /= np.max(np.abs(out)) + 1e-9
    return buf * (1 - wet) + out * wet * np.max(np.abs(buf))
def master(buf):
    buf = buf - buf.mean(axis=0)
    buf = buf / (np.max(np.abs(buf)) + 1e-9)
    return np.tanh(buf * 1.9) / np.tanh(1.9)   # glue / loudness
def save(name, buf, q=3):
    buf = master(buf) * 0.92
    pcm = (np.clip(buf, -1, 1) * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(R), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name)], input=pcm, check=True)
    print(name, round(len(buf) / R, 1), "s")

_gc = {}
def gtr(root, d, mute=False, chord="5", drive=9.0):
    """distorted power chord (midi root), duration d seconds"""
    key = (root, round(d, 3), mute, chord, drive)
    if key in _gc: return _gc[key]
    iv = {"5": [0, 7, 12], "1": [0, 12], "m": [0, 7, 12, 15]}[chord]
    x = sum(saw(hz(root + i), d, 0.004) * (1.0 if i == 0 else 0.8) for i in iv)
    if mute:
        x = fftfilt(x, 60, 900) * env(len(x), 0.002, 0.09, 0.0, 0.02)
    else:
        x = fftfilt(x, 70, 5000) * env(len(x), 0.003, 1.5, 0.75, 0.05, d - 0.05)
    y = np.tanh(x * drive)
    y = fftfilt(peak(y, 1800, 2.5, 0.8), 90, 4200, 6)
    _gc[key] = y * (0.55 if mute else 0.5)
    return _gc[key]
def lead(n, d, bend=False):
    x = saw(hz(n), d, 0.002, vib=0.012)
    x = np.tanh(fftfilt(x, 200, 4500) * 12) * env(int(d * R), 0.01, 2.0, 0.8, 0.08, d - 0.08)
    return fftfilt(peak(x, 2400, 2, 1.0), 250, 5200, 6) * 0.42
def bass(n, d):
    x = saw(hz(n), d) * 0.6 + np.sin(2 * np.pi * hz(n) * np.arange(int(d * R)) / R)
    return np.tanh(fftfilt(x, 35, 700) * 2.5) * env(int(d * R), 0.004, 0.6, 0.6, 0.03, d - 0.03) * 0.55
def kick():
    d = 0.35; f = 50 + 110 * np.exp(-np.arange(int(d * R)) / R * 35)
    y = np.tanh(np.sin(2 * np.pi * np.cumsum(f) / R) * env(int(d * R), 0.001, 0.22) * 1.8)
    y[:320] += fftfilt(noise(0.01), 1500) * np.linspace(0.5, 0, 320)   # beater click
    return y
def snare():
    d = 0.28
    return np.tanh((fftfilt(noise(d), 1200, 8000) * env(int(d * R), 0.001, 0.13) * 0.9 + sine(200, d) * env(int(d * R), 0.001, 0.05) * 0.8) * 1.6)
def hat(open_=False):
    d = 0.25 if open_ else 0.05; return fftfilt(noise(d), 8000) * env(int(d * R), 0.0005, 0.12 if open_ else 0.02) * 0.3
def crash():
    d = 2.2; return fftfilt(noise(d), 4500) * env(int(d * R), 0.001, 1.4) * 0.38
def tom(f):
    d = 0.4; ff = np.linspace(f * 1.5, f, int(d * R))
    return np.sin(2 * np.pi * np.cumsum(ff) / R) * env(int(d * R), 0.002, 0.25) * 0.8

def drums(B, t0, beat, style, fill=False, crash_on=False):
    if crash_on: put(B, crash(), t0, 0.3, 1.0)
    if style == "half":     # heavy half-time groove
        for b, k in [(0, 1), (0.75, 0.7), (1.5, 0.8), (3, 0.6), (3.5, 0.6)]:
            put(B, kick(), t0 + b * beat, 0, k)
        put(B, snare(), t0 + 2 * beat, 0.05, 1.0)
    elif style == "punk":   # kick-snare every beat pair + 8th hats
        for b in range(4):
            put(B, kick(), t0 + b * beat, 0, 0.9)
            put(B, snare(), t0 + (b + 0.5) * beat, 0.05, 0.75)
    else:                    # straight rock beat
        for b, k in [(0, 1), (1.5, 0.7), (2, 0.9), (2.5, 0.6)]:
            put(B, kick(), t0 + b * beat, 0, k)
        put(B, snare(), t0 + beat, 0.05, 0.95); put(B, snare(), t0 + 3 * beat, 0.05, 1.0)
    for h in range(8):
        put(B, hat(h == 7 and style != "punk"), t0 + h * beat / 2, 0.45, 0.8 if h % 2 == 0 else 0.55)
    if fill:
        for k, f in enumerate([220, 220, 160, 160, 110, 110, 80, 80]):
            put(B, tom(f) if k < 6 else snare(), t0 + 3 * beat + k * beat / 8, -0.3 + k * 0.08, 0.7)

def riff_bar(B, t0, beat, pattern, root, gpan=0.6):
    """pattern: list of (start_beat, length_beats, interval, mute) -> double-tracked guitars + bass"""
    for st, ln, iv, mute in pattern:
        d = ln * beat * (0.92 if mute else 0.98)
        g = gtr(root + iv, d, mute)
        put(B, g, t0 + st * beat, -gpan, 1.0); put(B, g, t0 + st * beat + 0.011, gpan, 0.95)
        put(B, bass(root + iv - 12, max(d, beat / 2 * 0.9)), t0 + st * beat, 0, 0.9)

def chug(n=8, accents=()):
    """8th-note palm-mute chug on the root with accented open hits"""
    out = []
    for k in range(n):
        if k in accents: out.append((k * 0.5, 0.5, accents[k], False))
        else: out.append((k * 0.5, 0.5, 0, True))
    return out

def song(name, bpm, root, sections, lead_line=None):
    beat = 60 / bpm; bars = sum(s[0] for s in sections); L = bars * 4 * beat
    B = np.zeros((int(L * R) + int(2.5 * R), 2))
    bar = 0
    for (n, kind, pats, style) in sections:
        for i in range(n):
            t0 = bar * 4 * beat
            pat = pats[i % len(pats)]
            if kind != "intro_drums":
                riff_bar(B, t0, beat, pat, root)
            if style:
                drums(B, t0, beat, style, fill=(i % 4 == 3), crash_on=(i % 4 == 0))
            if kind == "lead" and lead_line:
                for st, ln, iv in lead_line[i % len(lead_line)]:
                    put(B, lead(root + 24 + iv, ln * beat * 0.97), t0 + st * beat, 0.1, 1.0)
            bar += 1
    put(B, crash(), bar * 4 * beat, 0.3, 1.0)
    put(B, gtr(root, 2.4), bar * 4 * beat, -0.5, 1.0); put(B, gtr(root, 2.4), bar * 4 * beat + 0.011, 0.5, 1.0)
    save(name, room(B))

def full(*hits):   # open chords: (start, len, interval)
    return [(s, l, iv, False) for (s, l, iv) in hits]

TRACKS = {}
def t_breach():   # MENU banger, E minor 150
    A = chug(8, {0: 0, 3: 3, 6: 5})
    Bp = chug(8, {0: 0, 3: 7, 5: 5, 7: 3})
    C = full((0, 1.5, 0), (1.5, 1.5, -2), (3, 1, -4))
    D = full((0, 1.5, -5), (1.5, 1.5, -4), (3, 0.5, -2), (3.5, 0.5, 0))
    lead_line = [[(0, 1.5, 7), (1.5, 0.5, 10), (2, 2, 12)], [(0, 1, 15), (1, 1, 14), (2, 2, 12)],
                 [(0, 1.5, 10), (1.5, 0.5, 12), (2, 2, 7)], [(0, 0.5, 5), (0.5, 0.5, 7), (1, 3, 3)]]
    song("menu_breach_point.ogg", 150, 40, [
        (2, "riff", [A], None), (2, "riff", [A, Bp], "rock"), (8, "riff", [A, Bp], "rock"),
        (8, "lead", [C, D], "half"), (8, "riff", [A, Bp], "punk"), (8, "lead", [C, D], "rock"), (4, "riff", [A, Bp], "rock")], lead_line)
TRACKS["breach"] = t_breach
def t_convoy():   # D minor 132
    A = [(0, 0.5, 0, True), (0.5, 0.5, 0, True), (1, 1, 3, False), (2, 0.5, 0, True), (2.5, 0.5, 0, True), (3, 1, 5, False)]
    Bp = [(0, 0.5, 0, True), (0.5, 0.5, 0, True), (1, 1, 7, False), (2, 1, 5, False), (3, 0.5, 3, False), (3.5, 0.5, 1, False)]
    C = full((0, 2, -4), (2, 2, -2))
    D = full((0, 2, 0), (2, 1, 3), (3, 1, 5))
    lead_line = [[(0, 2, 12), (2, 1, 10), (3, 1, 12)], [(0, 1, 15), (1, 1, 17), (2, 2, 15)], [(0, 3, 14), (3, 1, 12)], [(0, 4, 10)]]
    song("battle_iron_convoy.ogg", 132, 38, [(4, "riff", [A, Bp], "rock"), (8, "riff", [A, Bp], "rock"), (8, "lead", [C, D], "rock"),
                                             (8, "riff", [A, Bp], "half"), (8, "lead", [C, D], "rock"), (4, "riff", [A, Bp], "rock")], lead_line)
TRACKS["convoy"] = t_convoy
def t_devils():   # A minor 168, punk
    A = full((0, 1, 0), (1, 1, 0), (2, 1, 3), (3, 1, 5))
    Bp = full((0, 1, 7), (1, 1, 5), (2, 1, 3), (3, 1, -2))
    C = chug(8, {0: 0, 4: -2})
    lead_line = [[(0, 1, 12), (1, 1, 15), (2, 2, 17)], [(0, 1, 19), (1, 1, 17), (2, 2, 15)], [(0, 2, 12), (2, 2, 10)], [(0, 4, 12)]]
    song("battle_dust_devils.ogg", 168, 45, [(4, "riff", [C], "punk"), (8, "riff", [A, Bp], "punk"), (8, "lead", [A, Bp], "punk"),
                                             (8, "riff", [C], "half"), (8, "lead", [A, Bp], "punk"), (4, "riff", [C], "punk")], lead_line)
TRACKS["devils"] = t_devils
def t_last():   # C# minor 96, heavy groove
    A = [(0, 0.75, 0, False), (0.75, 0.25, 0, True), (1, 0.5, 0, True), (1.5, 1, 3, False), (2.5, 0.5, 0, True), (3, 1, -2, False)]
    Bp = [(0, 0.75, 0, False), (0.75, 0.25, 0, True), (1, 0.5, 0, True), (1.5, 1, 5, False), (2.5, 0.5, 6, False), (3, 1, 7, False)]
    C = full((0, 4, -4))
    D = full((0, 2, -2), (2, 2, 0))
    lead_line = [[(0, 3, 12), (3, 1, 10)], [(0, 2, 7), (2, 2, 8)], [(0, 3, 10), (3, 1, 12)], [(0, 4, 15)]]
    song("battle_last_light.ogg", 96, 37, [(2, "riff", [A], None), (6, "riff", [A, Bp], "half"), (8, "lead", [C, D], "half"),
                                           (8, "riff", [A, Bp], "rock"), (4, "lead", [C, D], "half")], lead_line)
TRACKS["last"] = t_last

for k in (sys.argv[1:] or list(TRACKS)):
    TRACKS[k]()
