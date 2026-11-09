#!/usr/bin/env python3
"""Author the graphics-review battlefield.

Run:
  blender --background --factory-startup --python tools/gfx_review/author_demo.py

Original geometry and textures. The M1A3 mesh follows public M1A2 SEP v3
figures (hull 7.93 m, gun-forward 9.77 m, width 3.66 m, roof height 2.44 m)
at the game's 0.25 world-unit per metre scale. Nothing here is traced from a
game or a commercial model. Blender is only the authoring tool.

Outputs under assets/gfx_review/:
  m1a3.glb, plant.glb, ground.glb, tree.glb, rock.glb
  *_albedo.png, *_normal.png, *_orm.png, tread.png, scorch.png, layout.json

Bake: unique UV islands, raytraced hemisphere AO (mathutils BVH), panel seams,
bolts, mud, snow dust and edge wear written into the albedo / ORM / normal maps.
"""
import json, math, os, sys, time, traceback
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "gfx_review")
S = 0.25  # game units per metre (matches view/props/prop_meshes.gd)
SHOE_M = 0.18

# Public M1A2 SEP v3 layout, in metres. The in-game name stays M1A3.
# Hull 7.93, width over the skirts 3.66, height to the turret roof 2.44,
# gun forward 9.77, ground clearance about 0.48. Seven road wheels, a rear
# sprocket, a front idler and two return rollers. The 120 mm tube has a
# thermal sleeve, a bore evacuator and a muzzle reference sensor.
HULL_NOSE_Y = 3.965
HULL_TAIL_Y = -3.965
GUN_FORWARD = 9.77
MUZZLE_Y = HULL_TAIL_Y + GUN_FORWARD  # 5.805
SKIRT_X = 1.83
TRACK_X = 1.51
TRACK_HALF_W = 0.3175  # 635 mm track
WHEEL_R = 0.32
WHEEL_Z = 0.40
WHEEL_YS = (-2.72, -1.82, -0.92, -0.02, 0.88, 1.78, 2.68)
SPROCKET_Y, SPROCKET_Z, SPROCKET_R = -3.52, 0.50, 0.38
IDLER_Y, IDLER_Z, IDLER_R = 3.42, 0.44, 0.30
ROLLER_YS = (-1.05, 1.20)
ROLLER_Z, ROLLER_R = 0.78, 0.11
TRUNNION_Y, TRUNNION_Z = 1.70, 1.92
BARREL_LEN = MUZZLE_Y - TRUNNION_Y  # 4.105, muzzle 1.84 m past the hull nose
ROOF_Z = 2.44
RING_Y, RING_Z = 0.10, 1.62

# Face tags. Track has its own tiled texture and is not packed into the atlas.
PAINT, TURRET, STEEL, RUBBER, GLASS, DARK = 1, 2, 3, 4, 5, 6
CANVAS, JERRY = 7, 8
CONCRETE, ROOF, STACK, PIPE = 9, 10, 11, 12
BARK, NEEDLE, ROCK = 13, 14, 15

TANK_PX = 2048
PLANT_PX = 2048
PROP_PX = 1024
GROUND_PX = 2048
FIELD_HALF = 70.0  # textured ground covers 140 x 140 world units, the whole visible field
# Faces smaller than this (square metres) share a material swatch instead of a private island.
SWATCH_AREA = 0.06
RAYS = 8
SKIP_AO = os.environ.get("SKIP_AO") == "1"


def new_bm():
    bm = bmesh.new()
    bm.faces.layers.int.new("tag")
    return bm


def lay(bm):
    return bm.faces.layers.int.get("tag")


def tag_new(bm, before, tag):
    L = lay(bm)
    for f in bm.faces:
        if f not in before:
            f[L] = tag
            f.smooth = True


def try_bevel(bm, edges, offset, segs):
    if offset <= 0 or not edges:
        return
    try:
        bmesh.ops.bevel(bm, geom=list(edges), offset=float(offset), segments=int(segs),
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    except Exception as ex:
        print("bevel skipped", ex)


def add_box(bm, center, size, tag, bevel=0.0, segs=2, rot=None):
    before_f = set(bm.faces)
    before_e = set(bm.edges)
    ret = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Identity(4)
    m[0][0], m[1][1], m[2][2] = float(size[0]), float(size[1]), float(size[2])
    if rot is not None:
        R = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
        mat = Matrix.Translation(Vector(center)) @ R @ m
    else:
        m.translation = Vector(center)
        mat = m
    bmesh.ops.transform(bm, verts=ret["verts"], matrix=mat)
    if bevel > 0:
        edges = [e for e in bm.edges if e not in before_e]
        try_bevel(bm, edges, bevel, segs)
    tag_new(bm, before_f, tag)


def add_tube(bm, p0, p1, radius, tag, segs=12, bevel=0.0):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    length = d.length
    if length < 1e-5:
        return
    before_f = set(bm.faces)
    before_e = set(bm.edges)
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, verts=ret["verts"], matrix=Matrix.Translation((p0 + p1) * 0.5) @ rot)
    if bevel > 0:
        edges = [e for e in bm.edges if e not in before_e]
        try_bevel(bm, edges, bevel, 1)
    tag_new(bm, before_f, tag)


def add_cone(bm, center, radius, depth, tag, segs=10):
    before = set(bm.faces)
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=0.0, depth=depth)
    bmesh.ops.transform(bm, verts=ret["verts"], matrix=Matrix.Translation(Vector(center)))
    tag_new(bm, before, tag)


def add_convex(bm, pts, tag, bevel=0.0):
    before_f = set(bm.faces)
    vs = [bm.verts.new(Vector(p)) for p in pts]
    try:
        bmesh.ops.convex_hull(bm, input=vs)
    except Exception as ex:
        print("hull failed", ex)
        return
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    if bevel > 0:
        edges = [e for e in bm.edges if e not in set()]
        # bevel every edge of the new faces; clamp keeps it stable
        try_bevel(bm, list(bm.edges), bevel, 1)
        # retag happens below for faces not in before; bevel may replace them
    tag_new(bm, before_f, tag)


def mirror_xy(pts):
    out = []
    for p in pts:
        out.append(p)
        if abs(p[0]) > 1e-4:
            out.append((-p[0], p[1], p[2]))
    return out


def orient(bm):
    if not bm.faces:
        return
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    c = Vector()
    for v in bm.verts:
        c += v.co
    c /= max(1, len(bm.verts))
    bm.faces.ensure_lookup_table()
    acc = 0.0
    for f in bm.faces:
        acc += f.normal.dot(f.calc_center_median() - c)
    if acc < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()


def join(dst, src):
    if src is None or not src.faces:
        return
    dl, sl = lay(dst), lay(src)
    src.verts.index_update()
    mp = {}
    for v in src.verts:
        mp[v.index] = dst.verts.new(v.co.copy())
    for f in src.faces:
        try:
            nf = dst.faces.new([mp[v.index] for v in f.verts])
        except ValueError:
            continue
        nf[dl] = f[sl]
        nf.smooth = True
        nf.material_index = f.material_index
    src.free()


def scale_bm(bm, s):
    for v in bm.verts:
        v.co *= s


def shift_bm(bm, delta):
    d = Vector(delta)
    for v in bm.verts:
        v.co -= d


# ---------------------------------------------------------------- tank
def build_track(x_sign):
    bm = new_bm()
    y_r, z_r, r_r = SPROCKET_Y, SPROCKET_Z, SPROCKET_R + 0.045
    y_f, z_f, r_f = IDLER_Y, IDLER_Z, IDLER_R + 0.045
    pts = []
    y = y_r
    while y < y_f - 0.05:
        pts.append((y, 0.08))  # bottom run, just under the road wheels
        y += 0.14
    for i in range(1, 9):
        a = math.pi - i * math.pi / 9
        pts.append((y_f + math.sin(a) * r_f, z_f + math.cos(a) * r_f))
    y = y_f
    while y > y_r + 0.05:
        t = (y_f - y) / (y_f - y_r)
        pts.append((y, 0.90 - 0.045 * math.sin(math.pi * t)))
        y -= 0.14
    for i in range(1, 9):
        a = -i * math.pi / 9
        pts.append((y_r + math.sin(a) * r_r, z_r + math.cos(a) * r_r))
    # drop near-duplicates
    clean = [pts[0]]
    for p in pts[1:]:
        if (p[0] - clean[-1][0]) ** 2 + (p[1] - clean[-1][1]) ** 2 > 0.004:
            clean.append(p)
    pts = clean
    n = len(pts)
    cy = sum(p[0] for p in pts) / n
    cz = sum(p[1] for p in pts) / n
    half_w, half_th = TRACK_HALF_W, 0.045
    frames = []
    for yv, zv in pts:
        ny, nz = yv - cy, zv - cz
        ln = math.hypot(ny, nz) or 1.0
        frames.append((yv, zv, ny / ln, nz / ln))
    vs = []
    for yv, zv, ny, nz in frames:
        for sx in (1.0, -1.0):
            for sn in (1.0, -1.0):
                vs.append(bm.verts.new((
                    x_sign * (TRACK_X + sx * half_w),
                    yv + ny * sn * half_th,
                    zv + nz * sn * half_th,
                )))
    bm.verts.ensure_lookup_table()
    uv = bm.loops.layers.uv.new("UVMap")
    dist = [0.0]
    for i in range(1, n):
        dist.append(dist[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
    # close the loop length
    close = math.hypot(pts[0][0] - pts[-1][0], pts[0][1] - pts[-1][1])
    L = lay(bm)

    def quad(a, b, c, d, v0, v1, u0, u1):
        try:
            f = bm.faces.new((vs[a], vs[b], vs[c], vs[d]))
        except ValueError:
            return
        f[L] = RUBBER
        f.smooth = True
        loops = list(f.loops)
        # match loop verts to corners a,b,c,d
        order = [a, b, c, d]
        uvm = {
            a: (u0, v0 / SHOE_M), b: (u1, v0 / SHOE_M),
            c: (u1, v1 / SHOE_M), d: (u0, v1 / SHOE_M),
        }
        for lp in loops:
            vi = vs.index(lp.vert) if False else None
        # assign by vert identity
        for lp in f.loops:
            idx = vs.index(lp.vert)
            lp[uv].uv = uvm[idx]

    for i in range(n):
        j = (i + 1) % n
        i0, j0 = i * 4, j * 4
        v0 = dist[i]
        v1 = dist[i + 1] if j != 0 else dist[-1] + close
        # corners: 0 +x +n, 1 -x +n, 2 -x -n, 3 +x -n  (local sx, sn)
        # rebuild corner order independent of x_sign: indices are 0..3 as created (+sx first)
        quad(i0 + 0, i0 + 1, j0 + 1, j0 + 0, v0, v1, 0.0, 1.0)  # outer
        quad(i0 + 3, j0 + 3, j0 + 2, i0 + 2, v0, v1, 0.0, 1.0)  # inner
        quad(i0 + 0, j0 + 0, j0 + 3, i0 + 3, v0, v1, 0.0, 0.18)
        quad(i0 + 1, i0 + 2, j0 + 2, j0 + 1, v0, v1, 0.82, 1.0)
        # guide horn on the bottom run, inner side, pointing up toward the wheels
        if frames[i][3] < -0.55 and i % 2 == 0:
            inner = -1.0 if x_sign > 0 else 1.0
            hx = x_sign * TRACK_X + inner * half_w
            add_box(bm, (hx, frames[i][0], frames[i][1] + 0.07), (0.045, 0.09, 0.11), STEEL, bevel=0.004, segs=1)
    orient(bm)
    return bm


def _swatch_uvs(bm):
    """Tiny spinning parts share the rubber / steel tiles instead of unique islands."""
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    L = lay(bm)
    for f in bm.faces:
        rect = SWATCH_RECT.get(int(f[L]), SWATCH_RECT[STEEL])
        _assign_swatch(f, uv, rect)


def wheel_parts():
    """Seven road wheels a side, rear sprocket, front idler, two return rollers.
    Each part is its own object so the review scene can spin it. Local axle is +X.
    """
    out = []
    for side, x in (("L", TRACK_X), ("R", -TRACK_X)):
        for i, yv in enumerate(WHEEL_YS):
            bm = new_bm()
            add_tube(bm, (-0.13, 0, 0), (0.13, 0, 0), WHEEL_R, RUBBER, 12)
            add_tube(bm, (-0.145, 0, 0), (0.145, 0, 0), 0.11, STEEL, 8)
            orient(bm)
            _swatch_uvs(bm)
            out.append(("Wheel_%s_%d" % (side, i), bm, Vector((x, yv, WHEEL_Z))))
        sp = new_bm()
        add_tube(sp, (-0.12, 0, 0), (0.12, 0, 0), SPROCKET_R * 0.72, STEEL, 10)
        for k in range(11):
            a = k * math.tau / 11.0
            add_box(sp, (0.0, math.sin(a) * (SPROCKET_R + 0.02), math.cos(a) * (SPROCKET_R + 0.02)),
                    (0.16, 0.08, 0.09), STEEL, bevel=0.0)
        orient(sp)
        _swatch_uvs(sp)
        out.append(("Sprocket_%s" % side, sp, Vector((x, SPROCKET_Y, SPROCKET_Z))))
        idl = new_bm()
        add_tube(idl, (-0.10, 0, 0), (0.10, 0, 0), IDLER_R, STEEL, 10)
        add_tube(idl, (-0.11, 0, 0), (0.11, 0, 0), 0.10, DARK, 8)
        orient(idl)
        _swatch_uvs(idl)
        out.append(("Idler_%s" % side, idl, Vector((x, IDLER_Y, IDLER_Z))))
        for i, yv in enumerate(ROLLER_YS):
            rr = new_bm()
            add_tube(rr, (-0.07, 0, 0), (0.07, 0, 0), ROLLER_R, RUBBER, 8)
            add_tube(rr, (-0.08, 0, 0), (0.08, 0, 0), 0.04, STEEL, 6)
            orient(rr)
            _swatch_uvs(rr)
            out.append(("Roller_%s_%d" % (side, i), rr, Vector((x, yv, ROLLER_Z))))
    return out


def build_hull():
    bm = new_bm()
    # Nose at +3.965, tail at -3.965: hull length 7.93 m. Belly at 0.48 m clearance.
    pts = mirror_xy([
        (0.42, HULL_NOSE_Y, 0.62),
        (0.95, 3.72, 0.50),
        (1.18, 3.42, 1.02),
        (1.42, 2.78, 1.36),
        (1.55, 2.05, 1.58),
        (1.56, -2.15, 1.60),
        (1.48, -3.05, 1.42),
        (1.28, HULL_TAIL_Y, 1.12),
        (1.08, HULL_TAIL_Y, 0.50),
        (1.08, -2.30, 0.48),
        (1.08, 2.15, 0.48),
        (0.72, 3.55, 0.48),
    ])
    add_convex(bm, pts, PAINT, bevel=0.0)
    # Skirts take the width to 3.66 m. The front panel is raked.
    for s in (-1.0, 1.0):
        for i, yv in enumerate((-2.85, -1.85, -0.85, 0.15, 1.15, 2.15)):
            add_box(bm, (s * SKIRT_X, yv, 0.58), (0.055, 0.92, 0.62), PAINT, bevel=0.01, segs=1)
        add_box(bm, (s * (SKIRT_X - 0.02), 3.05, 0.78), (0.05, 0.72, 0.42), PAINT, bevel=0.01, segs=1)
        add_box(bm, (s * 1.68, -0.15, 1.02), (0.26, 6.55, 0.045), PAINT, bevel=0.008, segs=1)
        add_tube(bm, (s * 1.15, 3.55, 1.05), (s * 1.15, 3.66, 1.08), 0.065, GLASS, 8)
        add_box(bm, (s * 1.15, 3.62, 1.18), (0.18, 0.035, 0.035), STEEL, bevel=0.003, segs=1)
    # Driver's hatch on the glacis, with three periscopes.
    add_tube(bm, (0, 2.35, 1.46), (0, 2.72, 1.58), 0.22, TURRET, 10)
    for x in (-0.10, 0.0, 0.10):
        add_box(bm, (x, 2.78, 1.62), (0.055, 0.045, 0.035), GLASS, bevel=0.0)
    # Engine-deck grille.
    for i in range(9):
        add_box(bm, (-0.64 + i * 0.16, -2.95, 1.52), (0.045, 0.95, 0.035), DARK, bevel=0.0)
    add_box(bm, (0, HULL_TAIL_Y - 0.01, 0.92), (1.05, 0.05, 0.46), DARK, bevel=0.0)
    for i in range(6):
        add_box(bm, (-0.40 + i * 0.16, HULL_TAIL_Y - 0.04, 0.92), (0.035, 0.025, 0.40), STEEL, bevel=0.0)
    # UAAPU is under the left rear armor. Only the intake louvers and a low exhaust show.
    for i in range(7):
        add_box(bm, (-1.50, -3.22, 0.92 + i * 0.065), (0.045, 0.62, 0.022), DARK, bevel=0.0)
    add_box(bm, (-1.50, -3.22, 1.14), (0.03, 0.70, 0.52), STEEL, bevel=0.004, segs=1)
    add_box(bm, (-1.35, HULL_TAIL_Y - 0.02, 0.68), (0.16, 0.04, 0.10), DARK, bevel=0.0)
    add_box(bm, (-1.05, -2.05, 1.72), (0.40, 0.52, 0.26), CANVAS, bevel=0.015, segs=1)
    add_box(bm, (1.12, -1.65, 1.74), (0.26, 0.40, 0.30), JERRY, bevel=0.006, segs=1)
    for s in (-0.55, 0.55):
        add_box(bm, (s, HULL_NOSE_Y - 0.02, 0.70), (0.09, 0.07, 0.09), STEEL, bevel=0.004, segs=1)
    for s in (-1.28, 1.28):
        add_box(bm, (s, HULL_TAIL_Y - 0.02, 1.18), (0.07, 0.025, 0.045), GLASS, bevel=0.0)
    orient(bm)
    return bm


def build_turret():
    bm = new_bm()
    oy, oz = RING_Y, RING_Z
    # Roof local z 0.82 puts the turret roof at 2.44 m. +X is the vehicle's right
    # (commander and gunner). The loader is on the left.
    raw = [
        (0.22, 1.72, 0.16), (0.24, 1.72, 0.52),
        (0.78, 1.15, 0.02), (0.86, 1.05, 0.58),
        (1.35, 0.25, 0.00), (1.42, 0.10, 0.46), (1.22, 0.35, 0.78),
        (1.45, -0.55, 0.00), (1.46, -0.45, 0.55),
        (1.18, -1.55, 0.02), (1.16, -1.45, 0.52),
        (0.98, -2.55, 0.06), (0.92, -2.58, 0.48),
        (0.28, 0.25, 0.82), (0.16, -1.15, 0.78),
        (0.55, 0.95, 0.00), (0.85, -1.85, 0.00),
    ]
    pts = [(x, y + oy, z + oz) for x, y, z in mirror_xy(raw)]
    add_convex(bm, pts, TURRET, bevel=0.0)
    for s in (-1.0, 1.0):
        add_box(bm, (s * 1.28, 0.35 + oy, 0.28 + oz), (0.07, 1.05, 0.42), TURRET,
                bevel=0.01, segs=1, rot=(0, 10 * s, 0))
    add_box(bm, (0, 1.48 + oy, 0.28 + oz), (0.58, 0.26, 0.42), TURRET, bevel=0.016, segs=1)
    # Commander's hatch, right roof, under the remote weapon station.
    add_tube(bm, (0.52, -0.06 + oy, 0.78 + oz), (0.52, -0.06 + oy, 0.90 + oz), 0.20, TURRET, 10)
    # Low-profile CROWS over that hatch: cradle, 12.7 mm gun, sensor, ammunition box.
    rx, ry, rz = 0.52, -0.02 + oy, 0.98 + oz
    add_box(bm, (rx, ry, rz), (0.46, 0.58, 0.10), STEEL, bevel=0.008, segs=1)
    add_box(bm, (rx, ry + 0.06, rz + 0.10), (0.16, 0.28, 0.14), STEEL, bevel=0.004, segs=1)
    add_tube(bm, (rx, ry + 0.16, rz + 0.12), (rx, ry + 1.15, rz + 0.14), 0.018, STEEL, 6)
    add_box(bm, (rx + 0.16, ry + 0.10, rz + 0.12), (0.12, 0.16, 0.12), STEEL, bevel=0.0)
    add_box(bm, (rx + 0.16, ry + 0.19, rz + 0.12), (0.10, 0.02, 0.07), GLASS, bevel=0.0)
    add_box(bm, (rx - 0.20, ry - 0.02, rz + 0.08), (0.16, 0.22, 0.14), STEEL, bevel=0.0)
    # Gunner's primary sight: the armored doghouse on the right front roof.
    add_box(bm, (0.72, 0.92 + oy, 0.90 + oz), (0.28, 0.36, 0.16), STEEL, bevel=0.006, segs=1)
    add_box(bm, (0.72, 1.08 + oy, 0.96 + oz), (0.22, 0.06, 0.08), STEEL, bevel=0.0)
    add_box(bm, (0.72, 1.12 + oy, 0.90 + oz), (0.16, 0.02, 0.05), GLASS, bevel=0.0)
    # Commander's independent thermal viewer, in front of his hatch.
    add_box(bm, (0.22, 0.38 + oy, 0.90 + oz), (0.16, 0.18, 0.10), STEEL, bevel=0.004, segs=1)
    add_box(bm, (0.22, 0.38 + oy, 1.02 + oz), (0.12, 0.14, 0.08), STEEL, bevel=0.0)
    add_box(bm, (0.22, 0.46 + oy, 1.02 + oz), (0.08, 0.02, 0.05), GLASS, bevel=0.0)
    # Loader's hatch, periscope, and the shielded 7.62 mount on the left.
    add_box(bm, (-0.50, -0.18 + oy, 0.86 + oz), (0.36, 0.32, 0.05), TURRET, bevel=0.008, segs=1)
    add_box(bm, (-0.50, -0.02 + oy, 0.92 + oz), (0.10, 0.08, 0.05), STEEL, bevel=0.0)
    add_box(bm, (-0.50, 0.03 + oy, 0.92 + oz), (0.06, 0.015, 0.03), GLASS, bevel=0.0)
    add_box(bm, (-0.78, 0.15 + oy, 0.78 + oz), (0.04, 0.28, 0.22), STEEL, bevel=0.0, rot=(0, 0, 18))
    add_tube(bm, (-0.62, 0.22 + oy, 0.84 + oz), (-0.62, 0.85 + oy, 0.90 + oz), 0.012, STEEL, 5)
    # Ammunition data link. The real unit is a breech interface plus the fire-control
    # electronics inside the turret. The visible parts are this housing and the collar
    # on the barrel at the breech. No labels.
    add_box(bm, (0.40, 0.55 + oy, 0.90 + oz), (0.14, 0.16, 0.06), STEEL, bevel=0.003, segs=1)
    add_tube(bm, (0.18, 1.15 + oy, 0.55 + oz), (0.40, 0.62 + oy, 0.88 + oz), 0.012, STEEL, 4)
    # Blow-out panels on the bustle roof, then the storage basket.
    for k in range(2):
        add_box(bm, (-0.32 + k * 0.64, -1.40 + oy, 0.80 + oz), (0.46, 0.62, 0.02), DARK, bevel=0.0)
    add_box(bm, (0, -2.20 + oy, 0.50 + oz), (1.80, 0.85, 0.03), STEEL, bevel=0.0)
    for s in (-0.92, 0.92):
        add_box(bm, (s, -2.15 + oy, 0.52 + oz), (0.03, 1.00, 0.03), STEEL, bevel=0.0)
        add_box(bm, (s, -2.15 + oy, 0.82 + oz), (0.03, 1.00, 0.03), STEEL, bevel=0.0)
        add_box(bm, (s, -2.62 + oy, 0.67 + oz), (0.03, 0.03, 0.32), STEEL, bevel=0.0)
    add_box(bm, (0, -2.64 + oy, 0.82 + oz), (1.84, 0.03, 0.03), STEEL, bevel=0.0)
    add_box(bm, (0, -2.64 + oy, 0.52 + oz), (1.84, 0.03, 0.03), STEEL, bevel=0.0)
    for i in range(7):
        add_box(bm, (-0.75 + i * 0.25, -2.64 + oy, 0.67 + oz), (0.02, 0.02, 0.30), STEEL, bevel=0.0)
    add_box(bm, (-0.35, -2.05 + oy, 0.62 + oz), (0.50, 0.36, 0.16), CANVAS, bevel=0.015, segs=1)
    add_box(bm, (0.38, -1.95 + oy, 0.60 + oz), (0.42, 0.30, 0.14), CANVAS, bevel=0.015, segs=1)
    for s in (-1.0, 1.0):
        for k in range(6):
            add_tube(bm, (s * 1.18, 0.72 + oy + k * 0.07, 0.42 + oz),
                     (s * 1.28, 0.78 + oy + k * 0.07, 0.52 + oz), 0.028, STEEL, 5)
    add_tube(bm, (-0.72, -1.55 + oy, 0.80 + oz), (-0.72, -1.55 + oy, 1.55 + oz), 0.008, STEEL, 5)
    add_tube(bm, (0.78, -1.70 + oy, 0.80 + oz), (0.78, -1.70 + oy, 1.35 + oz), 0.008, STEEL, 5)
    orient(bm)
    return bm


def build_barrel():
    bm = new_bm()
    # Local to the trunnion, extending +Y. Length puts the muzzle 1.84 m past the nose.
    # The collar at the breech is the visible ammunition-data-link interface.
    add_tube(bm, (0, 0.0, 0), (0, 0.22, 0), 0.095, STEEL, 12)
    add_tube(bm, (0, 0.18, 0), (0, BARREL_LEN - 0.12, 0), 0.062, TURRET, 12)
    ev = BARREL_LEN * 0.58
    add_tube(bm, (0, ev - 0.28, 0), (0, ev + 0.28, 0), 0.115, TURRET, 12)
    for yv in (0.55, 1.35, 2.15, 3.05, 3.70):
        add_tube(bm, (0, yv, 0), (0, yv + 0.05, 0), 0.078, STEEL, 10)
    add_tube(bm, (0, BARREL_LEN - 0.16, 0), (0, BARREL_LEN, 0), 0.070, STEEL, 12)
    add_box(bm, (0.0, BARREL_LEN - 0.26, 0.085), (0.045, 0.09, 0.04), STEEL, bevel=0.0)
    orient(bm)
    return bm


# ---------------------------------------------------------------- plant (metres, front is +Y)
HALL = (8.4, 12.2, 5.2)  # full size, center at z = half height
FRONT_Y = HALL[1] * 0.5


def build_plant():
    bm = new_bm()
    hz = HALL[2] * 0.5
    # Large faces stay un-bevelled so each wall is one UV island at tank-level density.
    # The bevel read comes from the baked seam, not from a ring of sliver faces.
    add_box(bm, (0, 0, hz), HALL, CONCRETE, bevel=0.0)
    add_box(bm, (0, 0.2, 0.18), (10.4, 14.5, 0.36), CONCRETE, bevel=0.0)
    # pitched roof
    roof = []
    for x in (-4.35, 4.35):
        roof += [(x, -FRONT_Y - 0.15, 5.15), (x, FRONT_Y + 0.15, 5.15), (x, 0.0, 6.55)]
    add_convex(bm, roof, ROOF, bevel=0.0)
    add_box(bm, (0, -0.3, 6.55), (3.4, 8.0, 0.85), ROOF, bevel=0.0)
    for i in range(6):
        yv = -3.2 + i * 1.3
        add_box(bm, (0, yv, 7.02), (3.5, 0.08, 0.10), STEEL, bevel=0.0)
    # annex and its lower roof
    add_box(bm, (-5.7, -0.6, 1.75), (3.5, 7.2, 3.5), CONCRETE, bevel=0.0)
    add_box(bm, (-5.7, -0.6, 3.62), (3.8, 7.5, 0.22), ROOF, bevel=0.0)
    add_box(bm, (-5.7, -0.6, 3.85), (2.2, 4.0, 0.55), ROOF, bevel=0.0)
    add_box(bm, (0.4, FRONT_Y + 1.35, 0.55), (7.2, 2.5, 1.1), CONCRETE, bevel=0.0)
    # door and windows on the front face, proud of the wall so they don't z-fight
    add_box(bm, (-2.3, FRONT_Y + 0.02, 1.35), (1.7, 0.06, 2.5), CONCRETE, bevel=0.015, segs=1)
    add_box(bm, (-2.3, FRONT_Y + 0.08, 1.25), (1.15, 0.08, 2.05), DARK, bevel=0.0)
    for i, x in enumerate((-0.4, 1.3, 2.8)):
        add_box(bm, (x, FRONT_Y + 0.06, 3.15), (1.15, 0.08, 0.85), GLASS, bevel=0.008, segs=1)
        add_box(bm, (x, FRONT_Y + 0.10, 3.15), (0.95, 0.04, 0.62), DARK, bevel=0.0)
    # side windows
    for i in range(3):
        add_box(bm, (HALL[0] * 0.5 + 0.04, -2.5 + i * 2.2, 3.2), (0.08, 1.3, 0.8), GLASS, bevel=0.006, segs=1)
    # stacks
    def stack(x, y, h, r):
        add_tube(bm, (x, y, 0.4), (x, y, h), r, STACK, 12)
        add_tube(bm, (x, y, h - 0.05), (x, y, h + 0.35), r * 1.28, STEEL, 12)
        z = 2.2
        while z < h - 0.4:
            add_tube(bm, (x, y, z), (x, y, z + 0.14), r * 1.18, STEEL, 12)
            z += 3.1
    stack(3.15, -FRONT_Y - 0.9, 13.5, 0.52)
    stack(1.15, -FRONT_Y - 1.45, 10.5, 0.38)
    # pipes and a manifold
    add_tube(bm, (3.7, 2.5, 5.35), (3.7, -FRONT_Y - 0.2, 5.35), 0.13, PIPE, 8)
    add_tube(bm, (3.7, -FRONT_Y - 0.2, 5.35), (3.15, -FRONT_Y - 0.9, 9.5), 0.13, PIPE, 8)
    add_tube(bm, (2.4, -FRONT_Y - 0.4, 5.35), (1.15, -FRONT_Y - 1.45, 8.0), 0.10, PIPE, 8)
    add_tube(bm, (-3.2, FRONT_Y + 0.12, 4.15), (3.4, FRONT_Y + 0.12, 4.15), 0.09, PIPE, 8)
    add_tube(bm, (3.4, FRONT_Y + 0.12, 4.15), (3.7, 2.5, 5.35), 0.09, PIPE, 8)
    for x in (-1.2, 1.6):
        add_tube(bm, (x, FRONT_Y + 0.10, 4.15), (x, FRONT_Y + 0.10, 1.2), 0.07, PIPE, 7)
    # flanges
    add_tube(bm, (3.7, 0.2, 5.35), (3.7, 0.34, 5.35), 0.20, STEEL, 8)
    # ladder
    add_box(bm, (HALL[0] * 0.5 + 0.10, 2.2, 2.6), (0.06, 0.46, 4.6), STEEL, bevel=0.0)
    for i in range(8):
        add_box(bm, (HALL[0] * 0.5 + 0.10, 2.2, 0.6 + i * 0.55), (0.05, 0.40, 0.03), STEEL, bevel=0.0)
    # transformer yard and a short fence
    add_box(bm, (-2.4, -FRONT_Y - 1.6, 0.7), (1.4, 1.1, 1.2), STEEL, bevel=0.02, segs=1)
    add_box(bm, (-0.4, -FRONT_Y - 1.7, 0.55), (1.1, 0.8, 0.9), STEEL, bevel=0.015, segs=1)
    for i in range(5):
        add_box(bm, (-3.6 + i * 0.9, -FRONT_Y - 2.5, 0.7), (0.08, 0.08, 1.3), STEEL, bevel=0.0)
    add_box(bm, (-1.8, -FRONT_Y - 2.5, 1.25), (3.8, 0.05, 0.06), STEEL, bevel=0.0)
    add_box(bm, (-1.8, -FRONT_Y - 2.5, 0.7), (3.8, 0.05, 0.05), STEEL, bevel=0.0)
    # roof ribs so the slope reads in silhouette
    for i in range(7):
        yv = -4.6 + i * 1.45
        lift = 6.45 - abs(yv) / FRONT_Y * 1.25
        add_box(bm, (0, yv, lift + 0.08), (8.5, 0.08, 0.10), STEEL, bevel=0.0)
    orient(bm)
    return bm


def build_tree():
    """Trunk and stub limbs only. Foliage is separate crossed cards, not a cone."""
    bm = new_bm()
    add_tube(bm, (0, 0, 0.0), (0, 0, 0.85), 0.10, BARK, 8)
    add_tube(bm, (0, 0, 0.75), (0, 0, 1.45), 0.055, BARK, 6)
    for i, a in enumerate((0.3, 1.8, 3.4, 5.0)):
        z0 = 0.85 + (i % 2) * 0.25
        add_tube(bm, (0, 0, z0), (math.cos(a) * 0.42, math.sin(a) * 0.42, z0 + 0.38), 0.022, BARK, 5)
    orient(bm)
    return bm


def build_foliage():
    bm = new_bm()
    uv = bm.loops.layers.uv.new("UVMap")
    L = lay(bm)

    def card(center, right, up, w, h):
        c = Vector(center)
        r = Vector(right).normalized() * (w * 0.5)
        u = Vector(up).normalized() * (h * 0.5)
        vs = [bm.verts.new(p) for p in (c + r + u, c - r + u, c - r - u, c + r - u)]
        try:
            f = bm.faces.new(vs)
        except ValueError:
            return
        f[L] = NEEDLE
        coords = [(0.98, 0.98), (0.02, 0.98), (0.02, 0.02), (0.98, 0.02)]
        for lp, q in zip(f.loops, coords):
            lp[uv].uv = q

    for i, z in enumerate((1.15, 1.65, 2.15)):
        span = 1.55 - i * 0.38
        for k in range(4):
            a = k * math.tau / 4.0 + i * 0.4
            card((math.cos(a) * span * 0.12, math.sin(a) * span * 0.12, z),
                 (math.cos(a), math.sin(a), 0.0), (0.0, 0.05, 1.0), span, 0.95 - i * 0.12)
    return bm


def build_rock(seed, scale):
    """Angular stone, two variants. Facets stay large so the crack texture has room."""
    bm = new_bm()
    rng = np.random.default_rng(seed)
    pts = []
    for _i in range(11):
        v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.05, 1.2)))
        if v.length < 1e-3:
            continue
        v.x *= scale[0]
        v.y *= scale[1]
        v.z *= scale[2]
        pts.append((v.x, v.y, v.z))
    # a flat base so it sits on the snow
    pts += [(scale[0], scale[1] * 0.4, 0.0), (-scale[0], scale[1] * 0.3, 0.0),
            (0.0, -scale[1], 0.0), (scale[0] * 0.2, scale[1] * 0.2, scale[2] * 1.05)]
    add_convex(bm, pts, ROCK, bevel=0.0)
    orient(bm)
    return bm


def build_debris():
    """Loose chunks in plant-local metres, around the front wall impact."""
    bms = []
    specs = [
        ((0.2, FRONT_Y + 0.2, 2.5), (0.55, 0.28, 0.35), CONCRETE),
        ((-0.6, FRONT_Y + 0.15, 2.2), (0.35, 0.22, 0.5), CONCRETE),
        ((0.7, FRONT_Y + 0.25, 1.6), (0.4, 0.18, 0.22), CONCRETE),
        ((-0.2, FRONT_Y + 0.3, 2.9), (0.7, 0.12, 0.18), ROOF),
        ((0.4, FRONT_Y + 0.1, 1.1), (0.25, 0.25, 0.25), STEEL),
        ((-0.9, FRONT_Y + 0.2, 1.8), (0.3, 0.16, 0.4), CONCRETE),
    ]
    for c, sz, tag in specs:
        bm = new_bm()
        add_box(bm, c, sz, tag, bevel=0.02, segs=1, rot=(12, 8, 20))
        orient(bm)
        bms.append(bm)
    return bms


# ---------------------------------------------------------------- textures
def smoothstep(e0, e1, x):
    if e0 == e1:
        return 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def hash2(ix, iy):
    n = math.sin(ix * 127.1 + iy * 311.7) * 43758.5453
    return n - math.floor(n)


def vnoise(x, y):
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    return (hash2(x0, y0) * (1 - fx) * (1 - fy) + hash2(x0 + 1, y0) * fx * (1 - fy)
            + hash2(x0, y0 + 1) * (1 - fx) * fy + hash2(x0 + 1, y0 + 1) * fx * fy)


def fbm(x, y):
    return vnoise(x, y) * 0.62 + vnoise(x * 2.13 + 5.2, y * 2.13) * 0.28 + vnoise(x * 4.27 + 1.7, y * 4.27) * 0.10


def dist_point_seg(px, py, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby + 1e-8)))
    dx, dy = px - (ax + abx * t), py - (ay + aby * t)
    return math.hypot(dx, dy)


def seam_line(p, n, origin, direction, half_len, width):
    # distance from p to a segment, gated by the face normal roughly matching `n_gate` via caller
    o = Vector(origin)
    d = Vector(direction)
    if d.length < 1e-6:
        return 0.0
    d.normalize()
    rel = Vector(p) - o
    t = max(-half_len, min(half_len, rel.dot(d)))
    closest = o + d * t
    dist = (Vector(p) - closest).length
    return 1.0 - smoothstep(width * 0.35, width, dist)


FONT = {
    "3": ["1111", "0001", "0111", "0001", "1111"],
    "1": ["010", "110", "010", "010", "111"],
}


def glyph(ch, u, v):
    rows = FONT[ch]
    h, w = len(rows), len(rows[0])
    if u < 0 or v < 0 or u >= 1 or v >= 1:
        return 0.0
    c = int(u * w)
    r = int((1 - v) * h)
    if r < 0 or r >= h or c < 0 or c >= w:
        return 0.0
    return 1.0 if rows[r][c] == "1" else 0.0


def shade_tank(p, n, tag):
    p = Vector(p)
    n = Vector(n).normalized()
    if tag == GLASS:
        col, rough, metal = (0.05, 0.07, 0.09), 0.12, 0.55
    elif tag == RUBBER:
        col, rough, metal = (0.07, 0.07, 0.075), 0.92, 0.0
    elif tag == STEEL:
        col, rough, metal = (0.20, 0.20, 0.21), 0.66, 0.32
    elif tag == DARK:
        col, rough, metal = (0.05, 0.05, 0.052), 0.78, 0.08
    elif tag == CANVAS:
        col, rough, metal = (0.32, 0.29, 0.22), 0.90, 0.0
    elif tag == JERRY:
        col, rough, metal = (0.28, 0.30, 0.22), 0.78, 0.02
    elif tag == TURRET:
        # Dull matte tan. Roughness stays high so the paint does not flash.
        col, rough, metal = (0.36, 0.31, 0.21), 0.92, 0.0
    else:
        col, rough, metal = (0.33, 0.28, 0.19), 0.93, 0.0
    height = 0.0
    seam = 0.0
    # Authored panel seams (metres), not a noise lattice.
    if tag in (PAINT, TURRET) and abs(n.x) > 0.65:
        for yv in (-2.4, -1.45, -0.5, 0.45, 1.4, 2.35):
            seam = max(seam, seam_line(p, n, (0, yv, 0.9), (0, 0, 1), 0.7, 0.018))
        for zv in (0.78, 1.15, 1.48):
            seam = max(seam, seam_line(p, n, (0, 0.2, zv), (0, 1, 0), 3.2, 0.016))
        # bolt row on the skirt band
        if 0.45 < p.z < 0.95:
            fy = (p.y + 2.6) / 0.42
            if abs(fy - round(fy)) < 0.08 and abs(p.z - 0.78) < 0.03:
                seam = max(seam, 1.0)
                col = mix(col, (0.12, 0.12, 0.12), 0.7)
    if tag == TURRET and n.z > 0.7:
        # hatch outlines and blow-out seams on the roof
        for cx, cy, hx, hy in ((0.52, 0.04, 0.22, 0.22), (-0.50, -0.08, 0.20, 0.18),
                               (-0.32, -1.30, 0.26, 0.34), (0.32, -1.30, 0.26, 0.34)):
            dx, dy = abs(p.x - cx), abs(p.y - cy)
            border = min(abs(dx - hx), abs(dy - hy)) if dx < hx + 0.03 and dy < hy + 0.03 else 1.0
            if dx < hx and dy < hy:
                border = min(hx - dx, hy - dy)
            seam = max(seam, 1.0 - smoothstep(0.008, 0.028, border))
    if tag == PAINT and n.z > 0.75:
        for yv in (-0.4, -1.7, 1.0):
            seam = max(seam, seam_line(p, n, (0, yv, 1.6), (1, 0, 0), 1.4, 0.016))
        seam = max(seam, seam_line(p, n, (0, -2.7, 1.5), (1, 0, 0), 0.7, 0.02))  # grille frame
    if tag in (PAINT, TURRET) and n.y > 0.6:
        seam = max(seam, seam_line(p, n, (0, 3.4, 1.15), (1, 0, 0), 1.2, 0.016))
    # tactical number on the right cheek, star on the left. Original pixel glyphs.
    if tag == TURRET and n.x > 0.75 and 0.05 < p.y < 0.85 and 1.72 < p.z < 2.15:
        u = (p.y - 0.05) / 0.80
        v = (p.z - 1.72) / 0.43
        ink = max(glyph("3", (u - 0.15) / 0.28, v), glyph("1", (u - 0.52) / 0.22, v))
        if ink:
            col = mix(col, (0.10, 0.10, 0.09), 0.85)
    if tag == TURRET and n.x < -0.75 and 0.0 < p.y < 0.80 and 1.72 < p.z < 2.15:
        u = p.y / 0.80
        v = (p.z - 1.72) / 0.43
        # five-point star test in the decal square
        if 0.15 < u < 0.85 and 0.1 < v < 0.9:
            ang = math.atan2(v - 0.5, u - 0.5)
            rad = math.hypot(u - 0.5, v - 0.5)
            star = 0.22 + 0.12 * abs(math.cos(ang * 2.5))
            if rad < star:
                col = mix(col, (0.12, 0.12, 0.11), 0.75)
    # restrained streaks under the bustle, three authored lines
    if tag == TURRET and abs(n.x) > 0.7:
        for yv in (-1.15, -0.7, 0.15):
            if abs(p.y - yv) < 0.012 and 1.55 < p.z < 2.05:
                col = mix(col, (0.28, 0.24, 0.18), 0.45)
    # The barrel is baked in trunnion-local space, so it sits near the origin.
    # Keep the sleeve the same matte tan and skip the hull mud, which would
    # otherwise cover the whole gun.
    on_gun = tag == TURRET and abs(p.x) < 0.14 and abs(p.z) < 0.14 and 0.15 < p.y < BARREL_LEN + 0.05
    if on_gun:
        if abs(p.x) < 0.012 and p.z > 0.02:
            col = mix(col, (0.10, 0.09, 0.07), 0.7)
            height -= 0.45
        if seam > 0:
            col = mix(col, (col[0] * 0.25, col[1] * 0.25, col[2] * 0.25), min(1.0, seam))
        return col, rough, metal, height
    # mud, snow dust, soot
    if tag in (PAINT, TURRET, RUBBER, CANVAS) and p.z < 0.7:
        mud = smoothstep(0.72, 0.32, p.z)
        col = mix(col, (0.14, 0.11, 0.08), mud * (0.85 if tag != TURRET else 0.4))
        rough = rough + (0.92 - rough) * mud * 0.6
    if n.z > 0.84 and tag in (PAINT, TURRET, CANVAS):
        snow = smoothstep(0.84, 0.98, n.z) * 0.14
        col = mix(col, (0.46, 0.48, 0.50), snow)
        rough = min(1.0, rough + 0.02)
    if tag == PAINT and p.y < -3.3 and n.y < -0.4:
        col = mix(col, (0.08, 0.07, 0.07), 0.65)
    if tag == DARK:
        col = mix(col, (0.02, 0.02, 0.02), 0.4)
    # paint break-up, very low, only so a flat fill doesn't read as plastic
    if tag in (PAINT, TURRET, CANVAS):
        g = (fbm(p.x * 2.4, p.y * 2.4) - 0.62) * 0.07
        col = (max(0, min(1, col[0] + g)), max(0, min(1, col[1] + g)), max(0, min(1, col[2] + g * 0.6)))
    if seam > 0:
        col = mix(col, (col[0] * 0.25, col[1] * 0.25, col[2] * 0.25), min(1.0, seam))
        height -= seam * 0.9
        rough = min(1.0, rough + seam * 0.15)
    # edge wear: bright metal only where a seam is fading out (the lip, not the gap)
    if 0.25 < seam < 0.65 and tag in (PAINT, TURRET):
        col = mix(col, (0.40, 0.36, 0.28), 0.22)
        metal = max(metal, 0.12)
        rough = min(1.0, rough)
    return col, rough, metal, height


def shade_plant(p, n, tag):
    p = Vector(p)
    n = Vector(n).normalized()
    if tag == GLASS or tag == DARK:
        col, rough, metal = ((0.07, 0.09, 0.11) if tag == GLASS else (0.05, 0.05, 0.055)), 0.18 if tag == GLASS else 0.75, 0.45 if tag == GLASS else 0.1
    elif tag == ROOF:
        col, rough, metal = (0.40, 0.44, 0.48), 0.62, 0.28
    elif tag == STACK:
        col, rough, metal = (0.48, 0.50, 0.52), 0.7, 0.22
    elif tag == PIPE or tag == STEEL:
        col, rough, metal = (0.34, 0.36, 0.38), 0.48, 0.6
    else:
        col, rough, metal = (0.56, 0.57, 0.59), 0.88, 0.02
    height = 0.0
    seam = 0.0
    if tag == CONCRETE and abs(n.z) < 0.6:
        for x0 in (-2.8, 0.0, 2.8):
            seam = max(seam, seam_line(p, n, (x0, 0, 2.5), (0, 0, 1), 2.4, 0.045))
        for y0 in (-4.0, -1.5, 1.5, 4.0):
            seam = max(seam, seam_line(p, n, (0, y0, 2.5), (0, 0, 1), 2.4, 0.045))
        for z0 in (1.6, 3.3, 4.6):
            seam = max(seam, seam_line(p, n, (0, 0, z0), (1, 0, 0), 5.0, 0.04))
            seam = max(seam, seam_line(p, n, (0, 0, z0), (0, 1, 0), 6.0, 0.04))
    if tag == ROOF:
        # corrugation across the slope
        wave = abs(math.sin(p.x * 18.0))
        if wave > 0.82:
            seam = max(seam, (wave - 0.82) / 0.18)
            height += (wave - 0.82) * 0.4
        col = mix(col, (0.30, 0.33, 0.36), seam * 0.35)
    if tag == STACK:
        if p.z > 8.5:
            col = mix(col, (0.14, 0.13, 0.13), smoothstep(8.5, 12.5, p.z) * 0.75)
        if p.z < 2.2:
            col = mix(col, (0.42, 0.30, 0.24), smoothstep(2.2, 0.4, p.z) * 0.45)
            rough = min(1.0, rough + 0.1)
    if tag == CONCRETE and n.z > 0.8 and p.z < 0.6:
        col = mix(col, (0.40, 0.38, 0.36), 0.25)  # dock dirt
    if n.z > 0.75 and tag in (CONCRETE, ROOF):
        snow = smoothstep(0.75, 0.96, n.z) * (0.45 if tag == ROOF else 0.3)
        col = mix(col, (0.80, 0.83, 0.86), snow)
    if tag in (CONCRETE, ROOF):
        g = (fbm(p.x * 1.4, p.y * 1.4) - 0.5) * 0.035
        col = tuple(max(0, min(1, c + g)) for c in col)
    if seam > 0 and tag == CONCRETE:
        col = mix(col, (col[0] * 0.35, col[1] * 0.35, col[2] * 0.35), min(1, seam))
        height -= seam * 0.8
    return col, rough, metal, height


def shade_prop(p, n, tag):
    p = Vector(p)
    n = Vector(n).normalized()
    height = 0.0
    if tag == BARK:
        col, rough, metal = (0.28, 0.24, 0.20), 0.9, 0.0
    elif tag == NEEDLE:
        col, rough, metal = (0.20, 0.32, 0.24), 0.85, 0.0
    else:
        col, rough, metal = (0.50, 0.52, 0.55), 0.9, 0.02
    if tag == ROCK:
        crack = abs(math.sin(p.x * 22.0 + p.y * 9.0))
        if crack > 0.86:
            col = mix(col, (0.18, 0.19, 0.20), 0.65)
            height = -0.7
        grain = (fbm(p.x * 6.0, p.z * 6.0) - 0.5) * 0.06
        col = tuple(max(0, min(1, c + grain)) for c in col)
    if n.z > 0.55 and tag == ROCK:
        col = mix(col, (0.84, 0.87, 0.90), smoothstep(0.55, 0.92, n.z) * 0.7)
    if tag == BARK and p.z < 0.15:
        col = mix(col, (0.18, 0.16, 0.13), 0.4)
    if tag == BARK:
        if abs(math.sin(p.z * 40.0 + p.x * 8.0)) > 0.85:
            height -= 0.3
            col = mix(col, (0.16, 0.13, 0.11), 0.35)
    return col, rough, metal, height


def _dissolve_flat(bm):
    """Merge coplanar splits so a hull side is one island, not a fan of slivers."""
    if not bm.faces:
        return
    L = lay(bm)
    for f in bm.faces:
        f.material_index = int(f[L])
    try:
        bmesh.ops.dissolve_limit(
            bm, angle_limit=math.radians(20.0), use_dissolve_boundaries=False,
            verts=list(bm.verts), edges=list(bm.edges), delimit={"MATERIAL"})
    except Exception as ex:
        print("dissolve skipped", ex)


# Overlapping UVs for bolts, wheel segments and other tiny parts.
SWATCH_RECT = {
    RUBBER: (0.01, 0.01, 0.16, 0.16),
    STEEL: (0.18, 0.01, 0.34, 0.16),
    GLASS: (0.36, 0.01, 0.48, 0.12),
    DARK: (0.50, 0.01, 0.64, 0.12),
    PIPE: (0.18, 0.01, 0.34, 0.16),
    CONCRETE: (0.66, 0.01, 0.82, 0.16),
    ROOF: (0.84, 0.01, 0.98, 0.10),
    STACK: (0.84, 0.10, 0.98, 0.16),
}


def _assign_swatch(face, uv, rect):
    for lp in face.loops:
        co = lp.vert.co
        u = rect[0] + (abs(math.sin(co.x * 1.7 + co.y * 0.4)) ) * (rect[2] - rect[0]) * 0.85
        v = rect[1] + (abs(math.sin(co.z * 2.1 + co.y * 0.3)) ) * (rect[3] - rect[1]) * 0.85
        lp[uv].uv = (u, v)


def pack_faces(bms, size, pad, y0, swatch_area=SWATCH_AREA, max_ppm=220.0):
    for bm in bms:
        _dissolve_flat(bm)
    items = []
    swatched = 0
    for bm in bms:
        uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
        L = lay(bm)
        for f in list(bm.faces):
            area = f.calc_area()
            if area < 1e-8:
                continue
            tag = int(f[L])
            # Undersides are never seen. Tires, bolts, pipes and small panels share a tile.
            # The big wall and roof faces keep unique islands.
            hidden = f.normal.z < -0.45
            if tag in SWATCH_RECT and (hidden or area < swatch_area or tag in (PIPE, STEEL, GLASS, DARK, RUBBER)):
                _assign_swatch(f, uv, SWATCH_RECT[tag])
                swatched += 1
                continue
            n = f.normal
            t = n.cross(Vector((0, 0, 1)))
            if t.length < 0.15:
                t = n.cross(Vector((1, 0, 0)))
            t.normalize()
            b = n.cross(t).normalized()
            pts = [(lp.vert.co.dot(t), lp.vert.co.dot(b)) for lp in f.loops]
            items.append((bm, f, uv, pts))
    print("  swatch faces", swatched, "unique", len(items))
    lo, hi = 2.0, float(max_ppm)
    best = None
    y_limit = int(size * 0.80)  # bottom band is the shared swatches
    for _ in range(22):
        ppm = (lo + hi) * 0.5
        x = y = 0
        sh = 0
        y = y0
        placed = []
        ok = True
        for bm, f, uv, pts in items:
            minx = min(p[0] for p in pts)
            maxx = max(p[0] for p in pts)
            miny = min(p[1] for p in pts)
            maxy = max(p[1] for p in pts)
            w = max(2, int(math.ceil((maxx - minx) * ppm)) + 2)
            h = max(2, int(math.ceil((maxy - miny) * ppm)) + 2)
            if x + w + pad > size:
                x = 0
                y += sh + pad
                sh = 0
            if y + h + pad > y_limit:
                ok = False
                break
            placed.append((bm, f, uv, pts, minx, miny, maxx, maxy, x, y, w, h))
            x += w + pad
            sh = max(sh, h)
        if ok:
            best = (ppm, placed)
            lo = ppm
        else:
            hi = ppm
    if best is None:
        raise RuntimeError("UV pack failed")
    ppm, placed = best
    for bm, f, uv, pts, minx, miny, maxx, maxy, px, py, w, h in placed:
        spanx = max(maxx - minx, 1e-6)
        spany = max(maxy - miny, 1e-6)
        for lp, (pu, pv) in zip(f.loops, pts):
            u = (px + 1 + (pu - minx) / spanx * (w - 2)) / size
            v = 1.0 - (py + 1 + (pv - miny) / spany * (h - 2)) / size
            lp[uv].uv = (u, v)
    print("  packed %d faces at %.1f px/unit" % (len(placed), ppm))
    return ppm


def ao_dirs(n):
    dirs = []
    for i in range(n):
        u = (i + 0.5) / n
        a = i * 2.39996323
        r = math.sqrt(u)
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1.0 - u)))))
    return dirs


DIRS = ao_dirs(RAYS)


def basis(n):
    n = n.normalized()
    a = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    t = n.cross(a).normalized()
    b = n.cross(t).normalized()
    return t, b, n


def ao_at(bvh, pos, normal):
    if SKIP_AO:
        return 0.72
    t, b, nrm = basis(normal)
    origin = pos + nrm * 0.03
    hit = 0
    for d in DIRS:
        direction = (t * d.x + b * d.y + nrm * d.z).normalized()
        loc, _, _, dist = bvh.ray_cast(origin, direction, 3.0)
        if loc is None:
            hit += 1
    return hit / float(len(DIRS))


def make_bvh(bms, ground_z=0.0, span=40.0):
    verts = []
    polys = []
    for bm in bms:
        bm.verts.index_update()
        bm.faces.index_update()
        base = len(verts)
        for v in bm.verts:
            verts.append(v.co.copy())
        for f in bm.faces:
            polys.append([base + v.index for v in f.verts])
    base = len(verts)
    verts += [Vector((-span, -span, ground_z)), Vector((span, -span, ground_z)),
              Vector((span, span, ground_z)), Vector((-span, span, ground_z))]
    polys.append([base, base + 1, base + 2, base + 3])
    return BVHTree.FromPolygons(verts, polys)


def tri_ao_grid(bvh, a, b, c, n, spacing):
    area = (b - a).cross(c - a).length * 0.5
    N = max(1, int(math.sqrt(max(area, 1e-8)) / spacing))
    N = min(N, 18)
    grid = np.ones((N + 1, N + 1), np.float32)
    for i in range(N + 1):
        for j in range(N + 1 - i):
            w1 = i / N
            w2 = j / N
            w0 = 1.0 - w1 - w2
            p = a * w0 + b * w1 + c * w2
            grid[i, j] = ao_at(bvh, p, n)
    return grid


def bake(bms, size, spacing, shade, prefix, reserve_px=0, swatch_area=SWATCH_AREA, max_ppm=220.0):
    t0 = time.time()
    print("bake", prefix, "px", size)
    for bm in bms:
        orient(bm)
    ppm = pack_faces(bms, size, pad=4, y0=reserve_px, swatch_area=swatch_area, max_ppm=max_ppm)
    bvh = make_bvh(bms)
    albedo = np.zeros((size, size, 3), np.float32)
    orm = np.zeros((size, size, 3), np.float32)
    orm[..., 0] = 1.0
    orm[..., 1] = 1.0
    height = np.zeros((size, size), np.float32)
    mask = np.zeros((size, size), np.bool_)
    tris = 0
    samples = 0
    for bm in bms:
        uv = bm.loops.layers.uv.get("UVMap")
        L = lay(bm)
        for f in bm.faces:
            loops = list(f.loops)
            if len(loops) < 3:
                continue
            tag0 = int(f[L])
            if tag0 in SWATCH_RECT and (f.normal.z < -0.45 or f.calc_area() < swatch_area or tag0 in (PIPE, STEEL, GLASS, DARK, RUBBER)):
                continue
            n = f.normal.copy()
            tag = f[L]
            for i in range(1, len(loops) - 1):
                tri = (loops[0], loops[i], loops[i + 1])
                cos = [lp.vert.co.copy() for lp in tri]
                pxs = [lp[uv].uv[0] * (size - 1) for lp in tri]
                pys = [(1.0 - lp[uv].uv[1]) * (size - 1) for lp in tri]
                grid = tri_ao_grid(bvh, cos[0], cos[1], cos[2], n, spacing)
                samples += int(np.count_nonzero(grid) or grid.size)
                N = grid.shape[0] - 1
                minx = max(0, int(min(pxs)) - 1)
                maxx = min(size - 1, int(max(pxs)) + 1)
                miny = max(0, int(min(pys)) - 1)
                maxy = min(size - 1, int(max(pys)) + 1)
                if maxx <= minx or maxy <= miny:
                    continue
                den = (pys[1] - pys[2]) * (pxs[0] - pxs[2]) + (pxs[2] - pxs[1]) * (pys[0] - pys[2])
                if abs(den) < 1e-6:
                    continue
                xs = np.arange(minx, maxx + 1) + 0.5
                ys = np.arange(miny, maxy + 1) + 0.5
                X, Y = np.meshgrid(xs, ys)
                w0 = ((pys[1] - pys[2]) * (X - pxs[2]) + (pxs[2] - pxs[1]) * (Y - pys[2])) / den
                w1 = ((pys[2] - pys[0]) * (X - pxs[2]) + (pxs[0] - pxs[2]) * (Y - pys[2])) / den
                w2 = 1.0 - w0 - w1
                m = (w0 >= -0.002) & (w1 >= -0.002) & (w2 >= -0.002)
                if not np.any(m):
                    continue
                jj, ii = np.nonzero(m)
                for ky, kx in zip(jj, ii):
                    a0 = float(w0[ky, kx])
                    a1 = float(w1[ky, kx])
                    a2 = float(w2[ky, kx])
                    pos = cos[0] * a0 + cos[1] * a1 + cos[2] * a2
                    col, rough, metal, h = shade(pos, n, tag)
                    gi = min(N, max(0, int(round(a1 * N))))
                    gj = min(N, max(0, int(round(a2 * N))))
                    if gi + gj > N and gi + gj > 0:
                        scale = N / float(gi + gj)
                        gi = int(gi * scale)
                        gj = int(gj * scale)
                    ao = float(grid[gi, gj])
                    # The coarse ray grid stair-steps on big panels. Clamp the
                    # floor so that error cannot paint a chevron, and keep only
                    # a little darkening where the rays really found a crevice.
                    ao = 0.78 + 0.22 * ao
                    col = tuple(c * (0.86 + 0.14 * ao) for c in col)
                    py = miny + int(ky)
                    px = minx + int(kx)
                    albedo[py, px] = col
                    orm[py, px, 0] = ao
                    orm[py, px, 1] = rough
                    orm[py, px, 2] = metal
                    height[py, px] = h
                    mask[py, px] = True
                tris += 1
    albedo, mask = dilate(albedo, mask, 6)
    orm, _ = dilate(orm, mask, 4)
    height, _ = dilate(height[..., None], mask, 4)
    height = height[..., 0]
    _paint_swatches(albedo, orm, height, mask, size)
    normal = height_to_normal(height, strength=2.2)
    # neutral fill
    albedo[~mask] = 0.2
    save_png(prefix + "_albedo.png", albedo)
    save_png(prefix + "_normal.png", normal)
    save_png(prefix + "_orm.png", orm)
    print("  %s tris %d in %.1fs (ppm %.1f)" % (os.path.basename(prefix), tris, time.time() - t0, ppm))
    return albedo, mask


def _paint_swatches(albedo, orm, height, mask, size):
    """Authored tiles for the small parts that share UVs (tires, bolts, glass, grilles)."""
    h, w, _ = albedo.shape
    y1 = h - 1
    y0 = int(h * 0.82)

    def rect(u0, u1):
        return int(u0 * w), int(u1 * w)

    def fill(x0, x1, color, rough, metal, ao=0.7):
        albedo[y0:y1, x0:x1] = color
        orm[y0:y1, x0:x1, 0] = ao
        orm[y0:y1, x0:x1, 1] = rough
        orm[y0:y1, x0:x1, 2] = metal
        mask[y0:y1, x0:x1] = True
        height[y0:y1, x0:x1] = 0.0

    a, b = rect(0.01, 0.16)
    fill(a, b, (0.07, 0.07, 0.075), 0.92, 0.0, 0.62)
    # two circumferential grooves so a tire isn't a flat black cylinder
    for frac in (0.30, 0.62):
        yy = y0 + int((y1 - y0) * frac)
        albedo[yy:yy + 2, a:b] = (0.02, 0.02, 0.02)
        height[yy:yy + 2, a:b] = -0.8
    c, d = rect(0.18, 0.34)
    fill(c, d, (0.20, 0.20, 0.21), 0.66, 0.32, 0.62)
    for x in range(c + 4, d, 14):
        albedo[y0:y1, x:x + 1] *= 0.75
        height[y0:y1, x:x + 1] = -0.35
    e, f = rect(0.36, 0.48)
    fill(e, f, (0.05, 0.07, 0.09), 0.12, 0.55, 0.9)
    g, hh = rect(0.50, 0.64)
    fill(g, hh, (0.04, 0.04, 0.045), 0.72, 0.12, 0.4)
    c0, c1 = rect(0.66, 0.82)
    fill(c0, c1, (0.56, 0.57, 0.59), 0.88, 0.02, 0.72)
    for x in range(c0 + 6, c1, 18):
        albedo[y0:y1, x:x + 2] *= 0.55
        height[y0:y1, x:x + 2] = -0.6
    r0, r1 = rect(0.84, 0.98)
    mid = (y0 + y1) // 2
    fill(r0, r1, (0.40, 0.44, 0.48), 0.62, 0.28, 0.7)
    albedo[mid:y1, r0:r1] = (0.42, 0.40, 0.38)  # lower half of that tile reads as stack soot
    height[y0 + 4:y0 + 6, r0:r1] = 0.4


def dilate(img, mask, iters):
    a = img.copy()
    m = mask.copy()
    single = a.ndim == 2
    if single:
        a = a[..., None]
    h, w = m.shape
    for _ in range(iters):
        acc = np.zeros_like(a)
        wgt = np.zeros((h, w, 1), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(a, dy, 0), dx, 1)
            sm = np.roll(np.roll(m, dy, 0), dx, 1)
            if dy == 1:
                sm[0, :] = False
            elif dy == -1:
                sm[-1, :] = False
            if dx == 1:
                sm[:, 0] = False
            elif dx == -1:
                sm[:, -1] = False
            sel = sm & (~m)
            acc += shifted * sel[..., None]
            wgt += sel[..., None].astype(np.float32)
        take = wgt[..., 0] > 0
        a[take] = acc[take] / wgt[take]
        m = m | take
    if single:
        a = a[..., 0]
    return a, m


def height_to_normal(h, strength):
    du = np.zeros_like(h)
    dv = np.zeros_like(h)
    du[:, 1:-1] = h[:, 2:] - h[:, :-2]
    dv[1:-1, :] = h[:-2, :] - h[2:, :]  # image row 0 is UV top, so +v is -row
    nx = -du * strength
    ny = dv * strength
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-8
    return np.stack((nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5), axis=-1)


def save_png(path, arr):
    arr = np.clip(arr, 0.0, 1.0).astype(np.float32)
    if arr.ndim == 2:
        arr = np.stack([arr, arr, arr], axis=-1)
    h, w, c = arr.shape
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :c] = arr[..., :c]
    rgba = np.flipud(rgba)
    name = os.path.basename(path)
    # Byte buffer so the PNG is 8-bit. A float image saves as 16-bit and
    # blows the review folder up for no visible gain.
    im = bpy.data.images.new(name, width=w, height=h, alpha=(c == 4), float_buffer=False)
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    print("  wrote", path, os.path.getsize(path))


def paint_reserve(path_albedo, path_orm, size, reserve_px):
    """Rubble and interior swatch in the top band, shared by debris and the wreck hole."""
    # images already saved; reload via numpy by re-reading is awkward. Fill before dilate instead.
    pass


def tread_image(path):
    s = 256
    img = np.zeros((s, s, 3), np.float32)
    rough = np.full((s, s), 0.9, np.float32)
    metal = np.zeros((s, s), np.float32)
    height = np.zeros((s, s), np.float32)
    img[:] = (0.09, 0.09, 0.095)
    # end connectors (tile along V)
    img[:18, :] = (0.28, 0.29, 0.30)
    img[-18:, :] = (0.28, 0.29, 0.30)
    metal[:18, :] = 0.7
    metal[-18:, :] = 0.7
    rough[:18, :] = 0.45
    rough[-18:, :] = 0.45
    height[:18, :] = 0.3
    height[-18:, :] = 0.3
    # chevron pads
    yy, xx = np.mgrid[0:s, 0:s]
    chev = np.abs((xx - 128) * 0.55 + (yy - 128)) 
    pad = (yy > 40) & (yy < 216) & (np.abs(xx - 128) < 90) & (((yy + xx) // 14) % 2 == 0)
    img[pad] = (0.16, 0.16, 0.15)
    height[pad] = 0.45
    # center guide groove
    groove = np.abs(xx - 128) < 10
    img[groove] *= 0.45
    height[groove] = -0.5
    # bolt holes on the connectors
    for x in range(24, 240, 32):
        img[6:13, x - 3:x + 3] = 0.04
        img[-13:-6, x - 3:x + 3] = 0.04
    orm = np.stack([np.full((s, s), 0.78, np.float32), rough, metal], -1)
    save_png(path, img)
    save_png(path.replace(".png", "_n.png"), height_to_normal(height, 3.0))
    # tread uses albedo + normal only; roughness is constant in the material
    return path


def scorch_image(path):
    s = 256
    yy, xx = np.mgrid[0:s, 0:s]
    u = (xx + 0.5) / s * 2 - 1
    v = (yy + 0.5) / s * 2 - 1
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    wobble = 0.08 * np.sin(ang * 5) + 0.05 * np.sin(ang * 9 + 1.2)
    edge = 0.78 + wobble
    alpha = np.clip(1.0 - smoothstep_np(edge - 0.18, edge, r), 0, 1)
    # inner char, outer soot
    char = np.clip(1.0 - r / 0.45, 0, 1)
    rgb = np.zeros((s, s, 3), np.float32)
    rgb[..., 0] = 0.05 + 0.08 * (1 - char)
    rgb[..., 1] = 0.04 + 0.05 * (1 - char)
    rgb[..., 2] = 0.035 + 0.04 * (1 - char)
    rgba = np.dstack([rgb, alpha.astype(np.float32)])
    save_png(path, rgba)


def smoothstep_np(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-8), 0, 1)
    return t * t * (3 - 2 * t)


def _hash2(ix, iy):
    n = np.sin(ix.astype(np.float64) * 127.1 + iy.astype(np.float64) * 311.7) * 43758.5453
    return n - np.floor(n)


def _vnoise(x, y):
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    ix = x0.astype(np.int32)
    iy = y0.astype(np.int32)
    return (_hash2(ix, iy) * (1 - fx) * (1 - fy) + _hash2(ix + 1, iy) * fx * (1 - fy)
            + _hash2(ix, iy + 1) * (1 - fx) * fy + _hash2(ix + 1, iy + 1) * fx * fy)


def _fbm(x, y):
    return (_vnoise(x, y) * 0.62 + _vnoise(x * 2.13 + 5.2, y * 2.13) * 0.28
            + _vnoise(x * 4.2 + 1.7, y * 4.2) * 0.10)


def ground_images():
    size = GROUND_PX
    half = FIELD_HALF
    xs = np.linspace(-half, half, size)
    ys = np.linspace(half, -half, size)
    X, Y = np.meshgrid(xs, ys)
    # path in blender XY matching the tank's godot route (godot z = -blender y)
    # tank godot start (-9, z=2.2) -> blender (-9, -2.2); end (-1.4, z=0.5) -> (-1.4, -0.5)
    ax, ay, bx, by = -16.0, -3.0, -1.2, -0.4
    dx, dy = bx - ax, by - ay
    ln = math.hypot(dx, dy) or 1.0
    px, py = -dy / ln, dx / ln  # perpendicular
    off = 0.42
    d1 = dist_field(X, Y, ax + px * off, ay + py * off, bx + px * off, by + py * off)
    d2 = dist_field(X, Y, ax - px * off, ay - py * off, bx - px * off, by - py * off)
    groove = np.maximum(smoothstep_np(1.15, 0.12, d1), smoothstep_np(1.15, 0.12, d2))
    corridor = smoothstep_np(6.0, 0.9, np.minimum(d1, d2))
    # a second churned track so the field is not one stripe on an empty slab
    spur = smoothstep_np(1.8, 0.3, dist_field(X, Y, -10.0, 8.0, 10.0, -6.0))
    pad = smoothstep_np(4.6, 2.0, np.sqrt((X - 6.4) ** 2 + Y ** 2))
    # Broad rolls. A ridge sits in the RTS camera's middle distance (blender +Y
    # is Godot -Z, which that camera looks toward). The tank's lane stays flat.
    h = 1.7 * (_fbm(X * 0.022 + 1.2, Y * 0.022) - 0.42)
    h = h + 0.38 * (_fbm(X * 0.06 + 3.0, Y * 0.06) - 0.5)
    berm = np.exp(-((Y - 11.0) ** 2) / 14.0) * smoothstep_np(40.0, 6.0, np.abs(X + 2.0))
    h = h + berm * 1.25
    lane = smoothstep_np(2.4, 0.45, np.minimum(d1, d2))
    h = h * (1.0 - pad * 0.94) * (1.0 - lane * 0.92) - 0.09 * groove
    snow = np.array([0.62, 0.66, 0.70], np.float32)
    dirt = np.array([0.34, 0.24, 0.15], np.float32)
    mud = np.array([0.07, 0.05, 0.035], np.float32)
    conc = np.array([0.40, 0.39, 0.37], np.float32)
    nA = _fbm(X * 0.045, Y * 0.045)
    nB = _fbm(X * 0.09 + 4.0, Y * 0.08)
    patch = np.clip(smoothstep_np(0.30, 0.52, nA) * 0.9 + smoothstep_np(0.48, 0.68, nB) * 0.65, 0.0, 1.0)
    alb = snow * (1.0 - patch)[..., None] + dirt * patch[..., None]
    # Dirt under the fight, but not so wide that the frame becomes one tone.
    battle = smoothstep_np(16.0, 5.0, np.sqrt((X + 4.0) ** 2 + (Y + 1.0) ** 2))
    alb = alb * (1.0 - battle[..., None] * 0.45) + dirt * (battle[..., None] * 0.45)
    # Wide wet ruts, dark enough to read from the RTS camera.
    mud_band = np.clip(smoothstep_np(3.4, 0.35, np.minimum(d1, d2)) * 0.95 + groove * 0.85 + spur * 0.55, 0.0, 1.0)
    alb = alb * (1.0 - mud_band[..., None]) + mud * mud_band[..., None]
    alb = alb * (1.0 - pad[..., None] * 0.75) + conc * (pad[..., None] * 0.75)
    # shade the low ground so the rolls read even before the sun
    alb = alb * (0.78 + 0.22 * np.clip(h * 0.7 + 0.55, 0.0, 1.0))[..., None]
    alb = np.clip(alb, 0.0, 1.0)
    hf = h - groove * 0.10
    save_png(os.path.join(OUT, "ground_albedo.png"), alb)
    save_png(os.path.join(OUT, "ground_normal.png"), height_to_normal(hf * 16.0, 1.45))
    rough = np.full(h.shape, 0.90, np.float32)
    rough = np.clip(rough + patch * 0.06 - mud_band * 0.40, 0.34, 0.98)
    cav = np.clip(1.0 - groove * 0.75 - np.clip(-hf, 0, 1) * 0.45, 0.15, 1.0)
    orm = np.stack([cav, rough, np.zeros_like(h)], axis=-1)
    save_png(os.path.join(OUT, "ground_orm.png"), orm)
    return h


def dist_field(X, Y, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    den = abx * abx + aby * aby + 1e-8
    t = np.clip(((X - ax) * abx + (Y - ay) * aby) / den, 0, 1)
    dx = X - (ax + abx * t)
    dy = Y - (ay + aby * t)
    return np.sqrt(dx * dx + dy * dy)


def build_ground_mesh(height):
    bm = new_bm()
    half = FIELD_HALF
    nx, ny = 100, 100
    xs = np.linspace(-half, half, nx)
    ys = np.linspace(-half, half, ny)

    def sample(x, y):
        u = (x + half) / (2.0 * half)
        v = (half - y) / (2.0 * half)
        px = int(max(0, min(GROUND_PX - 1, u * (GROUND_PX - 1))))
        py = int(max(0, min(GROUND_PX - 1, v * (GROUND_PX - 1))))
        return float(height[py, px])
    verts = []
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            verts.append(bm.verts.new((float(x), float(y), sample(float(x), float(y)))))
    bm.verts.ensure_lookup_table()
    uv = bm.loops.layers.uv.new("UVMap")
    L = lay(bm)
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            b = a + 1
            c = a + nx + 1
            d = a + nx
            try:
                f = bm.faces.new((verts[a], verts[b], verts[c], verts[d]))
            except ValueError:
                continue
            f[L] = PAINT
            f.smooth = True
            for lp, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uv].uv = (ii / (nx - 1), jj / (ny - 1))
    orient(bm)
    return bm


# ---------------------------------------------------------------- blender objects
def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(block):
            try:
                block.remove(d)
            except Exception:
                pass


def mesh_object(name, bm, material=None):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    me.use_auto_smooth = True
    me.auto_smooth_angle = math.radians(58)
    try:
        me.calc_normals_split()
    except Exception:
        pass
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if material is not None:
        obj.data.materials.append(material)
    tris = sum(max(0, len(p.vertices) - 2) for p in me.polygons)
    print("mesh", name, "tris", tris, "verts", len(me.vertices))
    return obj


def make_mat(name, albedo_path, normal_path=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(albedo_path)
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def empty(name, loc, parent=None):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = "PLAIN_AXES"
    o.empty_display_size = 0.25
    o.location = Vector(loc)
    bpy.context.collection.objects.link(o)
    if parent is not None:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    return o


def export_glb(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="NONE",
        export_cameras=False,
        export_lights=False,
    )
    print("exported", path, os.path.getsize(path))


def dent_wreck(bm):
    """Push a crater into the front wall and drop the near roof. UVs stay put."""
    for v in bm.verts:
        dx = v.co.x - 0.1
        dy = v.co.y - FRONT_Y
        dz = v.co.z - 2.55
        if dy > -0.25 and (dx * dx + dz * dz) < 1.45 * 1.45 and v.co.z < 4.8:
            k = 1.0 - math.sqrt(dx * dx + dz * dz) / 1.45
            v.co.y -= 0.55 * max(0.0, k)
        if v.co.z > 4.9 and v.co.y > 2.8 and abs(v.co.x) < 3.4:
            v.co.z -= 0.85
            v.co.y -= 0.35
        # snap the taller stack
        if (v.co.x - 3.15) ** 2 + (v.co.y + FRONT_Y + 0.9) ** 2 < 0.85 ** 2 and v.co.z > 6.2:
            v.co.z = 6.0 + (v.co.z - 6.2) * 0.12
            v.co.x += 0.25
    # dark interior revealed by the crater. Only the new faces use the char swatch;
    # the door and windows already have their own islands.
    before = set(bm.faces)
    add_box(bm, (0.1, FRONT_Y - 0.55, 2.45), (1.5, 0.7, 1.5), DARK, bevel=0.0)
    uv = bm.loops.layers.uv.get("UVMap")
    if uv is not None:
        for f in bm.faces:
            if f not in before:
                for lp in f.loops:
                    lp[uv].uv = (0.72, 0.97)


def fill_swatch(albedo, orm, height, size, band):
    """Top `band` rows: left rubble, right char. Row 0 is the top of the image."""
    rubble = np.array([0.42, 0.40, 0.37], np.float32)
    char = np.array([0.04, 0.035, 0.03], np.float32)
    for y in range(band):
        for x in range(size):
            if x < size * 0.5:
                n = fbm(x * 0.08, y * 0.08)
                albedo[y, x] = rubble * (0.75 + 0.35 * n)
                orm[y, x] = (0.55, 0.9, 0.02)
                height[y, x] = (n - 0.5) * 0.4
            else:
                albedo[y, x] = char
                orm[y, x] = (0.4, 0.8, 0.05)
                height[y, x] = -0.2


def uv_into_swatch(bm, size, band):
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    # fit each face's planar bounds into the left half of the top band
    for f in bm.faces:
        pts = [lp.vert.co.copy() for lp in f.loops]
        xs = [p.x for p in pts]
        zs = [p.z for p in pts]
        minx, maxx = min(xs), max(xs)
        minz, maxz = min(zs), max(zs)
        for lp in f.loops:
            u = 0.02 + 0.42 * ((lp.vert.co.x - minx) / (maxx - minx + 1e-4))
            v = 1.0 - (4 + (band - 8) * ((lp.vert.co.z - minz) / (maxz - minz + 1e-4))) / size
            lp[uv].uv = (u, v)


def to_obj_hierarchy():
    pass


def preview(path, loc, target):
    try:
        cam_data = bpy.data.cameras.new("PreviewCam")
        cam = bpy.data.objects.new("PreviewCam", cam_data)
        bpy.context.collection.objects.link(cam)
        cam.location = Vector(loc)
        direction = Vector(target) - Vector(loc)
        cam.rotation_euler = direction.normalized().to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.camera = cam
        bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
        bpy.context.scene.render.resolution_x = 1100
        bpy.context.scene.render.resolution_y = 720
        bpy.context.scene.display.shading.light = "STUDIO"
        bpy.context.scene.display.shading.color_type = "TEXTURE"
        bpy.context.scene.display.shading.show_shadows = True
        bpy.context.scene.render.filepath = path
        bpy.context.scene.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    except Exception:
        traceback.print_exc()


def needle_image(path):
    """A small spruce sprig. Alpha is the card mask; tips carry snow."""
    h, w = 256, 128
    img = np.zeros((h, w, 4), np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    for k in range(9):
        cx = 18 + (k % 5) * 20
        cy = 30 + k * 22
        dx = (xx - cx) / 7.0
        dy = (yy - cy) / 26.0
        m = np.clip(1.0 - (dx * dx * 1.4 + dy * dy * 0.25), 0.0, 1.0)
        snowy = k % 3 == 0
        col = np.array([0.78, 0.82, 0.84] if snowy else [0.16, 0.34, 0.22], np.float32)
        img[..., :3] = np.maximum(img[..., :3], col * m[..., None])
        img[..., 3] = np.maximum(img[..., 3], m)
    # a darker stem
    stem = (np.abs(xx - w * 0.5) < 3) & (yy > 20) & (yy < h - 10)
    img[stem, :3] = (0.22, 0.16, 0.10)
    img[stem, 3] = 1.0
    save_png(path, img)


def main():
    os.makedirs(OUT, exist_ok=True)
    clear_scene()
    print("building tank")
    hull = build_hull()
    wheels = wheel_parts()
    turret = build_turret()
    barrel = build_barrel()
    track_l = build_track(1.0)
    track_r = build_track(-1.0)
    tracks = track_l
    join(tracks, track_r)
    print("building plant")
    plant = build_plant()
    debris = build_debris()
    print("building props")
    tree = build_tree()
    foliage = build_foliage()
    rock = build_rock(7, (0.62, 0.46, 0.36))
    rock_b = build_rock(19, (0.48, 0.70, 0.28))
    needle_image(os.path.join(OUT, "needle.png"))

    bake([hull, turret, barrel], TANK_PX, 0.10, shade_tank, os.path.join(OUT, "m1a3"))
    # reserve a top band on the plant atlas, then pack below it
    # pack_faces y0 is in pixels from the top. Bake writes the mesh; we paint the band after
    # by a second pass so dilation doesn't need to know. Easiest: bake, then overwrite the band.
    # Pipes, ribs and ladder rungs share the steel swatch so the walls keep the texels.
    # Only the big wall and roof faces get unique texels, at about the tank's density.
    bake([plant], PLANT_PX, 0.25, shade_plant, os.path.join(OUT, "plant"), reserve_px=0, swatch_area=8.0, max_ppm=140.0)
    # debris shares the plant albedo's top-left. Give them explicit UVs into a swatch we paint
    # over the corner after load. We'll overwrite corner pixels of the saved images in numpy
    # by re-baking the corner into a small array and compositing via a reload.
    swatch_band = 160
    # reload plant albedo by sampling is hard; composite using the PNG through bpy
    _paint_corner(os.path.join(OUT, "plant_albedo.png"), os.path.join(OUT, "plant_orm.png"),
                  os.path.join(OUT, "plant_normal.png"), swatch_band)
    for i, db in enumerate(debris):
        uv_into_swatch(db, PLANT_PX, swatch_band)
    bake([tree, rock], PROP_PX, 0.08, shade_prop, os.path.join(OUT, "props"))
    tread_image(os.path.join(OUT, "tread.png"))
    scorch_image(os.path.join(OUT, "scorch.png"))
    print("ground")
    height = ground_images()
    ground = build_ground_mesh(height)

    # wreck is a UV-preserving copy, then scaled with the intact mesh
    wreck = plant.copy()
    dent_wreck(wreck)

    print("scaling to game units")
    for bm in (hull, turret, barrel, tracks, plant, wreck, *debris):
        scale_bm(bm, S)
    # props and ground are already in game units

    trunnion = Vector((0, TRUNNION_Y, TRUNNION_Z)) * S
    ring = Vector((0, RING_Y, RING_Z)) * S
    muzzle = Vector((0, TRUNNION_Y + BARREL_LEN, TRUNNION_Z)) * S
    nose = Vector((0, HULL_NOSE_Y + 0.02, 1.05)) * S
    aim = Vector((0, 2.35, 2.05)) * S
    # turret and barrel were built in world metres, then scaled, so subtract the pivot.
    shift_bm(turret, ring)
    # The barrel mesh is already in trunnion-local space (it was built at the origin, along +Y).
    # Subtracting the trunnion as well put the gun back on the ground.

    tank_mat = make_mat("M1A3", os.path.join(OUT, "m1a3_albedo.png"))
    tread_mat = make_mat("Tread", os.path.join(OUT, "tread.png"))
    plant_mat = make_mat("Plant", os.path.join(OUT, "plant_albedo.png"))
    prop_mat = make_mat("Props", os.path.join(OUT, "props_albedo.png"))
    ground_mat = make_mat("Ground", os.path.join(OUT, "ground_albedo.png"))

    hull_o = mesh_object("Hull", hull, tank_mat)
    track_o = mesh_object("Tracks", tracks, tread_mat)
    turret_o = mesh_object("Turret", turret, tank_mat)
    barrel_o = mesh_object("Barrel", barrel, tank_mat)
    pivot = empty("TurretPivot", ring)
    barrel_pivot = empty("BarrelPivot", trunnion - ring, pivot)
    turret_o.parent = pivot
    turret_o.matrix_parent_inverse = Matrix.Identity(4)
    turret_o.location = (0, 0, 0)
    barrel_o.parent = barrel_pivot
    barrel_o.matrix_parent_inverse = Matrix.Identity(4)
    barrel_o.location = (0, 0, 0)
    empty("Muzzle", (muzzle - trunnion), barrel_o)
    empty("AimForward", (aim - ring), pivot)
    empty("HullForward", nose, hull_o)
    # AimForward should be a child of the turret so it yaws with it.
    # Reparent: created under pivot. Move under turret.
    aim_o = bpy.data.objects["AimForward"]
    aim_o.parent = turret_o
    aim_o.matrix_parent_inverse = Matrix.Identity(4)
    aim_o.location = Vector(aim - ring)

    wheel_objs = []
    for name, bm, loc in wheels:
        scale_bm(bm, S)
        wo = mesh_object(name, bm, tank_mat)
        wo.location = loc * S
        wheel_objs.append(wo)
    export_glb(os.path.join(OUT, "m1a3.glb"), [hull_o, track_o, pivot] + wheel_objs)

    plant_o = mesh_object("PlantIntact", plant, plant_mat)
    wreck_o = mesh_object("PlantWreck", wreck, plant_mat)
    debris_objs = []
    for i, db in enumerate(debris):
        debris_objs.append(mesh_object("Debris%d" % i, db, plant_mat))
    fwd = empty("PlantForward", Vector((0, 8, 2)) * S)
    impact = empty("ImpactPoint", Vector((0.1, FRONT_Y + 0.05, 2.55)) * S)
    export_glb(os.path.join(OUT, "plant.glb"), [plant_o, wreck_o, fwd, impact] + debris_objs)

    ground_o = mesh_object("Ground", ground, ground_mat)
    export_glb(os.path.join(OUT, "ground.glb"), [ground_o])
    tree_o = mesh_object("Trunk", tree, prop_mat)
    foliage_o = mesh_object("Foliage", foliage, prop_mat)
    rock_o = mesh_object("Rock", rock, prop_mat)
    rock_b_o = mesh_object("RockB", rock_b, prop_mat)
    export_glb(os.path.join(OUT, "tree.glb"), [tree_o, foliage_o])
    export_glb(os.path.join(OUT, "rock.glb"), [rock_o, rock_b_o])

    layout = {
        "metres_per_unit": 4.0,
        "scale_from_metres": S,
        "tank_start": [-9.0, 0.0, 2.2],
        "tank_end": [-1.4, 0.0, 0.5],
        "plant_pos": [6.4, 0.0, 0.0],
        "plant_face": [-1.0, 0.0, 0.0],
        "shoe_len": SHOE_M * S,
        "field": [36.0, 26.0],
        "hull_m": [HULL_NOSE_Y - HULL_TAIL_Y, SKIRT_X * 2.0, ROOF_Z],
        "gun_forward_m": GUN_FORWARD,
        "note": "Positions are Godot world units (Y up). The tank nose and the plant front are aligned at runtime from the exported empties.",
    }
    # props in godot space: blender (x, y, z) -> (x, z, -y)
    trees = [(-14, 7.5), (-11, -8), (1.5, 9), (13, 6.5), (15, -7), (-4, 10), (9.5, -9)]
    rocks = [(-7.5, 6.2), (3.5, -7), (12, 2.5), (-16, -4), (0.5, 11), (10, 8)]
    layout["trees"] = [{"pos": [bx, 0.0, -by], "yaw": (i * 0.7) % 6.28, "scale": 0.85 + (i % 3) * 0.12} for i, (bx, by) in enumerate(trees)]
    layout["rocks"] = [{"pos": [bx, 0.0, -by], "yaw": (i * 1.3) % 6.28, "scale": 0.7 + (i % 4) * 0.18} for i, (bx, by) in enumerate(rocks)]
    with open(os.path.join(OUT, "layout.json"), "w") as f:
        json.dump(layout, f, indent=2)

    tree_o.hide_render = True
    foliage_o.hide_render = True
    rock_o.hide_render = True
    rock_b_o.hide_render = True
    for wo in wheel_objs:
        wo.hide_render = False
    ground_o.hide_render = True
    plant_o.hide_render = True
    wreck_o.hide_render = True
    for o in debris_objs:
        o.hide_render = True
    preview("/tmp/gfx_tank_preview.png", (2.6, -3.6, 1.35), (0.0, 0.15, 0.45))
    preview("/tmp/gfx_tank_rear.png", (0.2, -4.2, 0.9), (0.0, 0.2, 0.45))
    preview("/tmp/gfx_tank_front.png", (0.15, 4.8, 1.1), (0.0, 0.4, 0.5))
    preview("/tmp/gfx_tank_side.png", (4.4, 0.2, 1.15), (0.0, 0.2, 0.45))
    hull_o.hide_render = True
    track_o.hide_render = True
    pivot.hide_render = True
    for c in pivot.children_recursive:
        c.hide_render = True
    plant_o.hide_render = False
    wreck_o.hide_render = True
    preview("/tmp/gfx_plant_preview.png", (6.2, -8.0, 2.6), (0.0, 0.2, 1.0))
    preview("/tmp/gfx_plant_front.png", (0.2, 9.0, 1.8), (0.0, 0.5, 1.2))
    print("DONE", OUT)


def _paint_corner(albedo_path, orm_path, normal_path, band):
    def load(path):
        im = bpy.data.images.load(path)
        w, h = im.size
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        px = np.flipud(px)
        bpy.data.images.remove(im)
        return px

    alb = load(albedo_path)
    orm = load(orm_path)
    nor = load(normal_path)
    h, w, _ = alb.shape
    for y in range(band):
        for x in range(w):
            if x < w * 0.45:
                n = fbm(x * 0.07, y * 0.09)
                alb[y, x, :3] = np.array([0.40, 0.38, 0.35]) * (0.7 + 0.45 * n)
                orm[y, x, :3] = (0.5, 0.9, 0.02)
            else:
                alb[y, x, :3] = (0.035, 0.03, 0.028)
                orm[y, x, :3] = (0.35, 0.85, 0.04)
            nor[y, x, :3] = (0.5, 0.5, 1.0)
    save_png(albedo_path, alb[..., :3])
    save_png(orm_path, orm[..., :3])
    save_png(normal_path, nor[..., :3])


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
