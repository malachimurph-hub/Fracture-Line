#!/bin/bash
# M3.3: re-bake the M3.2 item-14 surface textures (AO, edge wear, grime, faction marking) for
# the given view scenes and slot them into the existing atlas (others untouched).
#   tools/gfx_m33/bake_m33.sh res://view/units/us/bomb_drone.tscn ...
# Needs /workspace/tools/bakevenv (numpy, scipy, pillow, embreex) and the M3.2 bake workspace.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
PY=${PY:-/workspace/tools/bakevenv/bin/python}
W=${W:-/workspace/tex14}
rm -rf $W/m33_dump $W/m33_bake && mkdir -p $W/m33_dump $W/m33_bake
timeout 600 $G --headless --path . -s res://tools/gfx_m32/tex14/dump.gd -- $W/m33_dump "$@" 2>&1 | grep -E "DUMPED|ERROR"
NAMES=$(for s in "$@"; do echo "$s" | sed 's#res://view/##; s#/#__#g; s#\.tscn$##'; done)
$PY tools/gfx_m32/tex14/bake.py $W/m33_dump $W/m33_bake $NAMES || exit 1
$PY tools/gfx_m33/atlas_update.py assets/textures/bake/bake_atlas.png $W/placement.json $W/bake $W/m33_bake $W/m33_part.json $NAMES || exit 1
L=$($PY -c "import json;print(json.load(open('$W/placement.json'))['layers'])")
sed -i "s/^slices\/vertical=.*/slices\/vertical=$L/" assets/textures/bake/bake_atlas.png.import
cp $W/m33_bake/* $W/bake/
timeout 600 $G --headless --path . -s res://tools/gfx_m32/tex14/apply.gd -- $W/m33_part.json 2>&1 | grep -E "BAKE|APPLIED|ERROR"
timeout 600 $G --headless --path . --import >/dev/null 2>&1
git checkout docs/m1/ 2>/dev/null
