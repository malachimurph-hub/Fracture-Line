#!/usr/bin/env python3
"""M2.8: double the four built-in skirmish maps (128x128 -> 256x256), keeping each layout.

Source = the M2.7 128x128 maps (git 14da8e7), so this is re-runnable.
  - tile + biome grids: Scale2x / EPX upscale (rounds diagonal edges instead of 2x2 stair steps)
  - spawns / neutrals / mid-map resources: positions x2 (mirror-exact, footprint aware)
  - the home supply stashes keep their distance to the HQ (harvest trips don't double)
  - extra content for the 4x area: one more supply cache per quadrant between base and centre,
    decor density restored (3 jittered extra copies of every natural prop), sparse rock/bush clutter
Run: python3 tools/upscale_maps_m28.py   (then tools/run_m28_suite.sh ... content stash)
"""
import os, re, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "14da8e7"
O, N = 128, 256
MAPS = ["varno_crossing", "kessel_pass", "harrow_junction", "ochre_wells"]
NATURAL = {"bush", "oak", "palm", "pine", "pine_snow", "rock", "rock_small", "scrub_tree", "hay_bale"}
# home stash amount per map (tuned in M2.8 #2 so the AI opening drains them in ~17 min); None = keep
HOME_SEAM = 30000
HOME_CACHE = 6000

def git(path):
    return subprocess.check_output(["git", "-C", ROOT, "show", "%s:%s" % (SRC, path)], text=True)

def hsh(x, y, s=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (0x5bd1e995 + s * 2654435761)
    v &= 0xffffffff; v ^= v >> 13; v = (v * 0x5bd1e995) & 0xffffffff
    return (v & 0xffff) / 65535.0

def epx(g):
    h, w = len(g), len(g[0])
    out = [[None] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            P = g[y][x]
            A = g[y - 1][x] if y > 0 else P
            D = g[y + 1][x] if y < h - 1 else P
            C = g[y][x - 1] if x > 0 else P
            B = g[y][x + 1] if x < w - 1 else P
            p1 = A if (C == A and C != D and A != B) else P
            p2 = B if (A == B and A != C and B != D) else P
            p3 = C if (D == C and D != B and C != A) else P
            p4 = D if (B == D and B != A and D != C) else P
            out[2 * y][2 * x], out[2 * y][2 * x + 1], out[2 * y + 1][2 * x], out[2 * y + 1][2 * x + 1] = p1, p2, p3, p4
    return out

def sc_obj(c, w):
    # centre scales: 2*(c + w/2) -> top-left 2c + w/2 ; integral & mirror-exact for even w, for odd w round away from the centre line
    t2 = 2 * c + w / 2
    if t2 == int(t2):
        return int(t2)
    return int(t2 - 0.5) if c + w / 2 < O / 2 else int(t2 + 0.5)

def parse_tres(s):
    spawns = [tuple(map(int, m)) for m in re.findall(r"Vector2i\((\d+), (\d+)\)", re.search(r"spawns = (.*)", s).group(1))]
    res = [(k, int(x), int(y), int(a)) for k, x, y, a in re.findall(r'"kind": "(\w+)", "tile": Vector2i\((\d+), (\d+)\), "amount": (\d+)', s)]
    neu = [(k, int(x), int(y)) for k, x, y in re.findall(r'"kind": "(\w+)", "tile": Vector2i\((\d+), (\d+)\)\}', re.search(r"neutrals = (.*)", s).group(1))]
    return spawns, res, neu

def mirror4(x, y, w=1):
    return [(x, y), (N - x - w, y), (x, N - y - w), (N - x - w, N - y - w)]

def run(mid):
    tres = git("data/maps/%s.tres" % mid)
    g = [list(r) for r in git("data/maps/%s.txt" % mid).splitlines() if r]
    bio = [list(r) for r in git("data/maps/%s.biome.txt" % mid).splitlines() if r]
    decor = [l.split() for l in git("data/maps/%s.decor.txt" % mid).splitlines() if l.strip()]
    spawns, res, neu = parse_tres(tres)
    G, B = epx(g), epx(bio)
    for i in range(N):            # map border stays a 1-tile cliff ring; the 2nd ring opens up
        for (x, y) in ((i, 1), (i, N - 2), (1, i), (N - 2, i)):
            if G[y][x] == '^' and g[min(O - 1, y // 2 + (1 if y < N // 2 else -1))][min(O - 1, x // 2 + (1 if x < N // 2 else -1))] != '^':
                G[y][x] = '.'
    for i in range(N):
        for (x, y) in ((i, 0), (i, N - 1), (0, i), (N - 1, i)):
            G[y][x] = '^'
    nsp = [(sc_obj(x, 4), sc_obj(y, 4)) for (x, y) in spawns]
    out_res = []
    for (k, x, y, a) in res:
        # home stash: within 20 tiles of a spawn -> keep its offset to that spawn
        home = None
        for si, (sx, sy) in enumerate(spawns):
            if abs(x - sx) <= 20 and abs(y - sy) <= 20:
                home = si
        if home is not None:
            sx, sy = spawns[home]
            nx, ny = nsp[home][0] + (x - sx), nsp[home][1] + (y - sy)
            a = HOME_SEAM if k == "seam" else HOME_CACHE
        else:
            nx, ny = sc_obj(x, 1), sc_obj(y, 1)
        out_res.append((k, nx, ny, a))
    out_neu = [(k, sc_obj(x, 3 if k == "neutral_civ_block" else 2), sc_obj(y, 3 if k == "neutral_civ_block" else 2)) for (k, x, y) in neu]
    # one extra 8000 cache per quadrant halfway between the home base and the map centre
    def free(x, y):
        return all(0 <= x + dx < N and 0 <= y + dy < N and G[y + dy][x + dx] in '.,' for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)) \
            and all(abs(x - rx) > 6 or abs(y - ry) > 6 for (_, rx, ry, _) in out_res) \
            and all(abs(x - nx2 - 1) > 5 or abs(y - ny2 - 1) > 5 for (_, nx2, ny2) in out_neu)
    sx, sy = nsp[0]
    tx, ty = (sx + N // 2) // 2 + 6, (sy + N // 2) // 2 - 10
    found = None
    for r in range(0, 30):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if found is None and max(abs(dx), abs(dy)) == r and free(tx + dx, ty + dy) and tx + dx < N // 2 - 4 and ty + dy < N // 2 - 4:
                    found = (tx + dx, ty + dy)
    if found:
        for (x, y) in mirror4(*found):
            out_res.append(("cache", x, y, 8000))
    # decor: positions x2; natural props get 3 jittered siblings on the same ground type
    out_dec = []
    for d in decor:
        k, x, y, r = d[0], float(d[1]), float(d[2]), int(d[3])
        X, Y = x * 2, y * 2
        out_dec.append((k, X, Y, r))
        if k in NATURAL:
            ch = g[min(O - 1, int(y))][min(O - 1, int(x))]
            for j in range(3):
                jx = X + (hsh(int(X * 10), int(Y * 10), 20 + j) - 0.5) * 3.2
                jy = Y + (hsh(int(Y * 10), int(X * 10), 30 + j) - 0.5) * 3.2
                ix, iy = int(jx), int(jy)
                if 1 <= ix < N - 1 and 1 <= iy < N - 1 and G[iy][ix] == ch:
                    out_dec.append((k, jx, jy, int(hsh(ix, iy, 9) * 4)))
    # sparse clutter on open ground (mirror-symmetric) so the bigger fields aren't bare
    em = re.search(r'env = &"(\w+)"', tres)
    env = em.group(1) if em else "desert"
    clutter = {"desert": ["rock_small", "scrub_tree"], "arid": ["rock_small", "scrub_tree"], "winter": ["rock_small", "pine_snow"], "temperate": ["bush", "rock_small"]}.get(env, ["rock_small"])
    taken = set()
    for (k, x, y, a) in out_res:
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                taken.add((x + dx, y + dy))
    for y in range(2, N // 2):
        for x in range(2, N // 2):
            if G[y][x] == '.' and hsh(x, y, 77) < 0.006 and (x, y) not in taken and not (abs(x - nsp[0][0] - 2) < 22 and abs(y - nsp[0][1] - 2) < 22):
                k = clutter[int(hsh(x, y, 78) * len(clutter)) % len(clutter)]
                for (a, b) in mirror4(x, y):
                    out_dec.append((k, a + 0.5, b + 0.5, int(hsh(a, b, 9) * 4)))
    base = os.path.join(ROOT, "data/maps", mid)
    open(base + ".txt", "w").write("\n".join("".join(r) for r in G) + "\n")
    open(base + ".biome.txt", "w").write("\n".join("".join(r) for r in B) + "\n")
    open(base + ".decor.txt", "w").write("".join("%s %.2f %.2f %d\n" % d for d in out_dec))
    s = tres.replace("size = Vector2i(128, 128)", "size = Vector2i(256, 256)")
    s = re.sub(r"spawns = .*", "spawns = Array[Vector2i]([%s])" % ", ".join("Vector2i(%d, %d)" % p for p in nsp), s)
    s = re.sub(r"resources = .*", "resources = Array[Dictionary]([%s])" % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d), "amount": %d}' % r for r in out_res), s)
    s = re.sub(r"neutrals = .*", "neutrals = Array[Dictionary]([%s])" % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d)}' % n for n in out_neu), s)
    open(base + ".tres", "w").write(s)
    # sanity: everything sits on open ground
    for (k, x, y, a) in out_res:
        assert G[y][x] in '.,:', (mid, k, x, y, G[y][x])
    print("%s: 256x256, spawns %s, %d resources, %d neutrals, %d decor (was %d)" % (mid, nsp, len(out_res), len(out_neu), len(out_dec), len(decor)))

if __name__ == "__main__":
    for m in MAPS:
        run(m)
