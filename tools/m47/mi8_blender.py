# Mi-8. Bulbous glazed nose, twin intakes, left tail rotor, five-blade main rotor, rocket pods.
#   blender --background --python tools/m47/mi8_blender.py
import bmesh
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy_kit as K
from mathutils import Matrix

def _spin(bm, faces, pivot, axis, angle):
    bmesh.ops.rotate(bm, cent=K.G(*pivot), matrix=Matrix.Rotation(angle, 4, axis),
                     verts=list({v for f in faces for v in f.verts}))

def build():
    root = K.begin()
    h = K.fresh()
    # cabin
    cab = K.box(h, (0, 0.55, 0.15), (0.72, 0.48, 1.55), K.OLIVE)
    K.bevel(h, cab, 0.03)
    # bulbous nose
    nose = K.box(h, (0, 0.50, 1.05), (0.58, 0.42, 0.42), K.OLIVE)
    K.bevel(h, nose, 0.04)
    K.box(h, (0, 0.52, 1.22), (0.42, 0.22, 0.02), K.GLS)          # windscreen
    K.box(h, (-0.30, 0.50, 1.05), (0.012, 0.16, 0.22), K.GLS)
    K.box(h, (0.30, 0.50, 1.05), (0.012, 0.16, 0.22), K.GLS)
    # portholes
    for s in (-1.0, 1.0):
        for z in (0.45, 0.15, -0.15, -0.42):
            K.cyl(h, (s * 0.35, 0.58, z), (s * 0.38, 0.58, z), 0.045, 8, K.GLS)
    # rear clamshell
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.16, 0.48, -0.68), (0.28, 0.36, 0.03), K.OLIVE_D)
    # engine humps and round intakes
    for s in (-1.0, 1.0):
        hump = K.box(h, (s * 0.20, 0.86, 0.15), (0.26, 0.14, 0.55), K.OLIVE_D)
        K.bevel(h, hump, 0.02)
        K.cyl(h, (s * 0.20, 0.86, 0.40), (s * 0.20, 0.86, 0.52), 0.08, 10, K.STL)
        K.cyl(h, (s * 0.20, 0.86, 0.48), (s * 0.20, 0.86, 0.56), 0.045, 8, K.RUB)
    # tail boom, fin, left tail plane
    K.cyl(h, (0, 0.52, -0.7), (0, 0.62, -2.15), 0.09, 8, K.OLIVE)
    K.box(h, (0, 0.82, -2.05), (0.04, 0.38, 0.22), K.OLIVE_D)
    K.box(h, (0.0, 0.70, -1.85), (0.28, 0.02, 0.12), K.OLIVE)
    # stub pylons and rocket pods
    for s in (-1.0, 1.0):
        K.box(h, (s * 0.55, 0.42, 0.25), (0.40, 0.04, 0.16), K.OLIVE_D)
        K.cyl(h, (s * 0.72, 0.34, 0.25), (s * 0.72, 0.34, 0.55), 0.07, 8, K.OLIVE)
        for k in range(5):
            ang = (k - 2) * 0.35
            K.cyl(h, (s * 0.72 + math.sin(ang) * 0.0, 0.34 + (k - 2) * 0.0, 0.42),
                  (s * 0.72, 0.34, 0.62), 0.012, 5, K.STL)
        for i, yy in enumerate((-0.045, 0.0, 0.045)):
            for zz in (-0.02, 0.04):
                K.cyl(h, (s * 0.72, 0.34 + yy, 0.30 + zz), (s * 0.72, 0.34 + yy, 0.48), 0.016, 5, K.OLIVE_D)
    # fixed tricycle gear
    K.cyl(h, (0, 0.28, 1.05), (0, 0.08, 1.12), 0.015, 4, K.STL)
    K.wheel(h, (0.0, 0.07, 1.14), 0.07, 0.04, 8)
    for s in (-1.0, 1.0):
        K.cyl(h, (s * 0.15, 0.30, -0.05), (s * 0.32, 0.08, 0.05), 0.016, 4, K.STL)
        K.wheel(h, (s * 0.36, 0.09, 0.06), 0.09, 0.05, 8)
    K.box(h, (0.40, 0.55, 0.0), (0.01, 0.03, 0.4), K.TEAM_C)
    K.to_obj(h, "Hull", root)

    # five-blade main rotor. Blades are local to the hub so the view can spin the empty.
    piv = K.empty("Rotor", (0.0, 1.05, 0.15), root)
    r = K.fresh()
    K.cyl(r, (0, 0.0, 0), (0, 0.06, 0), 0.08, 8, K.STL)
    for i in range(5):
        faces = K.box(r, (0, 0.03, 1.0), (0.07, 0.015, 1.85), K.OLIVE_D)
        _spin(r, faces, (0, 0.03, 0), "Z", i * math.tau / 5.0)
        tip = K.box(r, (0, 0.03, 1.82), (0.08, 0.012, 0.10), K.OLIVE_L)
        _spin(r, tip, (0, 0.03, 0), "Z", i * math.tau / 5.0)
    K.to_obj(r, "RotorMesh", piv)

    # tail rotor on the left, disc in the vertical longitudinal plane, spun on local X
    tp = K.empty("TailRotor", (-0.16, 0.78, -2.02), root)
    tr = K.fresh()
    K.cyl(tr, (0, 0, 0), (-0.04, 0, 0), 0.035, 6, K.STL)
    for i in range(3):
        faces = K.box(tr, (0, 0, 0.20), (0.012, 0.04, 0.36), K.OLIVE_D)
        _spin(tr, faces, (0, 0, 0), "X", i * math.tau / 3.0)
    K.to_obj(tr, "TailMesh", tp)
    K.export("mi8.glb")

if __name__ == "__main__":
    build()
