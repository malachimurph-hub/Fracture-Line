#!/usr/bin/env python3
"""FRACTURE LINE M2: synthesizes the original TPLA weapon / mechanic SFX (numpy DSP ->
Ogg), reusing the DSP helpers of tools/gen_audio.py. No samples, no third-party audio.
Run: python3 tools/gen_audio_tpla.py"""
import os, re
import numpy as np
src = open(os.path.join(os.path.dirname(__file__), "gen_audio.py")).read()
# helpers only (everything before the first save() call), plus gunshot/explosion defs
helpers = src[:src.index('save("sfx/rifle.ogg"')]
exec(helpers)
exec(src[src.index("def explosion("):src.index('save("sfx/explosion_small.ogg"')])
rng = np.random.default_rng(2002)

# older, harsher carbine: more mid crack, short tail
save("sfx/tpla_carbine.ogg", gunshot(1700, 1.3, 0.14, 260))
# heavy MG on a truck bed: slower, chunkier, metallic rattle
def hmg():
    shots = []
    for i in range(5):
        s = gunshot(1200, 1.0, 0.16, 120) * (0.95 - 0.06 * i)
        rattle = bp(noise(0.05), 2500, 7000) * env(int(0.05 * R), 0.0005, 0.02, 3) * 0.25
        shots.append(np.concatenate([np.zeros(int(i * 0.105 * R)), mix(s, rattle)]))
    return norm(mix(*shots))
save("sfx/tpla_hmg.ogg", hmg())
# quad gun: four barrels, very fast
def quad():
    return norm(mix(*[np.concatenate([np.zeros(int(i * 0.045 * R)), gunshot(1900, 0.8, 0.09, 180) * (0.9 - 0.04 * i)]) for i in range(8)]))
save("sfx/tpla_quad.ogg", quad())
# RPG: pop + short hiss, wobbly
def rpg():
    d = 0.8; n = noise(d)
    pop = lp(noise(0.1), 700) * env(int(0.1 * R), 0.001, 0.04, 4) * 2.5
    hiss = bp(n, 900, 4500) * env(len(n), 0.01, 0.5, 3) * (0.8 + 0.2 * np.sin(2 * np.pi * 13 * t(d)))
    return norm(sat(mix(pop, hiss), 1.5))
save("sfx/tpla_rpg.ogg", rpg())
# buggy salvo: three staggered launches
def salvo():
    return norm(mix(*[np.concatenate([np.zeros(int(i * 0.12 * R)), rpg() * (1.0 - 0.15 * i)]) for i in range(3)]))
save("sfx/tpla_salvo.ogg", salvo())
# scrap tank cannon: boom with a clanky metallic ring
def scrap_cannon():
    d = 1.3; n = noise(d)
    boom = lp(n, np.linspace(1500, 110, len(n))) * env(len(n), 0.002, 0.8, 4) * 3
    sub = np.sin(2 * np.pi * np.cumsum(np.linspace(80, 32, len(n))) / R) * env(len(n), 0.002, 0.45, 4) * 1.2
    clank = sum(np.sin(2 * np.pi * f * t(d)) for f in (612, 947, 1433)) * env(len(n), 0.001, 0.35, 5) * 0.18
    return norm(sat(boom + sub + clank, 2.0))
save("sfx/tpla_scrap_cannon.ogg", scrap_cannon())
# rust canister launcher: hollow thump + gas hiss
def rust_launch():
    d = 1.2
    thump = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 60, int(0.25 * R))) / R) * env(int(0.25 * R), 0.001, 0.12, 4)
    hiss = bp(noise(d), 2000, 8000) * env(int(d * R), 0.15, 0.8, 2) * 0.35
    return norm(mix(thump, hiss))
save("sfx/tpla_rust_launch.ogg", rust_launch())
# rust zone: bubbling, sizzling corrosion loop-ish
def rust_sizzle():
    d = 2.0; y = bp(noise(d), 3000, 9000) * 0.25
    for k in range(60):
        s = int(rng.uniform(0, d - 0.05) * R); m = int(0.04 * R)
        y[s:s + m] += np.sin(2 * np.pi * rng.uniform(300, 900) * t(0.04)) * env(m, 0.002, 0.02, 4) * rng.uniform(0.2, 0.5)
    return norm(y) * 0.7
save("sfx/tpla_rust_sizzle.ogg", rust_sizzle())
# bomb truck / demo charge: huge blast
def huge():
    y = explosion(3.0, 2200, 50) * 1.0
    crack = hp(noise(0.05), 1500) * env(int(0.05 * R), 0.0005, 0.02, 3)
    return norm(sat(mix(y, crack * 0.8), 1.6))
save("sfx/explosion_huge.ogg", huge())
# salvage pickup: ratchet clicks + clank
def salvage():
    d = 0.6; y = np.zeros(int(d * R))
    for k in range(5):
        s = int((0.02 + k * 0.06) * R); m = int(0.03 * R)
        y[s:s + m] += bp(noise(0.03), 2000, 7000) * env(m, 0.0005, 0.01, 4) * 0.6
    s = int(0.34 * R); m = int(0.25 * R)
    y[s:s + m] += sum(np.sin(2 * np.pi * f * t(0.25)) for f in (523, 811, 1290)) * env(m, 0.001, 0.15, 5) * 0.3
    return norm(y) * 0.8
save("sfx/salvage.ogg", salvage())
# tunnel enter / exit: earthy whoosh
def tunnel():
    d = 0.7; n = noise(d)
    return norm(lp(n, np.linspace(300, 1400, len(n))) * env(len(n), 0.15, 0.4, 3)) * 0.7
save("sfx/tunnel.ogg", tunnel())
# trap click before the blast
def trap_click():
    return norm(mix(bp(noise(0.03), 3000, 8000) * env(int(0.03 * R), 0.0005, 0.008, 4), np.concatenate([np.zeros(int(0.08 * R)), bp(noise(0.03), 2500, 7000) * env(int(0.03 * R), 0.0005, 0.008, 4)]))) * 0.7
save("sfx/trap_click.ogg", trap_click())
