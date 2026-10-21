#!/usr/bin/env python3
"""FRACTURE LINE: synthesizes ALL original SFX, UI sounds, ambience and the two music
tracks from scratch (numpy DSP -> ffmpeg/libvorbis). No samples, no third-party audio.
Run: python3 tools/gen_audio.py   (needs numpy + ffmpeg)"""
import numpy as np, subprocess, os, sys
R = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(1337)

def t(d): return np.arange(int(d * R)) / R
def noise(d): return rng.uniform(-1, 1, int(d * R))
def env(n, a, d, curve=4.0):
    x = np.arange(n) / R
    e = np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-np.maximum(0, x - a) * curve / max(d, 1e-4))
    return e
def lp(x, fc, sr=R):
    # one-pole low-pass (fc may be array)
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
def pad(x, d): return np.concatenate([x, np.zeros(int(d * R))])
def mix(*parts):
    n = max(len(p) for p in parts); y = np.zeros(n)
    for p in parts: y[:len(p)] += p
    return y
def sweep(f0, f1, d, wave="sin"):
    f = np.linspace(f0, f1, int(d * R)); ph = 2 * np.pi * np.cumsum(f) / R
    return np.sin(ph) if wave == "sin" else 2 * ((ph / (2 * np.pi)) % 1) - 1

def save(rel, x, sr=R, ch=1, q=2):
    path = os.path.join(OUT, rel); os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(sr), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=pcm, check=True)
    print(rel, round(len(x) / sr / ch, 2), "s")

# ---------------------------------------------------------------- weapons
def gunshot(body_hz, crack, tail, lowcut=200):
    n = noise(tail + 0.05)
    c = hp(n, 1500) * env(len(n), 0.0005, 0.015, 3) * crack
    b = lp(n, body_hz) * env(len(n), 0.001, tail, 5) * 2.5
    thump = np.sin(2 * np.pi * 70 * t(tail + 0.05)) * env(len(n), 0.001, 0.06, 5) * 0.6
    return norm(sat(hp(c + b + thump, lowcut), 1.6))

save("sfx/rifle.ogg", gunshot(2200, 1.0, 0.18))
save("sfx/mg_burst.ogg", norm(mix(*[pad(np.zeros(int(i * 0.075 * R)), 0)[:0].tolist() and [] or np.concatenate([np.zeros(int(i * 0.075 * R)), gunshot(2500, 0.9, 0.12) * (0.9 - 0.08 * i)]) for i in range(5)])))
save("sfx/autocannon.ogg", norm(mix(*[np.concatenate([np.zeros(int(i * 0.16 * R)), gunshot(900, 0.8, 0.3, 80)]) for i in range(3)])))
def cannon():
    d = 1.4; n = noise(d)
    boom = lp(n, np.linspace(1800, 120, len(n))) * env(len(n), 0.002, 0.9, 4) * 3
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 35, len(n))) / R) * env(len(n), 0.002, 0.5, 4) * 1.2
    crack = hp(n, 2000) * env(len(n), 0.0005, 0.02, 3)
    return norm(sat(boom + sub + crack, 2.2))
save("sfx/tank_cannon.ogg", cannon())
def missile():
    d = 1.0; n = noise(d)
    hiss = bp(n, 1200, 5000) * env(len(n), 0.03, 0.8, 3)
    whoosh = lp(n, np.linspace(800, 3000, len(n))) * env(len(n), 0.01, 0.6, 3) * 1.5
    pop = lp(noise(0.12), 500) * env(int(0.12 * R), 0.001, 0.05, 4) * 2
    return norm(mix(hiss + whoosh, pop))
save("sfx/missile_launch.ogg", missile())
def grenade():
    thunk = np.sin(2 * np.pi * np.cumsum(np.linspace(260, 90, int(0.15 * R))) / R) * env(int(0.15 * R), 0.001, 0.08, 4)
    return norm(mix(thunk, hp(noise(0.05), 2500) * env(int(0.05 * R), 0.0005, 0.01, 3) * 0.4))
save("sfx/grenade_launch.ogg", grenade())
def flak():
    shots = [np.concatenate([np.zeros(int(i * 0.09 * R)), gunshot(1600, 0.7, 0.14, 150)]) for i in range(4)]
    return norm(mix(*shots))
save("sfx/flak.ogg", flak())

# ---------------------------------------------------------------- explosions
def explosion(d, cutoff, sub_hz, debris=True):
    n = noise(d)
    e = env(len(n), 0.004, d * 0.55, 4)
    body = lp(n, np.linspace(cutoff, 90, len(n))) * e * 3
    rumble = lp(noise(d), 120) * env(len(n), 0.02, d * 0.8, 3) * 4
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(sub_hz, 25, len(n))) / R) * env(len(n), 0.003, d * 0.35, 4) * 1.5
    y = body + rumble + sub
    if debris:
        for k in range(14):
            s = int(rng.uniform(0.15, d * 0.8) * R); m = int(0.03 * R)
            if s + m < len(y):
                y[s:s + m] += hp(noise(0.03), 2500) * env(m, 0.0005, 0.01, 3) * rng.uniform(0.1, 0.35)
    return norm(sat(y, 1.8))
save("sfx/explosion_small.ogg", explosion(0.9, 2500, 80, False))
save("sfx/explosion_large.ogg", explosion(2.2, 1800, 60))
def collapse():
    d = 3.2; y = explosion(d, 1200, 45) * 0.8
    crumble = lp(noise(d), 600) * env(int(d * R), 0.4, 2.2, 2) * 0.8
    for k in range(40):
        s = int(rng.uniform(0.3, 2.8) * R); m = int(0.05 * R)
        crumble[s:s + m] += bp(noise(0.05), 300, 3000) * env(m, 0.001, 0.02, 3) * rng.uniform(0.2, 0.6)
    return norm(y + crumble)
save("sfx/building_collapse.ogg", collapse())
def impact():
    return norm(hp(noise(0.12), 400) * env(int(0.12 * R), 0.0005, 0.04, 4) + lp(noise(0.12), 600) * env(int(0.12 * R), 0.001, 0.06, 4))
save("sfx/impact_dirt.ogg", impact())
def infantry_down():
    y = lp(noise(0.25), 400) * env(int(0.25 * R), 0.01, 0.1, 4)
    return norm(y) * 0.6
save("sfx/body_fall.ogg", infantry_down())

# ---------------------------------------------------------------- construction / base
def construct():
    d = 2.0; y = np.zeros(int(d * R))
    for k in range(9):          # hammer / rivet hits
        s = int((0.08 + k * 0.21 + rng.uniform(-0.03, 0.03)) * R); m = int(0.09 * R)
        hit = bp(noise(0.09), 900, 6000) * env(m, 0.0005, 0.025, 4) + np.sin(2 * np.pi * rng.uniform(1700, 2600) * t(0.09)) * env(m, 0.0005, 0.05, 4) * 0.4
        y[s:s + m] += hit * rng.uniform(0.5, 1.0)
    whirr = sweep(180, 420, d, "saw") * 0.07 * env(int(d * R), 0.3, 1.5, 1.5)
    return norm(y + lp(whirr, 1500))
save("sfx/construct.ogg", construct())
def place():
    return norm(lp(noise(0.3), 700) * env(int(0.3 * R), 0.005, 0.15, 4) + np.sin(2 * np.pi * 110 * t(0.3)) * env(int(0.3 * R), 0.003, 0.1, 4))
save("sfx/place_structure.ogg", place())
def power_down():
    return norm(sweep(420, 60, 1.2, "saw") * env(int(1.2 * R), 0.01, 1.0, 2) * 0.6 + lp(noise(1.2), 300) * 0.1)
save("sfx/power_down.ogg", lp(power_down(), 2500))
def engine_idle():
    d = 2.0; f = 34
    y = sum(np.sin(2 * np.pi * f * h * t(d) + rng.uniform(0, 6)) / h for h in range(1, 7))
    y = y * (0.7 + 0.3 * np.sin(2 * np.pi * 8 * t(d))) + lp(noise(d), 300) * 0.6
    return norm(lp(y, 900)) * 0.8
save("sfx/engine_loop.ogg", engine_idle())

# ---------------------------------------------------------------- UI
def blip(f, d, f2=None, vol=0.7):
    s = sweep(f, f2 or f, d) * env(int(d * R), 0.002, d * 0.6, 4)
    s += sweep(f * 2, (f2 or f) * 2, d) * env(int(d * R), 0.002, d * 0.3, 4) * 0.25
    return norm(s, vol)
save("ui/click.ogg", mix(blip(1400, 0.05, 1100), hp(noise(0.01), 3000) * 0.2))
save("ui/select.ogg", blip(900, 0.08, 1300, 0.6))
save("ui/error.ogg", norm(mix(sweep(240, 200, 0.22, "saw") * env(int(0.22 * R), 0.003, 0.15, 3), np.concatenate([np.zeros(int(0.1 * R)), sweep(200, 160, 0.18, "saw") * env(int(0.18 * R), 0.003, 0.12, 3)])), 0.5))
save("ui/confirm.ogg", norm(mix(blip(660, 0.09), np.concatenate([np.zeros(int(0.07 * R)), blip(990, 0.12)])), 0.65))
save("ui/alert.ogg", norm(mix(*[np.concatenate([np.zeros(int(i * 0.16 * R)), blip(880 if i % 2 == 0 else 660, 0.14)]) for i in range(3)]), 0.6))
save("ui/build_ready.ogg", norm(mix(blip(523, 0.12), np.concatenate([np.zeros(int(0.1 * R)), blip(784, 0.18)])), 0.6))

# ---------------------------------------------------------------- ambience (loops)
def wind(d):
    n = noise(d); m = 0.55 + 0.45 * np.sin(2 * np.pi * 0.11 * t(d)) * np.sin(2 * np.pi * 0.037 * t(d) + 1)
    y = lp(n, 350 + 250 * m) * m
    fade = int(0.5 * R); y[:fade] *= np.linspace(0, 1, fade); y[-fade:] *= np.linspace(1, 0, fade)
    return norm(y, 0.5)
w = wind(12.0)
save("ambient/desert_wind.ogg", w)
def river(d):
    n = noise(d); y = bp(n, 300, 2400) * (0.8 + 0.2 * lp(noise(d), 3))
    for k in range(120):
        s = int(rng.uniform(0, d - 0.1) * R); m = int(0.05 * R)
        y[s:s + m] += np.sin(2 * np.pi * np.cumsum(np.linspace(rng.uniform(500, 900), rng.uniform(1100, 1800), m)) / R) * env(m, 0.002, 0.02, 4) * 0.25
    fade = int(0.5 * R); y[:fade] *= np.linspace(0, 1, fade); y[-fade:] *= np.linspace(1, 0, fade)
    return norm(y, 0.45)
save("ambient/river.ogg", river(10.0))
print("sfx done")
