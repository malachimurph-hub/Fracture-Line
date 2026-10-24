#!/usr/bin/env python3
"""M3.1 texture overhaul: 2048 px tileable weathering + detail normal map for the model shader.
weather.png  R grime (smooth fbm), G panel seams (irregular plates, thin anti-aliased seams, hatches),
             B scratches / chips, A rust mask.   detail_n.png  tangent normal (seams, rivets, hatches,
             plate steps, fine grain).  rust.png 1024 (upscaled + fine noise).  All periodic (no seams)."""
import numpy as np, os, random, math
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "materials")
W = 2048
rng = np.random.default_rng(3101)
R = random.Random(3101)

def fbm(beta=2.2, lo=2.0, seed=0):
    g = np.random.default_rng(seed).standard_normal((W, W))
    f = np.fft.fftfreq(W) * W
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    amp = 1.0 / np.power(np.maximum(k, lo), beta / 2.0 * 2.0 / 2.0 + 0.0) ** 1.0
    amp = 1.0 / np.power(np.maximum(k, lo), beta)
    amp[0, 0] = 0
    n = np.real(np.fft.ifft2(np.fft.fft2(g) * amp))
    n -= n.min(); n /= n.max()
    return n

def blur(a, s):
    f = np.fft.fftfreq(W)
    fx, fy = np.meshgrid(f, f)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * (math.pi * s) ** 2 * (fx * fx + fy * fy))))

# ---- plates: recursive splits on the torus (edges at 0 == W wrap), min 70 px, max ~420 px
rects = []
def split(x0, y0, x1, y1, d):
    w, h = x1 - x0, y1 - y0
    if d > 7 or (max(w, h) < 420 and R.random() < 0.1 + d * 0.08) or max(w, h) < 120:
        rects.append((x0, y0, x1, y1)); return
    if w > h * R.uniform(0.8, 1.25):
        c = int(x0 + w * R.uniform(0.3, 0.7)); split(x0, y0, c, y1, d + 1); split(c, y0, x1, y1, d + 1)
    else:
        c = int(y0 + h * R.uniform(0.3, 0.7)); split(x0, y0, x1, c, d + 1); split(x0, c, x1, y1, d + 1)
# offset the root split so plate edges are not aligned to the texture border
split(0, 0, W, W, 0)
dist = np.full((W, W), 1e9, np.float32)
step_h = np.zeros((W, W), np.float32)
tone = np.zeros((W, W), np.float32)
yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
hatch = np.zeros((W, W), np.float32)
for (x0, y0, x1, y1) in rects:
    sl = (slice(y0, y1), slice(x0, x1))
    lx, ly = xx[sl], yy[sl]
    d = np.minimum.reduce([lx - x0 + 0.5, x1 - 0.5 - lx, ly - y0 + 0.5, y1 - 0.5 - ly])
    dist[sl] = np.minimum(dist[sl], d)
    step_h[sl] = R.uniform(-0.35, 0.35)
    tone[sl] = R.uniform(-1, 1)
    w, h = x1 - x0, y1 - y0
    if min(w, h) > 150 and R.random() < 0.35:   # access hatch: rounded inset panel with a groove
        iw, ih = w * R.uniform(0.3, 0.55), h * R.uniform(0.3, 0.55)
        cx, cy = x0 + w * R.uniform(0.3, 0.7), y0 + h * R.uniform(0.3, 0.7)
        rr = min(iw, ih) * 0.2
        qx = np.maximum(np.abs(lx - cx) - (iw / 2 - rr), 0); qy = np.maximum(np.abs(ly - cy) - (ih / 2 - rr), 0)
        sd = np.sqrt(qx * qx + qy * qy) - rr
        hatch[sl] = np.maximum(hatch[sl], np.clip(1.0 - np.abs(sd) / 3.5, 0, 1))
seam = np.clip(1.0 - (dist - 2.5) / 2.5, 0, 1)            # ~6 px anti-aliased groove
bevel = np.clip(1.0 - dist / 14.0, 0, 1) ** 2             # plates roll off into the seam
# ---- rivets along ~half the plate edges
riv = np.zeros((W, W), np.float32)
ker = np.zeros((13, 13), np.float32)
for j in range(13):
    for i in range(13):
        r = math.hypot(i - 6, j - 6) / 4.2
        ker[j, i] = max(0.0, 1 - r * r)
def stamp(x, y):
    xs = (np.arange(13) + int(x) - 6) % W; ys = (np.arange(13) + int(y) - 6) % W
    riv[np.ix_(ys, xs)] = np.maximum(riv[np.ix_(ys, xs)], ker)
for (x0, y0, x1, y1) in rects:
    sp = R.choice([30, 36, 44])
    for side in range(4):
        if R.random() < 0.5: continue
        if side < 2:
            y = y0 + 13 if side == 0 else y1 - 14
            for x in range(x0 + 18, x1 - 14, sp): stamp(x, y)
        else:
            x = x0 + 13 if side == 2 else x1 - 14
            for y in range(y0 + 18, y1 - 14, sp): stamp(x, y)
grain = fbm(1.0, 8, 11)
cloud = fbm(1.6, 3, 12)
H = (-seam * 1.0 - bevel * 0.35 + step_h * 0.12 * (1 - bevel) - hatch * 0.6 + riv * 0.55 + (grain - 0.5) * 0.06 + (cloud - 0.5) * 0.12)
# ---- normal map (periodic central differences)
Hs = blur(H, 0.6)
dx = (np.roll(Hs, -1, 1) - np.roll(Hs, 1, 1)) * 0.5
dy = (np.roll(Hs, -1, 0) - np.roll(Hs, 1, 0)) * 0.5
S = 3.2
n = np.dstack([-dx * S, -dy * S, np.ones_like(dx)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255 + 0.5).clip(0, 255).astype(np.uint8), "RGB").save(f"{OUT}/detail_n.png", optimize=True)
# ---- weather channels
grime = fbm(2.0, 2.5, 21)
grime = np.clip((grime - grime.mean()) * 2.2 + 0.55, 0, 1)
G = 1.0 - seam * 0.62 - hatch * 0.35 - riv * 0.18 + tone * 0.018 - bevel * 0.05
G = np.clip(blur(G, 0.5), 0, 1)
im = Image.new("L", (W, W), 0); dr = ImageDraw.Draw(im)
for _ in range(2600):
    x, y = R.uniform(0, W), R.uniform(0, W); a = R.uniform(0, math.tau); L = R.uniform(10, 90)
    for ox in (-W, 0, W):
        for oy in (-W, 0, W):
            dr.line([x + ox, y + oy, x + ox + math.cos(a) * L, y + oy + math.sin(a) * L], fill=int(R.uniform(110, 255)), width=R.choice([1, 1, 2]))
sc = np.asarray(im, np.float32) / 255.0
chips = fbm(1.2, 6, 31)
chips = np.clip((chips - 0.72) * 6.0, 0, 1)   # no plate imprint: B is also read at a coarse scale
B = np.clip(blur(np.maximum(sc * 0.85, chips), 0.6), 0, 1)
rust = fbm(1.8, 3, 41)
drip = blur(np.clip((fbm(1.0, 10, 42) - 0.6) * 4, 0, 1), 1.0)
A = np.clip((rust - 0.55) * 3.0, 0, 1) * np.clip(grime + 0.3, 0, 1)
A = np.clip(blur(A, 1.2) + drip * 0.15, 0, 1)
to8 = lambda a: (a * 255 + 0.5).clip(0, 255).astype(np.uint8)
Image.merge("RGBA", [Image.fromarray(to8(c)) for c in (grime, G, B, A)]).save(f"{OUT}/weather.png", optimize=True)
# ---- rust colour: upscale + fine grain
ru = Image.open(f"{OUT}/rust.png").convert("RGB")
if ru.size[0] < 1024:
    ru = ru.resize((1024, 1024), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    g2 = (fbm(1.0, 16, 51)[::2, ::2] - 0.5) * 0.18
    a = np.asarray(ru, np.float32) / 255.0 * (1 + g2[..., None])
    Image.fromarray(to8(np.clip(a, 0, 1)), "RGB").save(f"{OUT}/rust.png", optimize=True)
print("textures m31:", len(rects), "plates")
