# Pantsir-S1 on an 8x8 chassis. No badges, no lettering.
# Radar and outriggers are separate nodes so the view can deploy them.
#   blender --background --python tools/m47/pantsir_blender.py
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy_kit as K

def build():
    root = K.begin()
    h = K.fresh()
    # chassis spine
    bed = K.box(h, (0, 0.48, -0.15), (0.78, 0.16, 2.7), K.OLIVE_D)
    K.bevel(h, bed, 0.01)
    # forward cab
    cab = K.box(h, (0, 0.78, 1.05), (0.78, 0.48, 0.85), K.OLIVE)
    K.bevel(h, cab, 0.015)
    K.box(h, (0, 0.82, 1.46), (0.62, 0.22, 0.02), K.GLS)
    K.box(h, (-0.40, 0.78, 1.10), (0.012, 0.16, 0.28), K.GLS)
    K.box(h, (0.40, 0.78, 1.10), (0.012, 0.16, 0.28), K.GLS)
    # equipment module ahead of the turret
    mod = K.box(h, (0, 0.78, 0.22), (0.72, 0.36, 0.55), K.OLIVE)
    K.bevel(h, mod, 0.01)
    K.box(h, (0.37, 0.78, 0.22), (0.012, 0.18, 0.22), K.OLIVE_D)  # door, no lettering
    # flatbed rails
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.42, 0.62, -0.55), (0.06, 0.16, 1.15), K.OLIVE_D)
        for i in range(6):
            K.box(h, (s * 0.42, 0.58, -1.05 + i * 0.18), (0.04, 0.10, 0.012), K.STL)
    # four axles. The front pair steers.
    zs = (1.15, 0.72, -0.62, -1.08)
    for s in (-1.0, 1.0):
        for i, z in enumerate(zs):
            K.wheel(h, (s * 0.48, 0.28, z), 0.22, 0.16, 10, steer=(i < 2))
        K.box(h, (s * 0.30, 0.55, 1.42), (0.06, 0.04, 0.03), K.LMP)
    K.cyl(h, (-0.28, 1.02, 0.85), (-0.28, 1.45, 0.85), 0.006, 4, K.STL)
    K.box(h, (0.46, 0.62, 0.4), (0.01, 0.03, 0.45), K.TEAM_C)
    K.to_obj(h, "Hull", root)

    # planted outriggers. The view lifts this node while the truck is moving.
    og = K.fresh()
    for s in (-1.0, 1.0):
        for z in (0.85, -0.95):
            K.cyl(og, (s * 0.28, 0.42, z), (s * 0.62, 0.08, z), 0.02, 6, K.STL)
            K.box(og, (s * 0.66, 0.03, z), (0.10, 0.04, 0.14), K.OLIVE_D)
    K.to_obj(og, "Outriggers", root)

    piv = K.empty("TurretPivot", (0.0, 0.72, -0.55), root)
    t = K.fresh()
    base = K.box(t, (0, 0.08, 0.0), (0.55, 0.14, 0.50), K.OLIVE)
    K.bevel(t, base, 0.01)
    K.box(t, (0, 0.20, -0.02), (0.28, 0.12, 0.28), K.OLIVE_L)
    # missile packs, six tubes a side, lighter mouths
    for s in (-1.0, 1.0):
        K.box(t, (s * 0.38, 0.22, 0.05), (0.22, 0.22, 0.55), K.OLIVE_D)
        for row in range(2):
            for col in range(3):
                x = s * 0.38 + (col - 1) * 0.055
                y = 0.18 + row * 0.08
                K.cyl(t, (x, y, 0.28), (x, y, 0.40), 0.022, 8, K.OLIVE_L)
                K.cyl(t, (x, y, 0.34), (x, y, 0.42), 0.012, 6, K.STL)
    K.to_obj(t, "Turret", piv)

    # search radar, authored upright. The view folds it back until the truck deploys.
    radar = K.fresh()
    K.box(radar, (0, 0.15, 0), (0.08, 0.22, 0.08), K.OLIVE_D)
    K.box(radar, (0, 0.32, 0.02), (0.36, 0.22, 0.04), K.OLIVE)
    K.box(radar, (0, 0.32, 0.045), (0.28, 0.14, 0.012), K.STL)
    K.to_obj(radar, "Radar", piv)

    barrel = K.empty("Barrel", (0.0, 0.22, 0.16), piv)
    b = K.fresh()
    K.box(b, (0, 0.0, 0.0), (0.10, 0.08, 0.10), K.OLIVE_D)
    for s in (-1.0, 1.0):
        K.cyl(b, (s * 0.04, 0.0, 0.02), (s * 0.04, 0.0, 0.72), 0.016, 6, K.STL)
        K.cyl(b, (s * 0.04, 0.0, 0.66), (s * 0.04, 0.0, 0.78), 0.024, 6, K.OLIVE_D)
    K.to_obj(b, "BarrelMesh", barrel)
    K.export("pantsir.glb")

if __name__ == "__main__":
    build()
