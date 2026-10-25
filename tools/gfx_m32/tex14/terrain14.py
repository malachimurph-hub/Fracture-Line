#!/usr/bin/env python3
"""M3.2 item 14 (c): hand-painted terrain pass (tool-time only, run once from the originals).

Per biome albedo array (7 layers of 1024 px, tileable): a Kuwahara paint filter removes the
photographic grain but keeps pebbles, cracks and tufts as flat painted shapes; soft tileable
brush-scale tone / hue patches and a little extra saturation give the Zero Hour painted look.
NRAO arrays (normal RG, rough B, AO A) are smoothed and halved to 512 px layers: the shading
detail stays, the grain and shimmer go, and the four biomes ship ~29 MB smaller.
The ground decal atlas gets painted scorch marks in place of the third oil stain.
Run: python3 terrain14.py <repo_root>   (reads the committed originals via git show)
"""
import io, math, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

root = sys.argv[1]
T = root + "/assets/textures/terrain/"
BIOMES = ["", "_arid", "_temperate", "_winter"]
REV = "399ac03"   # originals (before M3.2 item 14)


def orig(path):
    return Image.open(io.BytesIO(subprocess.check_output(["git", "-C", root, "show", "%s:%s" % (REV, path)])))


def periodic_noise(n, scale, seed):
    g = np.random.default_rng(seed).standard_normal((n, n))
    f = np.fft.fftfreq(n) * n
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy); k[0, 0] = 1
    amp = np.exp(-(k / scale) ** 2); amp[0, 0] = 0
    r = np.real(np.fft.ifft2(np.fft.fft2(g) * amp))
    return (r - r.mean()) / (r.std() + 1e-9)


def kuwahara(img, r):
    lum = img @ np.array([0.3, 0.59, 0.11])
    best_var = None
    out = np.zeros_like(img)
    k = r + 1
    for (dy, dx) in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        sh = (dy * r // 2 if False else dy * (r // 2 + 0), dx * (r // 2))
        m = ndimage.uniform_filter(lum, k, mode="wrap")
        m2 = ndimage.uniform_filter(lum * lum, k, mode="wrap")
        var = np.roll(m2 - m * m, (dy * (k // 2), dx * (k // 2)), (0, 1))
        mc = np.stack([np.roll(ndimage.uniform_filter(img[..., c], k, mode="wrap"), (dy * (k // 2), dx * (k // 2)), (0, 1)) for c in range(3)], -1)
        if best_var is None:
            best_var = var; out = mc
        else:
            sel = var < best_var
            best_var = np.where(sel, var, best_var)
            out = np.where(sel[..., None], mc, out)
    return out


def paint_layer(a, seed, layer):
    a = a.astype(np.float32) / 255.0
    lin = a
    p = kuwahara(lin, 3)
    p = ndimage.gaussian_filter(p, (0.7, 0.7, 0), mode="wrap")
    # keep some of the original micro structure (35 %) so it does not read as plastic
    p = p * 0.65 + ndimage.gaussian_filter(lin, (0.8, 0.8, 0), mode="wrap") * 0.35
    n = a.shape[0]
    tone = periodic_noise(n, 9, seed)            # brush-scale tone patches
    hue = periodic_noise(n, 5, seed + 1)
    p *= (1 + 0.035 * tone)[..., None]
    warm = np.array([1.04, 1.0, 0.94]); cool = np.array([0.96, 0.99, 1.04])
    t = np.clip(0.5 + 0.2 * hue, 0, 1)[..., None]
    p *= cool * (1 - t) + warm * t
    lum = (p @ np.array([0.3, 0.59, 0.11]))[..., None]
    p = lum + (p - lum) * (1.08 if layer != 3 else 1.0)    # asphalt stays neutral
    return (np.clip(p, 0, 1) * 255 + 0.5).astype(np.uint8)


def smooth_nrao(a):
    a = a.astype(np.float32)
    s = ndimage.gaussian_filter(a, (1.0, 1.0, 0), mode="wrap")
    im = Image.fromarray(np.clip(s, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((a.shape[1] // 2, a.shape[0] // 2), Image.LANCZOS)


for b in BIOMES:
    alb = np.asarray(orig("assets/textures/terrain/terrain_albedo%s.png" % b).convert("RGB"))
    L = alb.shape[1]
    layers = [paint_layer(alb[i * L:(i + 1) * L], 1400 + i * 7 + len(b), i) for i in range(alb.shape[0] // L)]
    Image.fromarray(np.concatenate(layers, 0)).save(T + "terrain_albedo%s.png" % b, optimize=True)
    nr = np.asarray(orig("assets/textures/terrain/terrain_nrao%s.png" % b).convert("RGBA"))
    out = [smooth_nrao(nr[i * L:(i + 1) * L]) for i in range(nr.shape[0] // L)]
    Image.fromarray(np.concatenate([np.asarray(o) for o in out], 0), "RGBA").save(T + "terrain_nrao%s.png" % b, optimize=True)
    print("terrain", b or "_default", alb.shape, "->", len(layers), "painted layers; nrao", out[0].size)

# scorch decal in atlas slot 10 (row 2, col 2 of the 4 x 4 grid)
dec = orig("assets/textures/decals/ground_decals.png").convert("RGBA")
D = dec.size[0] // 4
rng = np.random.default_rng(1410)
yy, xx = np.mgrid[0:D, 0:D].astype(np.float32)
c = D / 2
r = np.hypot(xx - c, yy - c) / (D * 0.46)
ang = np.arctan2(yy - c, xx - c)
spikes = 1 + 0.25 * np.sin(ang * 7 + 1.3) + 0.15 * np.sin(ang * 13 + 0.4)
n = ndimage.gaussian_filter(rng.random((D, D)), 3)
n = (n - n.min()) / (n.max() - n.min())
core = np.clip(1.15 - r * spikes * (0.8 + 0.4 * n), 0, 1) ** 1.4
streaks = np.clip(1 - r, 0, 1) * np.clip(np.sin(ang * 23 + n * 6) * 0.5 + 0.5, 0, 1) * 0.5
alpha = np.clip(core + streaks * (r < 1), 0, 1)
col = np.stack([0.09 + 0.05 * n, 0.08 + 0.04 * n, 0.07 + 0.03 * n], -1)
ash = np.clip(1 - np.abs(r - 0.55) * 6, 0, 1) * 0.25 * n
col += ash[..., None] * np.array([0.6, 0.55, 0.5])
tile = Image.fromarray((np.dstack([col, alpha]) * 255).clip(0, 255).astype(np.uint8), "RGBA")
dec.paste(tile, (2 * D, 2 * D))
dec.save(root + "/assets/textures/decals/ground_decals.png", optimize=True)
print("decals: scorch in slot 10")
