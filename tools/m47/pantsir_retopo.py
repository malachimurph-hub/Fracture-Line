# Clean Pantsir-S1. Proportions taken from the full-resolution TRELLIS mesh
# (length : height : width about 1.00 : 0.48 : 0.34) and the owner photos.
# Geometry is authored symmetric. No badges, no lettering.
#   blender --background --python tools/m47/pantsir_retopo.py
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy_kit as K

def tyre(bm, x, y, z, r, w, steer=False):
    K.wheel(bm, (x, y, z), r, w, 12, steer)
    side = 1.0 if x > 0.0 else -1.0
    uv = (y, z)
    uv2 = (x, r + (10.0 if steer else 0.0))
    for i in range(12):
        a = i * math.tau / 8.0
        K.box(bm, (x + side * w * 0.28, y + math.sin(a) * r * 0.96, z + math.cos(a) * r * 0.96),
              (0.045, 0.055, 0.09), K.RUB, uv, uv2)

def leg(parent, name, s, z):
    """Extended hydraulic leg. Hinge is the empty origin; +local X is world +X."""
    node = K.empty(name, (s * 0.46, 0.58, z), parent)
    bm = K.fresh()
    K.cyl(bm, (0.0, 0.0, 0.0), (s * 0.42, -0.06, 0.0), 0.028, 6, K.STL)
    K.cyl(bm, (s * 0.40, -0.06, 0.0), (s * 0.42, -0.50, 0.0), 0.022, 6, K.STL)
    K.box(bm, (s * 0.42, -0.54, 0.0), (0.14, 0.045, 0.18), K.OLIVE_D)
    K.to_obj(bm, name + "Mesh", node)
    return node

def build():
    root = K.begin()
    h = K.fresh()
    # Chassis. Nose at +Z, matching the TRELLIS cab end.
    frame = K.box(h, (0, 0.46, -0.05), (0.86, 0.22, 3.05), K.OLIVE_D)
    K.bevel(h, frame, 0.012)
    # Cab
    cab = K.box(h, (0, 0.86, 1.18), (0.90, 0.62, 0.82), K.OLIVE)
    K.bevel(h, cab, 0.016)
    K.box(h, (0, 0.90, 1.58), (0.72, 0.28, 0.02), K.GLS)             # windscreen
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.46, 0.88, 1.22), (0.015, 0.22, 0.36), K.GLS)  # side glass
        # mirrors
        K.cyl(h, (s * 0.46, 0.98, 1.42), (s * 0.62, 1.02, 1.46), 0.012, 5, K.STL)
        K.box(h, (s * 0.66, 1.00, 1.46), (0.06, 0.10, 0.08), K.OLIVE_D)
        # headlights and bumper corners
        K.box(h, (s * 0.28, 0.62, 1.60), (0.10, 0.07, 0.03), K.LMP)
        K.box(h, (s * 0.38, 0.52, 1.58), (0.16, 0.08, 0.06), K.OLIVE_D)
    # grille, bars only, no badge
    K.box(h, (0, 0.70, 1.59), (0.36, 0.22, 0.02), K.OLIVE_D)
    for i in range(4):
        K.box(h, (0, 0.62 + i * 0.05, 1.605), (0.30, 0.012, 0.012), K.STL)
    K.box(h, (0, 0.50, 1.60), (0.78, 0.08, 0.08), K.OLIVE)            # bumper
    # Mid-body module, door both sides
    mod = K.box(h, (0, 0.86, 0.42), (0.84, 0.48, 0.70), K.OLIVE)
    K.bevel(h, mod, 0.01)
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.43, 0.84, 0.42), (0.02, 0.32, 0.28), K.OLIVE_D)  # access door
        K.box(h, (s * 0.445, 0.84, 0.54), (0.015, 0.06, 0.03), K.STL)    # handle
        # lockers along the bed
        lock = K.box(h, (s * 0.48, 0.62, -0.55), (0.14, 0.22, 1.15), K.OLIVE)
        K.bevel(h, lock, 0.008)
        K.box(h, (s * 0.55, 0.62, -0.55), (0.015, 0.14, 0.9), K.OLIVE_D)
        K.box(h, (s * 0.50, 0.78, 0.95), (0.16, 0.10, 0.22), K.OLIVE_D)   # step under the door
        for zc in (-1.15, -0.15):
            K.box(h, (s * 0.42, 0.78, zc), (0.18, 0.16, 0.28), K.OLIVE)  # stowage both sides
        # rails
        K.box(h, (s * 0.50, 0.78, -0.85), (0.03, 0.03, 1.3), K.STL)
        for i in range(7):
            K.box(h, (s * 0.50, 0.66, -1.45 + i * 0.20), (0.025, 0.22, 0.02), K.STL)
    # rear face
    K.box(h, (0, 0.62, -1.58), (0.82, 0.42, 0.06), K.OLIVE_D)
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.28, 0.72, -1.62), (0.08, 0.06, 0.02), K.LMP)
    K.box(h, (0, 0.40, -1.60), (0.7, 0.06, 0.06), K.OLIVE)
    # boarding ladder on the left, rungs only, no stencil
    for i in range(5):
        K.box(h, (-0.52, 0.28 + i * 0.10, 0.15), (0.02, 0.015, 0.16), K.STL)
    K.box(h, (-0.52, 0.55, 0.08), (0.02, 0.55, 0.015), K.STL)
    K.box(h, (-0.52, 0.55, 0.22), (0.02, 0.55, 0.015), K.STL)
    # eight wheels. Front pair steers. Centres follow the photo's axle groups.
    for s in (-1.0, 1.0):
        for i, z in enumerate((1.18, 0.76, -0.52, -1.02)):
            tyre(h, s * 0.55, 0.30, z, 0.30, 0.18, steer=(i < 2))
            K.box(h, (s * 0.55, 0.52, z), (0.28, 0.05, 0.42), K.OLIVE_D)  # fender
    K.cyl(h, (-0.32, 1.18, 0.55), (-0.32, 1.55, 0.55), 0.008, 4, K.STL)
    K.box(h, (0.50, 0.70, 0.1), (0.012, 0.03, 0.4), K.TEAM_C)
    K.to_obj(h, "Hull", root)

    og = K.empty("Outriggers", (0.0, 0.0, 0.0), root)
    for name, s, z in (("LegFR", 1.0, 0.95), ("LegFL", -1.0, 0.95), ("LegRR", 1.0, -0.9), ("LegRL", -1.0, -0.9)):
        leg(og, name, s, z)

    piv = K.empty("TurretPivot", (0.0, 0.64, -0.08), root)
    t = K.fresh()
    base = K.box(t, (0, 0.08, 0.0), (0.62, 0.16, 0.55), K.OLIVE)
    K.bevel(t, base, 0.012)
    K.hatch(t, 0.0, 0.26, -0.08, 0.07)
    K.box(t, (0, 0.20, -0.02), (0.34, 0.12, 0.32), K.OLIVE_L)
    # tracking radar on the front of the turret
    K.cyl(t, (0.0, 0.16, 0.26), (0.0, 0.16, 0.34), 0.10, 10, K.OLIVE_D)
    K.cyl(t, (0.0, 0.16, 0.33), (0.0, 0.16, 0.36), 0.07, 8, K.STL)
    # missile packs, both sides
    for s in (-1.0, 1.0):
        K.box(t, (s * 0.42, 0.20, 0.02), (0.24, 0.24, 0.58), K.OLIVE_D)
        for row in range(2):
            for col in range(3):
                x = s * 0.42 + (col - 1) * 0.06
                y = 0.15 + row * 0.09
                K.cyl(t, (x, y, 0.26), (x, y, 0.40), 0.026, 8, K.OLIVE_L)
                K.cyl(t, (x, y, 0.34), (x, y, 0.43), 0.014, 6, K.STL)
    K.to_obj(t, "Turret", piv)

    # Search radar, upright. Its origin is the hinge, so the view can fold it.
    rad = K.empty("Radar", (0.0, 0.28, -0.06), piv)
    radar = K.fresh()
    K.box(radar, (0, 0.10, 0), (0.07, 0.18, 0.07), K.OLIVE_D)
    K.box(radar, (0, 0.26, 0.02), (0.46, 0.30, 0.045), K.OLIVE)
    K.box(radar, (0, 0.26, 0.05), (0.36, 0.20, 0.012), K.STL)
    K.to_obj(radar, "RadarMesh", rad)

    # Twin 30 mm on each side.
    barrel = K.empty("Barrel", (0.0, 0.22, 0.18), piv)
    b = K.fresh()
    K.box(b, (0, 0.0, 0.0), (0.55, 0.08, 0.10), K.OLIVE_D)
    for s in (-1.0, 1.0):
        for k, dy in enumerate((-0.03, 0.03)):
            x = s * 0.22
            K.cyl(b, (x, dy, 0.04), (x, dy, 0.78), 0.016, 6, K.STL)
            K.cyl(b, (x, dy, 0.72), (x, dy, 0.86), 0.024, 6, K.OLIVE_D)
    K.to_obj(b, "BarrelMesh", barrel)
    K.export("pantsir.glb")

if __name__ == "__main__":
    build()
