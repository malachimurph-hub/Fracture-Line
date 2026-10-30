#!/usr/bin/env python3
"""M3.4: Malachi's official game emblem -> menu logo, boot splash, launcher icons, Play assets.

Source: assets_src/emblem/emblem_user.png (Malachi's own emblem, 1254 px square: a red/blue
hexagonal shield, tank top, 'FRACTURE LINE', 'MODERN CONFLICT' banner and a star, over a battle
background). The shield is cut out of its background with a feathered hexagon mask (the faint
red/blue glow round the frame is kept so the edge looks clean over the menu key art).
Writes:
  ui/logo/fl_badge.png              menu logo (shield cut-out, transparent)
  ui/logo/fl_splash.png             boot splash (shield centred on a transparent wide canvas)
  assets/icons/fl_icon_512.png      project / web icon
  assets/icons/lc_launcher_192.png  legacy launcher icon
  assets/icons/lc_adaptive_{fg,bg,mono}_432.png  Android adaptive layers (shield in the safe zone)
  ../builds/play/icon_512.png, feature_1024x500.png  Play listing art (outside the repo)
The previous procedural badge / icons are kept in ui/logo/superseded and assets/icons/superseded.
  python3 tools/gen_emblem_m34.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = f"{ROOT}/assets_src/emblem/emblem_user.png"
# outer edge of the shield frame (letters included), source pixels
HEX = [(626, 48), (1082, 262), (1148, 872), (626, 1212), (104, 872), (170, 262)]

def shield(img, feather=14):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon(HEX, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA")
    out.putalpha(m)
    return out.crop(out.getbbox())

def fit(im, box_w, box_h):
    k = min(box_w / im.width, box_h / im.height)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)

def main():
    src = Image.open(SRC).convert("RGB")
    sh = shield(src)
    os.makedirs(f"{ROOT}/ui/logo", exist_ok=True)
    fit(sh, 1024, 1024).save(f"{ROOT}/ui/logo/fl_badge.png", optimize=True)
    sp = Image.new("RGBA", (2340, 1080), (0, 0, 0, 0))
    b = fit(sh, 2340, 620)
    sp.alpha_composite(b, ((2340 - b.width) // 2, (1080 - b.height) // 2))
    sp.save(f"{ROOT}/ui/logo/fl_splash.png", optimize=True)
    # icons: the full emblem (shield over its battle background), zoomed so the shield fills it
    sq = src.crop((70, 30, 1184, 1144)).resize((512, 512), Image.LANCZOS)
    sq.save(f"{ROOT}/assets/icons/fl_icon_512.png", optimize=True)
    sq.resize((192, 192), Image.LANCZOS).save(f"{ROOT}/assets/icons/lc_launcher_192.png", optimize=True)
    # adaptive: the safe zone is the centre 66 dp circle of 108 dp (264 px of 432); the
    # hexagon's side corners must stay inside it, so the shield is drawn 262 px tall
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    s2 = fit(shield(src, 6), 262, 262)
    fg.alpha_composite(s2, ((432 - s2.width) // 2, (432 - s2.height) // 2))
    fg.save(f"{ROOT}/assets/icons/lc_adaptive_fg_432.png", optimize=True)
    bg = src.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(5))
    bg = ImageEnhance.Brightness(bg).enhance(0.75)
    bg.save(f"{ROOT}/assets/icons/lc_adaptive_bg_432.png", optimize=True)
    mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    # themed icons use alpha only: stone letters / frame solid, shield field faint
    a = s2.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    lum = s2.convert("L").filter(ImageFilter.GaussianBlur(1.0)).point(lambda v: 255 if v > 85 else 60)
    ma = Image.composite(lum, Image.new("L", s2.size, 0), a)
    white = Image.new("L", s2.size, 255)
    mono.paste(Image.merge("RGBA", (white, white, white, ma)), ((432 - s2.width) // 2, (432 - s2.height) // 2))
    mono.save(f"{ROOT}/assets/icons/lc_adaptive_mono_432.png", optimize=True)
    # Play listing art
    play = os.path.normpath(f"{ROOT}/../builds/play")
    if os.path.isdir(play):
        sq.save(f"{play}/icon_512.png", optimize=True)
        ka = Image.open(f"{ROOT}/assets/ui/menu_keyart.jpg").convert("RGBA")
        cw = int(ka.height * 1024 / 500)
        x0 = (ka.width - cw) // 2
        feat = ka.crop((x0, 0, x0 + cw, ka.height)).resize((1024, 500), Image.LANCZOS)
        shade = Image.linear_gradient("L").rotate(-90).resize((1024, 500)).point(lambda v: int(max(0, v - 90) * 0.75))
        feat = Image.composite(Image.new("RGBA", (1024, 500), (8, 10, 14, 255)), feat, shade)
        e = fit(sh, 470, 470)
        feat.alpha_composite(e, (60, (500 - e.height) // 2))
        feat.convert("RGB").save(f"{play}/feature_1024x500.png", optimize=True)
    print("emblem assets written")

if __name__ == "__main__":
    main()
