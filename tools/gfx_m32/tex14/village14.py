#!/usr/bin/env python3
"""M3.2 item 14 (d): European village houses in Harrow Junction's empty street-grid blocks.
Each grass block between the city streets gets houses on its corners facing the streets (and one
block a container stack yard); house tiles become Cliff (blocking, like the city towers) and the
biome under them pavement. Idempotent (skips if houses are already in the decor).
Run: python3 village14.py <repo_root>"""
import sys, collections
root = sys.argv[1]
M = root + "/data/maps/harrow_junction"
g = [list(l.rstrip("\n")) for l in open(M + ".txt")]
bio = [list(l.rstrip("\n")) for l in open(M + ".biome.txt")]
dec = open(M + ".decor.txt").read().splitlines()
if any(l.startswith("house_") for l in dec):
    print("already stamped"); sys.exit(0)
H, W = len(g), len(g[0])
seen = [[False] * W for _ in range(H)]
kinds = ["house_a", "house_b", "house_c", "house_d"]
occupied = set()   # small decor (trees, lamps) under a new house is removed instead
out = []
nb = 0
for y in range(H):
    for x in range(W):
        if seen[y][x] or g[y][x] != ".":
            continue
        q = collections.deque([(x, y)]); seen[y][x] = True; cells = []
        while q:
            cx, cy = q.popleft(); cells.append((cx, cy))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and g[ny][nx] == ".":
                    seen[ny][nx] = True; q.append((nx, ny))
        xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        # a city block: compact, fully enclosed by road tiles, 7..12 tiles a side
        if not (7 <= bw <= 12 and 7 <= bh <= 12 and len(cells) >= bw * bh * 0.9):
            continue
        ring = [(xx, y0 - 1) for xx in range(x0, x1 + 1)] + [(xx, y1 + 1) for xx in range(x0, x1 + 1)]
        if sum(1 for (xx, yy) in ring if 0 <= yy < H and g[yy][xx] == ":") < len(ring) * 0.8:
            continue
        nb += 1
        spots = [(x0, y0, 2), (x1 - 2, y0, 2), (x0, y1 - 2, 0), (x1 - 2, y1 - 2, 0)]
        if nb % 7 == 3:   # container yard
            spots = [(x0, y0, 0), (x0, y0 + 3, 0), (x0 + 4, y0, 0)]
        for k, (sx, sy, rot) in enumerate(spots):
            kind = "containers" if nb % 7 == 3 else kinds[(nb * 3 + k) % 4]
            fw, fh = (3, 2) if kind == "containers" else (3, 3)
            tiles = [(sx + i, sy + j) for i in range(fw) for j in range(fh)]
            if any(g[ty][tx] != "." or (tx, ty) in occupied for (tx, ty) in tiles):
                continue
            for (tx, ty) in tiles:
                g[ty][tx] = "^"; bio[ty][tx] = "c"; occupied.add((tx, ty))
            out.append("%s %.2f %.2f %d" % (kind, sx + fw / 2, sy + fh / 2, rot))
open(M + ".txt", "w").write("\n".join("".join(r) for r in g) + "\n")
open(M + ".biome.txt", "w").write("\n".join("".join(r) for r in bio) + "\n")
keep = [l for l in dec if len(l.split()) < 3 or (int(float(l.split()[1])), int(float(l.split()[2]))) not in occupied]
open(M + ".decor.txt", "w").write("\n".join(keep + out) + "\n")
print("removed decor under houses:", len(dec) - len(keep))
print("blocks", nb, "props", len(out))
