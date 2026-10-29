#!/usr/bin/env python3
"""FRACTURE LINE: GLOBAL CONFLICT logo + app icon (M2.7; retitled M3.2.2, was Rules of Engagement), recreated from Malachi's own concept
(builds/m2_7_rename/logo_concepts/concept4_tank_hex.jpg): a front-on Abrams-style tank in
worn bronze, inside a rounded-square bronze frame (app icon) or a bronze hexagon badge with
'FRACTURE / LINE / GLOBAL CONFLICT' and a small red diamond (menu logo, splash).

Writes:
  icon.svg                          project icon (also rasterised to the 192 px launcher icon)
  assets/icons/lc_adaptive_*.svg    Android adaptive layers (fg = tank in the safe zone, bg, mono)
  ui/logo/fl_badge.png             menu logo (transparent, 1024 px tall)
  ui/logo/fl_splash.png            boot splash (badge centred on a transparent wide canvas)
PNGs for the launcher icons are rasterised by tools/gen_icon_lc.gd (Godot's SVG renderer):
  python3 tools/gen_icon_lc.py && godot --headless --path . -s res://tools/gen_icon_lc.gd
Badge lettering: Barlow Semi Condensed Black (SIL OFL 1.1), baked into the PNG only.
"""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONT = "/usr/share/fonts/truetype/sand-box/google/Barlow Semi Condensed/BarlowSemiCondensed-Black.ttf"
L, HI, M, D, H = "#C9B38A", "#DDCBA3", "#8C7756", "#3B342B", "#141414"
TR = "#76664C"   # track blocks
BG_T, BG_B = "#232427", "#141517"
FR_A, FR_B = "#B39A6E", "#6A573D"

# Tank, front view, in 128-unit icon space. (kind, data, colour)
TANK = [
    ("poly", [(20, 60), (108, 60), (115, 66), (115, 77.5), (13, 77.5), (13, 66)], L),        # hull + fenders
    ("poly", [(20, 60), (108, 60), (110, 62.2), (18, 62.2)], HI),
    ("rect", (13, 74.5, 102, 3), M),
    ("rect", (40.3, 63.5, 2, 14), D), ("rect", (85.7, 63.5, 2, 14), D),                     # fender seams
    ("rect", (47, 68, 5.5, 2.8), D), ("rect", (75.5, 68, 5.5, 2.8), D),                     # vision slots
    ("rect", (42.3, 77.5, 43.4, 8.5), M),                                                   # lower hull
    ("rect", (42.3, 77.5, 43.4, 2.2), D),
    ("rect", (18, 79, 23.5, 21.5), TR), ("rect", (86.5, 79, 23.5, 21.5), TR),                # tracks
] + [("rect", (18, y, 23.5, 1.6), D) for y in (82, 85.6, 89.2, 92.8, 96.4)] \
  + [("rect", (86.5, y, 23.5, 1.6), D) for y in (82, 85.6, 89.2, 92.8, 96.4)] + [
    ("poly", [(31, 41.5), (97, 41.5), (105, 56.5), (23, 56.5)], L),                         # turret
    ("poly", [(31, 41.5), (97, 41.5), (98.8, 45), (29.2, 45)], HI),
    ("poly", [(23, 56.5), (105, 56.5), (104.2, 58.5), (23.8, 58.5)], M),
    ("poly", [(53.5, 41.5), (74.5, 41.5), (73, 56.5), (55, 56.5)], D),                      # mantlet recess
    ("rect", (37.5, 34.5, 6, 7), L), ("rect", (80, 37, 8, 4.5), L),                         # sights
    ("rect", (39, 29.5, 1.4, 5), L),                                                        # antenna
    ("rect", (58, 46, 12, 9), M),                                                           # gun collar
    ("rect", (59.5, 35, 9, 13), L), ("rect", (64.6, 35, 3.9, 13), M),                       # barrel
    ("circ", (64, 33.5, 5.6), L), ("circ", (64, 33.5, 2.4), H),                             # muzzle
]
TANK_BOX = (13, 27.9, 115, 100.5)

def tank_svg(mono=False):
    out = []
    for kind, d, c in TANK:
        if mono:
            c = "#000000" if c in (D, H) else "#FFFFFF"
        if kind == "poly":
            out.append('<polygon points="%s" fill="%s"/>' % (" ".join("%g,%g" % p for p in d), c))
        elif kind == "rect":
            out.append('<rect x="%g" y="%g" width="%g" height="%g" fill="%s"/>' % (*d, c))
        else:
            out.append('<circle cx="%g" cy="%g" r="%g" fill="%s"/>' % (*d, c))
    return "".join(out)

def bg_svg(rounded=True):
    rx = ' rx="24"' if rounded else ""
    return ('<defs><linearGradient id="bg" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="%s"/>'
            '<stop offset="1" stop-color="%s"/></linearGradient><linearGradient id="fr" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="#8E7852"/><stop offset="1" stop-color="%s"/>'
            '</linearGradient></defs><rect width="128" height="128"%s fill="url(#bg)"/>' % (BG_T, BG_B, FR_A, FR_B, rx))

def svg(body):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">%s</svg>\n' % body

def scaled(body, k, cy=64.0):
    return '<g transform="translate(%.2f %.2f) scale(%g)">%s</g>' % (64 - 64 * k, 64 - cy * k, k, body)

def write_svgs():
    frame = ('<rect x="5" y="5" width="118" height="118" rx="20" fill="none" stroke="url(#fr)" stroke-width="4.2"/>'
             '<rect x="8" y="8" width="112" height="112" rx="17.5" fill="none" stroke="#000" stroke-opacity="0.45" stroke-width="1.2"/>')
    open(f"{ROOT}/icon.svg", "w").write(svg(bg_svg() + frame + scaled(tank_svg(), 1.0, 64)))
    open(f"{ROOT}/assets/icons/lc_adaptive_bg.svg", "w").write(svg(bg_svg(rounded=False)))
    open(f"{ROOT}/assets/icons/lc_adaptive_fg.svg", "w").write(svg(scaled(tank_svg(), 0.6, 64)))
    open(f"{ROOT}/assets/icons/lc_adaptive_mono.svg", "w").write(svg(scaled(tank_svg(mono=True), 0.6, 64)))

# ---------------- badge (raster, supersampled) ----------------
def hexpts(W, H, inset=0.0):
    pts = [(0.5, 0.022), (0.982, 0.252), (0.982, 0.748), (0.5, 0.978), (0.018, 0.748), (0.018, 0.252)]
    cx, cy = W / 2, H / 2
    out = []
    for x, y in pts:
        px, py = x * W, y * H
        out.append((px + (cx - px) * inset, py + (cy - py) * inset))
    return out

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def noise(W, H, scale, seed):
    rnd = random.Random(seed)
    w, h = max(2, W // scale), max(2, H // scale)
    n = Image.new("L", (w, h))
    n.putdata([rnd.randint(0, 255) for _ in range(w * h)])
    return n.resize((W, H), Image.BICUBIC)

def bronze_fill(W, H, seed, base=(201, 179, 138), dark=(120, 98, 66)):
    """Worn bronze: vertical light->dark gradient with blotchy + fine grain."""
    g = Image.linear_gradient("L").resize((W, H)).rotate(0)
    a = Image.new("RGB", (W, H), base); b = Image.new("RGB", (W, H), dark)
    grad = Image.composite(b, a, g.point(lambda v: int(v * 0.55)))
    blotch = noise(W, H, 40, seed).filter(ImageFilter.GaussianBlur(W / 120))
    grain = noise(W, H, 2, seed + 1)
    m = ImageChops.add(blotch.point(lambda v: int(v * 0.5)), grain.point(lambda v: int(v * 0.5)))
    shade = Image.composite(b, grad, m.point(lambda v: 255 if v > 205 else (110 if v > 175 else 0)).filter(ImageFilter.GaussianBlur(1)))
    return shade

def draw_tank(d, ox, oy, sx, sy, cols):
    for kind, dd, c in TANK:
        col = cols.get(c, c)
        if kind == "poly":
            d.polygon([(ox + x * sx, oy + y * sy) for x, y in dd], fill=col)
        elif kind == "rect":
            x, y, w, h = dd
            d.rectangle([ox + x * sx, oy + y * sy, ox + (x + w) * sx, oy + (y + h) * sy], fill=col)
        else:
            x, y, r = dd
            rr = r * (sx + sy) / 2
            d.ellipse([ox + x * sx - rr, oy + y * sy - rr, ox + x * sx + rr, oy + y * sy + rr], fill=col)

def badge(Hout=1024):
    S = 2
    H = Hout * S; W = int(H * 0.925)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # outer bronze rim
    rim_mask = Image.new("L", (W, H), 0); ImageDraw.Draw(rim_mask).polygon(hexpts(W, H), fill=255)
    rim = bronze_fill(W, H, 7, base=(178, 150, 106), dark=(92, 72, 48))
    img.paste(rim, (0, 0), rim_mask)
    # dark inner line + interior
    ImageDraw.Draw(img).polygon(hexpts(W, H, 0.068), fill=(24, 21, 18, 255))
    inner = Image.new("L", (W, H), 0); ImageDraw.Draw(inner).polygon(hexpts(W, H, 0.08), fill=255)
    fill = Image.new("RGB", (W, H), (36, 33, 29))
    glow = Image.radial_gradient("L").resize((W, H)).point(lambda v: 255 - v)
    fill = Image.composite(Image.new("RGB", (W, H), (52, 47, 40)), fill, glow.point(lambda v: int(v * 0.6)))
    grime = noise(W, H, 6, 3).filter(ImageFilter.GaussianBlur(2))
    fill = Image.composite(Image.new("RGB", (W, H), (22, 20, 17)), fill, grime.point(lambda v: 150 if v > 190 else 0).filter(ImageFilter.GaussianBlur(3)))
    img.paste(fill, (0, 0), inner)
    # artwork layer (tank, text, diamond) drawn as a mask, then filled with worn bronze
    art = Image.new("L", (W, H), 0); ad = ImageDraw.Draw(art)
    shade = Image.new("L", (W, H), 0); sd = ImageDraw.Draw(shade)
    bx0, by0, bx1, by1 = TANK_BOX
    tw = 0.50 * W; sx = tw / (bx1 - bx0); sy = sx * 0.76
    ox = (W - tw) / 2 - bx0 * sx; oy = 0.095 * H - by0 * sy
    draw_tank(ad, ox, oy, sx, sy, {L: 255, HI: 255, M: 255, TR: 255, D: 0, H: 0})
    draw_tank(sd, ox, oy, sx, sy, {L: 0, HI: 0, M: 120, TR: 150, D: 0, H: 0})
    def text(s, cy, width_frac, max_h):
        size = 400
        f = ImageFont.truetype(FONT, size)
        x0, y0, x1, y1 = ad.textbbox((0, 0), s, font=f)
        k = min(width_frac * W / (x1 - x0), max_h * H / (y1 - y0))
        f = ImageFont.truetype(FONT, int(size * k))
        x0, y0, x1, y1 = ad.textbbox((0, 0), s, font=f)
        ad.text(((W - (x1 - x0)) / 2 - x0, cy * H - (y1 + y0) / 2), s, font=f, fill=255)
    text("FRACTURE", 0.50, 0.80, 0.15)
    text("LINE", 0.622, 0.34, 0.08)
    text("GLOBAL CONFLICT", 0.725, 0.76, 0.07)
    # drop shadow under the artwork
    sh = art.filter(ImageFilter.GaussianBlur(S * 5))
    img = Image.alpha_composite(img, Image.merge("RGBA", (*[Image.new("L", (W, H), 0)] * 3, sh.point(lambda v: int(v * 0.8)))).transform((W, H), Image.AFFINE, (1, 0, -S * 3, 0, 1, -S * 5)))
    metal = bronze_fill(W, H, 11)
    metal = Image.composite(Image.new("RGB", (W, H), (140, 118, 84)), metal, shade)
    # wear: small chips knocked out of the letters/tank
    chips = noise(W, H, 3, 21).point(lambda v: 0 if v > 238 else 255)
    img.paste(metal, (0, 0), ImageChops.multiply(art, chips))
    # rust dashes either side of LINE, red diamond
    dd = ImageDraw.Draw(img)
    for x0 in (0.13, 0.728):
        for i in range(4):
            xs = (x0 + i * 0.04) * W
            dd.rectangle([xs, 0.613 * H, xs + 0.022 * W, 0.619 * H], fill=(122, 52, 34, 150))
    cx, cy, hw, hh = 0.5 * W, 0.835 * H, 0.085 * W, 0.024 * H
    dd.polygon([(cx - hw, cy), (cx, cy - hh), (cx + hw, cy), (cx, cy + hh)], fill=(120, 46, 30, 255))
    dd.polygon([(cx - hw, cy), (cx, cy - hh), (cx + hw, cy)], fill=(142, 56, 36, 255))
    # rim bevel: light top-left edge, dark bottom-right
    bev = Image.new("RGBA", (W, H), (0, 0, 0, 0)); bd = ImageDraw.Draw(bev)
    p = hexpts(W, H, 0.004)
    for a, b, c in [(5, 0, (235, 214, 170, 140)), (0, 1, (235, 214, 170, 90)), (1, 2, (40, 30, 20, 120)), (2, 3, (40, 30, 20, 150)), (3, 4, (40, 30, 20, 120)), (4, 5, (235, 214, 170, 70))]:
        bd.line([p[a], p[b]], fill=c, width=S * 4)
    img = Image.alpha_composite(img, bev)
    img.putalpha(ImageChops.multiply(img.getchannel("A"), rim_mask))
    return img.resize((W // S, Hout), Image.LANCZOS)

if __name__ == "__main__":
    import sys
    os.makedirs(f"{ROOT}/assets/icons", exist_ok=True)
    os.makedirs(f"{ROOT}/ui/logo", exist_ok=True)
    if "--logo-only" not in sys.argv:   # M3.2.2 retitle: the icon (tank, no lettering) is unchanged
        write_svgs()
    b = badge()
    b.save(f"{ROOT}/ui/logo/fl_badge.png", optimize=True)
    sp = Image.new("RGBA", (2340, 1080), (0, 0, 0, 0))
    bs = b.resize((int(b.width * 560 / b.height), 560), Image.LANCZOS)
    sp.alpha_composite(bs, ((2340 - bs.width) // 2, (1080 - bs.height) // 2))
    sp.save(f"{ROOT}/ui/logo/fl_splash.png", optimize=True)
    print("wrote icon.svg, assets/icons/lc_adaptive_{bg,fg,mono}.svg, ui/logo/fl_badge.png, ui/logo/fl_splash.png")
