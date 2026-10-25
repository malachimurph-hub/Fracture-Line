#!/usr/bin/env python3
"""M3.2 item 14 (b): secondary-detail pass over the m3-kit view meshes (tool-time only).

Reads dump.gd output, appends real geometry in each mesh's local space and writes the same
layout (meshes flagged "changed") for bake.py and apply.gd. Idempotent: meshes already
carrying the "detail14" meta are left alone.

Vehicles (units with a Hull): turret whip antennas, smoke-grenade launcher clusters, rear
bustle rack with stowage (canvas rolls, boxes), Russian reactive-armour bricks on the turret
front, hull tow cables, rear jerrycans, fender tool boxes, spare track links on tracked hulls,
headlight guards; trucks / pickups get an antenna, jerrycans and a cab-roof light bar.
Buildings: window frames + sills around every glass pane, roof clutter on flat roofs (AC
units with fan grilles, vent stacks, skylights, antenna masts, dishes, water tanks, solar
panels, crates / sandbags by faction), downpipes at the main block's corners and a roof
ladder. Primitives are flat-shaded, vertex-coloured, part class in alpha (model_m3 shader).
Run: python3 detail.py <dump_dir> <out_dir> [names...]
"""
import json, math, os, sys
import numpy as np
from embreex import rtcore_scene as rtcs
from embreex.mesh_construction import TriangleMesh

PAINT, TEAM, GLASS, RUBBER, TRACK, LAMP, STEEL = 0, 1, 2, 3, 4, 5, 6
CANVAS, CONCRETE, CORR, WOOD, SANDBAG, DARK, SCRAP, CAMO = 9, 10, 11, 12, 13, 16, 17, 20
AIR = {"harrier", "wraith", "thunderlance", "kestrel", "corvid", "mig29", "f16", "mirage", "ka52",
       "su57", "tu160", "bomb_drone", "scout_drone", "shrike_x"}


def hexc(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


class Geo:
    def __init__(self):
        self.P, self.N, self.C, self.U2 = [], [], [], []
        self.col = [1, 1, 1, 0]
        self.uv2 = (0.0, 0.0)
        self.tris = 0

    def color(self, rgb, cls, uv2=(0.0, 0.0)):
        c = hexc(rgb) if isinstance(rgb, str) else list(rgb)
        self.col = c[:3] + [cls / 20.0]
        self.uv2 = uv2

    def faces(self, polys):
        pts = np.concatenate([np.asarray(p, np.float64) for p in polys])
        ctr = pts.mean(0)
        for p in polys:
            p = np.asarray(p, np.float64)
            for i in range(1, len(p) - 1):
                a, b, c = p[0], p[i], p[i + 1]
                n = np.cross(b - a, c - a)
                ln = np.linalg.norm(n)
                if ln < 1e-12:
                    continue
                n /= ln
                if np.dot(n, (a + b + c) / 3 - ctr) < 0:
                    b, c = c, b
                    n = -n
                for v in (a, c, b):      # Godot front faces are clockwise
                    self.P.append(v); self.N.append(n); self.C.append(self.col); self.U2.append(self.uv2)
                self.tris += 1

    def box(self, c, s, R=None):
        c = np.asarray(c, float); h = np.asarray(s, float) / 2
        R = np.eye(3) if R is None else R
        cs = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]) * h
        v = cs @ R.T + c
        f = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
        self.faces([v[i] for i in f])

    def cyl(self, p0, p1, r0, r1=None, seg=8, caps=True):
        p0 = np.asarray(p0, float); p1 = np.asarray(p1, float)
        r1 = r0 if r1 is None else r1
        ax = p1 - p0; L = np.linalg.norm(ax)
        if L < 1e-6:
            return
        ax /= L
        t = np.cross(ax, [0, 1, 0] if abs(ax[1]) < 0.9 else [1, 0, 0]); t /= np.linalg.norm(t)
        b = np.cross(ax, t)
        ang = np.arange(seg) * 2 * np.pi / seg
        ring0 = [p0 + (t * math.cos(a) + b * math.sin(a)) * r0 for a in ang]
        ring1 = [p1 + (t * math.cos(a) + b * math.sin(a)) * r1 for a in ang]
        polys = [[ring0[k], ring0[(k + 1) % seg], ring1[(k + 1) % seg], ring1[k]] for k in range(seg)]
        if caps:
            polys += [ring0, ring1]
        self.faces(polys)

    def arrays(self):
        n = len(self.P)
        a = np.zeros((n, 14), np.float32)
        if n:
            a[:, 0:3] = self.P; a[:, 3:6] = self.N; a[:, 6:10] = self.C; a[:, 12:14] = self.U2
        return a


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


class Caster:
    def __init__(self, a, idx, skip=()):
        cls = np.round(a[idx[:, 0], 9] * 20).astype(int)
        keep = ~np.isin(cls, list(skip)) if skip else np.ones(len(idx), bool)
        self.T = a[:, :3][idx[keep]].astype(np.float32)
        self.cls = cls[keep]
        self.sc = rtcs.EmbreeScene()
        TriangleMesh(self.sc, self.T)
        n = np.cross(self.T[:, 1] - self.T[:, 0], self.T[:, 2] - self.T[:, 0])
        self.tn = n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)

    def cast(self, o, d):
        o = np.asarray(o, np.float32).reshape(-1, 3)
        d = np.broadcast_to(np.asarray(d, np.float32), o.shape).copy()
        r = self.sc.run(o, d, output=1)
        hit = r["primID"] >= 0
        p = o + d * r["tfar"][:, None]
        n = np.zeros_like(o)
        n[hit] = self.tn[r["primID"][hit]]
        n[hit] *= np.where((n[hit] * d[hit]).sum(1) > 0, -1, 1)[:, None]
        return hit, p, n


def dom_paint(a, idx):
    cls = np.round(a[:, 9] * 20).astype(int)
    for want in (CAMO, PAINT, TEAM, CONCRETE, CORR):
        m = cls == want
        if m.sum() > 6:
            cols = np.round(a[m, 6:9] * 32)
            u, cnt = np.unique(cols, axis=0, return_counts=True)
            c = u[cnt.argmax()] / 32
            uv2 = (float(np.median(a[m, 12])), float(np.median(a[m, 13]))) if want == CAMO else (0.0, 0.0)
            return want, list(np.clip(c * 1.15, 0, 1)), uv2   # undo some of the vertex AO darkening
    return PAINT, hexc("#6b6b5e"), (0.0, 0.0)


FAC_CANVAS = {"us": "#8a7a55", "eu": "#5f6446", "tpla": "#8b7552", "ecc": "#5a5e3e", "neutral": "#8a8070"}


# ------------------------------------------------------------------------------- vehicles
def detail_turret(g, a, idx, fac, s):
    cst = Caster(a, idx, skip={2, 5})
    p = a[:, :3]
    lo, hi = p.min(0), p.max(0)
    cls, pc, uv2 = dom_paint(a, idx)
    W = hi[0] - lo[0]; Lz = hi[2] - lo[2]
    # top surface heights along the rear
    def top(x, z):
        h, q, n = cst.cast([[x, hi[1] + 1, z]], [0, -1, 0])
        return (q[0][1], n[0]) if h[0] else (None, None)
    steel = "#34373a"
    # whip antennas at the rear corners
    for sx in (-1, 1):
        x = sx * W * 0.36 + (lo[0] + hi[0]) / 2; z = lo[2] + Lz * 0.16
        y, n = top(x, z)
        if y is None:
            continue
        g.color(steel, STEEL)
        g.box([x, y + 0.02 * s, z], [0.05 * s, 0.04 * s, 0.05 * s])
        g.cyl([x, y + 0.04 * s, z], [x, y + 0.62 * s, z - 0.04 * s], 0.009 * s, 0.004 * s, seg=5)
    # smoke-grenade launcher clusters on the front sides
    for sx in (-1, 1):
        z = lo[2] + Lz * 0.72
        h, q, n = cst.cast([[sx * (W + 1), (lo[1] + hi[1]) * 0.55, z]], [-sx, 0, 0])
        if not h[0]:
            continue
        base = q[0] + np.array([sx * 0.01 * s, 0.05 * s, 0])
        g.color(steel, STEEL)
        g.box(base + [sx * 0.02 * s, 0, 0], [0.05 * s, 0.05 * s, 0.14 * s])
        for k in range(4):
            c0 = base + np.array([sx * 0.035 * s, 0.03 * s, (k - 1.5) * 0.032 * s])
            g.cyl(c0, c0 + np.array([sx * 0.05 * s, 0.05 * s, 0.025 * s]), 0.012 * s, seg=6)
    # rear bustle rack with stowage
    zb = lo[2] + 0.02 * s
    yb, _ = top((lo[0] + hi[0]) / 2, lo[2] + Lz * 0.12)
    if yb is not None:
        y0 = yb - 0.02 * s
        w = W * 0.7; d = 0.16 * s
        g.color(steel, STEEL)
        for x in np.linspace(-w / 2, w / 2, 5):
            g.box([x, y0 + 0.05 * s, zb - d], [0.012 * s, 0.1 * s, 0.012 * s])
        g.box([0, y0 + 0.1 * s, zb - d], [w, 0.012 * s, 0.012 * s])
        g.box([-w / 2, y0 + 0.1 * s, zb - d / 2], [0.012 * s, 0.012 * s, d])
        g.box([w / 2, y0 + 0.1 * s, zb - d / 2], [0.012 * s, 0.012 * s, d])
        g.box([0, y0 + 0.005 * s, zb - d / 2], [w, 0.01 * s, d])
        g.color(FAC_CANVAS[fac], CANVAS)
        g.cyl([-w * 0.42, y0 + 0.05 * s, zb - d * 0.55], [w * 0.05, y0 + 0.05 * s, zb - d * 0.55], 0.045 * s, seg=8)
        g.color(pc, cls, uv2)
        g.box([w * 0.25, y0 + 0.045 * s, zb - d * 0.5], [w * 0.3, 0.08 * s, d * 0.8])
    # Russian reactive armour bricks on the turret front
    if fac == "ecc":
        g.color(pc, cls, uv2)
        for sx in (-1, 1):
            for row in range(2):
                for k in range(3):
                    x = sx * W * (0.14 + k * 0.1); y = lo[1] + (hi[1] - lo[1]) * (0.35 + row * 0.22)
                    h, q, n = cst.cast([[x, y, hi[2] + 1]], [0, 0, -1])
                    if h[0] and n[0][2] > 0.3:
                        R = rot_y(math.atan2(n[0][0], n[0][2]))
                        g.box(q[0] + n[0] * 0.018 * s, [0.085 * s, 0.07 * s, 0.035 * s], R)


def detail_hull(g, a, idx, fac, s, tracked, has_turret, name):
    cst = Caster(a, idx, skip={2, 5, 7, 8, 4})
    p = a[:, :3]
    lo, hi = p.min(0), p.max(0)
    cls, pc, uv2 = dom_paint(a, idx)
    W = hi[0] - lo[0]; Lz = hi[2] - lo[2]
    steel = "#34373a"
    def top(x, z):
        h, q, n = cst.cast([[x, hi[1] + 1, z]], [0, -1, 0])
        return (q[0][1], n[0]) if h[0] else (None, None)
    # tow cables along the upper hull sides
    if has_turret:
        g.color("#2b2b2a", STEEL)
        for sx in (-1, 1):
            x = sx * W * 0.38
            pts = []
            for z in np.linspace(lo[2] + Lz * 0.25, lo[2] + Lz * 0.75, 4):
                y, n = top(x, z)
                if y is not None and n[1] > 0.6:
                    pts.append([x, y + 0.012 * s, z])
            for k in range(len(pts) - 1):
                g.cyl(pts[k], pts[k + 1], 0.011 * s, seg=5, caps=False)
    # jerrycans on the rear
    zr = lo[2]
    h, q, n = cst.cast([[0, (lo[1] + hi[1]) * 0.5, lo[2] - 1]], [0, 0, 1])
    if h[0]:
        zr = q[0][2]
    ny = 3 if W > 1.0 else 2
    can = {"us": "#5b5a3c", "eu": "#3f4632", "tpla": "#6a5a32", "ecc": "#46502f"}.get(fac, "#555")
    yr = lo[1] + (hi[1] - lo[1]) * 0.45
    for k in range(ny):
        x = (k - (ny - 1) / 2) * 0.1 * s + W * 0.22
        g.color(can, PAINT)
        g.box([x, yr, zr - 0.04 * s], [0.07 * s, 0.11 * s, 0.05 * s])
        g.color(steel, STEEL)
        g.box([x, yr + 0.06 * s, zr - 0.04 * s], [0.025 * s, 0.015 * s, 0.025 * s])
    # fender tool boxes (front corners)
    if has_turret:
        for sx in (-1, 1):
            x = sx * W * 0.4; z = lo[2] + Lz * 0.8
            y, n = top(x, z)
            if y is not None and n[1] > 0.7:
                g.color(pc, cls, uv2)
                g.box([x, y + 0.035 * s, z], [0.14 * s, 0.07 * s, 0.22 * s])
                g.color(steel, STEEL)
                g.box([x, y + 0.072 * s, z], [0.15 * s, 0.006 * s, 0.012 * s])
    # spare track links on the front glacis
    if tracked:
        g.color("#5a5852", STEEL)
        for k in range(5):
            x = (k - 2) * 0.085 * s
            h, q, n = cst.cast([[x, hi[1] + 1, lo[2] + Lz * 0.93]], [0, -1, 0])
            if h[0]:
                R = rot_x(-math.atan2(n[0][2], n[0][1]))
                g.box(q[0] + n[0] * 0.01 * s, [0.07 * s, 0.018 * s, 0.09 * s], R)
    # headlight guards
    zf = hi[2]
    h, q, n = cst.cast([[0, (lo[1] + hi[1]) * 0.5, hi[2] + 1]], [0, 0, -1])
    if h[0]:
        zf = q[0][2]
    g.color(steel, STEEL)
    for sx in (-1, 1):
        x = sx * W * 0.36; y = lo[1] + (hi[1] - lo[1]) * 0.62
        hh, qq, nn = cst.cast([[x, y, hi[2] + 1]], [0, 0, -1])
        if not hh[0]:
            continue
        c = qq[0]
        g.cyl(c + [-0.04 * s, 0, 0], c + [-0.04 * s, 0, 0.05 * s], 0.006 * s, seg=4)
        g.cyl(c + [0.04 * s, 0, 0], c + [0.04 * s, 0, 0.05 * s], 0.006 * s, seg=4)
        g.cyl(c + [-0.04 * s, 0, 0.05 * s], c + [0.04 * s, 0, 0.05 * s], 0.006 * s, seg=4)
    # no turret (trucks, pickups, engineers): antenna + cab-roof light bar
    if not has_turret:
        y, n = top(-W * 0.3, lo[2] + Lz * 0.65)
        if y is not None:
            g.color(steel, STEEL)
            g.cyl([-W * 0.3, y, lo[2] + Lz * 0.65], [-W * 0.3, y + 0.5 * s, lo[2] + Lz * 0.62], 0.008 * s, 0.004 * s, seg=5)
        y, n = top(0, lo[2] + Lz * 0.72)
        if y is not None and n[1] > 0.8:
            g.color(steel, STEEL)
            g.box([0, y + 0.02 * s, lo[2] + Lz * 0.72], [W * 0.5, 0.03 * s, 0.05 * s])
            g.color("#ffb030", LAMP)
            for sx in (-1, 1):
                g.box([sx * W * 0.2, y + 0.04 * s, lo[2] + Lz * 0.72], [0.05 * s, 0.025 * s, 0.04 * s])


# ------------------------------------------------------------------------------ buildings
def glass_components(a, idx):
    cls = np.round(a[idx[:, 0], 9] * 20).astype(int)
    tri = np.nonzero(cls == GLASS)[0]
    if len(tri) == 0:
        return []
    P = a[:, :3]
    key = np.round(P / 0.002).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    parent = {}
    def find(x):
        while parent.get(x, x) != x:
            parent[x] = parent.get(parent[x], parent[x]); x = parent[x]
        return x
    for t in tri:
        vs = [int(inv[i]) for i in idx[t]]
        r0 = find(vs[0])
        for v in vs[1:]:
            r = find(v)
            if r != r0:
                parent[r] = r0
    groups = {}
    for t in tri:
        groups.setdefault(find(int(inv[idx[t][0]])), []).append(t)
    return [np.array(v) for v in groups.values()]


def detail_windows(g, a, idx, s, frame_col):
    P = a[:, :3]
    n_done = 0
    for comp in glass_components(a, idx):
        T = P[idx[comp]]
        n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
        area = np.linalg.norm(n, axis=1)
        if area.sum() < 1e-5:
            continue
        nn = n / (area[:, None] + 1e-12)
        # main face: the horizontal normal with the most area
        horiz = np.abs(nn[:, 1]) < 0.3
        if not horiz.any():
            continue
        best = None
        for d in (np.array([1, 0, 0]), np.array([-1, 0, 0]), np.array([0, 0, 1]), np.array([0, 0, -1])):
            w = (area * ((nn @ d) > 0.9)).sum()
            if best is None or w > best[0]:
                best = (w, d)
        if best[0] <= 0:
            continue
        d = best[1]
        pts = T.reshape(-1, 3)
        lo, hi = pts.min(0), pts.max(0)
        ext = hi - lo
        ax_w = 2 if abs(d[0]) > 0.5 else 0
        Wd, H = ext[ax_w], ext[1]
        if Wd < 0.04 or H < 0.04 or Wd > 3.0 or H > 2.0:
            continue
        face = hi if (d > 0).any() else lo
        c = (lo + hi) / 2
        out_ax = 0 if abs(d[0]) > 0.5 else 2
        c[out_ax] = face[out_ax] + d[out_ax] * 0.004
        t = 0.018 * s if min(Wd, H) > 0.12 else 0.01 * s
        dep = 0.02 * s
        def bx(off_w, off_h, sw, sh, sd, dpush=0.0):
            cc = c.copy(); cc[ax_w] += off_w; cc[1] += off_h; cc[out_ax] += d[out_ax] * (sd / 2 + dpush)
            sz = np.zeros(3); sz[ax_w] = sw; sz[1] = sh; sz[out_ax] = sd
            g.box(cc, sz)
        g.color(frame_col, PAINT)
        bx(0, H / 2, Wd + t, t, dep)
        bx(0, -H / 2, Wd + t, t, dep)
        bx(-Wd / 2, 0, t, H, dep)
        bx(Wd / 2, 0, t, H, dep)
        if Wd > 0.25 and H > 0.1:
            bx(0, 0, t * 0.6, H, dep * 0.6)          # mullion
        g.color("#9a968a", CONCRETE)
        bx(0, -H / 2 - t, Wd + t * 3, t * 0.9, dep * 2.2)   # sill
        n_done += 1
    return n_done


ROOF_KIT = {
    "us": ["ac", "ac", "vent", "dish", "solar", "mast", "skylight"],
    "eu": ["ac", "vent", "solar", "solar", "mast", "skylight", "vent"],
    "tpla": ["tank", "crates", "sandbag", "vent", "dish", "tank", "ac"],
    "ecc": ["vent", "mast", "crates", "ac", "dish", "sandbag", "vent"],
    "neutral": ["tank", "ac", "vent", "dish", "ac"],
}


def roof_item(g, kind, c, s, fac, rng, yaw):
    x, y, z = c
    R = rot_y(yaw)
    steel, light = "#4a4d50", "#b9b7ae"
    if kind == "ac":
        g.color(light, PAINT)
        g.box([x, y + 0.08 * s, z], [0.3 * s, 0.16 * s, 0.22 * s], R)
        g.color("#2a2c2e", DARK)
        g.cyl([x, y + 0.16 * s, z], [x, y + 0.168 * s, z], 0.075 * s, seg=10)
        g.color(steel, STEEL)
        for k in range(3):
            g.box([x, y + 0.172 * s, z + (k - 1) * 0.045 * s], [0.16 * s, 0.006 * s, 0.008 * s], R)
    elif kind == "vent":
        g.color(steel, STEEL)
        g.cyl([x, y, z], [x, y + 0.22 * s, z], 0.045 * s, seg=8)
        g.cyl([x, y + 0.24 * s, z], [x, y + 0.27 * s, z], 0.08 * s, 0.02 * s, seg=8)
        g.cyl([x, y + 0.22 * s, z], [x, y + 0.24 * s, z], 0.012 * s, seg=4, caps=False)
    elif kind == "skylight":
        g.color(light, PAINT)
        g.box([x, y + 0.03 * s, z], [0.3 * s, 0.06 * s, 0.22 * s], R)
        g.color("#1d2a33", GLASS)
        g.box([x, y + 0.065 * s, z], [0.26 * s, 0.015 * s, 0.18 * s], R)
    elif kind == "mast":
        g.color(steel, STEEL)
        g.box([x, y + 0.015 * s, z], [0.08 * s, 0.03 * s, 0.08 * s])
        g.cyl([x, y, z], [x, y + 0.75 * s, z], 0.012 * s, 0.007 * s, seg=5)
        for k, hh in enumerate((0.45, 0.62)):
            g.box([x, y + hh * s, z], [0.18 * s * (1 - k * 0.35), 0.008 * s, 0.008 * s], R)
        g.color("#ff3020", LAMP)
        g.box([x, y + 0.76 * s, z], [0.02 * s, 0.02 * s, 0.02 * s])
    elif kind == "dish":
        g.color(steel, STEEL)
        g.cyl([x, y, z], [x, y + 0.12 * s, z], 0.015 * s, seg=5)
        f = R @ np.array([0, 0.5, 0.86])
        cc = np.array([x, y + 0.14 * s, z])
        g.color("#d8d6cf", PAINT)
        g.cyl(cc - f * 0.02 * s, cc + f * 0.03 * s, 0.11 * s, 0.03 * s, seg=12)
    elif kind == "tank":
        g.color(steel, STEEL)
        for sx in (-1, 1):
            for sz in (-1, 1):
                g.box([x + sx * 0.09 * s, y + 0.06 * s, z + sz * 0.09 * s], [0.02 * s, 0.12 * s, 0.02 * s])
        g.color("#c9c4b6" if fac != "tpla" else "#3b3e44", PAINT)
        g.cyl([x, y + 0.12 * s, z], [x, y + 0.34 * s, z], 0.14 * s, seg=12)
        g.cyl([x, y + 0.34 * s, z], [x, y + 0.37 * s, z], 0.14 * s, 0.05 * s, seg=12)
    elif kind == "solar":
        g.color(steel, STEEL)
        g.box([x, y + 0.04 * s, z], [0.04 * s, 0.08 * s, 0.04 * s])
        g.color("#1b2738", GLASS)
        g.box([x, y + 0.1 * s, z], [0.36 * s, 0.015 * s, 0.22 * s], R @ rot_x(0.4))
    elif kind == "crates":
        g.color("#7b6a48", WOOD)
        g.box([x, y + 0.06 * s, z], [0.14 * s, 0.12 * s, 0.14 * s], R)
        g.box([x + 0.15 * s, y + 0.05 * s, z + 0.02 * s], [0.12 * s, 0.1 * s, 0.12 * s], R @ rot_y(0.4))
        g.color(FAC_CANVAS[fac], CANVAS)
        g.box([x + 0.05 * s, y + 0.15 * s, z], [0.2 * s, 0.06 * s, 0.13 * s], R)
    elif kind == "sandbag":
        g.color("#9c8a62", SANDBAG)
        for k in range(4):
            g.box([x + (k - 1.5) * 0.09 * s, y + 0.03 * s, z], [0.085 * s, 0.055 * s, 0.05 * s], R)
        for k in range(3):
            g.box([x + (k - 1) * 0.09 * s, y + 0.085 * s, z], [0.085 * s, 0.055 * s, 0.05 * s], R)


def detail_building(g, a, idx, fac, nm, rng):
    P = a[:, :3]
    lo, hi = P.min(0), P.max(0)
    size = hi - lo
    s = 1.0
    frame_col = {"us": "#3d4044", "eu": "#2f3438", "tpla": "#5a4a36", "ecc": "#3b3d36", "neutral": "#4a4740"}[fac]
    nwin = detail_windows(g, a, idx, s, frame_col)
    if size[1] < 0.3 or "barricade" in nm or "sandbags" in nm or "minefield" in nm or "demo_trap" in nm or "camo_net" in nm:
        return nwin, 0
    cst = Caster(a, idx, skip={2, 5, 18, 19})
    step = 0.06
    xs = np.arange(lo[0] + step / 2, hi[0], step); zs = np.arange(lo[2] + step / 2, hi[2], step)
    X, Z = np.meshgrid(xs, zs)
    o = np.stack([X.ravel(), np.full(X.size, hi[1] + 1), Z.ravel()], 1)
    hit, q, n = cst.cast(o, [0, -1, 0])
    Hm = np.where(hit, q[:, 1], -1).reshape(X.shape)
    Ny = np.where(hit, n[:, 1], 0).reshape(X.shape)
    cls = np.full(X.size, -1)
    flat = (Ny > 0.97) & (Hm > max(0.35, size[1] * 0.3))
    # free = flat and the neighbourhood (r cells) has the same height
    from scipy import ndimage
    r = 2
    mx = ndimage.maximum_filter(Hm, size=2 * r + 1, mode="constant", cval=-1)
    mn = ndimage.minimum_filter(Hm, size=2 * r + 1, mode="constant", cval=-1)
    free = flat & (mx - mn < 0.015)
    area = free.sum() * step * step
    n_items = int(np.clip(area / 0.45, 0, 10))
    kit = ROOF_KIT[fac]
    placed = []
    cand = np.argwhere(free)
    rng.shuffle(cand)
    for (i, j) in cand:
        if len(placed) >= n_items:
            break
        c = np.array([X[i, j], Hm[i, j], Z[i, j]])
        if any(np.linalg.norm((c - p)[[0, 2]]) < 0.36 for p in placed):
            continue
        placed.append(c)
        roof_item(g, kit[len(placed) % len(kit)], c, s, fac, rng, float(rng.integers(0, 4)) * math.pi / 2)
    # main block: downpipes at its corners, one roof ladder
    top = Hm > max(0.35, size[1] * 0.3)
    lab, nl = ndimage.label(top)
    extra = 0
    if nl:
        big = np.argmax(ndimage.sum(top, lab, range(1, nl + 1))) + 1
        ii, jj = np.nonzero(lab == big)
        h_roof = float(np.median(Hm[ii, jj]))
        if (ii.size * step * step) > 0.5 and h_roof > 0.45:
            x0, x1 = X[0, jj.min()], X[0, jj.max()]
            z0, z1 = Z[ii.min(), 0], Z[ii.max(), 0]
            g.color("#55585a", STEEL)
            for (cx, cz, dx, dz) in ((x0, z0, -1, -1), (x1, z1, 1, 1), (x1, z0, 1, -1)):
                # find the wall: cast horizontally toward the block centre near this corner
                yy = h_roof * 0.5
                hh, qq, nn = cst.cast([[cx + dx * 3, yy, cz - dz * 0.12]], [-dx, 0, 0])
                if not hh[0]:
                    continue
                px = qq[0][0] + dx * 0.03
                pz = cz - dz * 0.12
                g.cyl([px, 0.03, pz], [px, h_roof - 0.02, pz], 0.022, seg=6)
                g.box([px - dx * 0.015, h_roof - 0.03, pz], [0.06, 0.04, 0.06])
                for yb in np.arange(0.25, h_roof - 0.1, 0.35):
                    g.box([px - dx * 0.012, yb, pz], [0.03, 0.02, 0.05])
                extra += 1
            # ladder on the -Z wall
            xl = x0 + (x1 - x0) * 0.75
            hh, qq, nn = cst.cast([[xl, h_roof * 0.5, z0 - 3]], [0, 0, 1])
            if hh[0] and nn[0][2] < -0.8:
                zl = qq[0][2] - 0.035
                g.color("#5a5d60", STEEL)
                for sx in (-1, 1):
                    g.box([xl + sx * 0.06, h_roof / 2 + 0.06, zl], [0.015, h_roof + 0.12, 0.015])
                for yb in np.arange(0.12, h_roof + 0.1, 0.09):
                    g.box([xl, yb, zl], [0.12, 0.01, 0.01])
                extra += 1
    return nwin, len(placed) + extra


def run(dump, out, nm, rng):
    j = json.load(open(os.path.join(dump, nm + ".json")))
    b = open(os.path.join(dump, nm + ".bin"), "rb").read()
    fac = next((f for f in ("us", "eu", "tpla", "ecc") if "__%s__" % f in nm), "neutral")
    unit = nm.startswith("units__")
    base = nm.split("__")[-1]
    meshes = []
    for m in j["meshes"]:
        a = np.frombuffer(b, dtype=np.float32, count=m["nv"] * 14, offset=m["off"]).reshape(-1, 14).copy()
        idx = np.frombuffer(b, dtype=np.int32, count=m["ni"], offset=m["off"] + m["nv"] * 56).reshape(-1, 3).copy()
        meshes.append([m, a, idx])
    paths = [m["path"] for m, _, _ in meshes]
    has_turret = any(p.endswith("TurretPivot/Turret") for p in paths)
    log = []
    hull_len = None
    for m, a, idx in meshes:
        if m["path"].endswith("Hull"):
            ext = a[:, :3].max(0) - a[:, :3].min(0)
            hull_len = float(max(ext[0], ext[2]))
    for rec in meshes:
        m, a, idx = rec
        if m.get("detail14") or not m["visible"]:
            continue
        g = Geo()
        path = m["path"]
        if unit and base not in AIR and hull_len:
            s = float(np.clip(hull_len / 2.0, 0.55, 1.4))
            if path.endswith("TurretPivot/Turret") and "harvester" not in base:
                detail_turret(g, a, idx, fac, s)
            elif path.endswith("Model/Hull"):
                cls = np.round(a[:, 9] * 20).astype(int)
                detail_hull(g, a, idx, fac, s, bool((cls == TRACK).any()), has_turret, base)
        elif not unit and path.endswith("Model/Hull"):
            nw, ni = detail_building(g, a, idx, fac, base, rng)
            log.append("win %d roof %d" % (nw, ni))
        if g.tris:
            add = g.arrays()
            rec[1] = np.concatenate([a, add])
            rec[2] = np.concatenate([idx, (np.arange(len(add)).reshape(-1, 3) + len(a)).astype(np.int32)])
            m["changed"] = True
            log.append("%s +%d" % (path.split("/")[-1], g.tris))
    # write dump layout
    os.makedirs(out, exist_ok=True)
    buf = bytearray()
    outm = []
    for m, a, idx in meshes:
        mm = dict(m)
        mm["off"] = len(buf); mm["nv"] = len(a); mm["ni"] = idx.size
        buf += a.astype(np.float32).tobytes() + idx.astype(np.int32).tobytes()
        outm.append(mm)
    open(os.path.join(out, nm + ".bin"), "wb").write(bytes(buf))
    json.dump({"scene": j["scene"], "meshes": outm}, open(os.path.join(out, nm + ".json"), "w"))
    return log


if __name__ == "__main__":
    dump, out = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or sorted(f[:-5] for f in os.listdir(dump) if f.endswith(".json"))
    for nm in names:
        rng = np.random.default_rng(abs(hash(nm)) % (2 ** 32) if False else sum(map(ord, nm)))
        print("DETAIL", nm, "; ".join(run(dump, out, nm, rng)), flush=True)
