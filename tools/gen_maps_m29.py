#!/usr/bin/env python3
"""M2.9 urban skirmish maps, 256 x 256, 4 players, mirror-symmetric on both axes.

  Crescent City   (desert):    a dense downtown fills everything between the four desert bases:
                               a street grid of glass / office / apartment towers, a 14-tile central
                               boulevard cross, parked cars on every street, street lights on every
                               corner; a few plazas hold supplies and garrisonable blocks.
  Riverside Metro (temperate): a river splits north from south through the middle of a city; four
                               bridges on the avenues and two fords near the edges; riverside parks;
                               apartment and slim towers, shop rows, cars and street lights.

Reuses the M2.5 Map helpers (tools/gen_maps_m25.py) at N = 256. Tall buildings are view props
(view/props/prop_meshes.gd FOOTPRINT kinds) standing on '^' tiles so units path around them.
Run: python3 tools/gen_maps_m29.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_maps_m25 as gm
gm.N = 256
gm.H = 128
N, H, hsh = 256, 128, gm.hsh
SPAWNS = [(30, 30), (222, 222), (222, 30), (30, 222)]
CARS = ["car_red", "car_white", "car_blue", "car_silver", "car_taxi", "car_van", "car_suv", "car_white", "car_silver"]

def build(mid, name_key, env, lines, centre, mix, tree, river=False, seed=1):
    m = gm.Map(mid, name_key, env)
    m.taken = set((x, y) for y in range(12, 52) for x in range(12, 52))
    m.border()
    ground = 'd' if env == 'desert' else 'g'
    for y in range(1, H):
        for x in range(1, H):
            m.bio[y][x] = ground if gm.vnoise(x, y, 9, seed) > 0.35 else ('s' if env == 'desert' else 'G')
    city = lambda x, y: x >= lines[0] or y >= lines[0]
    online = lambda p: any(l <= p < l + 3 for l in lines) or p >= centre
    # outskirts: rough patches + scrub around the bases
    for (cx, cy, r) in [(46, 8, 5), (8, 46, 5), (52, 52, 3)]:
        m.blob(cx, cy, r, ',', seed)
    for y in range(3, lines[0] - 1):
        for x in range(3, lines[0] - 1):
            if (x, y) not in m.taken and hsh(x, y, seed + 3) > 0.985:
                m.deco(tree, x, y)
    # river (Riverside Metro): water band across the middle; bridges on two avenues, fords at the edges
    if river:
        for y in range(H - 6, H):
            for x in range(1, H):
                m.put(x, y, '~'); m.put(x, y, 'w', m.bio)
    # streets
    for y in range(1, H):
        for x in range(1, H):
            if not city(x, y) or m.g[y][x] == '^':
                continue
            road = (online(x) and y >= 2) or (online(y) and x >= 2)
            if river and y >= H - 6:
                if online(x) and x in range(lines[1], lines[1] + 3) or x in range(lines[3], lines[3] + 3):
                    m.put(x, y, '#'); m.put(x, y, 'a', m.bio)
                continue
            if road:
                m.put(x, y, ':'); m.put(x, y, 'a', m.bio)
            else:
                m.put(x, y, 'c', m.bio)
    if river:
        for y in range(H - 6, H):
            for x in range(20, 27):
                m.put(x, y, '='); m.put(x, y, 'w', m.bio)
    # roads from each base into the grid
    m.road(30, 34, lines[0], 34, 3)
    m.road(34, 30, 34, lines[0], 3)
    # blocks = rectangles between street lines
    edges = [2] + [l + 3 for l in lines]
    ends = [l for l in lines] + [centre]
    blocks = []
    for i in range(len(edges)):
        for j in range(len(edges)):
            x0, x1, y0, y1 = edges[i], ends[i], edges[j], ends[j]
            if x1 - x0 < 6 or y1 - y0 < 6 or not (x0 >= lines[0] or y0 >= lines[0]):
                continue
            if river and y1 > H - 8:
                y1 = H - 8   # riverside promenade
            blocks.append((x0, y0, x1, y1))
    # supplies + garrisonable houses go into plaza blocks (reserved before the towers)
    m.economy((22, 44), (44, 23), (lines[1] + 8, lines[2] + 6), [(lines[2] + 8, lines[0] + 7), (lines[0] + 7, lines[3] + 8)],
              [(10, 70), (70, 10)], [(lines[1] + 5, lines[1] + 5), (lines[3] + 5, lines[1] + 5), (lines[1] + 5, lines[3] + 5)])
    m.res = [(k, a, b, {30000: 85000, 6000: 20000}.get(amt, amt)) for (k, a, b, amt) in m.res]
    for (x0, y0, x1, y1) in blocks:
        park = hsh(x0, y0, seed + 7) < 0.16 or any(x0 <= tx < x1 and y0 <= ty < y1 for (tx, ty) in m.taken)
        ix0, iy0, ix1, iy1 = x0 + 1, y0 + 1, x1 - 1, y1 - 1
        if park:
            for y in range(iy0, iy1):
                for x in range(ix0, ix1):
                    if (x, y) not in m.taken and m.bio[y][x] == 'c':
                        m.put(x, y, 'g' if env != 'desert' else 's', m.bio)
                        if hsh(x, y, seed + 11) > 0.9:
                            m.deco(tree, x, y)
            continue
        y = iy0
        while y < iy1:
            rowh = 0
            x = ix0
            while x < ix1:
                k = mix[int(hsh(x, y, seed + 5) * len(mix)) % len(mix)]
                w, h = {"tower_slim": (3, 3), "shops": (4, 3)}.get(k, (4, 4))
                if x + w > ix1 or y + h > iy1:
                    w, h, k = 3, 3, "tower_slim"
                    if x + w > ix1 or y + h > iy1:
                        break
                if any((xx, yy) in m.taken for yy in range(y, y + h) for xx in range(x, x + w)):
                    x += 1
                    continue
                m.structure(k, x, y, w, h)
                for yy in range(y - 1, y + h + 1):
                    for xx in range(x - 1, x + w + 1):
                        m.taken.add((xx, yy))
                rowh = max(rowh, h)
                x += w + 1
            y += max(rowh, 3) + 1
    # cars parked along both kerbs + a few in the lanes; street lights on the pavements
    for y in range(2, H):
        for x in range(2, H):
            if m.g[y][x] != ':' or not city(x, y):
                continue
            vert = online(x) and not online(y)
            horiz = online(y) and not online(x)
            if vert and (x in lines and True or (x - 2) in lines):
                if y % 3 == 0 and hsh(x, y, seed + 13) < 0.62:
                    m.deco(CARS[int(hsh(x, y, seed + 17) * 97) % len(CARS)], x, y, 0 if hsh(x, y, 21) < 0.5 else 2)
            elif horiz and (y in lines or (y - 2) in lines):
                if x % 3 == 0 and hsh(x, y, seed + 19) < 0.62:
                    m.deco(CARS[int(hsh(x, y, seed + 23) * 97) % len(CARS)], x, y, 1 if hsh(x, y, 25) < 0.5 else 3)
            elif x == centre and not online(y) and y % 3 == 1 and hsh(x, y, seed + 31) < 0.7:
                m.deco(CARS[int(hsh(x, y, seed + 37) * 97) % len(CARS)], x, y, 0)
            elif y == centre and not online(x) and x % 3 == 1 and hsh(x, y, seed + 41) < 0.7:
                m.deco(CARS[int(hsh(x, y, seed + 43) * 97) % len(CARS)], x, y, 1)
            elif x >= centre and y >= centre and hsh(x, y, seed + 29) < 0.03:
                m.deco("wreck_car", x, y)
    for y in range(2, H):
        for x in range(2, H):
            if m.bio[y][x] != 'c' or m.g[y][x] != '.' or not city(x, y):
                continue
            near_road = any(m.g[y + dy][x + dx] == ':' for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)])
            if near_road and (x + y) % 6 == 0:
                m.deco("streetlight", x, y, 0)
    for p in range(lines[0], H, 6):   # boulevard median lights
        if not (river and p >= H - 7):
            m.deco("streetlight_double", H - 1, p, 0)
        m.deco("streetlight_double", p, H - 1, 1)
    m.write(SPAWNS, name_key + "_DESC")
    base = os.path.join(gm.ROOT, "data/maps", mid + ".tres")
    t = open(base).read().replace("size = Vector2i(128, 128)", "size = Vector2i(256, 256)")
    open(base, "w").write(t)

build("crescent_city", "MAP_CRESCENT", "desert", [58, 73, 88, 103], 121,
      ["tower_glass", "tower_office", "tower_apart", "tower_slim", "tower_glass", "shops"], "palm", seed=3)
build("riverside_metro", "MAP_RIVERSIDE", "temperate", [58, 75, 92, 107], 120,
      ["tower_apart", "tower_slim", "shops", "tower_office", "tower_apart", "tower_glass"], "oak", river=True, seed=5)
