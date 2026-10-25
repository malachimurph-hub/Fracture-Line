#!/usr/bin/env python3
"""M3.2 faction battle music: four ORIGINAL tracks composed and rendered in numpy for this game
(pure synthesis, no samples, no third-party audio; helpers shared with tools/gen_music_m29.py).

  battle_us_liberty_steel.ogg  "Liberty Steel"  US   - military rock, E minor, 144 bpm: marching
                               snare intro, double-tracked power-chord riffs, live-style kit, lead
  battle_ru_red_bounce.ogg     "Red Bounce"     RU   - hard-bass techno, B minor (harmonic), 152 bpm:
                               distorted punchy kick, bouncing off-beat saw bass, claps, minor lead
  battle_de_tiefgarage.ogg     "Tiefgarage"     DE   - Berlin club techno, A minor, 130 bpm: deep
                               four-on-the-floor, rumble bass, dub chord stabs + delay, acid line
  battle_ir_zagros.ogg         "Zagros"         IR   - cinematic war drums: daf, tombak, low booms,
                               santur tremolo + tar-like plucks in a Shur-style mode (koron 2nd)

Usage: python3 tools/gen_music_m32.py [us ru de ir] [--sample OUTDIR]   (needs numpy + ffmpeg)
--sample also writes a ~20 s excerpt per track (m32_music_<faction>.ogg) to OUTDIR.
Licence: original work for the project.
"""
import numpy as np, os, sys, subprocess
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_music_m29.py")).read()
_src = _src[:_src.index("for k in (sys.argv[1:] or list(TRACKS)):")]
exec(compile(_src, "gen_music_m29.py", "exec"))   # fftfilt, env, saw, sine, noise, hz, put, room, master, save, gtr, lead, bass, kick, snare, hat, crash, tom, drums, riff_bar, chug, full, song
rng = np.random.default_rng(32)
SAMPLES = {}

def save2(name, buf, sample_key, s0, s1=None):
    """save the full track (q 3) and remember a 20 s excerpt (from s0 seconds) for --sample"""
    save(name, buf)
    a = int(s0 * R); b = a + int(20 * R)
    ex = buf[a:b].copy()
    fade = int(0.8 * R)
    ex[:fade] *= np.linspace(0, 1, fade)[:, None]; ex[-fade:] *= np.linspace(1, 0, fade)[:, None]
    SAMPLES[sample_key] = ex

def square(f, d, pw=0.5):
    tt = np.arange(int(d * R)) / R; ph = (f * tt + rng.uniform()) % 1
    return np.where(ph < pw, 1.0, -1.0)

def delay(buf, t, fb=0.4, wet=0.35, n=4):
    out = buf.copy(); s = int(t * R)
    for k in range(1, n + 1):
        out[s * k:] += buf[:len(buf) - s * k][:, ::-1] * (wet * fb ** (k - 1))   # ping-pong
    return out

# =================================================================== US: Liberty Steel
def t_us():
    bpm = 144; beat = 60 / bpm; root = 40   # E
    B = None
    A = chug(8, {0: 0, 3: 3, 6: 5})
    Bp = [(0, 0.5, 0, True), (0.5, 0.5, 0, True), (1, 1, 7, False), (2, 0.5, 0, True), (2.5, 0.5, 5, False), (3, 1, 3, False)]
    C = full((0, 2, -4), (2, 1, -2), (3, 1, 0))
    D = full((0, 2, 3), (2, 2, 5))
    lead_line = [[(0, 1.5, 7), (1.5, 0.5, 5), (2, 2, 7)], [(0, 1, 10), (1, 1, 12), (2, 2, 15)],
                 [(0, 1.5, 12), (1.5, 0.5, 10), (2, 2, 7)], [(0, 0.5, 5), (0.5, 0.5, 7), (1, 3, 3)]]
    sections = [(2, "intro_drums", [A], None), (8, "riff", [A, Bp], "rock"), (8, "lead", [C, D], "rock"),
                (4, "riff", [A, Bp], "half"), (8, "lead", [C, D], "rock"), (8, "riff", [A, Bp], "punk"), (2, "riff", [A], "rock")]
    bars = sum(s[0] for s in sections); L = bars * 4 * beat
    B = np.zeros((int(L * R) + int(2.5 * R), 2))
    # marching snare cadence over the 2-bar intro (military)
    for bar in range(2):
        t0 = bar * 4 * beat
        for k in range(16):
            acc = 1.0 if k % 4 == 0 else 0.45
            put(B, snare(), t0 + k * beat / 4, 0.1, 0.5 * acc)
        put(B, kick(), t0, 0, 0.9); put(B, kick(), t0 + 2 * beat, 0, 0.8)
    bar = 0
    for (n, kind, pats, style) in sections:
        for i in range(n):
            t0 = bar * 4 * beat; pat = pats[i % len(pats)]
            if kind != "intro_drums":
                riff_bar(B, t0, beat, pat, root)
                drums(B, t0, beat, style, fill=(i % 4 == 3), crash_on=(i % 4 == 0))
                if i % 4 == 0:   # military snare roll into each phrase
                    for k in range(6): put(B, snare(), t0 - beat / 2 + k * beat / 12, -0.1, 0.18 + k * 0.05)
            if kind == "lead":
                for st, ln, iv in lead_line[i % len(lead_line)]:
                    put(B, lead(root + 24 + iv, ln * beat * 0.97), t0 + st * beat, 0.1, 1.0)
            bar += 1
    put(B, crash(), bar * 4 * beat, 0.3, 1.0)
    put(B, gtr(root, 2.4), bar * 4 * beat, -0.5, 1.0); put(B, gtr(root, 2.4), bar * 4 * beat + 0.011, 0.5, 1.0)
    B = room(B)
    save2("battle_us_liberty_steel.ogg", B, "us", 10 * 4 * beat)

# =================================================================== RU: Red Bounce (hard bass)
def hb_kick():
    d = 0.32; f = 48 + 190 * np.exp(-np.arange(int(d * R)) / R * 28)
    y = np.sin(2 * np.pi * np.cumsum(f) / R) * env(int(d * R), 0.001, 0.2, 0.0)
    y = np.tanh(y * 4.0)   # hard, distorted
    y[:240] += fftfilt(noise(0.0075), 2000) * np.linspace(0.8, 0, 240)
    return y * 0.95
def clap():
    d = 0.22; x = fftfilt(noise(d), 900, 6000)
    e = sum(env(int(d * R), 0.001, 0.012) * (np.arange(int(d * R)) >= int(k * 0.011 * R)) for k in range(3)) * 0.4 + env(int(d * R), 0.001, 0.09)
    return x * e * 0.8
def hb_bass(n, d):
    """bouncy off-beat hard-bass: detuned saws, pitch drop, squashed"""
    m = int(d * R); tt = np.arange(m) / R
    f = hz(n) * (1 + 0.5 * np.exp(-tt * 40))
    y = 0
    for det in (-0.012, 0, 0.012):
        ph = np.cumsum(f * (1 + det)) / R % 1; y = y + (2 * ph - 1)
    y = fftfilt(y / 3, 30, 2400)
    return np.tanh(y * 3.5) * env(m, 0.002, d * 0.9, 0.0, 0.02) * 0.55
def hb_lead(n, d):
    x = square(hz(n), d, 0.35) * 0.6 + saw(hz(n + 12), d, 0.006) * 0.4
    return fftfilt(x, 300, 5000) * env(int(d * R), 0.005, 0.3, 0.55, 0.05, d - 0.05) * 0.28
def t_ru():
    bpm = 152; beat = 60 / bpm; root = 35   # B
    bars = 64; L = bars * 4 * beat
    B = np.zeros((int(L * R) + R, 2))
    prog = [0, 0, -4, -2]   # Bm Bm G A (harmonic-minor flavour in the lead)
    # B harmonic minor: B C# D E F# G A# B
    mel_a = [(0, 0.5, 12), (0.5, 0.5, 15), (1, 0.5, 19), (1.5, 0.5, 15), (2, 1, 18), (3, 0.5, 17), (3.5, 0.5, 15)]
    mel_b = [(0, 0.5, 19), (0.5, 0.5, 18), (1, 0.5, 15), (1.5, 0.5, 14), (2, 1, 12), (3, 1, 11)]
    for bar in range(bars):
        t0 = bar * 4 * beat; r = root + prog[(bar // 2) % 4]
        sect = 0 if bar < 8 else (1 if bar < 24 else (2 if bar < 32 else (3 if bar < 56 else 4)))
        if sect != 2:
            for b in range(4): put(B, hb_kick(), t0 + b * beat, 0, 1.0)
        if sect >= 1:
            for b in range(4): put(B, hb_bass(r, beat * 0.45), t0 + b * beat + beat / 2, 0, 0.9)   # bounce on the off-beat
            put(B, clap(), t0 + beat, 0.05, 0.8); put(B, clap(), t0 + 3 * beat, 0.05, 0.8)
        for h in range(16):
            put(B, hat(h % 4 == 2), t0 + h * beat / 4, 0.4 if h % 2 else -0.4, 0.7 if h % 4 == 2 else 0.35)
        if sect in (2, 3):
            for st, ln, iv in (mel_a if bar % 2 == 0 else mel_b):
                put(B, hb_lead(root + 12 + iv, ln * beat * 0.9), t0 + st * beat, 0.2, 1.0)
                put(B, hb_lead(root + 12 + iv, ln * beat * 0.9), t0 + st * beat + 0.018, -0.2, 0.7)
        if sect == 2:   # breakdown: riser
            n = fftfilt(noise(4 * beat), 500 + bar % 8 * 600, 9000) * np.linspace(0, 1, int(4 * beat * R)) * 0.25
            put(B, n, t0, 0, 1.0)
            put(B, fftfilt(saw(hz(r + 12), 4 * beat, 0.01), 100, 2000) * env(int(4 * beat * R), 0.3, 3, 0.7, 0.3, 4 * beat - 0.3), t0, 0, 0.25)
        if bar % 8 == 0 and bar > 0: put(B, crash(), t0, 0.3, 0.8)
    save2("battle_ru_red_bounce.ogg", room(B, 0.6, 0.08), "russia", 24 * 4 * beat)

# =================================================================== DE: Tiefgarage (Berlin club)
def deep_kick():
    d = 0.5; f = 42 + 80 * np.exp(-np.arange(int(d * R)) / R * 30)
    y = np.sin(2 * np.pi * np.cumsum(f) / R) * env(int(d * R), 0.002, 0.42)
    return np.tanh(y * 1.6) * 0.95
def rumble(d):   # low, reverb-washed kick tail (Berlin "rumble")
    x = fftfilt(noise(d), 30, 140, 6) * env(int(d * R), 0.02, d * 0.8) * 2.2
    return np.tanh(x * 2.0) * 0.5
def stab(notes, d):
    x = sum(saw(hz(n), d, 0.005) for n in notes) / len(notes)
    return fftfilt(x, 200, 1500) * env(int(d * R), 0.002, 0.18) * 0.5
def acid(n, d, cut):
    x = saw(hz(n), d)
    x = fftfilt(x, 40, cut, 8)
    return np.tanh(x * 3.0) * env(int(d * R), 0.002, d * 0.8, 0.3, 0.02) * 0.32
def t_de():
    bpm = 130; beat = 60 / bpm; root = 33   # A
    bars = 64; L = bars * 4 * beat
    B = np.zeros((int(L * R) + R, 2)); S = np.zeros_like(B)
    acid_pat = [0, 0, 12, 0, 3, 0, 10, 0, 0, 7, 0, 12, 0, 3, 5, 0]
    for bar in range(bars):
        t0 = bar * 4 * beat
        sect = 0 if bar < 8 else (1 if bar < 24 else (2 if bar < 32 else 3))
        if sect != 2:
            for b in range(4):
                put(B, deep_kick(), t0 + b * beat, 0, 1.0)
                if sect >= 1: put(B, rumble(beat * 0.9), t0 + b * beat + beat * 0.25, 0, 0.8)
        for b in range(4):
            put(B, hat(True), t0 + b * beat + beat / 2, 0.3, 0.6)                 # off-beat open hat
        for h in range(16):
            put(B, fftfilt(noise(0.03), 6000) * env(int(0.03 * R), 0.001, 0.01) * 0.25, t0 + h * beat / 4, -0.35, 0.6 + 0.4 * (h % 4 == 0))
        if sect >= 1:
            put(B, clap(), t0 + beat, 0.0, 0.45); put(B, clap(), t0 + 3 * beat, 0.0, 0.45)
            # deep rolling sub bassline (16ths, root + fifth)
            for k in range(16):
                if k % 4 != 0:
                    nb = root - 12 + (7 if k in (6, 14) else 0)
                    put(B, np.tanh(fftfilt(sine(hz(nb), beat / 4 * 0.8) + saw(hz(nb), beat / 4 * 0.8) * 0.2, 30, 300) * 2) * env(int(beat / 4 * 0.8 * R), 0.002, 0.1) * 0.5, t0 + k * beat / 4, 0, 1.0)
        # dub chord stabs (Am7) into a ping-pong delay send
        if sect >= 1 and sect != 2:
            for st in (0.75, 2.5):
                put(S, stab([root + 24, root + 27, root + 31, root + 34], beat * 0.4), t0 + st * beat, 0.0, 1.0)
        if sect >= 3 or sect == 2:   # hypnotic acid line, cutoff sweeping over 8 bars
            cut = 400 + 2400 * (0.5 - 0.5 * np.cos(2 * np.pi * (bar % 8) / 8))
            for k, iv in enumerate(acid_pat):
                put(B, acid(root + iv, beat / 4 * 0.85, cut), t0 + k * beat / 4, 0.15, 1.0)
        if bar % 16 == 0 and bar > 0: put(B, crash(), t0, 0.3, 0.6)
    S = delay(fftfilt_st(S, 250, 3000), beat * 0.75, 0.45, 0.5, 5)
    save2("battle_de_tiefgarage.ogg", room(B + S, 1.2, 0.12), "germany", 32 * 4 * beat)

def fftfilt_st(buf, lo, hi):
    out = buf.copy()
    for c in range(2): out[:, c] = fftfilt(buf[:, c], lo, hi)
    return out

# =================================================================== IR: Zagros (cinematic war drums)
def daf(heavy=True):   # frame drum: deep "dum" + jingles
    d = 0.6; m = int(d * R)
    f = 70 + 60 * np.exp(-np.arange(m) / R * 25)
    body = np.sin(2 * np.pi * np.cumsum(f) / R) * env(m, 0.001, 0.35) * (1.0 if heavy else 0.35)
    jing = fftfilt(noise(d), 5000, 12000) * env(m, 0.002, 0.18) * 0.45
    slap = fftfilt(noise(0.05), 800, 4000) * env(int(0.05 * R), 0.0005, 0.02) * 0.6
    y = body + jing; y[:len(slap)] += slap
    return y * 0.8
def tombak(kind):   # "tom" (bass, centre) / "bak" (sharp rim)
    if kind == "tom":
        d = 0.45; m = int(d * R); f = 95 + 70 * np.exp(-np.arange(m) / R * 30)
        return np.sin(2 * np.pi * np.cumsum(f) / R) * env(m, 0.001, 0.25) * 0.9
    d = 0.12; m = int(d * R)
    return (fftfilt(noise(d), 1500, 7000) * env(m, 0.0005, 0.03) + sine(520, d) * env(m, 0.0005, 0.04) * 0.6) * 0.6
def boom():
    d = 2.0; m = int(d * R); f = 38 + 50 * np.exp(-np.arange(m) / R * 6)
    y = np.sin(2 * np.pi * np.cumsum(f) / R) * env(m, 0.004, 1.2)
    y += fftfilt(noise(d), 40, 400) * env(m, 0.002, 0.4) * 0.6
    return np.tanh(y * 1.5) * 0.9
def string_pluck(f, d, bright=1.0, n_str=2, trem=0.0):
    """santur / tar-like plucked string: Karplus-Strong-ish decay via filtered harmonics"""
    m = int(d * R); tt = np.arange(m) / R; y = np.zeros(m)
    for s in range(n_str):
        ff = f * (1 + (s - (n_str - 1) / 2) * 0.0025)
        for h in range(1, 9):
            y += np.sin(2 * np.pi * ff * h * tt + rng.uniform(0, 6.28)) * (bright ** (h - 1)) / h * np.exp(-tt * (2.2 + h * 1.4))
    if trem > 0:
        y *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * trem * tt))
    return y * env(m, 0.0015, d, 1.0, 0.05) * 0.35
# Shur-style mode on D: D E-koron(+150c) F G A Bb C D  (cents from the tonic)
SHUR = [0, 150, 300, 500, 700, 800, 1000, 1200]
def fm(tonic, deg):
    o, i = divmod(deg, 7); return tonic * 2 ** (o + SHUR[i] / 1200)
def t_ir():
    bpm = 92; beat = 60 / bpm; tonic = hz(50)   # D3
    bars = 40; L = bars * 4 * beat
    B = np.zeros((int(L * R) + 2 * R, 2))
    phrase_a = [(0, 0.5, 4), (0.5, 0.5, 3), (1, 0.5, 2), (1.5, 0.5, 1), (2, 1.5, 0), (3.5, 0.5, 1)]
    phrase_b = [(0, 0.5, 2), (0.5, 0.5, 3), (1, 1, 4), (2, 0.5, 5), (2.5, 0.5, 4), (3, 1, 3)]
    phrase_c = [(0, 0.75, 7), (0.75, 0.25, 6), (1, 0.5, 5), (1.5, 0.5, 4), (2, 2, 4)]
    for bar in range(bars):
        t0 = bar * 4 * beat
        sect = 0 if bar < 4 else (1 if bar < 16 else (2 if bar < 28 else 3))
        # drone: low D + A strings
        if bar % 2 == 0:
            for nn, pan in ((tonic / 2, -0.3), (tonic * 0.75, 0.3)):
                dr = fftfilt(saw(nn, 8 * beat, 0.004), 40, 900) * env(int(8 * beat * R), 1.0, 6, 0.8, 0.8, 8 * beat - 0.8)
                put(B, dr, t0, pan, 0.14 if sect else 0.2)
        # daf groove (6/8-ish feel over 4/4: dum . tek dum tek tek)
        if sect >= 1:
            for st, hv in ((0, True), (0.75, False), (1.5, True), (2, False), (2.5, True), (3.25, False), (3.5, False)):
                put(B, daf(hv), t0 + st * beat, -0.25, 0.9 if hv else 0.6)
            for k in range(8):   # tombak rolls
                put(B, tombak("tom" if k in (0, 3, 6) else "bak"), t0 + k * beat / 2, 0.3, 0.7)
        if sect >= 2 or bar % 4 == 0:
            put(B, boom(), t0, 0, 0.9)
            if sect == 3: put(B, boom(), t0 + 2.5 * beat, 0, 0.7)
        # santur (tremolo) melody / tar answers
        if sect >= 1:
            ph = [phrase_a, phrase_b, phrase_a, phrase_c][bar % 4]
            for st, ln, deg in ph:
                f = fm(tonic * 2, deg)
                put(B, string_pluck(f, ln * beat + 0.6, 0.7, 2, 13.0 if ln >= 1 else 0.0), t0 + st * beat, 0.25, 0.9)
            if sect >= 2:   # tar-like answer an octave lower, nasal
                for st, ln, deg in ph[::2]:
                    put(B, fftfilt(string_pluck(fm(tonic, deg), ln * beat + 0.3, 0.85, 1), 250, 4000), t0 + st * beat + 2 * beat, -0.35, 0.8)
        if sect == 0:   # sparse santur intro
            for k, deg in enumerate((0, 4, 3, 2)):
                put(B, string_pluck(fm(tonic * 2, deg), 1.6, 0.7, 2, 13.0), t0 + k * beat, 0.2, 0.7)
    save2("battle_ir_zagros.ogg", room(B, 1.6, 0.18), "iran", 16 * 4 * beat)

TRACKS = {"us": t_us, "ru": t_ru, "de": t_de, "ir": t_ir}
if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sample_dir = sys.argv[sys.argv.index("--sample") + 1] if "--sample" in sys.argv else None
    if sample_dir in args: args.remove(sample_dir)
    for k in (args or list(TRACKS)):
        TRACKS[k]()
    if sample_dir:
        os.makedirs(sample_dir, exist_ok=True)
        for key, ex in SAMPLES.items():
            ex = master(ex) * 0.92
            pcm = (np.clip(ex, -1, 1) * 32767).astype("<i2").tobytes()
            p = os.path.join(sample_dir, "m32_music_%s.ogg" % key)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(R), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", p], input=pcm, check=True)
            print("sample", p)
