#!/usr/bin/env python3
"""M3.0: procedural foliage atlas (original, self-generated) for alpha-cut tree leaf cards.
2 x 2 quadrants (512 px each): 0 broadleaf cluster, 1 conifer spray, 2 palm frond, 3 scrub.
RGB is near-neutral light value (the prop's vertex colour gives the hue); A = cut-out mask.
Out: assets/textures/props/leaf_atlas.png"""
import math, random, os
from PIL import Image, ImageDraw, ImageFilter
S = 512
random.seed(30)
img = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))

def leaf(d, x, y, ang, l, w, v):
    pts = []
    for i in range(13):
        t = i / 12.0
        r = math.sin(t * math.pi) * w
        pts.append((t * l, r))
    pts += [(t * l, -math.sin(t * math.pi) * w) for t in [i / 12.0 for i in range(12, -1, -1)]]
    ca, sa = math.cos(ang), math.sin(ang)
    P = [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]
    c = int(255 * v)
    d.polygon(P, fill=(c, min(255, int(c * 1.04)), int(c * 0.86), 255))
    d.line([(x, y), (x + l * 0.9 * ca, y + l * 0.9 * sa)], fill=(int(c * 0.7), int(c * 0.72), int(c * 0.55), 255), width=1)

def quad(ox, oy):
    q = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return q, ImageDraw.Draw(q)

# 0 broadleaf: twig skeleton + ~260 leaves in a lumpy blob, darker inside
q, d = quad(0, 0)
cx, cy = S / 2, S / 2
for k in range(7):
    a = k / 7.0 * math.tau + random.uniform(-0.3, 0.3)
    d.line([(cx, cy + 60), (cx + math.cos(a) * 180, cy + math.sin(a) * 160)], fill=(90, 72, 55, 255), width=6)
for i in range(300):
    a = random.uniform(0, math.tau)
    r = (random.random() ** 0.6) * 205 * (0.85 + 0.15 * math.sin(a * 3))
    x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.9
    v = 0.62 + 0.38 * (r / 205) * random.uniform(0.7, 1.0)
    leaf(d, x, y, random.uniform(0, math.tau), random.uniform(26, 40), random.uniform(8, 13), v)
img.paste(q, (0, 0))
# 1 conifer tier: needle-covered branchlets fanning down from the trunk point (skirt silhouette)
q, d = quad(1, 0)
for k in range(26):
    t0 = k / 25.0
    ex = 30 + t0 * (S - 60)
    ey = S - 70 - 60 * math.sin(t0 * math.pi)
    for i in range(40):
        t = i / 40.0
        x = S / 2 + (ex - S / 2) * t
        y = 30 + (ey - 30) * t + math.sin(t * math.pi) * 25
        for n in range(4):
            a = math.atan2(ey - 30, ex - S / 2) + random.choice([-1, 1]) * random.uniform(0.5, 1.2)
            l = random.uniform(18, 34)
            c = int(255 * random.uniform(0.55, 1.0))
            d.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)], fill=(int(c * 0.9), c, int(c * 0.86), 255), width=3)
    d.line([(S / 2, 30), (ex, ey)], fill=(85, 70, 52, 255), width=3)
img.paste(q, (S, 0))
# 2 palm frond: rachis along x with long leaflets both sides, drooping
q, d = quad(0, 1)
for i in range(46):
    t = i / 46.0
    x = 20 + t * (S - 40)
    y = S / 2 + (t ** 2) * 40
    for s in [-1, 1]:
        l = 150 * math.sin(min(1.0, t * 1.2 + 0.1) * math.pi) + 20
        a = s * (math.pi / 2 - 0.5) + 0.25
        leaf(d, x, y, a, l, 7, random.uniform(0.7, 1.0))
d.line([(20, S / 2), (S - 20, S / 2 + 40)], fill=(150, 130, 90, 255), width=6)
img.paste(q, (0, S))
# 3 scrub: small, dense, ragged leaves on wiry twigs
q, d = quad(1, 1)
for k in range(10):
    a = random.uniform(0, math.tau)
    d.line([(S / 2, S - 40), (S / 2 + math.cos(a) * 200, S / 2 + math.sin(a) * 180)], fill=(95, 80, 60, 255), width=3)
for i in range(520):
    a = random.uniform(0, math.tau)
    r = (random.random() ** 0.7) * 210
    x, y = S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r * 0.85
    leaf(d, x, y, random.uniform(0, math.tau), random.uniform(12, 20), random.uniform(4, 7), random.uniform(0.55, 1.0))
img.paste(q, (S, S))
# bleed RGB into transparent texels so mipmaps don't fringe dark
rgb = img.convert("RGB").filter(ImageFilter.MaxFilter(5))
out = Image.merge("RGBA", (*Image.composite(img.convert("RGB"), rgb, img.split()[3]).split(), img.split()[3]))
os.makedirs("assets/textures/props", exist_ok=True)
out.save("assets/textures/props/leaf_atlas.png")
print("wrote assets/textures/props/leaf_atlas.png")
