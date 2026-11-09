#!/usr/bin/env python3
"""Photo-shaped M1A2 SEP v3 mesh for the in-game M1A3.

Blender Z-up. Longitudinal +f is the nose; blender Y is -f so a glTF export
lands nose-forward on Godot +Z (the match's forward). Scale is 0.25, the
same metres-to-world scale as the rest of the vehicles.

Vertex colour is the m3 kit: rgb is the paint, alpha * 20 is the class
(0 paint, 4 track, 6 steel, 7 wheel rubber, 8 wheel steel). Wheel UVs are
the axle so the match shader can spin them.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "view", "units", "us", "halberd_sepv3.glb")
S = 0.25

PAINT, STEEL, GLASS, TRACK, WRUB, WSTEEL = 0, 6, 2, 4, 7, 8
TAN = (0.78, 0.66, 0.45)
# Public SEP v3 figures, metres.
HULL_L, WIDTH, ROOF = 7.93, 3.66, 2.44
NOSE = HULL_L * 0.5


def bm_new():
    bm = bmesh.new()
    bm.faces.layers.int.new("tag")
    return bm


def tag(bm):
    return bm.faces.layers.int.get("tag")


def tag_new(bm, before, t):
    L = tag(bm)
    for f in bm.faces:
        if f not in before:
            f[L] = t


def box(bm, c, size, t, rot=None):
    before = set(bm.faces)
    ret = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    if rot:
        R = Matrix.Rotation(rot[0], 4, "X") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[2], 4, "Z")
        m = R @ m
    m.translation = Vector(c)
    bmesh.ops.transform(bm, verts=ret["verts"], matrix=m)
    tag_new(bm, before, t)


def tube(bm, p0, p1, radius, t, segs=10):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    if d.length < 1e-5:
        return
    before = set(bm.faces)
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, verts=ret["verts"], matrix=Matrix.Translation((p0 + p1) * 0.5) @ rot)
    tag_new(bm, before, t)


def ring(bm, major, minor, t, maj=12, minu=4):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=maj, minor_segments=minu,
        major_radius=major, minor_radius=minor,
        rotation=(0.0, math.pi * 0.5, 0.0),
    )
    obj = bpy.context.active_object
    src = bmesh.new()
    src.from_mesh(obj.data)
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    src.faces.layers.int.new("tag")
    L = src.faces.layers.int.get("tag")
    for f in src.faces:
        f[L] = t
    join(bm, src)
    src.free()


def _ensure(bm, kind, name):
    layer = getattr(bm.loops.layers, kind)
    return layer.get(name) or layer.new(name)


def join(dst, src):
    dl, sl = tag(dst), tag(src)
    pairs = []
    for kind in ("color", "uv"):
        for name in src.loops.layers.color.keys() if kind == "color" else src.loops.layers.uv.keys():
            pairs.append((kind, name, _ensure(dst, kind, name), _ensure(src, kind, name)))
    src.verts.index_update()
    mp = {}
    for v in src.verts:
        mp[v.index] = dst.verts.new(v.co.copy())
    dst.verts.ensure_lookup_table()
    for f in src.faces:
        try:
            nf = dst.faces.new([mp[v.index] for v in f.verts])
        except ValueError:
            continue
        nf[dl] = f[sl]
        for lp, slp in zip(nf.loops, f.loops):
            for kind, name, dlayer, slayer in pairs:
                lp[dlayer] = slp[slayer]


def P(x, f, z):
    """x right, f forward (nose +), z up. Blender Y is -f."""
    return (x, -f, z)


def convex(bm, pts, t):
    before = set(bm.faces)
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    tag_new(bm, before, t)


def mirror_x(pts):
    out = []
    for p in pts:
        out.append(p)
        if abs(p[0]) > 1e-4:
            out.append((-p[0], p[1], p[2]))
    return out


def hull():
    bm = bm_new()
    # Long shallow glacis, low nose, flat deck, squared rear.
    pts = mirror_x([
        (0.55, NOSE, 0.55),
        (1.15, NOSE - 0.15, 0.48),
        (1.25, NOSE - 0.55, 0.95),
        (1.40, 1.85, 1.48),
        (1.48, 1.35, 1.58),
        (1.50, -2.55, 1.58),
        (1.35, -NOSE, 1.15),
        (1.10, -NOSE, 0.48),
        (1.12, 2.2, 0.46),
        (1.12, -2.4, 0.46),
    ])
    convex(bm, [P(*p) for p in pts], PAINT)
    # Skirts: a band above the wheels, front section kicked forward.
    for s in (-1.0, 1.0):
        for i, f in enumerate((-2.55, -1.55, -0.55, 0.45, 1.45)):
            box(bm, P(s * 1.78, f, 0.92), (0.06, 0.92, 0.42), PAINT)
        box(bm, P(s * 1.72, 2.45, 0.85), (0.06, 0.85, 0.38), PAINT, rot=(0, 0, s * 0.35))
        # headlights and a tow lug
        tube(bm, P(s * 1.15, NOSE - 0.02, 0.95), P(s * 1.15, NOSE + 0.06, 0.98), 0.07, GLASS, 8)
        box(bm, P(s * 0.55, NOSE + 0.02, 0.62), (0.10, 0.08, 0.10), STEEL)
    # driver hatch on the glacis
    box(bm, P(0, 2.55, 1.52), (0.55, 0.42, 0.06), PAINT)
    # engine deck bars
    for i in range(7):
        box(bm, P(-0.55 + i * 0.18, -2.85, 1.60), (0.05, 0.9, 0.03), STEEL)
    box(bm, P(0, -NOSE - 0.02, 0.95), (1.1, 0.04, 0.4), STEEL)
    return bm


def wheel(side_x, f, z, radius, spokes=6):
    bm = bm_new()
    ring(bm, radius - 0.03, 0.034, WRUB, 12, 4)
    ring(bm, radius * 0.62, 0.016, WSTEEL, 10, 4)
    tube(bm, (-0.06, 0, 0), (0.06, 0, 0), 0.05, WSTEEL, 8)
    for k in range(spokes):
        a = k * math.tau / spokes
        # torus axis is +X; a positive X spin sends +Z toward -Y
        box(bm, (0.0, -math.sin(a) * radius * 0.40, math.cos(a) * radius * 0.40),
            (0.028, 0.03, radius * 0.42), WSTEEL, rot=(a, 0, 0))
    # move onto the axle. Local +X is the axle; side_x is the track centre.
    bmesh.ops.transform(bm, verts=list(bm.verts), matrix=Matrix.Translation(P(side_x, f, z)))
    return bm


def track(side_x):
    """A thick band. UV.x is arc length in world units so the match shader can scroll it."""
    bm = bm_new()
    y_r, z_r, r_r = -3.45, 0.50, 0.42
    y_f, z_f, r_f = 3.30, 0.46, 0.34
    pts = []
    y = y_r
    while y < y_f:
        pts.append((y, 0.05))
        y += 0.28
    for i in range(1, 7):
        a = math.pi - i * math.pi / 7
        pts.append((y_f + math.sin(a) * r_f, z_f + math.cos(a) * r_f))
    y = y_f
    while y > y_r:
        pts.append((y, 0.95))
        y -= 0.28
    for i in range(1, 7):
        a = -i * math.pi / 7
        pts.append((y_r + math.sin(a) * r_r, z_r + math.cos(a) * r_r))
    clean = [pts[0]]
    for p in pts[1:]:
        if (p[0] - clean[-1][0]) ** 2 + (p[1] - clean[-1][1]) ** 2 > 0.02:
            clean.append(p)
    pts = clean
    n = len(pts)
    half_w = 0.26
    L = tag(bm)
    uv = bm.loops.layers.uv.new("UVMap")
    dist = [0.0]
    for i in range(1, n):
        dist.append(dist[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
    close = math.hypot(pts[0][0] - pts[-1][0], pts[0][1] - pts[-1][1])

    def vert(i, sx, up):
        f, z = pts[i]
        f2, z2 = pts[(i + 1) % n]
        df, dz = f2 - f, z2 - z
        ln = math.hypot(df, dz) or 1.0
        # out of the loop (roughly +z on the top, -z on the bottom)
        nx, nz = -dz / ln, df / ln
        return bm.verts.new(P(side_x + sx * half_w, f, z + up * 0.04))

    bm.verts.ensure_lookup_table()
    # four verts per station: +x up, -x up, -x down, +x down — built on demand
    ring_v = []
    for i in range(n):
        ring_v.append((vert(i, 1, 1), vert(i, -1, 1), vert(i, -1, -1), vert(i, 1, -1)))
    for i in range(n):
        j = (i + 1) % n
        v0 = dist[i] * S
        v1 = (dist[j] if j else dist[-1] + close) * S
        for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
            try:
                fce = bm.faces.new((ring_v[i][a], ring_v[i][b], ring_v[j][b], ring_v[j][a]))
            except ValueError:
                continue
            fce[L] = TRACK
            for lp, vv in zip(fce.loops, (v0, v0, v1, v1)):
                lp[uv].uv = (vv, 0.5)
    return bm


def turret():
    bm = bm_new()
    # Low wide body. The front face stops behind the cheeks.
    pts = mirror_x([
        (0.35, 0.95, 1.72),
        (1.15, 0.70, 1.68),
        (1.35, 0.15, 1.62),
        (1.32, -0.85, 1.70),
        (1.05, -1.70, 1.78),
        (0.40, -1.75, 2.05),
        (0.55, 0.35, 2.44),
        (0.90, -0.6, 2.40),
        (0.70, 0.2, 1.58),
        (0.85, -1.2, 1.58),
    ])
    convex(bm, [P(*p) for p in pts], PAINT)
    # Cheeks stick well forward of the mantlet, one each side, low and wide.
    for s in (-1.0, 1.0):
        box(bm, P(s * 0.70, 1.55, 1.82), (0.72, 1.50, 0.48), PAINT, rot=(0, s * 0.16, 0))
    # Mantlet, recessed between the cheeks.
    box(bm, P(0, 0.85, 1.88), (0.50, 0.26, 0.38), PAINT)
    # Gunner's primary sight and the commander's thermal viewer: tall square housings.
    box(bm, P(0.55, 0.72, 2.62), (0.28, 0.32, 0.42), PAINT)
    box(bm, P(0.55, 0.72, 2.78), (0.16, 0.04, 0.10), GLASS)
    box(bm, P(0.15, 0.15, 2.58), (0.26, 0.26, 0.36), PAINT)
    box(bm, P(0.15, 0.28, 2.70), (0.12, 0.04, 0.08), GLASS)
    # Commander's hatch (right) and the remote station on it.
    box(bm, P(0.48, -0.25, 2.50), (0.42, 0.42, 0.08), PAINT)
    box(bm, P(0.48, -0.15, 2.66), (0.36, 0.46, 0.16), STEEL)
    tube(bm, P(0.48, 0.05, 2.74), P(0.48, 0.85, 2.78), 0.02, STEEL, 6)
    box(bm, P(0.66, 0.02, 2.74), (0.12, 0.14, 0.10), STEEL)
    box(bm, P(0.66, 0.10, 2.74), (0.08, 0.02, 0.06), GLASS)
    # Loader's hatch, left.
    box(bm, P(-0.48, -0.15, 2.50), (0.40, 0.36, 0.07), PAINT)
    # Spare road wheel lying flat on the roof.
    tube(bm, P(-0.15, -0.85, 2.42), P(-0.15, -0.85, 2.50), 0.30, WRUB, 12)
    tube(bm, P(-0.15, -0.85, 2.43), P(-0.15, -0.85, 2.49), 0.10, WSTEEL, 8)
    # Smoke banks, six tubes a side.
    for s in (-1.0, 1.0):
        for k in range(6):
            tube(bm, P(s * 1.15, 0.35 + k * 0.07, 2.05), P(s * 1.32, 0.55 + k * 0.07, 2.28), 0.028, STEEL, 6)
    # Bustle rack wrapping the rear.
    box(bm, P(0, -2.05, 1.85), (2.05, 0.06, 0.08), STEEL)
    box(bm, P(-1.0, -1.85, 2.05), (0.05, 0.7, 0.45), STEEL)
    box(bm, P(1.0, -1.85, 2.05), (0.05, 0.7, 0.45), STEEL)
    box(bm, P(0, -2.15, 2.15), (2.05, 0.05, 0.28), STEEL)
    for i in range(6):
        box(bm, P(-0.7 + i * 0.28, -2.15, 2.0), (0.025, 0.025, 0.28), STEEL)
    return bm


def barrel():
    """Local to the trunnion. Extends toward the nose (blender -Y, Godot +Z)."""
    bm = bm_new()
    L = 4.70
    tube(bm, (0, 0, 0), (0, -0.2, 0), 0.09, STEEL, 12)
    tube(bm, (0, -0.15, 0), (0, -L, 0), 0.062, PAINT, 12)
    ev = -L * 0.48
    tube(bm, (0, ev + 0.22, 0), (0, ev - 0.22, 0), 0.105, PAINT, 12)
    for yv in (-0.7, -1.6, -2.6, -3.4):
        tube(bm, (0, yv, 0), (0, yv - 0.05, 0), 0.075, STEEL, 10)
    tube(bm, (0, -L + 0.12, 0), (0, -L, 0), 0.07, STEEL, 10)
    box(bm, (0, -L + 0.18, 0.08), (0.04, 0.08, 0.04), STEEL)
    return bm


def paint(bm, axle=None, radius=0.0):
    L = tag(bm)
    col = bm.loops.layers.color.new("Color")
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    cls_rgb = {
        PAINT: TAN,
        STEEL: (0.45, 0.44, 0.42),
        GLASS: (0.25, 0.32, 0.38),
        TRACK: (0.18, 0.18, 0.17),
        WRUB: (0.10, 0.10, 0.10),
        WSTEEL: (0.35, 0.35, 0.34),
    }
    for f in bm.faces:
        t = int(f[L])
        rgb = cls_rgb.get(t, TAN)
        a = t / 20.0
        for lp in f.loops:
            lp[col] = (rgb[0], rgb[1], rgb[2], a)
            if t in (WRUB, WSTEEL) and axle is not None:
                # Godot axle: y = blender z * S, z = -blender y * S
                lp[uv].uv = (axle[2] * S, -axle[1] * S)
                lp[uv2].uv = (axle[0] * S, radius * S)
            elif t != TRACK:
                lp[uv].uv = (0.0, 0.0)
                lp[uv2].uv = (0.0, 0.0)
            else:
                lp[uv2].uv = (0.0, 0.0)


def scale(bm):
    bmesh.ops.scale(bm, verts=list(bm.verts), vec=Vector((S, S, S)))


def to_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    if me.color_attributes:
        me.color_attributes.active_color_index = 0
        me.color_attributes.render_color_index = 0
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def empty(name, loc, parent=None):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type = "PLAIN_AXES"
    o.location = Vector(loc)
    bpy.context.collection.objects.link(o)
    if parent:
        o.parent = parent
    return o


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    h = hull()
    wheels = []
    ys = [-2.55, -1.70, -0.85, 0.0, 0.85, 1.70, 2.55]
    for s in (1.52, -1.52):
        for f in ys:
            wheels.append((wheel(s, f, 0.38, 0.32), P(s, f, 0.38), 0.32))
        wheels.append((wheel(s, -3.45, 0.50, 0.36, spokes=0), P(s, -3.45, 0.50), 0.36))
        wheels.append((wheel(s, 3.30, 0.46, 0.30, spokes=0), P(s, 3.30, 0.46), 0.30))
    tr = track(1.52)
    join(tr, track(-1.52))
    paint(h)
    scale(h)
    for w, axle, r in wheels:
        paint(w, axle, r)
        scale(w)
        join(h, w)
    paint(tr)
    scale(tr)
    join(h, tr)
    tu = turret()
    paint(tu)
    ring_b = Vector(P(0.0, 0.15, 1.62))
    trun_b = Vector(P(0.0, 0.95, 1.95))
    bmesh.ops.translate(tu, verts=list(tu.verts), vec=-ring_b)
    scale(tu)
    ba = barrel()
    paint(ba)
    scale(ba)
    hull_o = to_obj("Hull", h)
    piv = empty("TurretPivot", ring_b * S)
    tur_o = to_obj("Turret", tu)
    tur_o.parent = piv
    bar = empty("Barrel", (trun_b - ring_b) * S, piv)
    bar_o = to_obj("BarrelMesh", ba)
    bar_o.parent = bar
    bpy.ops.object.select_all(action="DESELECT")
    for o in (hull_o, piv, tur_o, bar, bar_o):
        o.select_set(True)
    bpy.context.view_layer.objects.active = hull_o
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_texcoords=True,
        export_normals=True, export_materials="NONE", export_colors=True,
    )
    print("WROTE", OUT)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
