#!/usr/bin/env python3
"""M4.3 (items 10, 11): movement loops and heavier weapon sounds, synthesised from scratch with
numpy (noise + sine partials + envelopes + a simple multi-tap reverb). Original, no samples.
  /workspace/tools/bakevenv/bin/python tools/m43/gen_sfx_m43.py
Writes audio/sfx/*.ogg (ffmpeg libvorbis)."""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "sfx")
rng = np.random.default_rng(43)

def t(d): return np.arange(int(SR * d)) / SR
def lp(x, f, o=4): return sosfilt(butter(o, f, "low", fs=SR, output="sos"), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, "high", fs=SR, output="sos"), x)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], "band", fs=SR, output="sos"), x)
def noise(d): return rng.standard_normal(int(SR * d))
def brown(d):
    x = np.cumsum(noise(d)); x = hp(x, 15); return x / (np.abs(x).max() + 1e-9)
def norm(x, peak=0.89): return x / (np.abs(x).max() + 1e-9) * peak
def reverb(x, taps=((0.045, .5), (0.11, .38), (0.19, .3), (0.31, .22), (0.47, .15), (0.7, .1)), tail=1.0):
    y = np.concatenate([x, np.zeros(int(SR * (tail + max(d for d, _ in taps))))])
    for dt, g in taps:
        k = int(SR * dt); y[k:k + len(x)] += g * lp(x, 2500)
    n = len(y); f = int(SR * 0.3); y[-f:] *= np.linspace(1, 0, f)
    return y
def loop(x, xf=0.25):
    """seamless loop: crossfade the extra tail onto the head"""
    n = int(SR * xf); body, tl = x[:-n].copy(), x[-n:]
    w = np.linspace(0, 1, n); body[:n] = body[:n] * w + tl * (1 - w)
    return body
def write(name, x):
    with tempfile.TemporaryDirectory() as td:
        from scipy.io import wavfile
        w = os.path.join(td, "a.wav"); wavfile.write(w, SR, (norm(x) * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-ac", "1", "-c:a", "libvorbis", "-q:a", "4",
                        os.path.join(OUT, name + ".ogg")], check=True)
    print("SFX", name)

D = 3.25   # loops: 3.0 s + 0.25 s crossfade
# --- movement loops -------------------------------------------------------------------------------
tt = t(D)
# tank: deep diesel rumble, sub-bass, track clatter (11 links/s)
clank = bp(noise(D), 900, 3200) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 11 * tt))) ** 4
tank = 0.9 * lp(brown(D), 110) + 0.55 * np.sin(2 * np.pi * 31 * tt) * (0.8 + 0.2 * np.sin(2 * np.pi * 7.75 * tt)) \
    + 0.3 * np.sin(2 * np.pi * 62 * tt) + 0.22 * clank
write("move_tank_loop", loop(lp(tank, 1800)))
# IFV: lighter diesel, higher firing note, lighter tracks
clank2 = bp(noise(D), 1400, 4200) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * tt))) ** 4
ifv = 0.55 * lp(brown(D), 220) + 0.4 * np.sin(2 * np.pi * 52 * tt) + 0.28 * np.sin(2 * np.pi * 104 * tt) * (0.85 + 0.15 * np.sin(2 * np.pi * 13 * tt)) \
    + 0.12 * clank2
write("move_ifv_loop", loop(lp(ifv, 2600)))
# light 4x4 / pickup: V8 burble (uneven firing: crank order + half order)
f0 = 38.0
v8 = sum(a * np.sin(2 * np.pi * f0 * k * tt + p) for k, a, p in [(0.5, .35, 0), (1, .5, .3), (1.5, .2, 1), (2, .55, .2), (3, .18, .7), (4, .3, .1), (6, .1, .5)])
v8 *= 0.8 + 0.2 * np.sin(2 * np.pi * f0 / 2 * tt)
v8 += 0.25 * lp(noise(D), 400) + 0.08 * bp(noise(D), 2000, 5000)
write("move_light_loop", loop(lp(v8, 3000)))
# helicopter: blade slap (4 blades ~ 4.75 Hz x2), turbine whine, rotor wash
ph = (tt * 9.5) % 1.0
slap = np.exp(-ph * 14) * lp(noise(D), 900)
heli = 0.9 * slap + 0.25 * lp(brown(D), 300) + 0.06 * np.sin(2 * np.pi * 2650 * tt) + 0.12 * bp(noise(D), 1500, 6000)
write("move_heli_loop", loop(heli))
# jet in flight: broadband roar + turbine whine
jet = 0.7 * bp(noise(D), 250, 3500) + 0.45 * lp(brown(D), 200) + 0.07 * np.sin(2 * np.pi * 3800 * tt) + 0.05 * np.sin(2 * np.pi * 5100 * tt)
write("move_jet_loop", loop(jet))
# jet take-off: whine spools up, afterburner roar swells and passes
d = 4.0; tj = t(d)
spool = np.sin(2 * np.pi * np.cumsum(1500 + 2600 * np.clip(tj / 1.6, 0, 1)) / SR) * 0.08
roar = bp(noise(d), 120, 4200) * np.clip((tj - 0.6) / 1.2, 0, 1) ** 1.5 * np.exp(-np.clip(tj - 2.6, 0, None) * 1.6)
crackle = hp(noise(d), 2500) * (rng.random(len(tj)) > 0.985) * 3.0 * np.clip((tj - 1.0) / 1.0, 0, 1) * np.exp(-np.clip(tj - 2.4, 0, None) * 2)
write("jet_takeoff", reverb(spool + roar + 0.25 * crackle + 0.4 * lp(brown(d), 120) * np.clip((tj - 0.8), 0, 1) * np.exp(-np.clip(tj - 2.6, 0, None) * 1.6), tail=0.6))
# --- heavy weapons ---------------------------------------------------------------------------------
def boom(d, f, dec, nlp, ndec):
    x = t(d); return 0.9 * np.sin(2 * np.pi * f * x * (1 - 0.25 * x)) * np.exp(-x * dec) + 0.8 * lp(noise(d), nlp) * np.exp(-x * ndec)
# heavy rocket: ignition thump, crackling motor, long loud whoosh away
d = 2.4; tr = t(d)
whoosh = bp(noise(d), 350, 5000) * (np.clip(tr / 0.05, 0, 1) * np.exp(-tr * 1.1))
sweep = np.sin(2 * np.pi * np.cumsum(900 - 500 * np.clip(tr / d, 0, 1)) / SR) * 0.08 * np.exp(-tr * 1.5)
crack = hp(noise(d), 3000) * (rng.random(len(tr)) > 0.97) * 2.0 * np.exp(-tr * 2.5)
write("rocket_heavy", reverb(boom(d, 52, 9, 300, 14) + 1.1 * whoosh + sweep + 0.3 * crack, tail=0.8))
# heavy missile (ATGM / SAM launch): sharp pop, fast hiss
d = 1.6; tm = t(d)
write("missile_heavy", reverb(0.7 * boom(d, 70, 14, 600, 22) + 0.9 * bp(noise(d), 900, 7000) * np.clip(tm / 0.03, 0, 1) * np.exp(-tm * 2.2), tail=0.5))
# heavy artillery: deep boom, long reverberant roll
d = 2.0
write("artillery_heavy", reverb(boom(d, 38, 3.2, 180, 3.8) + 0.25 * bp(noise(d), 600, 3000) * np.exp(-t(d) * 18), taps=((0.06, .6), (0.15, .5), (0.27, .42), (0.42, .34), (0.63, .26), (0.9, .2), (1.25, .14), (1.7, .09)), tail=2.2))
# heavy tank gun: big crack + body, shorter tail than artillery
d = 1.4
write("cannon_heavy", reverb(boom(d, 48, 6, 900, 7) + 0.35 * hp(noise(d), 1800) * np.exp(-t(d) * 40), tail=0.9))
