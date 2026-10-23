#!/bin/bash
# Regenerate M2.7 models (args: names or "all") and bake their AO. Prints a tri report.
cd "$(dirname "$0")/../.." || exit 1
G=${G:-/workspace/tools/godot}
$G --headless --path . -s res://tools/gen_gfx_m7.gd -- "$@" 2>&1 | grep -E "tris|ERROR|SCRIPT|generated" | grep -v "start screen"
SC=$(grep -h "^WROTE " /tmp/gfx_m7_wrote.txt 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
[ -n "$SC" ] && $G --headless --path . -s res://tools/gfx_m7/bake_ao.gd -- $SC 2>&1 | grep -E "AO |ERROR" | grep -v "start screen"
[ -n "$SC" ] && $G --headless --path . -s res://tools/gfx_m7/camo_pass.gd -- $SC 2>&1 | grep -E "CAMO|ERROR|camo pass" | grep -v "start screen"
