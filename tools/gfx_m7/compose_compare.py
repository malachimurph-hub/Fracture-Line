#!/usr/bin/env python3
"""M2.7 graphics pass: compose before/after comparison sheets (builds/m2_7_gfx/compare_*.jpg)."""
import os
from PIL import Image, ImageDraw, ImageFont

B = os.path.join(os.path.dirname(__file__), "../../../builds/m2_7_gfx")
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

def sheet(name, rows, w=1200, title=""):
    """rows: list of (before_path, after_path, caption)"""
    tiles = []
    for b, a, cap in rows:
        ib = Image.open(b).convert("RGB")
        ia = Image.open(a).convert("RGB")
        h = int(ib.height * w / ib.width)
        ib = label(ib.resize((w, h), Image.LANCZOS), "BEFORE (M2.6)", cap)
        ia = label(ia.resize((w, int(ia.height * w / ia.width)), Image.LANCZOS), "AFTER (M2.7 gfx)", cap)
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
sheet("reactor", [(R("before_reactor_close.png"), R("after_reactor_close.png"), "US Fusion Plant, close"),
                  (R("before_reactor_rts.png"), R("after_reactor_rts.png"), "US Fusion Plant, RTS camera")])
sheet("us_buildings", [(R("before_us_buildings.png"), R("after_us_buildings.png"),
                        "reactor, command, barracks, garage, airfield / supply, strategy, patriot, firebase, drop zone")])
sheet("us_vehicles", [(R("before_us_vehicles.png"), R("after_us_vehicles.png"), "dozer, supply truck, Lynx, Halberd, Picket / Longreach, aircraft"),
                      (R("before_us_vehicles_close.png"), R("after_us_vehicles_close.png"), "Halberd, Lynx, Picket, Longreach")])
sheet("eu", [(R("before_eu_buildings_close.png"), R("after_eu_buildings_close.png"), "Fusion Reactor, Motor Pool, Supply Hub"),
             (R("before_eu_vehicles_close2.png"), R("after_eu_vehicles_close2.png"), "Harvester, Crawler, Salamander, Hearth"),
             (R("before_eu_vehicles_close.png"), R("after_eu_vehicles_close.png"), "Leopold, Wolfhound, Flakwerk, Salamander (AO + LOD)")])
sheet("tpla", [(R("before_tpla_buildings_close.png"), R("after_tpla_buildings_close.png"), "Chop Shop, Stash, Den"),
               (R("before_tpla_vehicles_close2.png"), R("after_tpla_vehicles_close2.png"), "Mule, Blight, Jackal, Sprayer")])
mb = [os.path.join(B, "../m2_6/screens/m26_main_menu_battle.png"), os.path.join(B, "../m2_6/screens/m26_main_menu_battle_2.png")]
ma = [R("after_menu_shot%d.png" % i) for i in range(4)]
if all(os.path.exists(p) for p in ma):
    sheet("menu", [(mb[0], ma[0], "wide establishing orbit"), (mb[1], ma[1], "side-on tracking along the front"),
                   (mb[0], ma[2], "push-in over side A's base"), (mb[1], ma[3], "push-in over side B's base")], w=1170)
