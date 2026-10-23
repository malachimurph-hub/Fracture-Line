#!/usr/bin/env python3
"""M2.7b vehicle/menu pass: compose before/after comparison sheets (builds/m2_7b_gfx/compare_*.jpg)."""
import os
from PIL import Image, ImageDraw, ImageFont

B = os.path.join(os.path.dirname(__file__), "../../../builds/m2_7b_gfx")
RAW = os.path.join(B, "raw")
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
SMALL = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)

def label(im, text, sub=""):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, im.width, 44 if not sub else 70), fill=(12, 14, 18))
    d.text((14, 8), text, font=FONT, fill=(240, 200, 90) if text.startswith("AFTER") else (200, 200, 200))
    if sub:
        d.text((14, 42), sub, font=SMALL, fill=(170, 170, 170))
    return im

def sheet(name, rows, w=1200, title="", before="BEFORE (M2.7)"):
    """rows: list of (before_path, after_path, caption)"""
    tiles = []
    for b, a, cap in rows:
        ib = Image.open(b).convert("RGB")
        ia = Image.open(a).convert("RGB")
        h = int(ib.height * w / ib.width)
        ib = label(ib.resize((w, h), Image.LANCZOS), before, cap)
        ia = label(ia.resize((w, int(ia.height * w / ia.width)), Image.LANCZOS), "AFTER (M2.7b)", cap)
        tiles.append((ib, ia))
    hh = sum(max(t[0].height, t[1].height) for t in tiles) + 8 * (len(tiles) - 1) + (56 if title else 0)
    out = Image.new("RGB", (w * 2 + 8, hh), (30, 30, 30))
    y = 0
    if title:
        ImageDraw.Draw(out).text((14, 12), title, font=FONT, fill=(255, 255, 255))
        y = 56
    for ib, ia in tiles:
        out.paste(ib, (0, y))
        out.paste(ia, (w + 8, y))
        y += max(ib.height, ia.height) + 8
    p = os.path.join(B, "compare_%s.jpg" % name)
    out.save(p, quality=88)
    print("wrote", os.path.normpath(p), out.size)

R = lambda n: os.path.join(RAW, n)
P = lambda n: (R("before_%s.png" % n), R("after_%s.png" % n))
sheet("us_vehicles", [(*P("us_vehicles_close"), "Halberd (Abrams-style), Lynx (JLTV-style), Picket (Avenger-style), Longreach (M777-style)"),
                      (*P("us_vehicles_close2"), "Dozer, supply truck, Lynx, Halberd"),
                      (*P("us_air_close"), "aircraft: Wraith (Apache-style), Harrier (F-22-style), Thunderlance (B-1-style)"),
                      (*P("us_vehicles"), "US roster at RTS distance")])
sheet("eu_vehicles", [(*P("eu_vehicles_close"), "Leopold (Leopard 2A6-style), Wolfhound, Flakwerk, Salamander"),
                      (*P("eu_vehicles_close2"), "Harvester, Crawler, Salamander, Hearth"),
                      (*P("eu_vehicles_close3"), "Brennus, Hearth, Sentinel, Spectre"),
                      (*P("eu_vehicles"), "EU roster at RTS distance")])
sheet("tpla_vehicles", [(*P("tpla_vehicles_close"), "Rattler, Scrapback, Hailstorm, Junkhammer"),
                        (*P("tpla_vehicles_close2"), "Mule, Blight, Jackal, Sprayer"),
                        (*P("tpla_vehicles_close3"), "Junkhammer, bus, Earwig, Shrike"),
                        (*P("tpla_vehicles"), "TPLA roster at RTS distance")])
sheet("bench", [(*P("bench"), "render benchmark scene: 3 x 40 vehicles + 30 structures, mid-zoom RTS camera")])
cap = ["shot 0: trailing a vehicle into the clash", "shot 1: close orbit over the clash",
       "shot 2: low angle past a building", "shot 3: close-up on the last shooter"]
sheet("menu", [(R("before_menu_shot%d.png" % i), R("after_menu_shot%d.png" % i), cap[i] + " (after: desert, ochre_wells)") for i in range(4)], w=1170)
sheet("menu_snow", [(R("before_menu_shot%d.png" % i), R("after_menu_snow_shot%d.png" % i), cap[i] + " (after: snow, kessel_pass)") for i in range(4)], w=1170)
