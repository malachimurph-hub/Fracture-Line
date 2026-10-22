#!/usr/bin/env python3
"""M2.5 skirmish maps (4 players, mirror-symmetric on both axes so every start is equal).

  Kessel Pass      (winter):    a frozen river splits north from south; two ice fords and two
                                bridges; snowy pine forests and rock ridges funnel the flanks; a
                                mountain village with garrisonable houses sits on both banks.
  Harrow Junction  (temperate): a canal runs north-south through a small city; a street grid of
                                garrisonable blocks around a central square; farmland, hedges and
                                oak woods around the bases.

Same outputs as tools/gen_map_varno.py (tiles / biome / decor / MapDef .tres) plus MapDef.env.
Tile chars: . grass  : road  , rough  ~ water  = ford  # bridge  ^ cliff  T forest.
Biome chars (view only, splat layers): s d g G (natural), a asphalt, r rock, w riverbed, c concrete.
"""
import math, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 128
H = N // 2

def hsh(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (0x5bd1e995 + s * 2654435761)
    v &= 0xffffffff; v ^= v >> 13; v = (v * 0x5bd1e995) & 0xffffffff
    return (v & 0xffff) / 65535.0

def vnoise(x, y, scale, s=0):
    fx, fy = x / scale, y / scale
    x0, y0 = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b, c, d = hsh(x0, y0, s), hsh(x0 + 1, y0, s), hsh(x0, y0 + 1, s), hsh(x0 + 1, y0 + 1, s)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

class Map:
    def __init__(self, mid, name_key, env):
        self.id, self.name_key, self.env = mid, name_key, env
        self.g = [['.'] * N for _ in range(N)]
        self.bio = [['g'] * N for _ in range(N)]
        self.decor, self.res, self.neu = [], [], []
        self.taken = set((x, y) for y in range(7, 27) for x in range(7, 27))   # base area stays clear

    @staticmethod
    def mirror(x, y, w=1, h=1):
        return [(x, y), (N - x - w, y), (x, N - y - h), (N - x - w, N - y - h)]

    def put(self, x, y, c, layer=None):
        L = self.g if layer is None else layer
        for (a, b) in self.mirror(x, y):
            if 0 <= a < N and 0 <= b < N:
                L[b][a] = c

    def road(self, x0, y0, x1, y1, width=2):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps); y = round(y0 + (y1 - y0) * i / steps)
            for dx in range(width):
                for dy in range(width):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < H and 0 <= yy < H and self.g[yy][xx] in '.,T':
                        self.put(xx, yy, ':')

    def blob(self, cx, cy, r, c, s=0, only='.,'):
        for y in range(int(cy - r - 2), int(cy + r + 3)):
            for x in range(int(cx - r - 2), int(cx + r + 3)):
                if 0 <= x < H and 0 <= y < H and (x - cx) ** 2 + (y - cy) ** 2 < r * r + hsh(x, y, s) * 4 and self.g[y][x] in only:
                    self.put(x, y, c)

    def border(self):
        for i in range(N):
            for (x, y) in ((i, 0), (i, N - 1), (0, i), (N - 1, i)):
                self.g[y][x] = '^'

    def clear_bases(self):
        for y in range(7, 33):
            for x in range(7, 33):
                if self.g[y][x] in 'T^,~':
                    self.put(x, y, '.')
        for y in range(11, 27):
            for x in range(11, 27):
                self.put(x, y, 'd', self.bio)

    def spot(self, x, y, w, h):
        """nearest free rect of plain ground (1-tile margin) in the NW quadrant"""
        for r in range(0, 14):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    X, Y = x + dx, y + dy
                    if not (2 < X and 2 < Y and X + w < H - 1 and Y + h < H - 1):
                        continue
                    ok = True
                    for yy in range(Y - 1, Y + h + 1):
                        for xx in range(X - 1, X + w + 1):
                            if (X <= xx < X + w and Y <= yy < Y + h and self.g[yy][xx] not in '.,') or (xx, yy) in self.taken:
                                ok = False
                    if ok:
                        for yy in range(Y - 1, Y + h + 1):
                            for xx in range(X - 1, X + w + 1):
                                self.taken.add((xx, yy))
                        return (X, Y)
        raise SystemExit("%s: no spot near %d,%d" % (self.id, x, y))

    def structure(self, kind, x, y, w, h, block_bio='c'):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, '^')
                if block_bio:
                    self.put(xx, yy, block_bio, self.bio)
        for i, (a, b) in enumerate(self.mirror(x, y, w, h)):
            self.decor.append((kind, a + w / 2, b + h / 2, (i * 2) % 4))

    def deco(self, kind, x, y, rot=None):
        for (a, b) in self.mirror(x, y):
            self.decor.append((kind, a + 0.5, b + 0.5, int(hsh(a, b, 9) * 4) if rot is None else rot))

    def write(self, spawns, desc_key):
        os.makedirs(os.path.join(ROOT, "data/maps"), exist_ok=True)
        base = os.path.join(ROOT, "data/maps", self.id)
        with open(base + ".txt", "w") as f:
            f.write("\n".join("".join(r) for r in self.g) + "\n")
        with open(base + ".biome.txt", "w") as f:
            f.write("\n".join("".join(r) for r in self.bio) + "\n")
        with open(base + ".decor.txt", "w") as f:
            for d in self.decor:
                f.write("%s %.2f %.2f %d\n" % d)
        def uniq(items):
            seen, out = set(), []
            for it in items:
                if (it[1], it[2]) not in seen:
                    seen.add((it[1], it[2])); out.append(it)
            return out
        res, neu = uniq(self.res), uniq(self.neu)
        lines = ['[gd_resource type="Resource" script_class="MapDef" load_steps=2 format=3]', '',
                 '[ext_resource type="Script" path="res://data/defs/map_def.gd" id="1_s"]', '', '[resource]', 'script = ExtResource("1_s")',
                 'id = &"%s"' % self.id, 'name_key = "%s"' % self.name_key, 'description_key = "%s"' % desc_key, 'size = Vector2i(128, 128)',
                 'tiles_path = "res://data/maps/%s.txt"' % self.id,
                 'spawns = Array[Vector2i]([%s])' % ", ".join("Vector2i(%d, %d)" % s for s in spawns),
                 'resources = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d), "amount": %d}' % r for r in res),
                 'neutrals = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d)}' % n for n in neu),
                 'env = &"%s"' % self.env]
        with open(base + ".tres", "w") as f:
            f.write("\n".join(lines) + "\n")
        print("%s ok: %d decor, %d neutrals (%d houses), %d resources" % (self.id, len(self.decor), len(neu),
              sum(1 for n in neu if n[0] == "neutral_civ_block"), len(res)))

    def economy(self, home_seam, home_pile, mid_seam, piles, pumps, civ):
        """resources (2x M2.4 amounts, M2.5) + neutral derricks and garrisonable houses"""
        sp = [self.spot(x, y, 1, 1) for (x, y) in [home_seam, home_pile, mid_seam] + piles]
        for i, (x, y) in enumerate(sp):
            kind, amt = [("seam", 30000), ("cache", 6000), ("seam", 40000)][i] if i < 3 else ("cache", 8000)
            for (a, b) in self.mirror(x, y):
                self.res.append((kind, a, b, amt))
        for (x, y) in pumps:
            X, Y = self.spot(x, y, 2, 2)
            for (a, b) in self.mirror(X, Y, 2, 2):
                self.neu.append(("neutral_pump", a, b))
        for (x, y) in civ:
            X, Y = self.spot(x, y, 3, 3)
            for yy in range(Y, Y + 3):
                for xx in range(X, X + 3):
                    self.put(xx, yy, 'c', self.bio)
            for (a, b) in self.mirror(X, Y, 3, 3):
                self.neu.append(("neutral_civ_block", a, b))

SPAWNS = [(14, 14), (N - 18, N - 18), (N - 18, 14), (14, N - 18)]

# ======================================================================= Kessel Pass (winter)
def kessel():
    m = Map("kessel_pass", "MAP_KESSEL", "winter")
    g, bio = m.g, m.bio
    # frozen river along y ~ 63.5 (east-west), meandering; mirror makes it continuous
    half = {}
    for x in range(N):
        xx = min(x, N - 1 - x)
        half[x] = 3.0 + 1.4 * math.sin(xx * 0.17) + (1.0 if 52 <= x <= 75 else 0)
        for y in range(N):
            if abs(y - 63.5) < half[x]:
                g[y][x] = '~'
    for x0, kind in ((22, '#'), (23, '#'), (24, '#'), (40, '='), (41, '='), (42, '='), (62, '#'), (63, '#'), (64, '#'), (65, '#')):
        for y in range(N):
            if g[y][x0] == '~':
                g[y][x0] = kind; g[y][N - 1 - x0] = kind
    # mountain ridges (impassable) that funnel the approach to the river
    for (cx, cy, r) in ((36, 30, 3.4), (46, 22, 3.0), (52, 40, 2.6), (8, 44, 3.2), (28, 50, 2.4)):
        m.blob(cx, cy, r, '^', 3)
    # pine forests (infantry only)
    for (cx, cy, r) in ((20, 40, 4.2), (40, 10, 3.6), (56, 30, 3.0), (10, 54, 3.0), (34, 44, 2.6), (50, 52, 2.4)):
        m.blob(cx, cy, r, 'T', 5)
    for y in range(H):
        for x in range(H):
            if g[y][x] == '.' and vnoise(x, y, 5, 4) > 0.76:
                m.put(x, y, ',')
    m.border()
    m.clear_bases()
    m.road(20, 22, 22, 56)           # base -> west bridge
    m.road(22, 30, 46, 30)           # cross road
    m.road(46, 30, 62, 56, 2)        # to the central bridge
    m.road(30, 46, 40, 56)           # to the ice ford
    # biomes: snow fields, frozen dirt on roads' shoulders and village, snowy grass patches
    for y in range(N):
        for x in range(N):
            t = g[y][x]
            xq, yq = min(x, N - 1 - x), min(y, N - 1 - y)
            n, n2 = vnoise(xq, yq, 8, 1), vnoise(xq, yq, 3, 2)
            if t in '~=#':
                b = 'w'
            elif t == '^':
                b = 'r'
            elif t == ':':
                b = 'a'
            elif t == ',':
                b = 'd'
            elif t == 'T':
                b = 'G' if n2 > 0.5 else 'g'
            elif n > 0.66:
                b = 'g'
            elif n < 0.24:
                b = 'd'
            else:
                b = 's'
            if bio[y][x] not in 'cd' or t in '~=#^:':
                bio[y][x] = b
    # village on each bank by the central bridge + houses along the west road
    m.economy(home_seam=(8, 26), home_pile=(27, 8), mid_seam=(40, 46), piles=[(52, 50)], pumps=[(30, 40), (56, 16)],
              civ=[(56, 52), (50, 54), (56, 46), (44, 52), (26, 52)])
    # decor
    for y in range(1, H):
        for x in range(1, H):
            t, b, r = g[y][x], bio[y][x], hsh(x, y, 11)
            if t == 'T' and r < 0.62:
                m.deco("pine_snow" if hsh(x, y, 4) < 0.6 else "pine", x, y)
            elif t == '^' and r < 0.22:
                m.deco("rock", x, y)
            elif t == '.' and b in 'sg' and r < 0.012:
                m.deco("pine_snow", x, y)
            elif t == '.' and r < 0.01:
                m.deco("rock_small", x, y)
    for y in range(1, H):
        for x in range(1, H):
            if g[y][x] == '.' and (x * 7 + y * 3) % 23 == 0 and any(g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                m.deco("power_pole", x, y, 0)
    for (x, y) in ((47, 56), (60, 49)):
        if g[y][x] in ':.,':
            m.deco("wreck_car", x, y)
    m.write(SPAWNS, "MAP_KESSEL_DESC")

# ================================================================== Harrow Junction (temperate)
def harrow():
    m = Map("harrow_junction", "MAP_HARROW", "temperate")
    g, bio = m.g, m.bio
    # canal along x ~ 63.5 (north-south), straight-sided, 3 bridges + a weir ford
    for y in range(N):
        for x in range(N):
            if abs(x - 63.5) < 3.0:
                g[y][x] = '~'
    for y0, kind in ((16, '#'), (17, '#'), (18, '#'), (38, '='), (39, '='), (58, '#'), (59, '#'), (60, '#'), (61, '#')):
        for x in range(N):
            if g[y0][x] == '~':
                g[y0][x] = kind; g[N - 1 - y0][x] = kind
    # oak woods and hedgerows, a hill ridge (cliff)
    for (cx, cy, r) in ((36, 12, 3.6), (8, 40, 3.8), (26, 36, 2.8), (40, 26, 2.2)):
        m.blob(cx, cy, r, 'T', 6)
    for (cx, cy, r) in ((12, 52, 2.8), (32, 22, 1.8)):
        m.blob(cx, cy, r, '^', 7)
    m.border()
    m.clear_bases()
    # city street grid (NW quadrant part of the centre: x 40..61, y 40..63)
    for y in range(40, H):
        for x in range(40, 61):
            if (x - 40) % 7 in (0, 1) or (y - 40) % 7 in (0, 1):
                if g[y][x] in '.,T':
                    m.put(x, y, ':')
    m.road(20, 22, 20, 44)
    m.road(20, 44, 40, 44)
    m.road(22, 20, 56, 17)            # to the north bridge
    m.road(40, 58, 58, 59, 3)         # main street onto the central bridge
    for y in range(N):
        for x in range(N):
            t = g[y][x]
            xq, yq = min(x, N - 1 - x), min(y, N - 1 - y)
            n, n2 = vnoise(xq, yq, 7, 1), vnoise(xq, yq, 3, 2)
            city = xq >= 40 and yq >= 40
            if t in '~=#':
                b = 'w'
            elif t == '^':
                b = 'r'
            elif t == ':':
                b = 'a'
            elif city:
                b = 'c' if n2 > 0.35 else 'G'      # pavements and small parks
            elif t == 'T':
                b = 'G'
            elif t == ',':
                b = 'd'
            elif 6 < xq < 38 and 28 < yq < 40 and ((xq // 3) % 2 == 0):
                b = 'd'                             # ploughed field strips
            elif n > 0.6:
                b = 's'
            else:
                b = 'g'
            if bio[y][x] != 'd' or t in '~=#^:':
                bio[y][x] = b
    m.economy(home_seam=(8, 26), home_pile=(27, 8), mid_seam=(30, 52), piles=[(50, 30)], pumps=[(34, 44), (54, 8)],
              civ=[(43, 43), (50, 43), (43, 50), (50, 50), (57, 43), (43, 57), (50, 56)])
    for y in range(1, H):
        for x in range(1, H):
            t, b, r = g[y][x], bio[y][x], hsh(x, y, 11)
            if t == 'T' and r < 0.6:
                m.deco("oak" if hsh(x, y, 3) < 0.65 else "pine", x, y)
            elif t == '^' and r < 0.2:
                m.deco("rock", x, y)
            elif t == '.' and b == 'G' and r < 0.05:
                m.deco("oak" if r < 0.02 else "bush", x, y)
            elif t == '.' and b == 'd' and r < 0.02:
                m.deco("hay_bale", x, y)
            elif t == '.' and b in 'sg' and r < 0.02:
                m.deco("bush", x, y)
    # fences along the fields, street lights in town
    for y in range(28, 40, 4):
        for x in range(8, 36, 2):
            if g[y][x] == '.' and hsh(x, y, 2) < 0.7:
                m.deco("fence", x, y, 0)
    for y in range(40, H):
        for x in range(40, 61):
            if g[y][x] == '.' and (x + y) % 5 == 0 and any(g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                m.deco("streetlight", x, y, 0)
    for (x, y) in ((45, 47), (54, 54)):
        if g[y][x] in ':.,':
            m.deco("wreck_car", x, y)
    m.write(SPAWNS, "MAP_HARROW_DESC")

if __name__ == "__main__":
    kessel()
    harrow()
