#!/usr/bin/env python3
"""M3.2 polish: (1) city blocks read as lawns / yards with sidewalks instead of paving (biome only:
tiles next to a street or building = sidewalk 'c', block interiors = grass 'G'/'g' in soft patches);
(2) small roadside hamlets of European houses on rural maps (3x3 footprints, open ground with a
free ring around them, far from spawns / resources / neutrals; tiles become Cliff = blocking like
the city houses, the terrain view keeps the ground flat under them). Idempotent per step.
Run: python3 city14.py <repo_root> lawns <map> [dry]   |   python3 city14.py <repo_root> hamlets <map> <n>"""
import sys, re, math, collections
root, mode, mid = sys.argv[1], sys.argv[2], sys.argv[3]
M = root + "/data/maps/" + mid
g = [list(l.rstrip("\n")) for l in open(M + ".txt")]
bio = [list(l.rstrip("\n")) for l in open(M + ".biome.txt")]
H, W = len(g), len(g[0])
def vn(x, y):   # smooth value noise for soft lawn patches
    def h(i, j): return (math.sin(i * 127.1 + j * 311.7) * 43758.5453) % 1.0
    ix, iy = math.floor(x), math.floor(y); fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = h(ix, iy) + (h(ix + 1, iy) - h(ix, iy)) * fx
    b = h(ix, iy + 1) + (h(ix + 1, iy + 1) - h(ix, iy + 1)) * fx
    return a + (b - a) * fy
if mode == "lawns":
    dry = len(sys.argv) > 4 and sys.argv[4] == "dry"
    seen = [[False] * W for _ in range(H)]; n = 0
    for y in range(H):
        for x in range(W):
            if seen[y][x] or g[y][x] != "." :
                continue
            q = collections.deque([(x, y)]); seen[y][x] = True; cells = []; edge = False
            while q:
                cx, cy = q.popleft(); cells.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if not (0 <= nx < W and 0 <= ny < H):
                        edge = True; continue
                    if not seen[ny][nx] and g[ny][nx] == ".":
                        seen[ny][nx] = True; q.append((nx, ny))
            if edge or len(cells) > 260:
                continue   # open country, not a city block
            xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
            if max(xs) - min(xs) > 22 or max(ys) - min(ys) > 22:
                continue
            # must be mostly enclosed by streets / buildings
            ring = set()
            for (cx, cy) in cells:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < W and 0 <= ny < H and g[ny][nx] != ".":
                            ring.add((nx, ny))
            if sum(1 for (rx, ry) in ring if g[ry][rx] in ":^") < len(ring) * 0.7:
                continue
            n += 1
            for (cx, cy) in cells:
                walk = any(0 <= cx + dx < W and 0 <= cy + dy < H and g[cy + dy][cx + dx] in ":^="
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                if walk:
                    bio[cy][cx] = "c"
                else:
                    v = vn(cx * 0.23, cy * 0.23)
                    bio[cy][cx] = ("g" if v > 0.35 else "d") if dry else ("G" if v > 0.42 else "g")
    print("lawn blocks", n)
elif mode == "hamlets":
    want = int(sys.argv[4])
    dec = open(M + ".decor.txt").read().splitlines()
    if any(l.startswith("house_") for l in dec):
        print("already has houses"); sys.exit(0)
    tres = open(M + ".tres").read()
    pts = [tuple(map(int, p)) for p in re.findall(r"Vector2i\((\d+), (\d+)\)", tres.split("size =")[1])][1:]
    spawns = [tuple(map(int, p)) for p in re.findall(r"Vector2i\((\d+), (\d+)\)", tres.split("spawns =")[1].split("\n")[0])]
    avoid = [p for p in pts]   # spawns, resources, neutrals
    def free(x, y):
        return 0 <= x < W and 0 <= y < H and g[y][x] == "."
    def ok(x0, y0):
        for yy in range(y0 - 2, y0 + 5):
            for xx in range(x0 - 2, x0 + 5):
                inner = x0 <= xx < x0 + 3 and y0 <= yy < y0 + 3
                if inner and not free(xx, yy):
                    return False
                if not inner and not (0 <= xx < W and 0 <= yy < H and g[yy][xx] in ".,:"):
                    return False   # keep a walkable ring (no cliffs / water / trees touching)
        for yy in range(y0 - 3, y0 + 6):
            for xx in range(x0 - 3, x0 + 6):
                if 0 <= xx < W and 0 <= yy < H and g[yy][xx] in "^~":
                    return False   # stay off slopes and banks
        cx, cy = x0 + 1, y0 + 1
        if any((cx - sx) ** 2 + (cy - sy) ** 2 < 30 ** 2 for (sx, sy) in spawns):
            return False
        if any((cx - ax) ** 2 + (cy - ay) ** 2 < 9 ** 2 for (ax, ay) in avoid):
            return False
        return True
    roads = [(x, y) for y in range(H) for x in range(W) if g[y][x] == ":"]
    roads.sort(key=lambda p: (math.sin(p[0] * 12.9898 + p[1] * 78.233) * 43758.5453) % 1.0)
    placed = []; centers = []; out = []; kinds = ["house_a", "house_b", "house_c", "house_d"]
    for (rx, ry) in roads:
        if len(placed) >= want:
            break
        near_c = [c for c in centers if (c[0] - rx) ** 2 + (c[1] - ry) ** 2 < 12 ** 2]
        if not near_c and (len(centers) >= max(1, want // 3) or any((c[0] - rx) ** 2 + (c[1] - ry) ** 2 < 45 ** 2 for c in centers)):
            continue
        for (dx, dy, rot) in ((0, -1, 0), (0, 1, 2), (-1, 0, 1), (1, 0, 3)):
            # house sits 1 tile off the road on side (dx, dy) and faces it
            if dx == 0:
                x0, y0 = rx - 1, (ry - 4 if dy < 0 else ry + 2)
            else:
                x0, y0 = (rx - 4 if dx < 0 else rx + 2), ry - 1
            if not ok(x0, y0):
                continue
            if any(abs(px - x0) < 5 and abs(py - y0) < 5 for (px, py) in placed):
                continue
            placed.append((x0, y0))
            if not near_c:
                centers.append((rx, ry))
            for yy in range(y0, y0 + 3):
                for xx in range(x0, x0 + 3):
                    g[yy][xx] = "^"; bio[yy][xx] = "c"
            out.append("%s %.2f %.2f %d" % (kinds[len(placed) % 4], x0 + 1.5, y0 + 1.5, rot))
            break
    occ = set((px + i, py + j) for (px, py) in placed for i in range(3) for j in range(3))
    keep = [l for l in dec if len(l.split()) < 3 or (int(float(l.split()[1])), int(float(l.split()[2]))) not in occ]
    open(M + ".decor.txt", "w").write("\n".join(keep + out) + "\n")
    print("hamlets", len(centers), "houses", len(placed), "decor removed", len(dec) - len(keep))
open(M + ".txt", "w").write("\n".join("".join(r) for r in g) + "\n")
open(M + ".biome.txt", "w").write("\n".join("".join(r) for r in bio) + "\n")
