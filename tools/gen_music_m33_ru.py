#!/usr/bin/env python3
"""M3.3 Phase 4 (item 44): a more traditional Russian battle theme, ORIGINAL music composed and
rendered in numpy for this game (pure synthesis: no samples, no third-party recordings, no quoted
folk or anthem melodies).

  battle_ru_steppe_march.ogg  "Steppe March"  RU - D minor, 108 bpm, ~2.5 min:
      1. intro   - a low male choir hum and a slow balalaika tremolo line over a bass drone
      2. march A - bass drum + snare march, bayan (button accordion) oom-pah chords, low brass melody
      3. march B - the male choir sings the theme ("ah / oh" vowels) over the full band, balalaikas strum
      4. bridge  - a balalaika solo that speeds up the way a folk dance does, then the band crashes back
      5. finale  - theme A with choir, brass and timpani; broad final chord
Usage: python3 tools/gen_music_m33_ru.py [--sample OUTDIR]   (needs numpy + ffmpeg)
Licence: original work for the project."""
import numpy as np, os, sys, subprocess
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_music_m29.py")).read()
_src = _src[:_src.index("for k in (sys.argv[1:] or list(TRACKS)):")]
exec(compile(_src, "gen_music_m29.py", "exec"))   # fftfilt, env, saw, sine, noise, hz, put, room, master, save, kick, snare, crash ...
rng = np.random.default_rng(33)

BPM = 108
BEAT = 60 / BPM
BAR = 4 * BEAT

def tt_(d): return np.arange(int(d * R)) / R

def balalaika(f, d, trem=0.0, bright=0.75):
    """three-string balalaika pluck (bright, fast decay); trem > 0 = tremolo picking"""
    m = int(d * R); t = tt_(d); y = np.zeros(m)
    if trem > 0:   # repeated picks
        step = 1.0 / trem; k = 0
        while k * step < d:
            s = int(k * step * R); n = min(m - s, int(0.35 * R))
            if n <= 0: break
            tk = np.arange(n) / R
            for h in range(1, 8):
                y[s:s + n] += np.sin(2 * np.pi * f * h * tk + rng.uniform(0, 6.28)) * bright ** (h - 1) / h * np.exp(-tk * (6 + h * 2.5)) * (0.8 + 0.2 * rng.uniform())
            k += 1
        return y * env(m, 0.002, d, 1.0, 0.06) * 0.28
    for s in range(3):
        ff = f * (1 + (s - 1) * 0.002) * (1 if s < 2 else 2)
        for h in range(1, 9):
            y += np.sin(2 * np.pi * ff * h * t + rng.uniform(0, 6.28)) * bright ** (h - 1) / h * np.exp(-t * (3.0 + h * 1.8))
    return y * env(m, 0.0015, d, 1.0, 0.05) * 0.3

def bayan(notes, d, g=1.0):
    """button accordion chord: detuned reed pairs (pulse-ish), bellows swell, reedy band-pass"""
    m = int(d * R); t = tt_(d); y = np.zeros(m)
    bell = 0.85 + 0.15 * np.sin(2 * np.pi * 0.7 * t)
    for n in notes:
        f = hz(n)
        for det in (-0.0035, 0.0035):
            ph = (f * (1 + det) * t + rng.uniform()) % 1
            y += np.where(ph < 0.32, 1.0, -0.45)
    y = fftfilt(y, 180, 3200)
    return y * bell * env(m, 0.04, d, 0.85, 0.08, d - 0.08) * 0.05 * g

VOWELS = {"a": ((700, 1.0), (1150, 0.5), (2600, 0.25)), "o": ((450, 1.0), (800, 0.45), (2830, 0.15)),
          "u": ((330, 1.0), (750, 0.3), (2400, 0.1))}
def choir(n, d, vowel="a", voices=6, g=1.0):
    """male choir: several glottal (saw) voices with vibrato and slight detune through vowel formants"""
    m = int(d * R); t = tt_(d); src = np.zeros(m)
    f = hz(n)
    for v in range(voices):
        vr = 5.0 + rng.uniform(-0.6, 0.6)
        fm_ = f * (1 + rng.uniform(-0.006, 0.006)) * (1 + 0.006 * np.sin(2 * np.pi * vr * t + rng.uniform(0, 6)) * np.clip(t * 1.5, 0, 1))
        ph = (np.cumsum(fm_) / R + rng.uniform()) % 1
        src += 2 * ph - 1
    src /= voices
    X = np.fft.rfft(src); fr = np.fft.rfftfreq(m, 1 / R); G = np.zeros_like(fr)
    for (fc, a) in VOWELS[vowel]:
        G += a * np.exp(-((fr - fc) / (fc * 0.12)) ** 2)
    y = np.fft.irfft(X * (G + 0.02), m)
    breath = fftfilt(noise(d), 1500, 5000) * 0.02
    return (y + breath) * env(m, 0.18, d, 0.9, 0.25, d - 0.25) * 1.6 * g

def brass(n, d, g=1.0):
    """low brass section (tuba / horns): saw with a lowpass that opens on the attack"""
    m = int(d * R); t = tt_(d)
    y = saw(hz(n), d, 0.003, 0.004) + 0.5 * saw(hz(n - 12), d, 0.002)
    y = fftfilt(y[:m], 60, 1400) * (0.6 + 0.4 * np.exp(-t * 6))
    return np.tanh(y * 1.4) * env(m, 0.03, d, 0.85, 0.08, d - 0.08) * 0.22 * g

def bass_drum():
    d = 0.7; m = int(d * R); f = 52 + 40 * np.exp(-tt_(d) * 18)
    return (np.sin(2 * np.pi * np.cumsum(f) / R) * env(m, 0.002, 0.45) + fftfilt(noise(d), 60, 600) * env(m, 0.001, 0.08) * 0.3) * 0.9
def march_snare(g=1.0):
    d = 0.25; m = int(d * R)
    return (fftfilt(noise(d), 900, 7000) * env(m, 0.001, 0.09) * 0.7 + sine(210, d) * env(m, 0.001, 0.05) * 0.4) * g
def timpani(n):
    d = 1.6; m = int(d * R); t = tt_(d)
    y = sum(np.sin(2 * np.pi * hz(n) * r * t) * a * np.exp(-t * (1.6 + i)) for i, (r, a) in enumerate(((1, 1.0), (1.5, 0.35), (1.99, 0.2))))
    return (y + fftfilt(noise(d), 80, 900) * env(m, 0.001, 0.05) * 0.4) * env(m, 0.003, d, 1.0) * 0.6
def cymbal():
    d = 2.2; m = int(d * R)
    return fftfilt(noise(d), 3500, 13000) * env(m, 0.002, 1.2) * 0.35

# chords (MIDI roots and voicings), D minor: i, iv, V7, VI, III, VII
CH = {"Dm": [50, 57, 62, 65], "Gm": [55, 58, 62, 67], "A7": [57, 61, 64, 67], "Bb": [58, 62, 65, 70],
      "F": [53, 57, 60, 65], "C": [48, 55, 60, 64], "A": [57, 61, 64, 69]}
PROG_A = ["Dm", "Gm", "A7", "Dm", "Dm", "C", "F", "A"]
PROG_B = ["Bb", "Gm", "Dm", "A7", "Dm", "Bb", "A7", "Dm"]
# original melodies: (MIDI note or 0 = rest, beats) per bar
MEL_A = [[(69, 1), (67, .5), (65, .5), (64, 1), (62, 1)], [(65, 1), (67, 1), (69, 2)],
         [(70, 1), (69, .5), (67, .5), (64, 1), (61, 1)], [(62, 3), (0, 1)],
         [(69, 1), (72, 1), (70, 1), (69, 1)], [(67, 1), (65, .5), (67, .5), (69, 2)],
         [(70, 1), (69, 1), (67, 1), (64, 1)], [(65, 1), (64, 1), (61, 2)]]
MEL_B = [[(74, 2), (72, 1), (70, 1)], [(69, 3), (65, 1)], [(67, 2), (70, 1), (69, 1)], [(64, 4)],
         [(65, 2), (67, 1), (69, 1)], [(70, 2), (69, 1), (67, 1)], [(65, 1), (64, 1), (61, 2)], [(62, 4)]]

def play_line(B, t0, bars, inst, pan=0.0, g=1.0, octave=0, beat=BEAT):
    t = t0
    for bar in bars:
        for (n, ln) in bar:
            if n:
                put(B, inst(n + octave, ln * beat), t, pan, g)
            t += ln * beat
    return t

def oompah(B, t0, chord, beat=BEAT, g=1.0):
    c = CH[chord]
    for k in range(4):
        if k % 2 == 0:
            put(B, brass(c[0] - 12, beat * 0.9, 0.9), t0 + k * beat, 0.0, g)
        else:
            put(B, bayan(c[1:], beat * 0.8), t0 + k * beat, -0.35, g)

def march_drums(B, t0, beat=BEAT, roll=False):
    for k in range(4):
        put(B, bass_drum(), t0 + k * beat, 0.0, 0.85 if k % 2 == 0 else 0.55)
        put(B, march_snare(0.55), t0 + (k + 0.5) * beat, 0.2)
        if k == 3 and roll:
            for r in range(6):
                put(B, march_snare(0.3 + r * 0.08), t0 + (k + r / 6) * beat, 0.2)

def t_ru():
    total = 4 + 8 + 8 + 8 + 8 + 8 + 8 + 2
    L = total * BAR + 3
    B = np.zeros((int(L * R), 2))
    t = 0.0
    # 1. intro: drone + choir hum (u) + slow balalaika tremolo
    for i, ch in enumerate(["Dm", "Dm", "Gm", "A7"]):
        put(B, choir(CH[ch][0], BAR, "u", 6, 0.8), t + i * BAR, -0.1)
        put(B, choir(CH[ch][2] - 12, BAR, "u", 5, 0.5), t + i * BAR, 0.15)
    play_line(B, t, [[(62, 2), (65, 2)], [(69, 3), (67, 1)], [(65, 2), (64, 1), (62, 1)], [(61, 4)]],
              lambda n, d: balalaika(hz(n), d, trem=11.0), 0.3, 0.9)
    put(B, timpani(38), t + 3 * BAR + 3 * BEAT, 0)
    t += 4 * BAR
    # 2. march A: drums, oom-pah, brass melody
    for i, ch in enumerate(PROG_A):
        oompah(B, t + i * BAR, ch)
        march_drums(B, t + i * BAR, roll=(i == 7))
    play_line(B, t, MEL_A, lambda n, d: brass(n, d * 0.95, 1.2), 0.1, 1.0, -12)
    t += 8 * BAR
    # march A again with balalaika doubling an octave up
    for i, ch in enumerate(PROG_A):
        oompah(B, t + i * BAR, ch)
        march_drums(B, t + i * BAR, roll=(i == 7))
    play_line(B, t, MEL_A, lambda n, d: brass(n, d * 0.95, 1.1), 0.1, 1.0, -12)
    play_line(B, t, MEL_A, lambda n, d: balalaika(hz(n), d + 0.2, trem=12.0 if d >= BEAT else 0.0), 0.4, 0.9)
    put(B, cymbal(), t, 0.3)
    t += 8 * BAR
    # 3. march B: the choir sings the theme; balalaikas strum the chords
    for i, ch in enumerate(PROG_B):
        oompah(B, t + i * BAR, ch, g=0.9)
        march_drums(B, t + i * BAR, roll=(i == 7))
        for k in range(8):
            put(B, balalaika(hz(CH[ch][1 + k % 3]), BEAT * 0.6), t + i * BAR + k * BEAT / 2, -0.45, 0.6)
    play_line(B, t, MEL_B, lambda n, d: choir(n - 12, d, "a" if d >= 2 * BEAT else "o", 7, 1.1), 0.0, 1.0)
    play_line(B, t, MEL_B, lambda n, d: choir(n - 24, d, "o", 5, 0.6), 0.0, 1.0)
    put(B, cymbal(), t, -0.3)
    t += 8 * BAR
    # 4. bridge: balalaika solo, accelerating (folk-dance style), light drums
    beat = BEAT
    bridge = [[(62, .5), (64, .5), (65, .5), (67, .5), (69, .5), (67, .5), (65, .5), (64, .5)],
              [(65, .5), (67, .5), (69, .5), (70, .5), (69, 1), (65, 1)],
              [(67, .5), (69, .5), (70, .5), (72, .5), (70, .5), (69, .5), (67, .5), (65, .5)],
              [(64, .5), (65, .5), (67, .5), (64, .5), (61, 2)]]
    tb = t
    for rep in range(2):
        for bar_i, bar in enumerate(bridge):
            sp = 1.0 - 0.06 * (rep * 4 + bar_i) / 7.0 * 4   # speeds up to ~1.3x
            b2 = BEAT * max(0.72, sp)
            ch = ["Dm", "Gm", "C", "A7"][bar_i]
            for k in range(4):
                put(B, bayan(CH[ch][1:], b2 * 0.45, 0.8), tb + k * b2, -0.3)
                put(B, bass_drum(), tb + k * b2, 0, 0.35 if k % 2 else 0.5)
            tb = play_line(B, tb, [bar], lambda n, d: balalaika(hz(n), d + 0.15), 0.35, 1.0, 0, b2)
    put(B, timpani(38), tb - 2 * BEAT, 0)
    put(B, timpani(45), tb - BEAT, 0)
    t = tb
    # 5. finale: theme A with choir, brass, timpani; then broad final chord
    for i, ch in enumerate(PROG_A):
        oompah(B, t + i * BAR, ch, g=1.1)
        march_drums(B, t + i * BAR, roll=(i == 7))
        if i % 2 == 0:
            put(B, timpani(CH[ch][0] - 12), t + i * BAR, 0)
    play_line(B, t, MEL_A, lambda n, d: brass(n, d * 0.95, 1.2), 0.1, 1.0, -12)
    play_line(B, t, MEL_A, lambda n, d: choir(n - 12, d, "a", 7, 1.0), -0.1, 1.0)
    put(B, cymbal(), t, 0.0)
    t += 8 * BAR
    for i, ch in enumerate(PROG_B):
        oompah(B, t + i * BAR, ch, g=1.1)
        march_drums(B, t + i * BAR, roll=(i == 7))
    play_line(B, t, MEL_B, lambda n, d: choir(n - 12, d, "a", 8, 1.15), 0.0, 1.0)
    play_line(B, t, MEL_B, lambda n, d: brass(n - 12, d * 0.95, 0.9), 0.15, 1.0)
    t += 8 * BAR
    for n in CH["Dm"]:
        put(B, choir(n, 2 * BAR, "a", 6, 0.8), t, 0)
        put(B, brass(n - 12, 2 * BAR, 0.6), t, 0.1)
    put(B, timpani(38), t, 0); put(B, cymbal(), t, 0); put(B, bass_drum(), t, 0)
    B = B[:int((t + 2 * BAR + 1.5) * R)]
    fade = int(1.5 * R); B[-fade:] *= np.linspace(1, 0, fade)[:, None]
    save("battle_ru_steppe_march.ogg", room(B, 1.8, 0.2))
    return B

if __name__ == "__main__":
    B = t_ru()
    if "--sample" in sys.argv:
        d = sys.argv[sys.argv.index("--sample") + 1]
        os.makedirs(d, exist_ok=True)
        a = int(28 * R); ex = master(B[a:a + int(30 * R)]) * 0.92
        pcm = (np.clip(ex, -1, 1) * 32767).astype("<i2").tobytes()
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(R), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "4",
                        os.path.join(d, "m33_music_ru_sample.ogg")], input=pcm, check=True)
