#!/usr/bin/env python3
"""M3.3 Phase 3 (items 17, 21, 22): new skirmish maps with hills and more ground types.

  Twin Ridges     2 players, 128 x 128, temperate: two bases in opposite corners, rolling hills,
                  farm fields (tilled earth), gravel farm tracks and a paved village square.
  Harvest Valley  4 players, 192 x 192, temperate: a river with two bridges and two fords splits the
                  valley; hills on both banks, fields, meadows and two villages.
  Sunfall Basin   6 players, 224 x 224, arid: four corner bases plus one on the north and south edges,
                  a ring of dunes and mesas around a gravel basin with an oasis town.
  Highland Crown  8 players, 256 x 256, temperate: corner and edge-middle bases around a ring of high
                  hills ("the crown"), lakes, woods, farmland and a market town in the centre.

Every map is mirror-symmetric on both axes (gen_maps_m25.Map). New biome chars (view only, item 22):
e earth (tilled), v gravel, p pavers, l lush grass. MapDef.hills = [cx, cy, radius, height mm].
Run: python3 tools/gen_maps_m33.py
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_maps_m25 as gm
hsh, vnoise = gm.hsh, gm.vnoise

def mirror_pts(N, x, y, w=1, h=1):
    out = []
    for p in [(x, y), (N - x - w, y), (x, N - y - h), (N - x - w, N - y - h)]:
        if p not in out:
            out.append(p)
    return out

def gen(mid, key, N, env, spawn_q, seed, river=False, lakes=(), hills_q=(), towns=(), fields=(), woods=(), mesas=(),
        pumps=(), mid_seams=(), tree="oak", two_player=False):
    gm.N, gm.H = N, N // 2
    H = N // 2
    m = gm.Map(mid, key, env)
    m.taken = set()
    for (sx, sy) in spawn_q:
        for y in range(sy - 8, sy + 12):
            for x in range(sx - 8, sx + 12):
                m.taken.add((x, y))
    # ground: natural mix by noise (item 22: lush grass patches on temperate maps)
    for y in range(H):
        for x in range(H):
            n = vnoise(x, y, 11, seed) * 0.7 + vnoise(x, y, 4, seed + 1) * 0.3
            if env == "arid":
                c = 's' if n > 0.55 else ('d' if n > 0.36 else 'g')
            else:
                c = 'g' if n > 0.62 else ('G' if n > 0.36 else 'l')
            m.put(x, y, c, m.bio)
    m.border()
    near_spawn = lambda x, y, r: any((x - sx - 2) ** 2 + (y - sy - 2) ** 2 < r * r for (sx, sy) in spawn_q)
    # water
    if river:
        for y in range(H - 4, H):
            for x in range(1, H):
                m.put(x, y, '~'); m.put(x, y, 'w', m.bio)
        for y in range(H - 6, H - 4):   # muddy banks
            for x in range(1, H):
                if hsh(x, y, seed) < 0.7:
                    m.put(x, y, 'd' if env != "arid" else 's', m.bio)
    for (cx, cy, r) in lakes:
        for y in range(cy - r - 2, cy + r + 3):
            for x in range(cx - r - 2, cx + r + 3):
                d = math.hypot(x - cx, y - cy) + (vnoise(x, y, 3, seed + 5) - 0.5) * 2.5
                if 0 < x < H and 0 < y < H and d < r:
                    m.put(x, y, '~'); m.put(x, y, 'w', m.bio)
                elif 0 < x < H and 0 < y < H and d < r + 1.6 and m.g[y][x] == '.':
                    m.put(x, y, 'd' if env != "arid" else 'g', m.bio)
    # woods, mesas (rock), rough scrub
    for (cx, cy, r) in woods:
        m.blob(cx, cy, r, 'T', seed)
    for (cx, cy, r) in mesas:
        m.blob(cx, cy, r, '^', seed + 3)
    for y in range(H):
        for x in range(H):
            if m.g[y][x] == '^':
                m.put(x, y, 'r', m.bio)
    # fields: tilled earth with hay bales and fences (passable ground)
    for (x0, y0, w, h) in fields:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if 0 < x < H and 0 < y < H and m.g[y][x] == '.':
                    m.put(x, y, 'l' if (y - y0) % 6 == 5 else 'e', m.bio)   # tilled rows with green crop strips
        for x in range(x0, x0 + w, 3):
            if m.g[y0 - 1][x] == '.' and 0 < y0 - 1:
                m.deco("fence", x + 0.5 - 0.5, y0 - 1, 1)
        for k in range(max(1, w * h // 60)):
            hx, hy = x0 + int(hsh(k, x0, seed) * w), y0 + int(hsh(k, y0, seed + 1) * h)
            if m.g[hy][hx] == '.':
                m.deco("hay_bale", hx, hy)
    # roads: asphalt main roads from each base to the centre; gravel farm tracks elsewhere
    for (sx, sy) in spawn_q:
        m.road(sx + 2, sy + 6, sx + 2, min(H - 1, sy + 18), 2)
        tx, ty = (H - 1, sy + 18) if sx + 2 < H - 6 else (sx + 2, H - 1)
        m.road(sx + 2, min(H - 1, sy + 18), tx, ty, 2)
        if sx + 2 < H - 6:
            m.road(H - 1, sy + 18, H - 1, H - 1, 2)   # on to the centre
    def track(x0, y0, x1, y1):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps); y = round(y0 + (y1 - y0) * i / steps)
            for dx in range(2):
                for dy in range(2):
                    if 0 < x + dx < H and 0 < y + dy < H and m.g[y + dy][x + dx] in '.,' and m.bio[y + dy][x + dx] != 'e':
                        m.put(x + dx, y + dy, 'v', m.bio)
    for (x0, y0, w, h) in fields:
        track(x0 - 2, y0 + h // 2, x0 + w + 1, y0 + h // 2)
    for (cx, cy, r) in towns:
        for (sx, sy) in spawn_q:
            track(cx, cy, sx + 12, min(H - 2, sy + 18))
    for y in range(H):
        for x in range(H):
            if m.g[y][x] in ':#':
                m.put(x, y, 'a', m.bio)
    # bridges + fords over the river
    if river:
        for y in range(H - 4, H):
            for (bx, kind) in [(int(H * 0.42), '#'), (int(H * 0.12), '=')]:
                for x in range(bx, bx + 3):
                    m.put(x, y, kind); m.put(x, y, 'a' if kind == '#' else 'w', m.bio)
        m.road(int(H * 0.42), H - 14, int(H * 0.42), H - 5, 3)
        for y in range(H - 14, H):
            for x in range(int(H * 0.42), int(H * 0.42) + 3):
                if m.g[y][x] == ':':
                    m.put(x, y, 'a', m.bio)
    # towns: paved square, houses (garrisonable neutrals) round it, street lights, cars
    civ = []
    for (cx, cy, r) in towns:
        for y in range(cy - r, cy + r):
            for x in range(cx - r, cx + r):
                if 0 < x < H and 0 < y < H and m.g[y][x] in '.,T':
                    m.put(x, y, '.'); m.put(x, y, 'p', m.bio)
        for (dx, dy) in [(-r, -r), (r - 3, -r), (-r, r - 3), (r - 3, r - 3)]:
            civ.append((cx + dx, cy + dy))
        for k in range(0, 2 * r, 5):
            m.deco("streetlight", cx - r + k, cy - r, 0)
        m.deco("gas_station" if env != "arid" else "shack", cx - 2, cy - 2, 0)
    # bases: clear ground, gravel yards
    for (sx, sy) in spawn_q:
        for y in range(sy - 9, sy + 14):
            for x in range(sx - 9, sx + 14):
                if 0 < x < H and 0 < y < H and m.g[y][x] in 'T^,~=':
                    m.put(x, y, '.'); m.put(x, y, 'd' if env == "arid" else 'G', m.bio)
                if 0 < x < H and 0 < y < H and sx - 3 <= x < sx + 8 and sy - 3 <= y < sy + 8 and m.g[y][x] == '.':
                    m.put(x, y, 'v', m.bio)
    # economy: each base gets a seam and a cache; mid-map seams; derricks; houses
    sp = []
    for (sx, sy) in spawn_q:
        on_axis = sx + 2 >= H - 3 or sy + 2 >= H - 3
        s1 = m.spot(min(H - 4, sx + 11), sy + 3, 1, 1)
        s2 = m.spot(sx + 3, min(H - 4, sy + 11), 1, 1)
        amt = 42500 if on_axis else 85000   # an edge-middle base gets a mirrored pair, so half each
        for (a, b) in mirror_pts(N, *s1):
            m.res.append(("seam", a, b, amt))
        for (a, b) in mirror_pts(N, *s2):
            m.res.append(("cache", a, b, 10000 if on_axis else 20000))
    for (x, y) in mid_seams:
        X, Y = m.spot(x, y, 1, 1)
        for (a, b) in mirror_pts(N, X, Y):
            m.res.append(("seam", a, b, 60000))
    for (x, y) in pumps:
        X, Y = m.spot(x, y, 2, 2)
        for (a, b) in mirror_pts(N, X, Y, 2, 2):
            m.neu.append(("neutral_pump", a, b))
    for (x, y) in civ:
        X, Y = m.spot(x, y, 3, 3)
        for yy in range(Y, Y + 3):
            for xx in range(X, X + 3):
                m.put(xx, yy, 'c', m.bio)
        for (a, b) in mirror_pts(N, X, Y, 3, 3):
            m.neu.append(("neutral_civ_block", a, b))
    # trees in the woods, rocks on mesas, scattered trees / bushes
    for y in range(1, H):
        for x in range(1, H):
            if (x, y) in m.taken:
                continue
            if m.g[y][x] == 'T' and hsh(x, y, seed + 7) > 0.45:
                m.deco(tree, x, y)
            elif m.g[y][x] == '^' and hsh(x, y, seed + 8) > 0.86:
                m.deco("rock", x, y)
            elif m.g[y][x] == '.' and m.bio[y][x] in 'gGls' and hsh(x, y, seed + 9) > 0.994:
                m.deco(tree if hsh(x, y, 3) > 0.4 else "bush", x, y)
    # hills (item 17): mirrored, kept off water, bases and the map edge
    hills = []
    for (cx, cy, r, hm) in hills_q:
        r, hm = max(6, int(r * 0.85)), min(3200, int(hm * 1.3))
        for (a, b) in mirror_pts(N, cx, cy, 0, 0):   # hills sit on tile corners
            hills.append([a, b, r, hm])
    spawns = []
    for (sx, sy) in spawn_q:
        ps = mirror_pts(N, sx, sy, 4, 4)
        if len(ps) == 4:   # corner bases: NW, SE, NE, SW (slots 1 and 2 face each other)
            ps = [ps[0], ps[3], ps[1], ps[2]]
        spawns += ps
    if two_player:
        spawns = spawns[:2]
    m.write(spawns, key + "_DESC")
    base = os.path.join(gm.ROOT, "data/maps", mid + ".tres")
    t = open(base).read().replace("size = Vector2i(128, 128)", "size = Vector2i(%d, %d)" % (N, N))
    t += "hills = [%s]\n" % ", ".join("[%d, %d, %d, %d]" % tuple(h) for h in hills)
    open(base, "w").write(t)
    return spawns

gen("twin_ridges", "MAP_TWIN_RIDGES", 128, "temperate", [(14, 14)], 11,
    hills_q=[(40, 22, 12, 1600), (22, 44, 11, 1400), (52, 52, 14, 2200), (58, 30, 9, 1200)],
    towns=[(46, 46, 5)], fields=[(30, 6, 14, 8), (6, 34, 8, 14)], woods=[(56, 12, 5), (12, 58, 5), (34, 36, 3)],
    mesas=[(62, 8, 2)], pumps=[(28, 52)], mid_seams=[(50, 34)], two_player=True)
gen("harvest_valley", "MAP_HARVEST_VALLEY", 192, "temperate", [(22, 22)], 13, river=True,
    hills_q=[(58, 30, 15, 2200), (30, 62, 13, 1800), (72, 64, 14, 2400), (90, 30, 10, 1500)],
    towns=[(60, 80, 6)], fields=[(40, 8, 18, 10), (8, 42, 10, 18), (44, 44, 14, 10), (80, 74, 10, 8)],
    woods=[(82, 12, 6), (12, 84, 6), (70, 46, 4)], mesas=[(92, 52, 3)], pumps=[(46, 70), (84, 46)], mid_seams=[(72, 80), (52, 52)])
gen("sunfall_basin", "MAP_SUNFALL_BASIN", 224, "arid", [(36, 36), (110, 12)], 17,
    hills_q=[(70, 40, 14, 2000), (40, 72, 14, 2000), (86, 86, 16, 2600), (106, 62, 12, 1600), (62, 104, 12, 1800)],
    lakes=[(104, 104, 5)], towns=[(92, 106, 6)], fields=[(14, 70, 10, 12), (70, 14, 12, 10)],
    woods=[(60, 60, 4), (100, 40, 3)], mesas=[(80, 26, 4), (26, 92, 4), (54, 86, 3), (76, 62, 3)], pumps=[(62, 46), (48, 100)],
    mid_seams=[(80, 96), (96, 80)], tree="palm")
gen("highland_crown", "MAP_HIGHLAND_CROWN", 256, "temperate", [(48, 48), (126, 18), (18, 126)], 19,
    hills_q=[(96, 96, 18, 3000), (80, 112, 13, 2200), (112, 80, 13, 2200), (64, 82, 10, 1500), (82, 64, 10, 1500),
             (40, 96, 12, 1800), (96, 40, 12, 1800)],
    lakes=[(78, 78, 6), (30, 30, 4)], towns=[(116, 116, 7)], fields=[(80, 14, 16, 10), (14, 80, 10, 16), (60, 30, 12, 8), (30, 60, 8, 12)],
    woods=[(60, 14, 5), (14, 60, 5), (100, 60, 5), (60, 100, 5)], mesas=[(108, 46, 3), (46, 108, 3)],
    pumps=[(66, 66), (106, 98)], mid_seams=[(96, 120), (120, 96), (70, 50)])
