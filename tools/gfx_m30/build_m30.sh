#!/bin/bash
# M3.0: regenerate US models (args: job names, e.g. us_command us_bradley), then LODs, AO, camo.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
rm -f /tmp/gfx_m7_wrote.txt
timeout 600 $G --headless --path . -s res://tools/gen_gfx_m7.gd -- "$@" 2>&1 | grep -E "tris|ERROR|SCRIPT|generated|at:" | grep -v "start screen"
SC=$(grep -h "^WROTE " /tmp/gfx_m7_wrote.txt 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
[ -z "$SC" ] && exit 1
timeout 600 $G --headless --path . -s res://tools/gfx_m7/add_lods.gd -- $SC 2>&1 | grep -iE "ERROR|lod" | grep -v "start screen" | tail -2
timeout 600 $G --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- $SC 2>&1 | grep -E "AO |ERROR" | grep -v "start screen"
timeout 600 $G --headless --path . -s res://tools/gfx_m7/camo_pass.gd -- $SC 2>&1 | grep -E "ERROR|camo pass" | grep -v "start screen"
