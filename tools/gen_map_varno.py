#!/usr/bin/env python3
"""Generates data/maps/varno_crossing.txt and .tres. Mirror-symmetric on both axes so all 4
start corners are equivalent (fair for 1v1 on diagonal/adjacent corners, 2v2 and FFA)."""
import math, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 128
g = [['.'] * N for _ in range(N)]
def sym_set(x, y, c):
    for (a, b) in ((x, y), (N-1-x, y), (x, N-1-y), (N-1-x, N-1-y)):
        if 0 <= a < N and 0 <= b < N:
            g[b][a] = c
def h(x, y):  # deterministic hash noise
    v = (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
    return (v & 0xffff) / 65535.0
# river: centered on x=63.5, width varies with y (symmetric in y)
for y in range(N):
    yy = min(y, N-1-y)
    half = 3.2 + 1.3 * math.sin(yy * 0.19) + (1.5 if 56 <= y <= 71 else 0)
    for x in range(N):
        if abs(x - 63.5) < half:
            g[y][x] = '~'
# fords (infantry only) and bridges (all)
for y0, kind in ((18, '#'), (19, '#'), (20, '#'), (42, '='), (43, '='), (61, '#'), (62, '#'), (63, '#'), (64, '#'), (65, '#'), (66, '#'), (85, '='), (84, '='), (107, '#'), (108, '#'), (109, '#')):
    for x in range(N):
        if g[y0][x] == '~':
            g[y0][x] = kind
# central island for the Veridite Pump
for y in range(58, 70):
    for x in range(58, 70):
        if (x - 63.5) ** 2 + (y - 63.5) ** 2 < 22:
            g[y][x] = ','
# roads from each base towards bridges (draw in one quadrant, mirror)
def road(x0, y0, x1, y1):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        x = round(x0 + (x1 - x0) * i / steps); y = round(y0 + (y1 - y0) * i / steps)
        for dx in (0, 1):
            if g[y][x+dx] in '.,':
                sym_set(x + dx, y, ':')
road(20, 20, 56, 19); road(20, 20, 20, 56); road(20, 56, 56, 63); road(34, 42, 57, 42)
# forests and rock outcrops (quadrant, mirrored)
clusters = [(40, 30, 3.5, 'T'), (10, 40, 3, 'T'), (44, 52, 2.5, '^'), (30, 8, 2.5, 'T'), (8, 58, 3, '^'), (48, 8, 2.5, '^'), (36, 56, 3, 'T')]
for cx, cy, r, c in clusters:
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if 0 <= x < 64 and 0 <= y < 64 and (x-cx)**2 + (y-cy)**2 < r*r + h(x, y) * 3 and g[y][x] == '.':
                sym_set(x, y, c)
# rough patches
for y in range(64):
    for x in range(64):
        if g[y][x] == '.' and h(x // 4, y // 4) > 0.86:
            sym_set(x, y, ',')
# map edges: cliffs border
for i in range(N):
    for c in ((i, 0), (i, N-1), (0, i), (N-1, i)):
        g[c[1]][c[0]] = '^'
# clear the base areas
for y in range(8, 32):
    for x in range(8, 32):
        if g[y][x] in 'T^,':
            sym_set(x, y, '.')
for (cx, cy) in ((30, 62), (46, 26), (24, 46)):
    for y in range(cy - 2, cy + 5):
        for x in range(cx - 2, cx + 5):
            if g[y][x] in 'T^~=':
                if not (58 <= x <= 69):
                    sym_set(x, y, '.')
with open(os.path.join(ROOT, "data/maps/varno_crossing.txt"), "w") as f:
    f.write("\n".join("".join(r) for r in g) + "\n")
# spawns (HQ top-left tile, HQ is 4x4): NW, SE, NE, SW (slot order: 1v1 uses diagonal NW vs SE)
sp = [(14, 14), (N - 18, N - 18), (N - 18, 14), (14, N - 18)]
res = []
def quad(x, y):
    return [(x, y), (N-1-x, N-1-y), (N-1-x, y), (x, N-1-y)]
for (x, y) in quad(8, 26): res.append(('seam', x, y, 15000))      # home seam
for (x, y) in quad(27, 9): res.append(('cache', x, y, 3000))      # home cache
for (x, y) in quad(38, 44): res.append(('seam', x, y, 20000))     # contested seam (riverside)
neu = [("neutral_pump", 63, 63), ("neutral_pump", 30, 62), ("neutral_pump", N - 30 - 2, 62)]
for (x, y) in ((46, 26), (24, 46)):
    for (a, b2) in ((x, y), (N-x-3, y), (x, N-y-3), (N-x-3, N-y-3)):
        neu.append(("neutral_civ_block", a, b2))
lines = ['[gd_resource type="Resource" script_class="MapDef" load_steps=2 format=3]', '',
         '[ext_resource type="Script" path="res://data/defs/map_def.gd" id="1_s"]', '', '[resource]', 'script = ExtResource("1_s")',
         'id = &"varno_crossing"', 'name_key = "MAP_VARNO"', 'description_key = "MAP_VARNO_DESC"', 'size = Vector2i(128, 128)',
         'tiles_path = "res://data/maps/varno_crossing.txt"',
         'spawns = Array[Vector2i]([%s])' % ", ".join("Vector2i(%d, %d)" % s for s in sp),
         'resources = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d), "amount": %d}' % r for r in res),
         'neutrals = Array[Dictionary]([%s])' % ", ".join('{"kind": "%s", "tile": Vector2i(%d, %d)}' % n for n in neu)]
with open(os.path.join(ROOT, "data/maps/varno_crossing.tres"), "w") as f:
    f.write("\n".join(lines) + "\n")
print("map ok")
