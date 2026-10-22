#!/usr/bin/env python3
"""FRACTURE LINE M2.4: extra synthesized weapon SFX (original, numpy DSP -> ffmpeg/libvorbis):
flame thrower burst, howitzer boom, metal ricochet / hit variants and explosion variants used
by WeaponFx for variation. Run: python3 tools/gen_audio_m24.py"""
import numpy as np, subprocess, os
R = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(2404)

def t(d): return np.arange(int(d * R)) / R
def noise(d): return rng.uniform(-1, 1, int(d * R))
def env(n, a, d, curve=4.0):
    x = np.arange(n) / R
    return np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-np.maximum(0, x - a) * curve / max(d, 1e-4))
def lp(x, fc, sr=R):
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * fc / sr)
    y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a[i]) * x[i] + a[i] * s; y[i] = s
    return y
def hp(x, fc): return x - lp(x, fc)
def bp(x, lo, hi): return hp(lp(x, hi), lo)
def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak
def sat(x, k=2.0): return np.tanh(x * k) / np.tanh(k)
def save(rel, x, sr=R, q=2):
    path = os.path.join(OUT, rel); os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(sr), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=pcm, check=True)
    print(rel, round(len(x) / sr, 2), "s")

def flame():
    d = 0.6; n = noise(d)
    roar = lp(n, 900) * env(len(n), 0.04, 0.5, 2.5) * 2.5
    hiss = bp(n, 1500, 6000) * env(len(n), 0.02, 0.4, 3) * 0.6
    flutter = 1.0 + 0.35 * np.sin(2 * np.pi * 23 * t(d))
    ign = lp(noise(0.08), 400) * env(int(0.08 * R), 0.001, 0.04, 4) * 1.5
    y = (roar + hiss) * flutter
    y[:len(ign)] += ign
    return norm(sat(y, 1.5))
save("sfx/flame.ogg", flame())

def howitzer():
    d = 2.0; n = noise(d)
    boom = lp(n, np.linspace(1400, 70, len(n))) * env(len(n), 0.003, 1.3, 3.5) * 3.5
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(70, 25, len(n))) / R) * env(len(n), 0.002, 0.8, 3.5) * 1.6
    crack = hp(n, 1800) * env(len(n), 0.0005, 0.03, 3) * 1.2
    echo = np.concatenate([np.zeros(int(0.35 * R)), lp(noise(d - 0.35), 300) * env(int((d - 0.35) * R), 0.05, 0.9, 3) * 0.5])
    echo = np.pad(echo, (0, max(0, len(n) - len(echo))))[:len(n)]
    return norm(sat(boom + sub + crack + echo, 2.0))
save("sfx/howitzer.ogg", howitzer())

def ricochet(f0, f1, d):
    ping = np.sin(2 * np.pi * np.cumsum(np.linspace(f0, f1, int(d * R))) / R) * env(int(d * R), 0.001, d * 0.6, 3) * 0.6
    hit = hp(noise(d), 2500) * env(int(d * R), 0.0005, 0.012, 3)
    clank = bp(noise(d), 600, 2400) * env(int(d * R), 0.0005, 0.04, 4) * 0.8
    return norm(ping + hit + clank, 0.8)
save("sfx/hit_metal_1.ogg", ricochet(3200, 2100, 0.28))
save("sfx/hit_metal_2.ogg", ricochet(4100, 2600, 0.22))
save("sfx/hit_metal_3.ogg", ricochet(2600, 1900, 0.32))

def explosion(d, cutoff, sub_hz, debris):
    n = noise(d)
    body = lp(n, np.linspace(cutoff, 90, len(n))) * env(len(n), 0.004, d * 0.55, 4) * 3
    rumble = lp(noise(d), 120) * env(len(n), 0.02, d * 0.8, 3) * 4
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(sub_hz, 25, len(n))) / R) * env(len(n), 0.003, d * 0.35, 4) * 1.5
    y = body + rumble + sub
    for k in range(debris):
        s = int(rng.uniform(0.1, d * 0.8) * R); m = int(0.03 * R)
        if s + m < len(y):
            y[s:s + m] += hp(noise(0.03), 2500) * env(m, 0.0005, 0.01, 3) * rng.uniform(0.1, 0.3)
    return norm(sat(y, 1.8))
save("sfx/explosion_small_b.ogg", explosion(0.8, 3000, 95, 4))
save("sfx/explosion_small_c.ogg", explosion(1.0, 2100, 70, 8))
