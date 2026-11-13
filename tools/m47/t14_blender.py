# T-14. Longer than the T-90, seven road wheels, a low unmanned turret set back, rear slats.
# The top-down photo puts it about a quarter longer and a little wider than the T-90.
#   blender --background --python tools/m47/t14_blender.py
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy_kit as K

def build():
    root = K.begin()
    h = K.fresh()
    body = K.box(h, (0, 0.30, -0.02), (1.05, 0.36, 2.10), K.OLIVE)
    glacis = K.box(h, (0, 0.30, 1.15), (0.98, 0.32, 0.48), K.OLIVE)
    for v in h.verts:
        gz = -v.co.y
        if gz > 1.28 and v.co.z > 0.26:
            v.co.z = 0.18
    K.bevel(h, body + glacis, 0.012)
    K.box(h, (0, 0.34, -1.20), (0.94, 0.28, 0.08), K.OLIVE_D)
    # rear slat basket
    for i in range(8):
        K.box(h, (-0.38 + i * 0.11, 0.40, -1.30), (0.012, 0.28, 0.02), K.STL)
    for i in range(4):
        K.box(h, (0, 0.30 + i * 0.08, -1.30), (0.82, 0.012, 0.02), K.STL)
    for s in (-1.0, 1.0):
        for zc, zl in ((0.42, 0.85), (-0.48, 0.75)):
            sk = K.box(h, (s * 0.62, 0.34, zc), (0.10, 0.22, zl), K.OLIVE)
            K.bevel(h, sk, 0.008)
            K.box(h, (s * 0.68, 0.34, zc), (0.01, 0.14, zl * 0.7), K.OLIVE_D)
        for i in range(7):
            z = -0.72 + i * (1.40 / 6.0)
            K.wheel(h, (s * 0.56, 0.145, z), 0.115, 0.09, 10)
        K.wheel(h, (s * 0.56, 0.18, -1.10), 0.14, 0.08, 10)
        for k in range(8):
            a = k * math.tau / 8.0
            K.box(h, (s * 0.56, 0.18 + math.sin(a) * 0.13, -1.10 + math.cos(a) * 0.13),
                  (0.06, 0.03, 0.034), K.WH_S, (0.18, -1.10), (s * 0.56, 0.14))
        K.wheel(h, (s * 0.56, 0.13, 0.88), 0.095, 0.06, 8)
        K.box(h, (s * 0.28, 0.24, 1.32), (0.05, 0.035, 0.02), K.LMP)
    # three closed crew hatches in a row on the front deck
    for x in (-0.30, 0.0, 0.30):
        K.hatch(h, x, 0.48, 0.68, 0.09)
    K.box(h, (0.64, 0.40, -0.1), (0.01, 0.03, 0.4), K.TEAM_C)
    K.to_obj(h, "Hull", root)
    K.add_tracks(root, -1.10, 0.88, 0.18, 0.13, 0.145, 0.10, y_top=0.30, x=0.56, step=0.095)

    # low wedge turret, set back over the rear half
    piv = K.empty("TurretPivot", (0.0, 0.50, -0.28), root)
    t = K.fresh()
    wedge = K.box(t, (0, 0.08, 0.02), (0.72, 0.14, 0.70), K.OLIVE)
    K.bevel(t, wedge, 0.012)
    for v in t.verts:
        gz = -v.co.y
        gy = v.co.z
        if gz > 0.22 and gy > 0.08:
            v.co.z = 0.08 + (0.32 - gz) * 0.15
    bustle = K.box(t, (0, 0.10, -0.28), (0.55, 0.10, 0.28), K.OLIVE_D)
    K.bevel(t, bustle, 0.008)
    # sensor mast
    K.box(t, (-0.22, 0.22, -0.05), (0.10, 0.16, 0.12), K.OLIVE_D)
    K.box(t, (-0.22, 0.26, 0.02), (0.06, 0.04, 0.012), K.GLS)
    # remote weapon station
    K.box(t, (0.18, 0.18, -0.08), (0.10, 0.08, 0.14), K.OLIVE)
    K.cyl(t, (0.18, 0.20, 0.0), (0.18, 0.20, 0.16), 0.012, 6, K.STL)
    K.cyl(t, (0.22, 0.20, -0.22), (0.22, 0.55, -0.22), 0.005, 4, K.STL)
    K.cyl(t, (-0.28, 0.16, -0.22), (-0.28, 0.42, -0.22), 0.005, 4, K.STL)
    # launcher boxes, small, on the bustle sides
    for s in (-1.0, 1.0):
        K.box(t, (s * 0.32, 0.12, -0.05), (0.08, 0.08, 0.22), K.OLIVE_D)
    K.to_obj(t, "Turret", piv)
    barrel = K.empty("Barrel", (0.0, 0.10, 0.28), piv)
    b = K.fresh()
    K.box(b, (0, 0.02, 0.0), (0.14, 0.08, 0.12), K.OLIVE_D)
    K.cyl(b, (0, 0.02, 0.04), (0, 0.03, 1.35), 0.032, 8, K.STL)
    K.cyl(b, (0, 0.03, 1.25), (0, 0.03, 1.42), 0.042, 8, K.OLIVE_D)
    K.to_obj(b, "BarrelMesh", barrel)
    K.export("t14.glb")

if __name__ == "__main__":
    build()
