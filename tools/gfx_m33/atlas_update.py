#!/usr/bin/env python3
"""M3.3: update the M3.2 bake atlas for a few re-baked or new scenes without moving any other
scene's cell (tools/gfx_m32/tex14/atlas.py repacks everything, which would touch every view).
A re-baked scene keeps its old slot when the cell size is unchanged; new scenes (or a size
change) get slots in new layers at the end. Writes the atlas, the full placement and a
placement with only the updated scenes (for apply.gd).
Run: python3 atlas_update.py <atlas_png> <placement_json> <old_bake_dir> <new_bake_dir> <out_partial_json> names...
"""
import json, os, sys
import numpy as np
from PIL import Image

atlas_png, place_json, old_dir, new_dir, out_part = sys.argv[1:6]
names = sys.argv[6:]
L = 512
pl = json.load(open(place_json))
atlas = np.asarray(Image.open(atlas_png).convert("RGB")).copy()
nl = atlas.shape[0] // L
assert nl == pl["layers"], (nl, pl["layers"])
layers = [atlas[i * L:(i + 1) * L] for i in range(nl)]

def new_layer():
    a = np.zeros((L, L, 3), np.uint8); a[..., 0] = 255; a[..., 1] = 128
    layers.append(a)
    return len(layers) - 1

def origin(scene, old_j):
    """cell origin (layer, ox, oy) of an existing scene from its placement + old cell json"""
    e = pl["scenes"].get(scene)
    if e is None or old_j is None:
        return None
    S = old_j["size"]
    for path, v in old_j["meshes"].items():
        if path in e["meshes"]:
            pv = e["meshes"][path]
            ox = round(pv[6] * L - v[6] * S); oy = round(pv[7] * L - v[7] * S)
            return e["layer"], ox, oy, S
    return None

small_free = []   # free 256 slots in appended layers
part = {}
for nm in names:
    j = json.load(open(os.path.join(new_dir, nm + ".json")))
    im = np.asarray(Image.open(os.path.join(new_dir, nm + ".png")).convert("RGB"))
    S = j["size"]
    oj_path = os.path.join(old_dir, nm + ".json")
    old_j = json.load(open(oj_path)) if os.path.exists(oj_path) else None
    o = origin(j["scene"], old_j)
    if o is not None and o[3] == S:
        layer, ox, oy, _ = o
        how = "kept slot"
    elif S == L:
        layer, ox, oy = new_layer(), 0, 0
        how = "new layer"
    else:
        if not small_free:
            ly = new_layer()
            small_free = [(ly, (k % 2) * 256, (k // 2) * 256) for k in range(4)]
        layer, ox, oy = small_free.pop(0)
        how = "new small slot"
    layers[layer][oy:oy + S, ox:ox + S] = im
    m = {}
    for path, v in j["meshes"].items():
        r = v[6:10]
        m[path] = v[0:6] + [(ox + r[0] * S) / L, (oy + r[1] * S) / L, r[2] * S / L, r[3] * S / L]
    pl["scenes"][j["scene"]] = {"layer": layer, "meshes": m}
    part[j["scene"]] = pl["scenes"][j["scene"]]
    print("ATLAS %s: %s (layer %d at %d,%d)" % (nm, how, layer, ox, oy))
pl["layers"] = len(layers)
Image.fromarray(np.concatenate(layers, 0)).save(atlas_png, optimize=True)
json.dump(pl, open(place_json, "w"))
json.dump({"layers": len(layers), "scenes": part}, open(out_part, "w"))
print("ATLAS now %d layers" % len(layers))
