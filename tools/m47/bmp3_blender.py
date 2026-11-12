# BMP-3. Boat bow, raised rear deck, 100 mm with the 30 mm beside it.
#   blender --background --python tools/m47/bmp3_blender.py
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy_kit as K

def build():
    root = K.begin()
    h = K.fresh()
    body = K.box(h, (0, 0.26, -0.05), (0.88, 0.30, 1.50), K.OLIVE)
    bow = K.box(h, (0, 0.24, 0.82), (0.80, 0.26, 0.48), K.OLIVE)
    for v in h.verts:
        gz = -v.co.y
        if gz > 0.98:
            v.co.z = min(v.co.z, 0.14)
            v.co.x *= max(0.55, 1.0 - (gz - 0.98) * 1.6)
    K.bevel(h, body + bow, 0.01)
    deck = K.box(h, (0, 0.46, -0.48), (0.84, 0.14, 0.78), K.OLIVE)
    K.bevel(h, deck, 0.008)
    # two rear clamshell doors
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.18, 0.34, -0.96), (0.30, 0.32, 0.028), K.OLIVE_D)
        K.box(h, (s * 0.08, 0.36, -0.98), (0.03, 0.08, 0.012), K.STL)
    K.box(h, (0, 0.18, 1.04), (0.62, 0.035, 0.06), K.OLIVE_D)  # trim vane
    for s in (-1.0, 1.0):
        sk = K.box(h, (s * 0.50, 0.20, -0.02), (0.07, 0.14, 1.25), K.OLIVE)
        K.bevel(h, sk, 0.006)
        K.box(h, (s * 0.54, 0.20, 0.05), (0.01, 0.08, 0.85), K.OLIVE_D)
        for i in range(6):
            z = -0.52 + i * (0.90 / 5.0)
            K.wheel(h, (s * 0.48, 0.135, z), 0.105, 0.08, 10)
        K.wheel(h, (s * 0.48, 0.16, -0.78), 0.125, 0.075, 10)
        for k in range(7):
            a = k * math.tau / 7.0
            K.box(h, (s * 0.48, 0.16 + math.sin(a) * 0.11, -0.78 + math.cos(a) * 0.11),
                  (0.055, 0.026, 0.03), K.WH_S, (0.16, -0.78), (s * 0.48, 0.125))
        K.wheel(h, (s * 0.48, 0.12, 0.58), 0.085, 0.055, 8)
        K.box(h, (s * 0.22, 0.20, 0.96), (0.05, 0.03, 0.02), K.LMP)
    # three closed bow hatches across the front deck
    for x in (-0.26, 0.0, 0.26):
        K.hatch(h, x, 0.40, 0.48, 0.085)
    for s in (-1.0, 1.0):
        K.cyl(h, (s * 0.30, 0.40, 0.58), (s * 0.30, 0.40, 0.74), 0.012, 6, K.STL)
    K.cyl(h, (-0.56, 0.32, -0.2), (-0.56, 0.32, 0.35), 0.032, 6, K.WOOD)  # unditching log
    K.box(h, (0.52, 0.30, -0.15), (0.01, 0.025, 0.26), K.TEAM_C)
    K.to_obj(h, "Hull", root)
    K.add_tracks(root, -0.78, 0.58, 0.16, 0.12, 0.125, 0.09, y_top=0.26, x=0.48, step=0.09)

    piv = K.empty("TurretPivot", (0.0, 0.50, 0.12), root)
    t = K.fresh()
    ring = K.box(t, (0, 0.05, 0.0), (0.58, 0.09, 0.50), K.OLIVE)
    K.bevel(t, ring, 0.018)
    cap = K.box(t, (0, 0.13, -0.02), (0.34, 0.09, 0.30), K.OLIVE_L)
    K.bevel(t, cap, 0.012)
    K.hatch(t, 0.10, 0.175, -0.02, 0.065)
    K.box(t, (-0.14, 0.14, 0.14), (0.08, 0.06, 0.07), K.OLIVE_D)
    K.box(t, (-0.14, 0.14, 0.18), (0.045, 0.035, 0.012), K.GLS)
    for s in (-1.0, 1.0):
        for i in range(3):
            K.cyl(t, (s * 0.24, 0.10, -0.06 + i * 0.07), (s * 0.36, 0.18, 0.0 + i * 0.07), 0.015, 6, K.STL)
    K.cyl(t, (0.16, 0.18, -0.12), (0.16, 0.48, -0.12), 0.005, 4, K.STL)
    K.cyl(t, (-0.16, 0.18, -0.10), (-0.16, 0.42, -0.10), 0.005, 4, K.STL)
    K.to_obj(t, "Turret", piv)
    barrel = K.empty("Barrel", (0.0, 0.08, 0.18), piv)
    b = K.fresh()
    K.box(b, (0.035, 0.02, 0.0), (0.18, 0.08, 0.10), K.OLIVE_D)
    K.cyl(b, (0.0, 0.02, 0.04), (0.0, 0.02, 1.15), 0.028, 8, K.STL)          # 100 mm
    K.cyl(b, (0.0, 0.02, 1.08), (0.0, 0.02, 1.20), 0.038, 8, K.OLIVE_D)
    K.cyl(b, (0.075, 0.02, 0.06), (0.075, 0.02, 0.92), 0.014, 6, K.STL)      # 30 mm beside it
    K.cyl(b, (0.075, 0.02, 0.86), (0.075, 0.02, 0.98), 0.022, 6, K.OLIVE_D)
    K.to_obj(b, "BarrelMesh", barrel)
    K.export("bmp3.glb")

if __name__ == "__main__":
    build()
