# BMPT hard-surface mesh. Godot space in the comments: +Y up, +Z forward.
# Blender is Z-up and its front (-Y) exports to glTF/Godot +Z.
#   blender --background --python tools/m47/bmpt_blender.py
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "ecc", "bmpt.glb")

# class / 20 goes in vertex alpha (model_m3.gdshader)
PAINT, TEAM, GLASS, RUBBER, TRACK, LAMP, STEEL = 0, 1, 2, 3, 4, 5, 6
WHEEL_R, WHEEL_S = 7, 8

def rgba(hex_s, cls):
    h = hex_s.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
    return (r, g, b, cls / 20.0)

# Mid grey-green. The match sun and grime darken it; #5a6448 went near-black.
OLIVE = rgba("#84906e", PAINT)
OLIVE_D = rgba("#6c745c", PAINT)
OLIVE_L = rgba("#98a480", PAINT)
CAP = rgba("#c8c4a4", PAINT)       # lighter missile-mouth caps; luminance survives the paint mix
RUB = rgba("#141413", RUBBER)
STL = rgba("#3a3d38", STEEL)
GLS = rgba("#243038", GLASS)
LMP = rgba("#f2efe4", LAMP)
TRK = rgba("#2c2c2a", TRACK)
WH_R = rgba("#161615", WHEEL_R)
WH_S = rgba("#3a3d38", WHEEL_S)
TEAM_C = rgba("#ffffff", TEAM)

def G(x, y, z):
    """Godot (x, y, z) to Blender (x, -z, y)."""
    return Vector((x, -z, y))

def fresh():
    bm = bmesh.new()
    bm.loops.layers.float_color.new("Color")
    bm.loops.layers.uv.new("UVMap")
    bm.loops.layers.uv.new("UV2")
    return bm

def color_of(bm):
    return bm.loops.layers.float_color["Color"]

def paint(bm, faces, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    cl = color_of(bm)
    uvl = bm.loops.layers.uv["UVMap"]
    uv2l = bm.loops.layers.uv["UV2"]
    for f in faces:
        f.smooth = True
        for loop in f.loops:
            loop[cl] = col
            loop[uvl].uv = uv
            loop[uv2l].uv = uv2

def born(bm):
    return set(bm.faces)

def added(bm, prev):
    return [f for f in bm.faces if f not in prev]

def box(bm, c, s, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    prev = born(bm)
    res = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(s[0], s[2], s[1]), verts=res["verts"])
    bmesh.ops.translate(bm, vec=G(*c), verts=res["verts"])
    faces = added(bm, prev)
    paint(bm, faces, col, uv, uv2)
    return faces

def bevel(bm, faces, offset):
    if not faces or offset <= 0.0:
        return
    edges = set()
    for f in faces:
        edges.update(f.edges)
    bmesh.ops.bevel(bm, geom=list(edges), offset=offset, segments=1, affect="EDGES", profile=0.6)

def cyl(bm, p0, p1, r, segs, col, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
    prev = born(bm)
    a, b = G(*p0), G(*p1)
    d = b - a
    length = max(0.002, d.length)
    res = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=True, segments=segs,
        radius1=r, radius2=r, depth=length)
    quat = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=quat.to_matrix().to_4x4(), verts=res["verts"])
    bmesh.ops.translate(bm, vec=(a + b) * 0.5, verts=res["verts"])
    faces = added(bm, prev)
    paint(bm, faces, col, uv, uv2)
    return faces

def oriented_box(bm, center, tangent, normal, size, col, uv):
    """size is (across, thickness, along). thickness follows normal."""
    t = Vector(tangent).normalized()
    n = Vector(normal).normalized()
    r = n.cross(t).normalized()
    prev = born(bm)
    res = bmesh.ops.create_cube(bm, size=1.0)
    c = Vector(center)
    for v in res["verts"]:
        p = c + r * (v.co.x * size[0]) + n * (v.co.z * size[1]) + t * (v.co.y * size[2])
        v.co = G(p.x, p.y, p.z)
    faces = added(bm, prev)
    paint(bm, faces, col, uv, (0.0, 0.0))
    return faces

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

def track_loop():
    """Belt tucked inside the hull. Idler low under the glacis, sprocket under the rear.
    The top run sits behind the skirts. (y, z) in Godot space."""
    z0, z1 = -0.80, 0.60
    ys, yi = 0.18, 0.13
    rs, ri = 0.15, 0.11
    raw = []
    for i in range(16):
        t = i / 15.0
        raw.append(Vector((0.035, z1 - 0.06 - t * (z1 - z0 - 0.20))))
    for i in range(1, 9):
        a = math.radians(270 - 180 * i / 8.0)
        raw.append(Vector((ys + math.sin(a) * rs, z0 + math.cos(a) * rs)))
    for i in range(16):
        t = i / 15.0
        raw.append(Vector((0.30, z0 + 0.08 + t * (z1 - z0 - 0.18))))
    for i in range(1, 8):
        a = math.radians(90 - 180 * i / 7.0)
        raw.append(Vector((yi + math.sin(a) * ri, z1 + math.cos(a) * ri)))
    raw.append(raw[0])
    return _resample([(p.x, p.y) for p in raw], 0.086)

def add_tracks(parent):
    """One shoe and a guide tooth per link, both sides. UV.x is distance along the run so the match shader can scroll it."""
    fine = fresh()
    coarse = fresh()
    pts = track_loop()
    center = Vector((0.19, 0.0))
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
            c = (s * 0.50, p.x, p.y)
            uv = (along, 0.5)
            oriented_box(fine, c, tangent3, outward3, (0.10, 0.015, 0.058), TRK, uv)
            horn = Vector(c) - outward3 * 0.018
            oriented_box(fine, (horn.x, horn.y, horn.z), tangent3, outward3, (0.022, 0.024, 0.026), TRK, uv)
        # far stand-in: one quad-thick band, no teeth
        if i % 2 == 0:
            for s in (-1.0, 1.0):
                c = (s * 0.50, p.x, p.y)
                oriented_box(coarse, c, tangent3, outward3, (0.09, 0.012, seg * 1.7), TRK, (along, 0.5))
        along += seg
    to_obj(fine, "Tracks", parent)
    far = to_obj(coarse, "TracksFar", parent)
    return far

def wheel(bm, c, r, w, segs=12):
    """Road wheel. UV is the godot-space centre so the match shader can spin it."""
    uv = (c[1], c[2])
    uv2 = (c[0], r)
    x0, x1 = c[0] - w * 0.5, c[0] + w * 0.5
    cyl(bm, (x0, c[1], c[2]), (x1, c[1], c[2]), r, segs, WH_R, uv, uv2)
    # hub, slightly proud of the outer face
    side = 1.0 if c[0] > 0 else -1.0
    hx = c[0] + side * w * 0.5
    cyl(bm, (hx, c[1], c[2]), (hx + side * 0.02, c[1], c[2]), r * 0.42, 8, WH_S, uv, uv2)

def to_obj(bm, name, parent):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    # keep 90-degree armour edges crisp; cylinders (about 30 deg) stay smooth
    sharp = bm.edges.layers.float.get("sharp") 
    for e in bm.edges:
        if e.link_faces and len(e.link_faces) == 2:
            n0 = e.link_faces[0].normal
            n1 = e.link_faces[1].normal
            if n0.dot(n1) < math.cos(math.radians(50)):
                e.smooth = False
            else:
                e.smooth = True
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.shade_smooth()
    obj = bpy.data.objects.new(name, me)
    parent.users_collection[0].objects.link(obj) if False else bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    # glTF wants the color attribute active
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

def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = empty("Model", (0, 0, 0), None)

    h = fresh()
    # lower hull and the sloped glacis (front top edge pulled down)
    body = box(h, (0, 0.30, -0.15), (0.92, 0.36, 1.55), OLIVE)
    glacis = box(h, (0, 0.30, 0.78), (0.86, 0.34, 0.48), OLIVE)
    for v in h.verts:
        gy = v.co.z          # godot y
        gz = -v.co.y         # godot z
        if gz > 0.95 and gy > 0.28:
            v.co.z = 0.18
    bevel(h, body + glacis, 0.012)
    # rear plate
    bevel(h, box(h, (0, 0.32, -0.96), (0.84, 0.30, 0.08), OLIVE_D), 0.008)
    # slatted rear
    for i in range(9):
        box(h, (-0.32 + i * 0.08, 0.34, -1.02), (0.012, 0.22, 0.02), STL)
    # boxy side skirts, two modules a side, with a darker inset panel
    for s in (-1.0, 1.0):
        for zc, zl in ((0.18, 0.55), (-0.38, 0.48)):
            sk = box(h, (s * 0.56, 0.36, zc), (0.12, 0.24, zl), OLIVE)
            bevel(h, sk, 0.01)
            box(h, (s * 0.63, 0.36, zc), (0.012, 0.16, zl * 0.72), OLIVE_D)
        # slats at the back of the skirt
        for i in range(5):
            box(h, (s * 0.60, 0.26 + i * 0.04, -0.72), (0.02, 0.012, 0.16), OLIVE_D)
        # closed bow hatch: thin lid, a low rim, a small rear hinge. No ring, no open cover.
        cyl(h, (s * 0.30, 0.478, 0.48), (s * 0.30, 0.490, 0.48), 0.132, 18, OLIVE_D)
        cyl(h, (s * 0.30, 0.488, 0.48), (s * 0.30, 0.500, 0.48), 0.112, 18, OLIVE)
        box(h, (s * 0.30, 0.498, 0.35), (0.055, 0.010, 0.016), STL)
        box(h, (s * 0.30, 0.502, 0.56), (0.022, 0.005, 0.010), STL)
        # headlights and tow hooks on the glacis
        box(h, (s * 0.22, 0.24, 1.00), (0.06, 0.04, 0.03), LMP)
        cyl(h, (s * 0.16, 0.16, 0.98), (s * 0.16, 0.16, 1.04), 0.012, 6, STL)
    # six road wheels, rear sprocket, front idler, return rollers
    for s in (-1.0, 1.0):
        for i in range(6):
            z = -0.52 + i * (0.92 / 5.0)
            wheel(h, (s * 0.50, 0.145, z), 0.125, 0.10, 12)
        wheel(h, (s * 0.50, 0.18, -0.80), 0.145, 0.09, 12)   # rear sprocket, under the hull
        for k in range(8):
            a = k * math.tau / 8.0
            box(h, (s * 0.50, 0.18 + math.sin(a) * 0.14, -0.80 + math.cos(a) * 0.14), (0.07, 0.032, 0.038), WH_S,
                (0.18, -0.80), (s * 0.50, 0.145))
        wheel(h, (s * 0.50, 0.13, 0.60), 0.10, 0.07, 10)     # front idler, low under the glacis
        for k, z in enumerate((-0.35, 0.15)):
            cyl(h, (s * 0.50 - 0.04, 0.34, z), (s * 0.50 + 0.04, 0.34, z), 0.035, 8, WH_S, (0.34, z), (s * 0.50, 0.035))
    # team colour pip, same idea as the other vehicles (not a parade stripe)
    box(h, (0.64, 0.40, -0.1), (0.01, 0.03, 0.35), TEAM_C)
    hull = to_obj(h, "Hull", root)
    add_tracks(root)

    # Turret sits aft of the hull centre, over the rear road wheels. Children move with it.
    piv = empty("TurretPivot", (0.0, 0.50, -0.38), root)
    t = fresh()
    deck = box(t, (0, 0.04, 0.0), (0.78, 0.07, 0.52), OLIVE)
    bevel(t, deck, 0.01)
    # tall sight at the rear left
    sight = box(t, (-0.22, 0.16, -0.16), (0.14, 0.22, 0.16), OLIVE_D)
    bevel(t, sight, 0.006)
    box(t, (-0.22, 0.20, -0.07), (0.08, 0.05, 0.012), GLS)
    # missile launcher each side: armoured box, two lighter round mouths
    for s in (-1.0, 1.0):
        parts = []
        parts += box(t, (s * 0.46, 0.14, 0.08), (0.28, 0.18, 0.46), OLIVE)
        for k in (-1.0, 1.0):
            x = s * 0.46 + k * 0.065
            # pale caps and dark mouths, proud of the front face
            parts += cyl(t, (x, 0.15, 0.28), (x, 0.17, 0.40), 0.05, 14, CAP)
            parts += cyl(t, (x, 0.155, 0.32), (x, 0.17, 0.42), 0.026, 10, STL)
        pivot = G(s * 0.46, 0.08, -0.12)
        bmesh.ops.rotate(t, cent=pivot, matrix=Matrix.Rotation(math.radians(-18), 4, "X"),
                         verts=list({v for f in parts for v in f.verts}))
    # antenna
    cyl(t, (-0.30, 0.10, -0.22), (-0.30, 0.62, -0.22), 0.006, 5, STL)
    # small stowage on the bustle
    box(t, (0.18, 0.08, -0.22), (0.16, 0.06, 0.10), OLIVE_D)
    turret = to_obj(t, "Turret", piv)

    barrel = empty("Barrel", (0.0, 0.10, 0.08), piv)
    b = fresh()
    box(b, (0, 0.02, 0.02), (0.12, 0.05, 0.10), OLIVE_D)
    for s in (-1.0, 1.0):
        cyl(b, (s * 0.04, 0.03, 0.04), (s * 0.04, 0.16, 0.92), 0.016, 10, STL)
        # muzzle brake
        cyl(b, (s * 0.04, 0.155, 0.88), (s * 0.04, 0.175, 1.02), 0.026, 10, STL)
        box(b, (s * 0.04, 0.165, 0.95), (0.04, 0.012, 0.05), rgba("#1c1e1a", 16))
    to_obj(b, "BarrelMesh", barrel)
    return root

if __name__ == "__main__":
    build()
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(OUT),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_colors=True,
        export_attributes=True,
    )
    print("WROTE", os.path.abspath(OUT))
