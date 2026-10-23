#!/bin/bash
# M2.7b: regenerate older EU/TPLA vehicle views (args: names or "all"), then LODs, AO and camo.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
$G --headless --path . -s res://tools/gfx_m7/regen_v8.gd -- "$@" 2>&1 | grep -E "tris|ERROR|SCRIPT|regen" | grep -v "start screen"
SC=$(grep -h "^WROTE " /tmp/gfx_v8_wrote.txt 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
[ -z "$SC" ] && exit 0
$G --headless --path . -s res://tools/gfx_m7/add_lods.gd -- $SC 2>&1 | grep -E "ERROR|lod" -i | grep -v "start screen" | tail -2
$G --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- $SC 2>&1 | grep -E "AO |ERROR" | grep -v "start screen"
$G --headless --path . -s res://tools/gfx_m7/camo_pass.gd -- $SC 2>&1 | grep -E "ERROR|camo pass" | grep -v "start screen"
