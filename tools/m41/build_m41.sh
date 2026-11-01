#!/bin/bash
# M4.1: regenerate the new models, then LODs + baked AO on them.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
$G --headless --path . -s res://tools/m41/models_m41.gd 2>&1 | grep -E "tris|wrote|SCRIPT ERROR"
SC="$(cat /tmp/m41_wrote.txt | tr '\n' ' ')"
$G --headless --path . -s res://tools/gfx_m7/add_lods.gd -- $SC 2>&1 | grep -E "^LODs"
$G --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- $SC res://view/neutral/cache.tscn 2>&1 | grep -E "^AO baked"
