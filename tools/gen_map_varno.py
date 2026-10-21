#!/usr/bin/env python3
"""Varno Crossing v2 (M1.2): a Zero Hour-style 4-player map. A river runs north-south with
three bridges and two fords. A riverside town straddles the central bridge (garrisonable
civilian blocks, a gas station, shacks, wrecks, power poles). Oil derricks (Veridite pumps)
and supply piles sit near the town, home supply seams sit behind each base, and there is a
contested seam per side. The map is mirror-symmetric on both axes, so all 4 starts are equivalent.

Outputs:
  data/maps/varno_crossing.txt        sim tiles (one char per tile)
  data/maps/varno_crossing.biome.txt  view-only ground types (splat source)
  data/maps/varno_crossing.decor.txt  view-only props: kind x y rot (one per line)
  data/maps/varno_crossing.tres       MapDef (spawns, resources, neutral structures)
"""
import math, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 128
g = [['.'] * N for _ in range(N)]      # sim tiles
bio = [['g'] * N for _ in range(N)]    # s sand, d dirt, g dry scrub, G green, a asphalt, c concrete, r rock, w riverbed
decor = []

def mirror(x, y, w=1, h=1):
    return [(x, y), (N - x - w, y), (x, N - y - h), (N - x - w, N - y - h)]
def sym_set(x, y, c, layer=None):
    L = g if layer is None else layer
    for (a, b) in mirror(x, y):
        if 0 <= a < N and 0 <= b < N:
            L[b][a] = c
def hsh(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (0x5bd1e995 + s * 2654435761)
    v &= 0xffffffff
    v ^= v >> 13
    v = (v * 0x5bd1e995) & 0xffffffff
    return (v & 0xffff) / 65535.0
def vnoise(x, y, scale, s=0):
    fx, fy = x / scale, y / scale
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = hsh(x0, y0, s), hsh(x0 + 1, y0, s)
    c, d = hsh(x0, y0 + 1, s), hsh(x0 + 1, y0 + 1, s)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

# ---- river (x ~ 63.5), width varies, symmetric in y
river_half = {}
for y in range(N):
    yy = min(y, N - 1 - y)
    half = 3.4 + 1.2 * math.sin(yy * 0.19) + (0.8 if 54 <= y <= 73 else 0)
    river_half[y] = half
    for x in range(N):
        if abs(x - 63.5) < half:
            g[y][x] = '~'
# bridges (vehicles) and fords (infantry)
for y0, kind in ((18, '#'), (19, '#'), (20, '#'), (42, '='), (43, '='), (61, '#'), (62, '#'), (63, '#'), (64, '#'), (65, '#'), (66, '#'), (84, '='), (85, '='), (107, '#'), (108, '#'), (109, '#')):
    for x in range(N):
        if g[y0][x] == '~':
            g[y0][x] = kind

# ---- roads (drawn in the NW quadrant, mirrored): base -> north bridge, base -> town
def road(x0, y0, x1, y1, width=2):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = round(x0 + (x1 - x0) * i / steps); y = round(y0 + (y1 - y0) * i / steps)
        for dx in range(width):
            for dy in range(width):
                xx, yy = x + dx, y + dy
                if 0 <= xx < 64 and 0 <= yy < 64 and g[yy][xx] in '.,':
                    sym_set(xx, yy, ':')
road(20, 20, 57, 19)          # to the north bridge
road(20, 20, 20, 50)          # down the west side
road(20, 50, 40, 62)          # into town
road(40, 62, 58, 62, 3)       # town main street onto the central bridge (3 wide + mirror = 6)
road(48, 50, 48, 63)          # town cross street
road(34, 42, 57, 42)          # to the ford

# ---- rocky outcrops / mesas (impassable) and scrub woods (infantry only)
clusters = [(40, 30, 3.2, 'T'), (10, 40, 3, 'T'), (44, 50 - 8, 2.2, '^'), (30, 8, 2.5, 'T'), (8, 58, 3, '^'), (48, 8, 2.5, '^'), (34, 52, 2.4, '^'), (28, 34, 2.6, '^')]
for cx, cy, r, c in clusters:
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if 0 <= x < 64 and 0 <= y < 64 and (x - cx) ** 2 + (y - cy) ** 2 < r * r + hsh(x, y) * 3 and g[y][x] == '.':
                sym_set(x, y, c)
# rough (dirt / rubble) patches
for y in range(64):
    for x in range(64):
        if g[y][x] == '.' and vnoise(x, y, 6, 3) > 0.74:
            sym_set(x, y, ',')
# map border cliffs
for i in range(N):
    for c in ((i, 0), (i, N - 1), (0, i), (N - 1, i)):
        g[c[1]][c[0]] = '^'
# clear base areas
for y in range(8, 32):
    for x in range(8, 32):
        if g[y][x] in 'T^,':
            sym_set(x, y, '.')

# ---- town (west bank, mirrored): civilian blocks are sim entities (3x3, garrisonable)
# town decor structures that block movement (impassable '^' under them): gas station, shacks
def block(x, y, w, h):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            sym_set(xx, yy, '^')
            sym_set(xx, yy, 'c', bio)
town_props = [("gas_station", 54, 50, 3, 2, 0), ("shack", 38, 54, 2, 2, 1), ("shack", 41, 50, 2, 2, 0), ("shack", 36, 58, 2, 2, 2)]
for kind, x, y, w, h, rot in town_props:
    block(x, y, w, h)
    for i, (a, b) in enumerate(mirror(x, y, w, h)):
        decor.append((kind, a + w / 2, b + h / 2, (rot + (2 if i in (1, 3) else 0)) % 4))
# ---- biomes (view only)
for y in range(N):
    for x in range(N):
        t = g[y][x]
        xq, yq = min(x, N - 1 - x), min(y, N - 1 - y)   # quadrant coords (symmetric)
        dr = abs(x - 63.5) - river_half[y]              # distance from the river bank
        n = vnoise(xq, yq, 9, 1)
        n2 = vnoise(xq, yq, 4, 2)
        if t in '~=#':
            b = 'w'
        elif t == '^':
            b = 'r'
        elif t == ':':
            b = 'a'
        elif dr < 4 + n2 * 3:
            b = 'G'                                      # green riverbank
        elif t == ',':
            b = 'd'
        elif xq < 12 + n * 10 or yq < 6 + n2 * 4:
            b = 's'                                      # sun-baked sand toward the map edge
        elif n > 0.62:
            b = 's'
        elif n < 0.3:
            b = 'd'
        else:
            b = 'g'
        bio[y][x] = b if bio[y][x] != 'c' else 'c'
# concrete/dirt around the town and base pads
for y in range(48, 80):
    for x in range(34, 60):
        if bio[y][x] in 'gsG' and g[y][x] == '.' and vnoise(x, y, 3, 7) > 0.35:
            sym_set(x, y, 'd', bio)
for (bx, by) in ((14, 14),):
    for y in range(by - 3, by + 9):
        for x in range(bx - 3, bx + 9):
            if g[y][x] == '.':
                sym_set(x, y, 'd', bio)

# ---- decor (view only): palms on the green banks, scrub trees in woods, rocks on cliffs,
# power poles along roads, burned-out cars on the town streets
for y in range(1, 64):
    for x in range(1, 64):
        t, b = g[y][x], bio[y][x]
        r = hsh(x, y, 11)
        if t == 'T' and r < 0.55:
            for (a, c) in mirror(x, y):
                decor.append(("palm" if b == 'G' or hsh(a, c, 5) < 0.4 else "scrub_tree", a + 0.5, c + 0.5, int(hsh(a, c, 9) * 4)))
        elif t == '^' and x > 0 and y > 0 and r < 0.18 and x < 63:
            for (a, c) in mirror(x, y):
                decor.append(("rock", a + 0.5, c + 0.5, int(hsh(a, c, 9) * 4)))
        elif t == '.' and b == 'G' and r < 0.05:
            for (a, c) in mirror(x, y):
                decor.append(("palm", a + 0.5, c + 0.5, int(hsh(a, c, 9) * 4)))
        elif t == '.' and b in 'sd' and r < 0.012:
            for (a, c) in mirror(x, y):
                decor.append(("rock_small", a + 0.5, c + 0.5, int(hsh(a, c, 9) * 4)))
# power poles every 5 tiles beside the long roads
for y in range(1, 64):
    for x in range(1, 64):
        if g[y][x] == '.' and (x * 7 + y * 3) % 23 == 0 and any(g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            for (a, c) in mirror(x, y):
                decor.append(("power_pole", a + 0.5, c + 0.5, 0))
for (x, y, rot) in ((45, 61, 1), (52, 59, 0), (49, 53, 2), (30, 55, 1)):
    if g[y][x] in ':.,':
        for i, (a, c) in enumerate(mirror(x, y)):
            decor.append(("wreck_car", a + 0.5, c + 0.5, (rot + i) % 4))

# ---- write
os.makedirs(os.path.join(ROOT, "data/maps"), exist_ok=True)
with open(os.path.join(ROOT, "data/maps/varno_crossing.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in g) + "\n")
with open(os.path.join(ROOT, "data/maps/varno_crossing.biome.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in bio) + "\n")
with open(os.path.join(ROOT, "data/maps/varno_crossing.decor.txt"), "w") as f:
    for d in decor:
        f.write("%s %.2f %.2f %d\n" % d)

def free_spot(x, y, w, h, taken):
    """Nearest rect (spiral) of plain ground with a 1-tile clear margin, not touching
    anything already placed - keeps roads and town streets open."""
    for r in range(0, 12):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                X, Y = x + dx, y + dy
                ok = X > 2 and Y > 2 and X + w < 62 and Y + h < 62
                if ok:
                    for yy in range(Y - 1, Y + h + 1):
                        for xx in range(X - 1, X + w + 1):
                            inside = X <= xx < X + w and Y <= yy < Y + h
                            if inside and g[yy][xx] not in '.,':
                                ok = False
                            if (xx, yy) in taken:
                                ok = False
                if ok:
                    for yy in range(Y - 1, Y + h + 1):
                        for xx in range(X - 1, X + w + 1):
                            taken.add((xx, yy))
                    return (X, Y)
    raise SystemExit("no spot near %d,%d" % (x, y))
taken = set()
for yy in range(8, 26):
    for xx in range(8, 26):
        taken.add((xx, yy))   # base area stays clear
civ = [free_spot(x, y, 3, 3, taken) for (x, y) in ((51, 56), (43, 56), (51, 58), (43, 58), (24, 46))]
pumps = [free_spot(34, 58, 2, 2, taken), free_spot(56, 30, 2, 2, taken)]
piles = [free_spot(31, 61, 1, 1, taken)]
sp = [(14, 14), (N - 18, N - 18), (N - 18, 14), (14, N - 18)]
res = []
def quad(x, y, w=1, h=1):
    return mirror(x, y, w, h)
for (x, y) in quad(8, 26): res.append(('seam', x, y, 15000))       # home seam
for (x, y) in quad(27, 9): res.append(('cache', x, y, 3000))       # home supply pile
for (x, y) in quad(38, 44): res.append(('seam', x, y, 20000))      # contested riverside seam
for (px, py) in piles:
    for (x, y) in quad(px, py): res.append(('cache', x, y, 4000))  # supply piles outside the town
neu = []
for (x, y) in pumps:                                                # oil derricks
    for (a, b) in quad(x, y, 2, 2):
        neu.append(("neutral_pump", a, b))
for (x, y) in civ:
    for (a, b) in quad(x, y, 3, 3):
        neu.append(("neutral_civ_block", a, b))
seen = set(); neu2 = []
for n in neu:
    if (n[1], n[2]) not in seen:
        seen.add((n[1], n[2])); neu2.append(n)
neu = neu2
seen = set(); res2 = []
for r in res:
    if (r[1], r[2]) not in seen:
        seen.add((r[1], r[2])); res2.append(r)
res = res2
lines = ['[gd_resource type="Resource" script_class="MapDef" load_steps=2 format=3]', '',
         '[ext_resource type="Script" path="res://data/defs/map_def.gd" id="1_s"]', '', '[resource]', 'script = ExtResource("1_s")',
         'id = &"varno_crossing"', 'name_key = "MAP_VARNO"', 'description_key = "MAP_VARNO_DESC"', 'size = Vector2i(128, 128)',
         'tiles_path = "res://data/maps/varno_crossing.txt"',
         'spawns = Array[Vector2i]([%s])' % ", ".join("Vector2i(%d, %d)" % s for s in sp),
         'resources = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d), "amount": %d}' % r for r in res),
         'neutrals = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d)}' % n for n in neu)]
with open(os.path.join(ROOT, "data/maps/varno_crossing.tres"), "w") as f:
    f.write("\n".join(lines) + "\n")
print("map ok: %d decor, %d neutrals, %d resources" % (len(decor), len(neu), len(res)))
