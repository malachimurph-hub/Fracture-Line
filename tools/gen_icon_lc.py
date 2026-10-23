#!/usr/bin/env python3
"""Last Command (M2.7) app icon: original military emblem, drawn from primitives.
An olive shield with an amber rim, a stencilled amber command star and two rank chevrons on
gunmetal. Writes res://icon.svg (project icon, also the 192 px launcher icon) and the Android
adaptive-icon layer SVGs in assets/icons/. PNGs are rasterised by tools/gen_icon_lc.gd (Godot's
own SVG renderer):
  python3 tools/gen_icon_lc.py && godot --headless --path . -s res://tools/gen_icon_lc.gd
"""
import math, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GUN, GUN_D, GUN_L = "#2C3136", "#1E2226", "#3E454C"
OLIVE, OLIVE_D, OLIVE_L = "#4F5E2A", "#3A4620", "#66783A"
AMBER, AMBER_D = "#E3A62B", "#A8741A"

def star(cx, cy, r, ri):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else ri
        pts.append(f"{cx + rr * math.cos(a):.2f},{cy + rr * math.sin(a):.2f}")
    return " ".join(pts)

SHIELD = "M64 13 L105 24 L105 60 C105 84 88 102 64 115 C40 102 23 84 23 60 L23 24 Z"
SHIELD_IN = "M64 20 L98 29.5 L98 60 C98 80 84 95.5 64 107 C44 95.5 30 80 30 60 L30 29.5 Z"

def emblem(mono=False):
    """Shield emblem in 128-unit space (fits ~23..105 x 13..115)."""
    if mono:
        w = "#FFFFFF"
        return (f'<path d="{SHIELD}" fill="none" stroke="{w}" stroke-width="7" stroke-linejoin="round"/>'
                f'<polygon points="{star(64, 47, 20, 8.2)}" fill="{w}"/>'
                f'<path d="M42 70 L64 81 L86 70 L86 77 L64 88 L42 77 Z" fill="{w}"/>'
                f'<path d="M42 82 L64 93 L86 82 L86 89 L64 100 L42 89 Z" fill="{w}"/>')
    s = []
    s.append(f'<path d="{SHIELD}" transform="translate(0 3)" fill="#000" opacity="0.35"/>')     # drop shadow
    s.append(f'<path d="{SHIELD}" fill="{AMBER}" stroke="{AMBER_D}" stroke-width="1.5" stroke-linejoin="round"/>')
    s.append(f'<path d="{SHIELD_IN}" fill="{OLIVE}"/>')
    s.append(f'<path d="M64 20 L98 29.5 L98 60 C98 80 84 95.5 64 107 Z" fill="{OLIVE_D}" opacity="0.55"/>')  # bevel shade
    s.append(f'<path d="M30 29.5 L64 20 L64 27 L36 35 Z" fill="{OLIVE_L}" opacity="0.7"/>')              # top-left light
    # stencilled star: amber with two gunmetal stencil bridges
    sp = star(64, 47, 20, 8.2)
    s.append(f'<defs><clipPath id="st"><polygon points="{sp}"/></clipPath></defs>')
    s.append(f'<polygon points="{sp}" fill="{AMBER}" stroke="{AMBER_D}" stroke-width="1"/>')
    s.append(f'<g clip-path="url(#st)" fill="{OLIVE_D}">'
             f'<rect x="20" y="49.5" width="88" height="2.6"/><rect x="62.7" y="20" width="2.6" height="22"/></g>')
    # two rank chevrons
    for y in (70, 82):
        s.append(f'<path d="M42 {y} L64 {y + 11} L86 {y} L86 {y + 7} L64 {y + 18} L42 {y + 7} Z" fill="{AMBER}" stroke="{AMBER_D}" stroke-width="1"/>')
    return "".join(s)

def background(rounded=True):
    rx = ' rx="22"' if rounded else ""
    return (f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{GUN_L}"/><stop offset="1" stop-color="{GUN_D}"/></linearGradient>'
            f'<clipPath id="bgc"><rect width="128" height="128"{rx}/></clipPath></defs>'
            f'<rect width="128" height="128"{rx} fill="url(#g)"/><g clip-path="url(#bgc)">'
            + "".join(f'<rect x="{x}" y="-20" width="5" height="170" fill="#000" opacity="0.07" transform="rotate(35 64 64)"/>' for x in range(-40, 170, 14))
            + '</g>')

def svg(body, extra=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{body}</svg>\n'

def scaled(body, k):
    """Scale content around the centre (adaptive layers: keep the emblem inside the 66% safe zone)."""
    return f'<g transform="translate({64 - 64 * k:.2f} {64 - 64 * k:.2f}) scale({k})">{body}</g>'

os.makedirs(f"{ROOT}/assets/icons", exist_ok=True)
open(f"{ROOT}/icon.svg", "w").write(svg(background() + f'<rect x="3" y="3" width="122" height="122" rx="19" fill="none" stroke="{GUN_D}" stroke-width="2"/>' + scaled(emblem(), 0.94)))
open(f"{ROOT}/assets/icons/lc_adaptive_bg.svg", "w").write(svg(background(rounded=False)))
open(f"{ROOT}/assets/icons/lc_adaptive_fg.svg", "w").write(svg(scaled(emblem(), 0.66)))
open(f"{ROOT}/assets/icons/lc_adaptive_mono.svg", "w").write(svg(scaled(emblem(mono=True), 0.66)))
print("wrote icon.svg + assets/icons/lc_adaptive_{bg,fg,mono}.svg")
