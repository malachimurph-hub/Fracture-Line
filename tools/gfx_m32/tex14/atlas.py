#!/usr/bin/env python3
"""M3.2 item 14: pack the per-scene bake cells into one Texture2DArray atlas (512 px layers:
a building cell fills a layer, four 256 px unit cells share one) + placement JSON for apply.gd.
Run: python3 atlas.py <bake_dir> <atlas_png> <placement_json>"""
import json, os, sys
import numpy as np
from PIL import Image

bake, out_png, out_json = sys.argv[1:4]
L = 512
cells = []
for f in sorted(os.listdir(bake)):
    if f.endswith(".json"):
        j = json.load(open(os.path.join(bake, f)))
        cells.append((f[:-5], j))
big = [c for c in cells if c[1]["size"] == 512]
small = [c for c in cells if c[1]["size"] == 256]
layers = []
place = {}
def put(nm, j, layer, ox, oy):
    im = np.asarray(Image.open(os.path.join(bake, nm + ".png")).convert("RGB"))
    S = j["size"]
    layers[layer][oy:oy + S, ox:ox + S] = im
    m = {}
    for path, v in j["meshes"].items():
        r = v[6:10]
        m[path] = v[0:6] + [(ox + r[0] * S) / L, (oy + r[1] * S) / L, r[2] * S / L, r[3] * S / L]
    place[j["scene"]] = {"layer": layer, "meshes": m}
def new_layer():
    a = np.zeros((L, L, 3), np.uint8); a[..., 0] = 255; a[..., 1] = 128
    layers.append(a)
    return len(layers) - 1
for nm, j in big:
    put(nm, j, new_layer(), 0, 0)
for i, (nm, j) in enumerate(small):
    if i % 4 == 0:
        cur = new_layer()
    k = i % 4
    put(nm, j, cur, (k % 2) * 256, (k // 2) * 256)
Image.fromarray(np.concatenate(layers, 0)).save(out_png, optimize=True)
json.dump({"layers": len(layers), "scenes": place}, open(out_json, "w"))
print("ATLAS %d layers (%d buildings, %d units)" % (len(layers), len(big), len(small)))
