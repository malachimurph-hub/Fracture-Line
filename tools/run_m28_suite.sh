#!/bin/bash
# M2.8: run the headless suite (+ optional rendered tests). Usage: tools/run_m28_suite.sh [logdir] [tests...]
cd "$(dirname "$0")/.."
G=/workspace/tools/godot
LOG=${1:-/tmp/m28_suite}; shift || true
mkdir -p "$LOG"
TESTS=${@:-content saveload replay placement corners resume tpla audio zh roster m24 m25 viewcost turret stash airspread m33}
fail=0
for t in $TESTS; do
  s=$(date +%s)
  timeout 1800 $G --headless --path . res://tests/test_runner.tscn -- $t > "$LOG/$t.log" 2>&1; rc=$?
  r=$(grep -c "^FAIL" "$LOG/$t.log")
  echo "$t rc=$rc fails=$r $(( $(date +%s) - s ))s $(grep '=== RESULT' "$LOG/$t.log")"
  [ $rc -ne 0 ] && fail=1
done
# M3.2.1: rendered tap-path regression (infantry board transports / barricades / houses, 4 factions)
if [ -z "$*" ] || [[ " $TESTS " == *" board "* ]]; then
  s=$(date +%s)
  timeout 1200 xvfb-run -a -s "-screen 0 1600x740x24" $G --path . --resolution 1600x740 --rendering-method gl_compatibility res://tests/m321_board_test.tscn > "$LOG/board.log" 2>&1; rc=$?
  echo "board rc=$rc fails=$(grep -c '^FAIL' "$LOG/board.log") $(( $(date +%s) - s ))s $(grep '=== M321' "$LOG/board.log")"
  [ $rc -ne 0 ] && fail=1
fi
exit $fail
