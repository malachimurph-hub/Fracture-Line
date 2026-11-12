#!/usr/bin/env python3
"""Paint production icons for Combat Squads as a full group of soldiers.

The checked-in squad icons were a single trooper. This stamps the faction's own
soldier icons into a six-man wedge (rifles plus the anti-tank figure, and a
machine-gunner where that icon exists). Original art already in ui/icons; nothing
outside the project.
"""
import struct, subprocess, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "ui" / "icons"
OUT = 128

# Back row first, then the front rank, so nearer soldiers paint over the ones behind.
# (x, y, height) — y is the sprite centre.
SLOTS = [
    (34, 34, 36),
    (64, 28, 34),
    (94, 34, 36),
    (28, 78, 48),
    (64, 86, 52),
    (100, 78, 48),
]

# Six figures, leader-to-rear is not required on an icon. Front-right is the
# anti-tank soldier so the launcher reads; front-left is the machine gunner when
# that picture exists.
CAST = {
    "us_squad": ["us_grunt", "us_grunt", "us_grunt", "us_grunt", "us_grunt", "us_javelin"],
    "eu_squad": ["eu_grenadier", "eu_grenadier", "eu_grenadier", "eu_grenadier", "eu_grenadier", "eu_lancer"],
    "tpla_squad": ["tpla_militia", "tpla_militia", "tpla_militia", "tpla_militia", "tpla_militia", "tpla_rocket_cell"],
    "ecc_squad": ["ecc_rifleman", "ecc_rifleman", "ecc_rifleman", "ecc_machine_gunner", "ecc_rpg", "ecc_rpg"],
}


def load_rgba(path: Path):
    probe = subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height", "-of", "csv=p=0", str(path),
    ]).decode().strip().split(",")
    w, h = int(probe[0]), int(probe[1])
    raw = subprocess.check_output([
        "ffmpeg", "-loglevel", "error", "-i", str(path),
        "-f", "rawvideo", "-pix_fmt", "rgba", "-",
    ])
    if len(raw) != w * h * 4:
        raise SystemExit("bad decode %s (%d != %d)" % (path, len(raw), w * h * 4))
    return w, h, bytearray(raw)


def crop_alpha(w, h, buf, thr=24):
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        row = y * w * 4
        for x in range(w):
            if buf[row + x * 4 + 3] > thr:
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return w, h, buf
    cw, ch = maxx - minx + 1, maxy - miny + 1
    out = bytearray(cw * ch * 4)
    for y in range(ch):
        for x in range(cw):
            s = ((miny + y) * w + (minx + x)) * 4
            d = (y * cw + x) * 4
            out[d:d + 4] = buf[s:s + 4]
    return cw, ch, out


def sample(buf, w, h, x, y):
    if x < 0 or y < 0 or x >= w - 1 or y >= h - 1:
        x = min(max(x, 0), w - 1)
        y = min(max(y, 0), h - 1)
        i = (int(y) * w + int(x)) * 4
        return buf[i:i + 4]
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    def px(ix, iy):
        j = (iy * w + ix) * 4
        return buf[j], buf[j + 1], buf[j + 2], buf[j + 3]
    p00, p10, p01, p11 = px(x0, y0), px(x0 + 1, y0), px(x0, y0 + 1), px(x0 + 1, y0 + 1)
    out = [0, 0, 0, 0]
    for c in range(4):
        top = p00[c] * (1 - fx) + p10[c] * fx
        bot = p01[c] * (1 - fx) + p11[c] * fx
        out[c] = int(top * (1 - fy) + bot * fy + 0.5)
    return out


def scale_to_height(w, h, buf, th):
    tw = max(1, int(round(w * (th / float(h)))))
    out = bytearray(tw * th * 4)
    for y in range(th):
        sy = (y + 0.5) * h / th - 0.5
        for x in range(tw):
            sx = (x + 0.5) * w / tw - 0.5
            pix = sample(buf, w, h, sx, sy)
            i = (y * tw + x) * 4
            out[i:i + 4] = bytes(pix)
    return tw, th, out


def blit(canvas, src, sw, sh, dx, dy):
    for y in range(sh):
        cy = dy + y
        if cy < 0 or cy >= OUT:
            continue
        for x in range(sw):
            cx = dx + x
            if cx < 0 or cx >= OUT:
                continue
            si = (y * sw + x) * 4
            sa = src[si + 3]
            if sa < 8:
                continue
            di = (cy * OUT + cx) * 4
            da = canvas[di + 3]
            out_a = sa + da * (255 - sa) // 255
            if out_a == 0:
                continue
            for c in range(3):
                canvas[di + c] = (src[si + c] * sa + canvas[di + c] * da * (255 - sa) // 255) // out_a
            canvas[di + 3] = out_a


def save_png(path: Path, buf: bytearray):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(buf[y * OUT * 4:(y + 1) * OUT * 4]) for y in range(OUT))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", OUT, OUT, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def sprite(name):
    w, h, buf = load_rgba(ICON / ("%s.png" % name))
    w, h, buf = crop_alpha(w, h, buf)
    return w, h, buf


def build(dest, names):
    parts = []
    for name, (_x, _y, ht) in zip(names, SLOTS):
        w, h, buf = sprite(name)
        parts.append(scale_to_height(w, h, buf, ht))
    canvas = bytearray(OUT * OUT * 4)
    for (sw, sh, buf), (cx, cy, _ht) in zip(parts, SLOTS):
        blit(canvas, buf, sw, sh, int(cx - sw / 2), int(cy - sh / 2))
    save_png(ICON / ("%s.png" % dest), canvas)
    # distinct silhouettes: count opaque columns that fall to clear, a rough head count
    cols = 0
    on = False
    for x in range(OUT):
        hit = False
        for y in range(OUT):
            if canvas[(y * OUT + x) * 4 + 3] > 40:
                hit = True
                break
        if hit and not on:
            cols += 1
        on = hit
    print("ICON", dest, "column-groups", cols)


def main():
    for dest, names in CAST.items():
        for n in names:
            p = ICON / ("%s.png" % n)
            if not p.exists():
                raise SystemExit("missing %s" % p)
        build(dest, names)


if __name__ == "__main__":
    main()
