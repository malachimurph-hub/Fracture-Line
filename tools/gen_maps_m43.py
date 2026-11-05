#!/usr/bin/env python3
"""M4.3: four country-staged review maps (mirror-symmetric, 128x128, 4 players).

  Prairie Crossing — USA      temperate strip-mall town, ranch houses, blue-canopy gas
  Rheinbruck — Germany        temperate canal town, half-timbered houses (existing EU look)
  Qanat Gate — Iran           arid courtyard town, flat-roof adobe, gold-canopy gas
  Severny Bridge — Russia     winter panel blocks + izbas, red-canopy gas, pines

Each MapDef.civ_theme is us|de|ir|ru so props/houses remap. Labels include the country.
Run: python3 tools/gen_maps_m43.py
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_maps_m25 as gm

N = gm.N
H = gm.H
SPAWNS = gm.SPAWNS
hsh, vnoise = gm.hsh, gm.vnoise

def write_themed(m, spawns, desc_key, civ_theme, size=128):
    """Like Map.write but adds civ_theme and keeps size configurable."""
    ROOT = gm.ROOT
    os.makedirs(os.path.join(ROOT, "data/maps"), exist_ok=True)
    base = os.path.join(ROOT, "data/maps", m.id)
    with open(base + ".txt", "w") as f:
        f.write("\n".join("".join(r) for r in m.g) + "\n")
    with open(base + ".biome.txt", "w") as f:
        f.write("\n".join("".join(r) for r in m.bio) + "\n")
    with open(base + ".decor.txt", "w") as f:
        for d in m.decor:
            f.write("%s %.2f %.2f %d\n" % d)
    def uniq(items):
        seen, out = set(), []
        for it in items:
            key = (it[1], it[2]) if len(it) >= 3 else it
            if key not in seen:
                seen.add(key); out.append(it)
        return out
    res, neu = uniq(m.res), uniq(m.neu)
    # houses may carry rot as 4th field
    neu_s = []
    for n in neu:
        if len(n) >= 4:
            neu_s.append('{"kind": "%s", "tile": Vector2i(%d, %d), "rot": %d}' % (n[0], n[1], n[2], n[3]))
        else:
            neu_s.append('{"kind": "%s", "tile": Vector2i(%d, %d)}' % (n[0], n[1], n[2]))
    lines = ['[gd_resource type="Resource" script_class="MapDef" load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://data/defs/map_def.gd" id="1_s"]', '', '[resource]',
             'script = ExtResource("1_s")',
             'id = &"%s"' % m.id, 'name_key = "%s"' % m.name_key, 'description_key = "%s"' % desc_key,
             'size = Vector2i(%d, %d)' % (size, size),
             'tiles_path = "res://data/maps/%s.txt"' % m.id,
             'spawns = Array[Vector2i]([%s])' % ", ".join("Vector2i(%d, %d)" % s for s in spawns),
             'resources = Array[Dictionary]([%s])' % ", ".join(
                 '{"kind": "%s", "tile": Vector2i(%d, %d), "amount": %d}' % r for r in res),
             'neutrals = Array[Dictionary]([%s])' % ", ".join(neu_s),
             'env = &"%s"' % m.env,
             'civ_theme = &"%s"' % civ_theme]
    with open(base + ".tres", "w") as f:
        f.write("\n".join(lines) + "\n")
    print("%s ok theme=%s decor=%d neu=%d res=%d" % (m.id, civ_theme, len(m.decor), len(neu), len(res)))


def paint_biome(m, env):
    g, bio = m.g, m.bio
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
            elif env == "winter":
                b = 's' if n > 0.35 else ('d' if n < 0.2 else 'g')
            elif env == "arid" or env == "desert":
                b = 's' if n > 0.45 else ('d' if n > 0.28 else 'g')
            else:
                b = 'g' if n > 0.55 else ('G' if n > 0.3 else 'l' if hasattr(gm, 'l') else 'g')
                if b == 'l':
                    b = 'G'
            if bio[y][x] not in 'cd' or t in '~=#^:':
                bio[y][x] = b


def place_cars(m, roads, fleet):
    """Park cars along road tiles near the town."""
    for (x, y) in roads:
        if hsh(x, y, 17) < 0.22 and m.g[y][x] == ':':
            # offset to the shoulder
            for dx, dy, rot in ((1, 0, 1), (-1, 0, 3), (0, 1, 0), (0, -1, 2)):
                xx, yy = x + dx, y + dy
                if 0 < xx < H and 0 < yy < H and m.g[yy][xx] in '.,' and hsh(xx, yy, 19) < 0.5:
                    kind = fleet[int(hsh(xx, yy, 21) * len(fleet)) % len(fleet)]
                    m.deco(kind, xx, yy, rot)
                    break


def town_grid(m, x0, y0, cols, rows, gap, house_kinds, block_kind="neutral_civ_block"):
    """Place a rectangular street grid of garrisonable blocks/houses; returns road cells."""
    roads = []
    # streets
    for c in range(cols + 1):
        x = x0 + c * gap
        for y in range(y0, y0 + rows * gap + 1):
            if 2 < x < H - 2 and 2 < y < H - 2 and m.g[y][x] in '.,T':
                m.put(x, y, ':'); roads.append((x, y))
                if x + 1 < H - 2 and m.g[y][x + 1] in '.,T':
                    m.put(x + 1, y, ':'); roads.append((x + 1, y))
    for r in range(rows + 1):
        y = y0 + r * gap
        for x in range(x0, x0 + cols * gap + 2):
            if 2 < x < H - 2 and 2 < y < H - 2 and m.g[y][x] in '.,T:':
                m.put(x, y, ':'); roads.append((x, y))
                if y + 1 < H - 2 and m.g[y + 1][x] in '.,T:':
                    m.put(x, y + 1, ':'); roads.append((x, y + 1))
    # buildings in cells
    hi = 0
    for r in range(rows):
        for c in range(cols):
            bx = x0 + c * gap + 2
            by = y0 + r * gap + 2
            if not (2 < bx < H - 4 and 2 < by < H - 4):
                continue
            if any((bx + dx, by + dy) in m.taken for dy in range(3) for dx in range(3)):
                continue
            # alternate blocks and houses
            if (r + c) % 2 == 0:
                for yy in range(by, by + 3):
                    for xx in range(bx, bx + 3):
                        m.put(xx, yy, '^')
                        m.put(xx, yy, 'c', m.bio)
                        m.taken.add((xx, yy))
                for (a, b) in m.mirror(bx, by, 3, 3):
                    m.neu.append((block_kind, a, b))
            else:
                hk = house_kinds[hi % len(house_kinds)]; hi += 1
                for yy in range(by, by + 3):
                    for xx in range(bx, bx + 3):
                        m.put(xx, yy, '^')
                        m.put(xx, yy, 'c', m.bio)
                        m.taken.add((xx, yy))
                rot = (r + c) % 4
                for i, (a, b) in enumerate(m.mirror(bx, by, 3, 3)):
                    m.neu.append((hk, a, b, (rot + i * 2) % 4))
    return roads


def standard_economy(m):
    # Modern (post-M2.5) pile sizes matching kessel/harrow/ochre; town_grid places civs.
    home_seam, home_pile, mid_seam = (8, 26), (27, 8), (40, 46)
    piles = [(52, 50)]
    pumps = [(30, 40), (56, 16)]
    sp = [m.spot(x, y, 1, 1) for (x, y) in [home_seam, home_pile, mid_seam] + piles]
    amts = [("seam", 85000), ("cache", 20000), ("seam", 40000)] + [("cache", 8000)] * len(piles)
    for i, (x, y) in enumerate(sp):
        kind, amt = amts[i]
        for (a, b) in m.mirror(x, y):
            m.res.append((kind, a, b, amt))
    for (x, y) in pumps:
        X, Y = m.spot(x, y, 2, 2)
        for (a, b) in m.mirror(X, Y, 2, 2):
            m.neu.append(("neutral_pump", a, b))


# ======================================================================= Prairie Crossing — USA
def prairie():
    m = gm.Map("prairie_crossing", "MAP_PRAIRIE", "temperate")
    for y in range(H):
        for x in range(H):
            n = vnoise(x, y, 9, 3)
            m.put(x, y, 'g' if n > 0.4 else 'G', m.bio)
            if n > 0.78:
                m.put(x, y, ',')
    m.border()
    # light oak copses away from bases
    for (cx, cy, r) in ((36, 18, 3.2), (50, 36, 2.8), (20, 48, 2.6)):
        m.blob(cx, cy, r, 'T', 5)
    m.clear_bases()
    # arterial roads from each base toward town
    m.road(20, 22, 44, 44, 2)
    m.road(22, 30, 50, 30, 2)
    m.road(30, 22, 30, 50, 2)
    roads = town_grid(m, 42, 42, 3, 3, 6, ["neutral_house_a", "neutral_house_b"])
    standard_economy(m)
    paint_biome(m, "temperate")
    # decor
    for y in range(1, H):
        for x in range(1, H):
            t, r = m.g[y][x], hsh(x, y, 11)
            if t == 'T' and r < 0.55:
                m.deco("oak", x, y)
            elif t == '.' and r < 0.008:
                m.deco("rock_small", x, y)
    for (x, y) in ((46, 40), (52, 46), (40, 52)):
        if m.g[y][x] in ':.,':
            m.deco("gas_station", x, y, 0)
    for (x, y) in ((44, 48), (50, 44)):
        m.deco("shops", x, y, 0) if False else None
    # strip shops as structure decor
    if m.g[48][54] in '.,:':
        m.structure("shops", 54, 48, 4, 3)
    place_cars(m, roads, ["car_suv", "car_white", "car_red", "car_pickup" if False else "car_van", "car_blue", "car_silver"])
    for y in range(1, H):
        for x in range(1, H):
            if m.g[y][x] == '.' and (x * 7 + y * 3) % 29 == 0 and any(
                    m.g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < H and 0 <= y + dy < H):
                m.deco("power_pole", x, y, 0)
    write_themed(m, SPAWNS, "MAP_PRAIRIE_DESC", "us")


# ======================================================================= Rheinbruck — Germany
def rheinbruck():
    m = gm.Map("rheinbruck", "MAP_RHEINBRUCK", "temperate")
    for y in range(H):
        for x in range(H):
            n = vnoise(x, y, 8, 2)
            m.put(x, y, 'G' if n > 0.5 else 'g', m.bio)
    # canal east-west through town
    for x in range(N):
        for y in range(H - 3, H):
            m.g[y][x] = '~'; m.bio[y][x] = 'w'
            m.g[N - 1 - y][x] = '~'; m.bio[N - 1 - y][x] = 'w'
    for x0 in (24, 48, 64):
        for y in range(N):
            if m.g[y][x0] == '~':
                m.g[y][x0] = '#'; m.g[y][N - 1 - x0] = '#'
    for (cx, cy, r) in ((18, 40, 3.5), (40, 16, 3.0), (52, 28, 2.6)):
        m.blob(cx, cy, r, 'T', 4)
    m.border()
    m.clear_bases()
    m.road(20, 22, 24, 56, 2)
    m.road(24, 30, 48, 30, 2)
    m.road(48, 30, 48, 56, 2)
    roads = town_grid(m, 40, 34, 3, 2, 7, ["neutral_house_a", "neutral_house_b", "neutral_house_c", "neutral_house_d"])
    standard_economy(m)
    paint_biome(m, "temperate")
    for y in range(1, H):
        for x in range(1, H):
            t, r = m.g[y][x], hsh(x, y, 11)
            if t == 'T' and r < 0.6:
                m.deco("oak", x, y)
            elif t == '.' and r < 0.01:
                m.deco("rock_small", x, y)
    for (x, y) in ((44, 38), (50, 44)):
        if m.g[y][x] in ':.,':
            m.deco("gas_station", x, y, 0)
    place_cars(m, roads, ["car_silver", "car_white", "car_blue", "car_red", "car_van"])
    for y in range(1, H):
        for x in range(1, H):
            if m.g[y][x] == '.' and (x * 5 + y * 9) % 27 == 0 and any(
                    m.g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < H and 0 <= y + dy < H):
                m.deco("power_pole", x, y, 0)
    write_themed(m, SPAWNS, "MAP_RHEINBRUCK_DESC", "de")


# ======================================================================= Qanat Gate — Iran
def qanat():
    m = gm.Map("qanat_gate", "MAP_QANAT", "arid")
    for y in range(H):
        for x in range(H):
            n = vnoise(x, y, 10, 7)
            m.put(x, y, 's' if n > 0.5 else ('d' if n > 0.3 else 'g'), m.bio)
            if n > 0.82:
                m.put(x, y, ',')
    # oasis pools near centre
    for (cx, cy, r) in ((56, 56, 3.0), (48, 60, 2.2)):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if 0 < x < H and 0 < y < H and (x - cx) ** 2 + (y - cy) ** 2 < r * r:
                    m.put(x, y, '~'); m.put(x, y, 'w', m.bio)
    for (cx, cy, r) in ((30, 20, 2.8), (50, 18, 2.4), (18, 44, 2.2)):
        m.blob(cx, cy, r, '^', 3)   # mesas
    m.border()
    m.clear_bases()
    m.road(20, 22, 44, 48, 2)
    m.road(22, 34, 52, 34, 2)
    roads = town_grid(m, 40, 40, 3, 3, 6, ["neutral_house_a", "neutral_house_b"])
    standard_economy(m)
    paint_biome(m, "arid")
    for y in range(1, H):
        for x in range(1, H):
            t, b, r = m.g[y][x], m.bio[y][x], hsh(x, y, 11)
            if t == '^' and r < 0.25:
                m.deco("rock", x, y)
            elif t == '.' and b in 'sg' and r < 0.03:
                m.deco("palm", x, y)
            elif t == '.' and r < 0.012:
                m.deco("rock_small", x, y)
            elif t == '.' and r < 0.02:
                m.deco("scrub_tree", x, y)
    for (x, y) in ((46, 40), (52, 48)):
        if m.g[y][x] in ':.,':
            m.deco("gas_station", x, y, 0)
    place_cars(m, roads, ["car_white", "car_taxi", "car_van", "car_silver", "car_red"])
    write_themed(m, SPAWNS, "MAP_QANAT_DESC", "ir")


# ======================================================================= Severny Bridge — Russia
def severny():
    m = gm.Map("severny_bridge", "MAP_SEVERNY", "winter")
    for y in range(H):
        for x in range(H):
            n = vnoise(x, y, 8, 5)
            m.put(x, y, 's' if n > 0.35 else 'g', m.bio)
    # frozen river
    for x in range(N):
        xx = min(x, N - 1 - x)
        half = 2.6 + 1.2 * math.sin(xx * 0.2)
        for y in range(N):
            if abs(y - 63.5) < half:
                m.g[y][x] = '~'
    for x0 in (28, 52, 64):
        for y in range(N):
            if m.g[y][x0] == '~':
                m.g[y][x0] = '#'; m.g[y][N - 1 - x0] = '#'
            elif m.g[y][x0 + 1] == '~' and x0 == 40:
                m.g[y][x0 + 1] = '='
    for (cx, cy, r) in ((22, 38, 4.0), (44, 14, 3.2), (54, 34, 2.8), (14, 50, 3.0)):
        m.blob(cx, cy, r, 'T', 6)
    m.border()
    m.clear_bases()
    m.road(20, 22, 28, 56, 2)
    m.road(28, 30, 52, 30, 2)
    m.road(52, 30, 52, 56, 2)
    roads = town_grid(m, 38, 36, 3, 2, 7, ["neutral_house_a", "neutral_house_b"])
    standard_economy(m)
    paint_biome(m, "winter")
    for y in range(1, H):
        for x in range(1, H):
            t, r = m.g[y][x], hsh(x, y, 11)
            if t == 'T' and r < 0.65:
                m.deco("pine_snow" if hsh(x, y, 4) < 0.7 else "pine", x, y)
            elif t == '.' and r < 0.01:
                m.deco("rock_small", x, y)
    for (x, y) in ((44, 40), (50, 46)):
        if m.g[y][x] in ':.,':
            m.deco("gas_station", x, y, 0)
    place_cars(m, roads, ["car_van", "car_silver", "car_white", "car_blue", "car_suv"])
    for y in range(1, H):
        for x in range(1, H):
            if m.g[y][x] == '.' and (x * 7 + y * 3) % 25 == 0 and any(
                    m.g[y + dy][x + dx] == ':' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < H and 0 <= y + dy < H):
                m.deco("power_pole", x, y, 0)
    write_themed(m, SPAWNS, "MAP_SEVERNY_DESC", "ru")


if __name__ == "__main__":
    prairie()
    rheinbruck()
    qanat()
    severny()
