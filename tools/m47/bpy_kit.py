# Shared hard-surface helpers for the Russian vehicle meshes.
# Godot space in the comments: +Y up, +Z forward.
# Blender is Z-up and its front (-Y) exports to glTF/Godot +Z.
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

PAINT, TEAM, GLASS, RUBBER, TRACK, LAMP, STEEL = 0, 1, 2, 3, 4, 5, 6
WHEEL_R, WHEEL_S = 7, 8

def rgba(hex_s, cls):
    h = hex_s.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
    return (r, g, b, cls / 20.0)

# Same chip the BMPT in-match render settled on. Grime and the sun darken it.
OLIVE = rgba("#84906e", PAINT)
OLIVE_D = rgba("#6c745c", PAINT)
OLIVE_L = rgba("#98a480", PAINT)
RUB = rgba("#141413", RUBBER)
STL = rgba("#3a3d38", STEEL)
GLS = rgba("#243038", GLASS)
LMP = rgba("#f2efe4", LAMP)
TRK = rgba("#2c2c2a", TRACK)
WH_R = rgba("#161615", WHEEL_R)
WH_S = rgba("#3a3d38", WHEEL_S)
TEAM_C = rgba("#ffffff", TEAM)
WOOD = rgba("#6a5a40", PAINT)

def G(x, y, z):
    return Vector((x, -z, y))

def fresh():
    bm = bmesh.new()
    bm.loops.layers.float_color.new("Color")
    bm.loops.layers.uv.new("UVMap")
    bm.loops.layers.uv.new("UV2")
    return bm

def _paint(bm, faces, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    cl = bm.loops.layers.float_color["Color"]
    uvl = bm.loops.layers.uv["UVMap"]
    uv2l = bm.loops.layers.uv["UV2"]
    for f in faces:
        f.smooth = True
        for loop in f.loops:
            loop[cl] = col
            loop[uvl].uv = uv
            loop[uv2l].uv = uv2

def _new(bm):
    return set(bm.faces)

def _added(bm, prev):
    return [f for f in bm.faces if f not in prev]

def box(bm, c, s, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    prev = _new(bm)
    res = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(s[0], s[2], s[1]), verts=res["verts"])
    bmesh.ops.translate(bm, vec=G(*c), verts=res["verts"])
    faces = _added(bm, prev)
    _paint(bm, faces, col, uv, uv2)
    return faces

def bevel(bm, faces, offset):
    if not faces or offset <= 0.0:
        return
    edges = set()
    for f in faces:
        edges.update(f.edges)
    try:
        bmesh.ops.bevel(bm, geom=list(edges), offset=offset, segments=1, affect="EDGES", profile=0.6)
    except TypeError:
        bmesh.ops.bevel(bm, geom=list(edges), offset=offset, segments=1, affect="EDGES")

def cyl(bm, p0, p1, r, segs, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    prev = _new(bm)
    a, b = G(*p0), G(*p1)
    d = b - a
    length = max(0.002, d.length)
    res = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=True, segments=segs,
        radius1=r, radius2=r, depth=length)
    quat = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=quat.to_matrix().to_4x4(), verts=res["verts"])
    bmesh.ops.translate(bm, vec=(a + b) * 0.5, verts=res["verts"])
    faces = _added(bm, prev)
    _paint(bm, faces, col, uv, uv2)
    return faces

def hatch(bm, x, y, z, r=0.09):
    """Closed flush lid: a thin rim, a lower disc, a small hinge. No open cover."""
    cyl(bm, (x, y, z), (x, y + 0.012, z), r, 12, OLIVE_D)
    cyl(bm, (x, y + 0.010, z), (x, y + 0.020, z), r * 0.82, 12, OLIVE)
    box(bm, (x, y + 0.018, z - r * 0.95), (r * 0.42, 0.008, 0.012), STL)

def wheel(bm, c, r, w, segs=10, steer=False):
    uv = (c[1], c[2])
    uv2 = (c[0], r + (10.0 if steer else 0.0))
    x0, x1 = c[0] - w * 0.5, c[0] + w * 0.5
    cyl(bm, (x0, c[1], c[2]), (x1, c[1], c[2]), r, segs, WH_R, uv, uv2)
    side = 1.0 if c[0] > 0 else -1.0
    hx = c[0] + side * w * 0.5
    cyl(bm, (hx, c[1], c[2]), (hx + side * 0.015, c[1], c[2]), r * 0.38, 8, WH_S, uv, uv2)

def _resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for i in range(1, len(pts)):
        a = Vector(pts[i - 1])
        b = Vector(pts[i])
        seg = (b - a).length
        if seg < 1e-6:
            continue
        while acc + seg >= step:
            t = (step - acc) / seg
            out.append(a.lerp(b, t))
            a = out[-1]
            seg = (b - a).length
            acc = 0.0
        acc += seg
    return out

def oriented_box(bm, center, tangent, normal, size, col, uv):
    t = Vector(tangent).normalized()
    n = Vector(normal).normalized()
    r = n.cross(t).normalized()
    prev = _new(bm)
    res = bmesh.ops.create_cube(bm, size=1.0)
    c = Vector(center)
    for v in res["verts"]:
        p = c + r * (v.co.x * size[0]) + n * (v.co.z * size[1]) + t * (v.co.y * size[2])
        v.co = G(p.x, p.y, p.z)
    faces = _added(bm, prev)
    _paint(bm, faces, col, uv, (0.0, 0.0))
    return faces

def add_tracks(parent, z_rear, z_front, ys, yi, rs, ri, y_bot=0.035, y_top=0.28, step=0.09, x=0.48):
    """Tucked belt. Idler at z_front, sprocket at z_rear. Top run stays low, behind skirts."""
    fine = fresh()
    coarse = fresh()
    raw = []
    span = z_front - z_rear
    for i in range(16):
        t = i / 15.0
        raw.append(Vector((y_bot, z_front - ri * 0.4 - t * (span - ri * 0.5 - rs * 0.4))))
    for i in range(1, 9):
        a = math.radians(270 - 180 * i / 8.0)
        raw.append(Vector((ys + math.sin(a) * rs, z_rear + math.cos(a) * rs)))
    for i in range(16):
        t = i / 15.0
        raw.append(Vector((y_top, z_rear + rs * 0.45 + t * (span - rs * 0.6 - ri * 0.4))))
    for i in range(1, 8):
        a = math.radians(90 - 180 * i / 7.0)
        raw.append(Vector((yi + math.sin(a) * ri, z_front + math.cos(a) * ri)))
    raw.append(raw[0])
    pts = _resample([(p.x, p.y) for p in raw], step)
    center = Vector(((y_bot + y_top) * 0.5, (z_rear + z_front) * 0.5))
    along = 0.0
    n = len(pts)
    for i in range(n):
        p = Vector(pts[i])
        nxt = Vector(pts[(i + 1) % n])
        prv = Vector(pts[(i - 1) % n])
        tangent3 = Vector((0.0, nxt.x - prv.x, nxt.y - prv.y))
        if tangent3.length < 1e-6:
            continue
        tangent3.normalize()
        outward2 = (p - center).normalized()
        outward3 = Vector((0.0, outward2.x, outward2.y))
        seg = (nxt - p).length
        for s in (-1.0, 1.0):
            c = (s * x, p.x, p.y)
            uv = (along, 0.5)
            oriented_box(fine, c, tangent3, outward3, (0.10, 0.014, step * 0.72), TRK, uv)
            horn = Vector(c) - outward3 * 0.016
            oriented_box(fine, (horn.x, horn.y, horn.z), tangent3, outward3, (0.022, 0.022, step * 0.32), TRK, uv)
        if i % 2 == 0:
            for s in (-1.0, 1.0):
                c = (s * x, p.x, p.y)
                oriented_box(coarse, c, tangent3, outward3, (0.09, 0.012, seg * 1.7), TRK, (along, 0.5))
        along += seg
    to_obj(fine, "Tracks", parent)
    to_obj(coarse, "TracksFar", parent)

def to_obj(bm, name, parent):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    for e in bm.edges:
        if e.link_faces and len(e.link_faces) == 2:
            n0 = e.link_faces[0].normal
            n1 = e.link_faces[1].normal
            e.smooth = n0.dot(n1) >= math.cos(math.radians(50))
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.shade_smooth()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    if me.color_attributes:
        me.color_attributes.render_color_index = 0
        me.color_attributes.active_color_index = 0
    return obj

def empty(name, godot_pos, parent):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.05
    o.location = G(*godot_pos)
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    return o

def begin():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return empty("Model", (0, 0, 0), None)

def export(name):
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "ecc", name))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_apply=True, export_yup=True,
        export_colors=True, export_attributes=True)
    print("WROTE", out)
