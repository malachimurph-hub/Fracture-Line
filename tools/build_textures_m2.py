#!/usr/bin/env python3
"""M2 texture pass (build-time tool, not shipped).

Inputs: ambientCG 1K-JPG sets (CC0, https://ambientcg.com) unpacked in /tmp/acg.
Outputs (res://assets/textures/):
  terrain/terrain_albedo.png   7 slices of 1024x1024, stacked vertically (Texture2DArray)
  terrain/terrain_nrao.png     same layout: R,G = NormalGL x,y; B = roughness; A = AO
  terrain/terrain_detail.png   512x512: R = micro detail luma, G,B = detail normal x,y
  terrain/terrain_macro.png    512x512: R = brightness variation, G = warm/cool, B = dryness
  decals/ground_decals.png     1024x1024 RGBA atlas, 4x4 cells (procedural, original)
  materials/weather.png        512x512: R = grime, G = panel lines, B = edge wear/scratches, A = rust mask
  materials/rust.png           512x512 rust colour (ambientCG Rust004 / Metal grime, CC0)
  materials/stencils.png       512x512 RGBA stencil sheet (procedural, original)
"""
import glob, math, os, random
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ACG = "/tmp/acg"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
S = 1024
# layer order must match terrain.gdshader
LAYERS = [("sand", "Ground097"), ("dirt", "Ground109"), ("grass", "Grass004"), ("asphalt", "Asphalt033"),
          ("rock", "Rock063"), ("riverbed", "Gravel035"), ("concrete", "Concrete034")]

def src(name, kind):
    f = glob.glob(f"{ACG}/{name}/*_{kind}.jpg")
    return Image.open(f[0]) if f else None

def square(im, mode):
    im = im.convert(mode)
    if im.size == (S, S):
        return im
    if im.size == (S, S // 2):  # 2:1 seamless sets: stack two copies (still tiles both ways)
        sq = Image.new(mode, (S, S))
        sq.paste(im, (0, 0)); sq.paste(im, (0, S // 2))
        return sq
    return im.resize((S, S), Image.LANCZOS)

def desert_rock(im):
    # Rock063 is mossy; desaturate and warm it so it reads as sun-baked desert rock
    g = ImageOps.grayscale(im).convert("RGB")
    warm = Image.merge("RGB", [p.point(lambda v, k=k: min(255, int(v * k))) for p, k in zip(g.split(), (1.12, 1.0, 0.84))])
    return Image.blend(im, warm, 0.78)

def build_terrain():
    alb = Image.new("RGB", (S, S * len(LAYERS)))
    nra = Image.new("RGBA", (S, S * len(LAYERS)))
    for i, (key, name) in enumerate(LAYERS):
        c = square(src(name, "Color"), "RGB")
        if key == "rock":
            c = desert_rock(c)
        alb.paste(c, (0, i * S))
        n = square(src(name, "NormalGL"), "RGB")
        r = square(src(name, "Roughness"), "L")
        ao = src(name, "AmbientOcclusion")
        ao = square(ao, "L") if ao else Image.new("L", (S, S), 255)
        nr, ng, _ = n.split()
        nra.paste(Image.merge("RGBA", (nr, ng, r, ao)), (0, i * S))
        print("layer", i, key, name)
    os.makedirs(f"{OUT}/terrain", exist_ok=True)
    alb.save(f"{OUT}/terrain/terrain_albedo.png", optimize=True)
    nra.save(f"{OUT}/terrain/terrain_nrao.png", optimize=True)
    # detail: high-pass of gravel luma + its normal, at 512 (tiled ~4x denser than the base)
    gl = ImageOps.grayscale(square(src("Gravel035", "Color"), "RGB")).resize((512, 512), Image.LANCZOS)
    hp = ImageChops.add(ImageChops.subtract(gl, gl.filter(ImageFilter.GaussianBlur(6)), 1, 128), Image.new("L", gl.size, 0))
    gn = square(src("Gravel035", "NormalGL"), "RGB").resize((512, 512), Image.LANCZOS)
    _, gx, gy = Image.merge("RGB", (hp, *gn.split()[:2])).split()[0], *gn.split()[:2]
    Image.merge("RGB", (hp, gx, gy)).save(f"{OUT}/terrain/terrain_detail.png", optimize=True)
    # macro: very low frequency variation baked from the dirt displacement (tiled across ~64 m)
    d = ImageOps.grayscale(square(src("Ground109", "Displacement"), "L").convert("RGB")).resize((512, 512), Image.LANCZOS)
    m1 = ImageOps.autocontrast(d.filter(ImageFilter.GaussianBlur(28)))
    m2 = ImageOps.autocontrast(d.transpose(Image.ROTATE_90).filter(ImageFilter.GaussianBlur(40)))
    m3 = ImageOps.autocontrast(d.transpose(Image.FLIP_LEFT_RIGHT).filter(ImageFilter.GaussianBlur(18)))
    Image.merge("RGB", (m1, m2, m3)).save(f"{OUT}/terrain/terrain_macro.png", optimize=True)

# ---------------------------------------------------------------- M2.5 map environments
# Same 7 layers (same splat meaning) with environment materials; asphalt and concrete slices are
# copied from the desert set (already built). ambientCG sets, all CC0.
ENV_LAYERS = {
    "winter": [("snow", "Snow006"), ("frozen_dirt", "Ground054"), ("snowy_grass", "Snow004"), None,
               ("snowy_rock", "Rock035"), ("ice", "Ice002"), None],
    "temperate": [("meadow", "Grass001"), ("mud", "Ground037"), ("grass", "Grass004"), None,
                  ("rock", "Rock023"), ("riverbed", "Gravel035"), ("paving", "PavingStones130")],
    # M2.5 Ochre Wells: pale dune sand, cracked dry flats, sandy scrub, ochre mesa rock, wadi gravel
    "arid": [("dune_sand", "Ground090"), ("dry_flat", "Ground102"), ("sandy_scrub", "Ground054"), None,
             ("mesa_rock", "Rock061"), ("wadi_gravel", "Ground079S"), None],
}

def build_terrain_env(env):
    base_a = Image.open(f"{OUT}/terrain/terrain_albedo.png").convert("RGB")
    base_n = Image.open(f"{OUT}/terrain/terrain_nrao.png").convert("RGBA")
    alb = Image.new("RGB", (S, S * 7))
    nra = Image.new("RGBA", (S, S * 7))
    for i, layer in enumerate(ENV_LAYERS[env]):
        if layer is None:
            alb.paste(base_a.crop((0, i * S, S, (i + 1) * S)), (0, i * S))
            nra.paste(base_n.crop((0, i * S, S, (i + 1) * S)), (0, i * S))
            continue
        key, name = layer
        c = square(src(name, "Color"), "RGB")
        if key == "frozen_dirt":
            # cold, frost-dusted packed earth (not beach sand): desaturate, cool, blend in frost
            g = ImageOps.grayscale(c).convert("RGB")
            cool = Image.merge("RGB", [p.point(lambda v, k=k: min(255, int(v * k))) for p, k in zip(g.split(), (0.86, 0.92, 1.0))])
            c = Image.blend(Image.blend(c, cool, 0.7), square(src("Snow010A", "Color"), "RGB"), 0.28)
        alb.paste(c, (0, i * S))
        n = square(src(name, "NormalGL"), "RGB")
        r = square(src(name, "Roughness"), "L")
        ao = src(name, "AmbientOcclusion")
        ao = square(ao, "L") if ao else Image.new("L", (S, S), 255)
        nr, ng, _ = n.split()
        nra.paste(Image.merge("RGBA", (nr, ng, r, ao)), (0, i * S))
        print(env, "layer", i, key, name)
    alb.save(f"{OUT}/terrain/terrain_albedo_{env}.png", optimize=True)
    nra.save(f"{OUT}/terrain/terrain_nrao_{env}.png", optimize=True)

# ---------------------------------------------------------------- decals (original, procedural)
def cell_img():
    return Image.new("RGBA", (256, 256), (0, 0, 0, 0))

def tire_tracks(rng, curve):
    im = cell_img(); d = ImageDraw.Draw(im)
    for lane in (-46, 46):
        for y in range(0, 256, 3):
            x = 128 + lane + int(curve * math.sin(y / 256 * math.pi) * 30)
            fade = int(150 * (0.55 + 0.45 * math.sin(y / 256 * math.pi)) * rng.uniform(0.75, 1.0))
            d.rectangle([x - 15, y, x + 15, y + 2], fill=(38, 32, 26, fade))
            if (y // 3) % 3 == 0:  # tread chevrons
                d.line([x - 13, y, x, y + 4, x + 13, y], fill=(22, 18, 15, min(255, fade + 40)), width=2)
    return im.filter(ImageFilter.GaussianBlur(0.8))

def cracks(rng):
    im = cell_img(); d = ImageDraw.Draw(im)
    def branch(x, y, a, length, w):
        for _ in range(int(length)):
            nx, ny = x + math.cos(a) * 4, y + math.sin(a) * 4
            d.line([x, y, nx, ny], fill=(18, 16, 14, 220), width=max(1, int(w)))
            x, y = nx, ny
            a += rng.uniform(-0.45, 0.45)
            w *= 0.985
            if rng.random() < 0.06 and w > 1.2:
                branch(x, y, a + rng.choice((-1, 1)) * rng.uniform(0.6, 1.2), length * 0.45, w * 0.7)
            if not (8 < x < 248 and 8 < y < 248):
                return
    for _ in range(3):
        branch(128 + rng.uniform(-20, 20), 128 + rng.uniform(-20, 20), rng.uniform(0, math.tau), 34, 3.2)
    return im.filter(ImageFilter.GaussianBlur(0.6))

def oil(rng):
    im = cell_img(); d = ImageDraw.Draw(im)
    for _ in range(26):
        r = rng.uniform(12, 46)
        x, y = 128 + rng.gauss(0, 30), 128 + rng.gauss(0, 30)
        d.ellipse([x - r, y - r * rng.uniform(0.6, 1.0), x + r, y + r * rng.uniform(0.6, 1.0)], fill=(12, 11, 10, int(rng.uniform(60, 120))))
    im = im.filter(ImageFilter.GaussianBlur(5))
    d = ImageDraw.Draw(im)
    for _ in range(5):  # faint sheen rings
        r = rng.uniform(10, 28); x, y = 128 + rng.gauss(0, 18), 128 + rng.gauss(0, 18)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(60, 52, 70, 50), width=2)
    return im.filter(ImageFilter.GaussianBlur(1.5))

def rubble(rng):
    im = cell_img(); d = ImageDraw.Draw(im)
    for _ in range(60):
        x, y = 128 + rng.gauss(0, 42), 128 + rng.gauss(0, 42)
        s = rng.uniform(3, 14)
        pts = [(x + math.cos(a) * s * rng.uniform(0.6, 1.0), y + math.sin(a) * s * rng.uniform(0.6, 1.0)) for a in [i * math.tau / 6 for i in range(6)]]
        sh = [(px + 3, py + 3) for px, py in pts]
        d.polygon(sh, fill=(10, 9, 8, 120))
        g = int(rng.uniform(95, 160))
        d.polygon(pts, fill=(g, int(g * 0.93), int(g * 0.84), 255))
        d.line(pts[:3], fill=(min(255, g + 40), min(255, g + 35), min(255, g + 28), 255), width=1)
    return im

def sand_drift(rng):
    im = cell_img(); d = ImageDraw.Draw(im)
    for i in range(14):
        y = 30 + i * 14 + rng.uniform(-4, 4)
        pts = [(x, y + math.sin(x / 30 + i) * 6) for x in range(10, 250, 6)]
        d.line(pts, fill=(222, 196, 150, 70), width=4)
    return im.filter(ImageFilter.GaussianBlur(3))

def build_decals():
    rng = random.Random(4242)
    cells = [tire_tracks(rng, 0), tire_tracks(rng, 1), tire_tracks(rng, -1), tire_tracks(rng, 0.4),
             cracks(rng), cracks(rng), cracks(rng), cracks(rng),
             oil(rng), oil(rng), oil(rng), sand_drift(rng),
             rubble(rng), rubble(rng), rubble(rng), rubble(rng)]
    atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        atlas.paste(c, ((i % 4) * 256, (i // 4) * 256))
    os.makedirs(f"{OUT}/decals", exist_ok=True)
    atlas.save(f"{OUT}/decals/ground_decals.png", optimize=True)

# ---------------------------------------------------------------- model weathering
def build_weather():
    rng = random.Random(77)
    W = 512
    # R: grime (soft cloudy noise from the dirt displacement)
    d = ImageOps.grayscale(square(src("Ground109", "Displacement"), "L").convert("RGB")).resize((W, W), Image.LANCZOS)
    grime = ImageOps.autocontrast(d.filter(ImageFilter.GaussianBlur(3)))
    # G: panel lines (tileable plate grid with rivets), 255 = no line
    pl = Image.new("L", (W, W), 255); dp = ImageDraw.Draw(pl)
    for k in range(0, W, 128):
        dp.line([(k, 0), (k, W)], fill=40, width=3)
        dp.line([(0, k), (W, k)], fill=40, width=3)
    for k in range(64, W, 128):
        if rng.random() < 0.7:
            dp.line([(k, 0), (k, W)], fill=110, width=2)
    for x in range(8, W, 32):
        for y in (8, 120, 136, 248, 264, 376, 392, 504):
            dp.ellipse([x - 2, y - 2, x + 2, y + 2], fill=70)
    pl = pl.filter(ImageFilter.GaussianBlur(0.7))
    # B: scratches / chipped paint
    sc = Image.new("L", (W, W), 0); ds = ImageDraw.Draw(sc)
    for _ in range(420):
        x, y = rng.uniform(0, W), rng.uniform(0, W)
        a = rng.uniform(0, math.tau); L = rng.uniform(4, 26)
        ds.line([x, y, x + math.cos(a) * L, y + math.sin(a) * L], fill=int(rng.uniform(120, 255)), width=1)
    for _ in range(140):
        x, y, r = rng.uniform(0, W), rng.uniform(0, W), rng.uniform(1.5, 6)
        ds.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=int(rng.uniform(150, 255)))
    # wrap-around copy so the pattern tiles
    sc = ImageChops.lighter(sc, ImageChops.offset(sc, W // 2, W // 2).point(lambda v: v // 3))
    # A: rust mask (blotchy streaks running down)
    rm = Image.new("L", (W, W), 0); dr = ImageDraw.Draw(rm)
    for _ in range(90):
        x, y = rng.uniform(0, W), rng.uniform(0, W)
        r = rng.uniform(6, 26)
        dr.ellipse([x - r, y - r, x + r, y + r], fill=int(rng.uniform(120, 255)))
        dr.line([x, y, x + rng.uniform(-3, 3), y + rng.uniform(20, 70)], fill=int(rng.uniform(90, 200)), width=int(rng.uniform(2, 6)))
    rm = rm.filter(ImageFilter.GaussianBlur(4))
    rm = ImageChops.multiply(rm, ImageOps.autocontrast(grime).point(lambda v: min(255, 60 + v)))
    os.makedirs(f"{OUT}/materials", exist_ok=True)
    Image.merge("RGBA", (grime, pl, sc, rm)).save(f"{OUT}/materials/weather.png", optimize=True)
    rust = None
    for cand in ("Rust004.png", "Rust001.png"):
        if os.path.exists(f"{ACG}/{cand}"):
            rust = Image.open(f"{ACG}/{cand}").convert("RGB").resize((W, W), Image.LANCZOS); break
    rust.save(f"{OUT}/materials/rust.png", optimize=True)
    # stencils: original markings drawn from primitives (no fonts): unit numbers in block
    # digits, chevrons, hazard stripes, arrows, "no step" bar
    st = Image.new("RGBA", (W, W), (0, 0, 0, 0)); dd = ImageDraw.Draw(st)
    SEG = {0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg", 9: "abcfgd"}
    def digit(x, y, n, s=18, col=(235, 235, 225, 255)):
        segs = {"a": (0, 0, 1, 0), "b": (1, 0, 1, 1), "c": (1, 1, 1, 2), "d": (0, 2, 1, 2), "e": (0, 1, 0, 2), "f": (0, 0, 0, 1), "g": (0, 1, 1, 1)}
        for k in SEG[n]:
            x0, y0, x1, y1 = segs[k]
            dd.line([x + x0 * s, y + y0 * s, x + x1 * s, y + y1 * s], fill=col, width=5)
    for i in range(4):
        n = rng.randint(10, 99)
        digit(30 + i * 120, 40, n // 10); digit(56 + i * 120, 40, n % 10)
    for i in range(4):  # chevrons
        cx = 60 + i * 120
        for k in range(3):
            dd.line([cx - 22, 180 + k * 14, cx, 166 + k * 14, cx + 22, 180 + k * 14], fill=(235, 235, 225, 255), width=5)
    for i in range(12):  # hazard stripes band
        x = i * 44
        dd.polygon([(x, 300), (x + 22, 300), (x + 52, 340), (x + 30, 340)], fill=(230, 190, 40, 255))
    for i in range(4):  # arrows
        cx = 60 + i * 120
        dd.polygon([(cx - 8, 440), (cx + 8, 440), (cx + 8, 410), (cx + 18, 410), (cx, 390), (cx - 18, 410), (cx - 8, 410)], fill=(235, 235, 225, 255))
    dd.rectangle([20, 470, 240, 478], fill=(220, 60, 40, 255))
    st = st.filter(ImageFilter.GaussianBlur(0.5))
    st.save(f"{OUT}/materials/stencils.png", optimize=True)

if __name__ == "__main__" and len(__import__("sys").argv) > 2 and __import__("sys").argv[1] == "--env":
    build_terrain_env(__import__("sys").argv[2])
    raise SystemExit(0)
if __name__ == "__main__":
    build_terrain(); build_decals(); build_weather()
    print("done")
