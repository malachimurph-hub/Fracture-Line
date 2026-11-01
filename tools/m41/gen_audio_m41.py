#!/usr/bin/env python3
"""M4.1 sound design (Malachi: heavy MGs vs smaller ones, ear-ringing miniguns, reverb on
explosions). Everything synthesized here from numpy noise/oscillators - no samples, no
third-party audio. Writes audio/sfx/hmg_heavy.ogg, minigun.ogg and re-renders the explosion
takes with a synthetic outdoor reverb tail (decaying filtered-noise impulse response, our own).
Run: python3 tools/m41/gen_audio_m41.py   (numpy + ffmpeg). Keeps the dry originals in
audio/sfx/superseded/ (not exported) so the pass is repeatable."""
import numpy as np, subprocess, os, shutil
R = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SFX = os.path.join(ROOT, "audio", "sfx")
DRY = os.path.join(SFX, "superseded")
rng = np.random.default_rng(4141)

def lp(x, fc):
    a = np.exp(-2 * np.pi * fc / R); y = np.empty_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s; y[i] = s
    return y
def hp(x, fc): return x - lp(x, fc)
def env(n, a, d):
    t = np.arange(n) / R
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) / d)
def save(name, x, q=1):
    x = np.clip(x / (np.max(np.abs(x)) or 1) * 0.92, -1, 1)
    pcm = (x * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(R), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(SFX, name)], input=pcm, check=True)
    print(name, round(len(x) / R, 2), "s", os.path.getsize(os.path.join(SFX, name)), "bytes")
def load(path):
    out = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(R), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, "<i2").astype(float) / 32768

def shot(n_len, body_hz, crack, boom, tail):
    n = int(n_len * R); t = np.arange(n) / R
    nz = rng.uniform(-1, 1, n)
    c = hp(nz, 2500) * env(n, 0.0003, 0.006) * crack
    b = lp(nz, 900) * env(n, 0.001, tail) * 1.4
    th = np.sin(2 * np.pi * body_hz * t * (1 - 0.35 * t / n_len)) * env(n, 0.001, tail * 0.8) * boom
    return c + b + th

# heavy .50 cal: slow ~550 rpm, deep chest thump + long low tail, 4-round burst
def hmg_heavy():
    gap = 0.109; out = np.zeros(int((gap * 3 + 0.6) * R))
    for k in range(4):
        s = shot(0.5, 62 + rng.uniform(-4, 4), 0.9, 1.6, 0.11)
        i = int(k * gap * R); out[i:i + len(s)] += s * (1 - 0.05 * k)
    out = lp(out, 3800) * 0.8 + out * 0.2
    return np.tanh(out * 1.8)

# minigun: ~3,000 rpm (50 rounds/s) - the shots fuse into a buzz; motor whine + ringing tone
def minigun():
    d = 0.42; n = int(d * R); t = np.arange(n) / R
    out = np.zeros(n + int(0.2 * R))
    rate = 50.0; k = 0
    while k / rate < d:
        s = shot(0.06, 180, 1.0, 0.5, 0.012)
        i = int(k / rate * R); out[i:i + len(s)] += s * 0.7; k += 1
    tt = np.arange(len(out)) / R
    whine = np.sin(2 * np.pi * 1450 * tt + 0.3 * np.sin(2 * np.pi * 50 * tt)) * 0.05
    ring = np.sin(2 * np.pi * 3950 * tt) * np.exp(-np.maximum(0, tt - d) / 0.1) * np.minimum(1, tt / 0.05) * 0.03
    buzz = np.sign(np.sin(2 * np.pi * rate * tt)) * 0.06 * (tt < d)
    out += whine * (tt < d + 0.05) + ring + lp(buzz, 1800)
    return np.tanh(out * 1.6)

# outdoor reverb: two-stage IR (early slap off buildings, then a long dark tail)
def reverb(x, secs=1.6, wet=0.42):
    n = int(secs * R); t = np.arange(n) / R
    ir = rng.normal(0, 1, n) * np.exp(-t / (secs / 5.5))
    ir = lp(ir, 1400) * 1.0
    for dt, g in [(0.045, 0.5), (0.11, 0.35), (0.19, 0.22)]:
        ir[int(dt * R)] += g * 6
    ir[:int(0.012 * R)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(x) + n
    F = np.fft.rfft(np.pad(x, (0, n)), L) * np.fft.rfft(ir, L)
    wetsig = np.fft.irfft(F, L)[:L]
    wetsig *= np.max(np.abs(x)) / (np.max(np.abs(wetsig)) or 1)
    y = np.pad(x, (0, n)) + wetsig * wet
    k = np.nonzero(np.abs(y) > 0.004)[0]
    return y[:k[-1] + 1] if len(k) else y

save("hmg_heavy.ogg", hmg_heavy())
save("minigun.ogg", minigun())
os.makedirs(DRY, exist_ok=True)
open(os.path.join(DRY, ".gdignore"), "w").close()
for nm, secs in [("explosion_small.ogg", 1.2), ("explosion_small_b.ogg", 1.2), ("explosion_small_c.ogg", 1.2),
                 ("explosion_large.ogg", 1.8), ("explosion_huge.ogg", 2.4), ("howitzer.ogg", 1.4)]:
    dry = os.path.join(DRY, nm)
    if not os.path.exists(dry):   # M4.1: dry takes deleted with the other superseded assets;
        subprocess.run("git show 6fdb5f4:audio/sfx/%s > '%s'" % (nm, dry), shell=True, check=True, cwd=ROOT)   # restore from git
    save(nm, reverb(load(dry), secs))
