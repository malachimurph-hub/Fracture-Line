#!/usr/bin/env python3
"""M3.2 item 14: per-asset baked surface textures (tool-time only).

Input: raw mesh dumps from dump.gd (one .json + .bin per view scene).
Output (per scene): an RGB bake cell (256 px for units, 512 px for buildings) and a JSON map of
mesh node path -> local bake box + rect in the cell.

Each mesh gets 6 axis views of its own local box (+X +Y +Z on the top row, -X -Y -Z below),
so no UV unwrap is needed: the shader (model_m3.gdshaderinc) projects the fragment's object
position into the view picked by its normal, triplanar-blended. Channels:
  R  ambient occlusion: 32 hemisphere rays against the whole asset at rest + the ground plane
  G  signed curvature (0.5 flat, brighter convex edges = worn paint, darker creases) plus
     panel seams and rivet rows on large flat painted faces
  B  grime 0..0.75 (cavity dirt, ground splash, top dust, streaks running down from edges);
     values above 0.8 mark faction markings (stencilled emblems on hull sides / roofs)
Run: python3 bake.py <dump_dir> <out_dir> [names...]
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from embreex import rtcore_scene as rtcs
from embreex.mesh_construction import TriangleMesh

SKIP_PRIMARY = {2, 5, 7, 8, 15, 18, 19}      # glass, lamps, spinning wheels/fans: not baked
PAINTED = {0, 1, 20}                        # paint, team paint, camo
FLATTISH = {0, 1, 6, 10, 11, 20, 17}        # where panel seams make sense
AO_RAYS = 32
rng0 = np.random.default_rng(14)


def load(dump, nm):
    j = json.load(open(os.path.join(dump, nm + ".json")))
    b = open(os.path.join(dump, nm + ".bin"), "rb").read()
    out = []
    for m in j["meshes"]:
        a = np.frombuffer(b, dtype=np.float32, count=m["nv"] * 14, offset=m["off"]).reshape(-1, 14)
        idx = np.frombuffer(b, dtype=np.int32, count=m["ni"], offset=m["off"] + m["nv"] * 56).reshape(-1, 3)
        x = m["xf"]
        M = np.eye(4, dtype=np.float64)
        M[:3, 0] = x[0:3]; M[:3, 1] = x[3:6]; M[:3, 2] = x[6:9]; M[:3, 3] = x[9:12]
        out.append(dict(m, a=a, idx=idx, M=M))
    return j["scene"], out


def faction_of(nm):
    for f in ("us", "eu", "tpla", "ecc"):
        if "__%s__" % f in nm:
            return f
    return "neutral"


def tri_cls(m):
    return np.round(m["a"][m["idx"][:, 0], 9] * 20).astype(int)


def world_tris(m):
    p = m["a"][:, :3].astype(np.float64)
    pw = p @ m["M"][:3, :3].T + m["M"][:3, 3]
    return pw[m["idx"]].astype(np.float32)


def hemi_dirs(n):
    i = np.arange(n) + 0.5
    u = i / n
    r = np.sqrt(u)
    a = i * 2.39996323
    return np.stack([r * np.cos(a), r * np.sin(a), np.sqrt(1 - u)], 1)


HEMI = hemi_dirs(AO_RAYS)

# view k: axis, sign, (u axis, v axis); tile (col,row) = (k%3, k//3)
VIEWS = [(0, 1, 2, 1), (1, 1, 0, 2), (2, 1, 0, 1), (0, -1, 2, 1), (1, -1, 0, 2), (2, -1, 0, 1)]


def pack(sizes, S, pad=2):
    """shelf-pack rects (w,h floats, relative) scaled to fit S x S; returns list of (x,y,w,h) px"""
    lo, hi = 1.0, 4096.0
    best = None
    for _ in range(40):
        s = (lo + hi) / 2
        pos = []
        x = y = shelf = 0
        ok = True
        for (w, h) in sizes:
            W = max(6, int(w * s)) + pad * 2
            H = max(4, int(h * s)) + pad * 2
            if x + W > S:
                x = 0; y += shelf; shelf = 0
            if W > S or y + H > S:
                ok = False; break
            pos.append((x + pad, y + pad, W - pad * 2, H - pad * 2))
            x += W; shelf = max(shelf, H)
        if ok:
            best = pos; lo = s
        else:
            hi = s
    return best


def emblem(fac, size):
    """faction marking mask (original simple shapes), size px square, float 0..1"""
    im = Image.new("L", (size * 4, size * 4), 0)
    d = ImageDraw.Draw(im)
    S = size * 4; c = S / 2; r = S * 0.45
    if fac == "us":       # five-point star in a ring
        d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=int(S * 0.06))
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = r * 0.8 if k % 2 == 0 else r * 0.32
            pts.append((c + rr * math.cos(a), c + rr * math.sin(a)))
        d.polygon(pts, fill=255)
    elif fac == "eu":     # M3.3: Bundeswehr-style cross (straight flared arms), white border only
        def xcross(rr, w0, w1):
            return [(c - w1, c - rr), (c + w1, c - rr), (c + w0, c - w0), (c + rr, c - w1), (c + rr, c + w1), (c + w0, c + w0),
                    (c + w1, c + rr), (c - w1, c + rr), (c - w0, c + w0), (c - rr, c + w1), (c - rr, c - w1), (c - w0, c - w0)]
        d.polygon(xcross(r * 0.9, r * 0.17, r * 0.4), fill=255)
        d.polygon(xcross(r * 0.72, r * 0.09, r * 0.28), fill=0)
    elif fac == "tpla":   # three stacked chevrons
        for k in range(3):
            y = c - r * 0.7 + k * r * 0.55
            d.line([(c - r * 0.8, y + r * 0.35), (c, y), (c + r * 0.8, y + r * 0.35)], fill=255, width=int(S * 0.08))
    elif fac == "ecc":    # triangle in a square frame
        d.rectangle([c - r, c - r, c + r, c + r], outline=255, width=int(S * 0.06))
        d.polygon([(c, c - r * 0.65), (c + r * 0.65, c + r * 0.5), (c - r * 0.65, c + r * 0.5)], fill=255)
    else:
        return None
    return np.asarray(im.resize((size, size), Image.LANCZOS), dtype=np.float32) / 255.0


def bake_scene(dump, out, nm):
    scene, meshes = load(dump, nm)
    fac = faction_of(nm)
    building = nm.startswith("buildings__") or nm.startswith("neutral__")
    S = 512 if building else 256
    vis = [m for m in meshes if m["visible"]]
    if not vis:
        return None
    # occluders: whole asset at rest (scene space) + ground plane unless airborne
    allw = np.concatenate([world_tris(m) for m in vis])
    occ = rtcs.EmbreeScene()
    TriangleMesh(occ, allw)
    lo = allw.reshape(-1, 3).min(0); hi = allw.reshape(-1, 3).max(0)
    size = hi - lo
    ground = lo[1] < 0.15
    reach = float(np.clip(max(size[0], size[2]) * 0.12, 0.12, 0.45))
    todo = []
    for m in vis:
        cls = tri_cls(m)
        keep = ~np.isin(cls, list(SKIP_PRIMARY))
        if keep.sum() < 6:
            continue
        p = m["a"][:, :3]
        bl = p[m["idx"][keep]].reshape(-1, 3)
        bo = bl.min(0) - 0.01; bs = np.maximum(bl.max(0) + 0.01 - bo, 0.02)
        m["box"] = (bo, bs); m["keep"] = keep
        todo.append(m)
    if not todo:
        return None
    # rect per mesh: 3 x 2 tiles; tile size from the box face areas
    rel = []
    for m in todo:
        bs = m["box"][1]
        a = math.sqrt(max(bs[0] * bs[1], bs[1] * bs[2], bs[0] * bs[2]))
        rel.append((3 * a, 2 * a))
    order = sorted(range(len(todo)), key=lambda i: -rel[i][1])
    rects = pack([rel[i] for i in order], S)
    img = np.zeros((S, S, 3), np.float32)
    img[..., 0] = 1.0; img[..., 1] = 0.5; img[..., 2] = 0.0
    mapping = {}
    emb = emblem(fac, 64)
    for oi, i in enumerate(order):
        m = todo[i]
        x0, y0, W, H = rects[oi]
        tw, th = W // 3, H // 2
        bo, bs = m["box"]
        loc = m["a"][:, :3]
        T = loc[m["idx"][m["keep"]]].astype(np.float32)
        tcls = tri_cls(m)[m["keep"]]
        prim = rtcs.EmbreeScene()
        TriangleMesh(prim, T)
        tn = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]); tn /= np.linalg.norm(tn, axis=1, keepdims=True) + 1e-12
        Mr = m["M"][:3, :3]; Mt = m["M"][:3, 3]
        for k, (ax, sg, ua, va) in enumerate(VIEWS):
            col, row = k % 3, k // 3
            tx0 = x0 + col * tw; ty0 = y0 + row * th
            uu = (np.arange(tw) + 0.5) / tw
            vv = (np.arange(th) + 0.5) / th
            U, V = np.meshgrid(uu, vv)
            org = np.zeros((th, tw, 3), np.float32)
            org[..., ua] = bo[ua] + U * bs[ua]
            org[..., va] = bo[va] + (1 - V) * bs[va]
            org[..., ax] = (bo[ax] + bs[ax] + 0.05) if sg > 0 else (bo[ax] - 0.05)
            d = np.zeros(3, np.float32); d[ax] = -sg
            o = org.reshape(-1, 3)
            dirs = np.repeat(d[None], o.shape[0], 0)
            r = prim.run(o, dirs, output=1)
            hit = r["primID"] >= 0
            ao = np.ones(o.shape[0], np.float32)
            nrm = np.zeros((o.shape[0], 3), np.float32)
            cls = np.full(o.shape[0], -1)
            depth = np.zeros(o.shape[0], np.float32)
            hp = o + dirs * r["tfar"][:, None]
            if hit.any():
                pid = r["primID"][hit]
                n = tn[pid]
                flip = (n @ d) > 0
                n[flip] *= -1
                nrm[hit] = n
                cls[hit] = tcls[pid]
                depth[hit] = r["tfar"][hit]
                # AO in scene space
                pw = hp[hit] @ Mr.T + Mt
                nw = n @ Mr.T; nw /= np.linalg.norm(nw, axis=1, keepdims=True) + 1e-9
                t1 = np.cross(nw, np.where(np.abs(nw[:, 1:2]) < 0.9, [[0, 1, 0]], [[1, 0, 0]]))
                t1 /= np.linalg.norm(t1, axis=1, keepdims=True) + 1e-9
                t2 = np.cross(nw, t1)
                rot = rng0.random() * 6.283
                occ_sum = np.zeros(pw.shape[0], np.float32)
                for hd in HEMI:
                    ca, sa = math.cos(rot), math.sin(rot)
                    hx = hd[0] * ca - hd[1] * sa; hy = hd[0] * sa + hd[1] * ca
                    w = t1 * hx + t2 * hy + nw * hd[2]
                    oo = (pw + nw * 0.004).astype(np.float32)
                    rr = occ.run(oo, w.astype(np.float32), output=1)
                    tt = np.where(rr["primID"] >= 0, rr["tfar"], 1e9)
                    if ground:
                        gt = np.where(w[:, 1] < -0.01, oo[:, 1] / np.maximum(-w[:, 1], 1e-4), 1e9)
                        gt = np.where(oo[:, 1] >= 0, gt, 1e9)
                        tt = np.minimum(tt, gt)
                    occ_sum += np.where(tt < reach, 1 - tt / reach, 0)
                ao[hit] = np.clip(1 - 0.85 * occ_sum / AO_RAYS, 0.25, 1)
            hitg = hit.reshape(th, tw)
            aog = ao.reshape(th, tw)
            ng = nrm.reshape(th, tw, 3)
            dg = depth.reshape(th, tw)
            cg = cls.reshape(th, tw)
            # --- signed curvature: divergence of the in-plane normal + depth steps (texel units)
            px_u = bs[ua] / tw; px_v = bs[va] / th
            nu = ng[..., ua]; nv = -ng[..., va]
            div = np.gradient(nu, axis=1) + np.gradient(nv, axis=0)
            dd = np.where(hitg, dg, dg.max() + 1)
            step = np.maximum.reduce([dd - np.roll(dd, s, a) for s in (1, -1) for a in (0, 1)])
            pxm = min(px_u, px_v)
            convex_step = np.clip((-np.minimum.reduce([dd - np.roll(dd, s, a) for s in (1, -1) for a in (0, 1)]) - 3 * pxm) / (6 * pxm), 0, 1)
            curv = np.clip(div * 2.2, -1, 1) + convex_step * 0.6 * hitg
            curv = ndimage.gaussian_filter(curv, 0.7)
            # --- panel seams + rivets on big flat faces
            flat = hitg & np.isin(cg, list(FLATTISH)) & (np.abs(div) < 0.02)
            dist = ndimage.distance_transform_edt(flat)
            seam_px = max(4, int(round(0.38 / max(pxm, 1e-4))))
            if building:
                seam_px = max(5, int(round(0.6 / max(pxm, 1e-4))))
            off_u = int(rng0.integers(0, seam_px)); off_v = int(rng0.integers(0, seam_px))
            ii, jj = np.mgrid[0:th, 0:tw]
            # plate seams: one main direction, every other cross seam dropped per plate row
            row_id = (ii + off_v) // (seam_px * 2)
            cross = ((jj + off_u + row_id * (seam_px // 2)) % seam_px == 0) & ((row_id % 2) == 0 if not building else True)
            lines = cross | ((ii + off_v) % (seam_px * 2) == 0)
            seam = np.where(lines & (dist > 3), -0.28, 0)
            riv = (((jj + off_u) % seam_px == 2) & ((ii + off_v) % 4 == 0)) & (dist > 4) & np.isin(cg, list(PAINTED))
            seam = seam + np.where(riv, 0.35, 0)
            g = 0.5 + 0.5 * np.clip(curv + seam, -1, 1)
            # --- grime
            pw_y = (org[..., ax] * 0)  # placeholder shape
            # world height of each texel (scene space y)
            hpg = hp.reshape(th, tw, 3)
            wy = hpg @ Mr[1] + Mt[1]
            ht = np.clip((wy - lo[1]) / max(size[1], 1e-3), 0, 1)
            noise = ndimage.gaussian_filter(rng0.random((th, tw)), 1.1)
            noise = (noise - noise.mean()) / (noise.std() + 1e-6)
            cav = np.clip((0.9 - aog) * 1.6, 0, 1)
            splash = np.clip(1 - ht / (0.35 if not building else 0.18), 0, 1) ** 1.5 * (0.7 + 0.25 * noise)
            topn = ng[..., 1] @ np.eye(1)[0] if False else (ng @ Mr[1])
            dust = np.clip((topn - 0.6) * 2.5, 0, 1) * np.clip(0.12 + 0.07 * noise, 0, 0.3)
            grime = cav * 0.5 + splash * 0.45 + dust
            if ax != 1:   # side views: streaks running down from convex edges / seams
                src = np.clip(curv, 0, 1) * hitg
                streak = ndimage.uniform_filter1d(np.roll(src, 1, 0), size=max(6, th // 6), axis=0, origin=-(max(6, th // 6) // 2 - 1))
                streak *= np.clip(0.5 + 0.5 * ndimage.gaussian_filter1d(rng0.random((th, tw)), 1.0, axis=1) * 2 - 0.5, 0, 1)
                grime += np.clip(streak, 0, 1) * 0.5
            grime = np.clip(grime, 0, 0.75) * hitg
            # --- faction markings: unit hull/turret sides (views along +-X), building walls once
            if emb is not None and ax == 0:
                painted = hitg & np.isin(cg, list(PAINTED))
                mark_ok = (not building) or (sg > 0 and m["path"].endswith("Hull"))
                if mark_ok and painted.sum() > 0.25 * tw * th:
                    es = int(min(tw, th) * (0.42 if not building else 0.3))
                    if es >= 10:
                        cy, cx = ndimage.center_of_mass(painted & (dist > 2))
                        if not np.isnan(cy):
                            cx = int(cx); cy = int(cy)
                            e = np.asarray(Image.fromarray((emb * 255).astype(np.uint8)).resize((es, es), Image.LANCZOS), np.float32) / 255
                            if sg < 0:
                                e = e[:, ::-1]
                            yy0 = max(0, cy - es // 2); xx0 = max(0, cx - es // 2)
                            yy1 = min(th, yy0 + es); xx1 = min(tw, xx0 + es)
                            sub = e[:yy1 - yy0, :xx1 - xx0] * painted[yy0:yy1, xx0:xx1]
                            reg = grime[yy0:yy1, xx0:xx1]
                            grime[yy0:yy1, xx0:xx1] = np.where(sub > 0.5, 0.82 + 0.18 * sub, reg)
            # fill misses by nearest hit (no seams under bilinear / mips)
            tile = np.stack([np.where(hitg, aog, np.nan), np.where(hitg, g, np.nan), np.where(hitg, grime, np.nan)], -1)
            if hitg.any() and not hitg.all():
                _, (iy, ix) = ndimage.distance_transform_edt(~hitg, return_indices=True)
                tile = tile[iy, ix]
            elif not hitg.any():
                tile = np.stack([np.ones((th, tw)), np.full((th, tw), 0.5), np.zeros((th, tw))], -1)
            img[ty0:ty0 + th, tx0:tx0 + tw] = tile
        mapping[m["path"]] = [float(v) for v in list(bo) + list(bs)] + [x0 / S, y0 / S, (tw * 3) / S, (th * 2) / S]
    # gutters: bleed every rect outward 2 px
    os.makedirs(out, exist_ok=True)
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, nm + ".png"))
    json.dump({"scene": scene, "size": S, "meshes": mapping}, open(os.path.join(out, nm + ".json"), "w"))
    return S


if __name__ == "__main__":
    dump, out = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or sorted(f[:-5] for f in os.listdir(dump) if f.endswith(".json"))
    import time
    for nm in names:
        t = time.time()
        s = bake_scene(dump, out, nm)
        print("BAKED %s %s %.1fs" % (nm, s, time.time() - t), flush=True)
