#!/bin/bash
# M2.9: generate TPLA models (args: names or "all"), then AO + camo on the written scenes.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
$G --headless --path . -s res://tools/gen_gfx_m29.gd -- "$@" 2>&1 | grep -E "tris|ERROR|SCRIPT|generated|Parse|error" | grep -v "start screen"
SC=$(grep -h "^WROTE " /tmp/gfx_m29_wrote.txt 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
[ -n "$SC" ] && $G --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- $SC 2>&1 | grep -E "AO |ERROR" | grep -v "start screen"
VS=$(echo $SC | tr ' ' '\n' | grep units/ | tr '\n' ' ')
[ -n "$VS" ] && $G --headless --path . -s res://tools/gfx_m7/camo_pass.gd -- $VS 2>&1 | grep -E "CAMO|ERROR|camo pass" | grep -v "start screen"
