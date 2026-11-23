#!/usr/bin/env bash
# Run the Sleepy Sun test suite headlessly.
#
#   tools/run_tests.sh                 # uses `godot` from PATH
#   GODOT=/path/to/godot tools/run_tests.sh
#
# Needs Godot 4.7 -- the version the project is actually played on. Verifying
# on 4.6 while the game ran on 4.7 is how a HUD bug survived three rounds of
# "verified". Nothing here opens a window, so it works over SSH and in CI.
set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Set GODOT=/path/to/godot, or put godot on your PATH." >&2
  exit 127
fi

# Filters the engine's progress bars and banner, keeping errors and test output.
quiet() { grep -avE '^\[ *[0-9]+%|\[ DONE \]|^\[0m$|Godot Engine v|godotengine\.org'; }

status=0

echo "=== importing assets ==="
"$GODOT" --headless --path "$PROJECT" --import 2>&1 | grep -aiE 'error|failed' && status=1

# Every tests/*_test.tscn is a suite, one per game, all standing on
# tests/soak_base.gd. Adding a game means adding a file here, not editing this
# script -- with eight games coming, a hand-maintained list would rot.
#
# --fixed-fps lets a minute of play run in a couple of seconds.
suites=$(find "$PROJECT/tests" -name '*_test.tscn' | sort)
if [ -z "$suites" ]; then
  echo "no suites found in tests/ -- nothing was run" >&2
  exit 1
fi

# A suite that prints a script error but asserts nothing about it used to
# PASS: the engine logs the error and carries on, and the exit code only
# reflects the check tally. A null-dereference on every results-card press
# went unnoticed that way for several rounds, because no test drove that path
# and nothing would have failed if one had. Any engine-level error now fails
# the run, whether or not a check noticed.
errors_in() {
  grep -aE "SCRIPT ERROR|Cannot call method|Invalid access|Invalid call|Parse Error|Condition \"" "$1" \
    | grep -av "ALSA\|audio driver\|init_output_device\|set_use_vsync"
}

for suite in $suites; do
  name=$(basename "$suite" .tscn)
  echo
  echo "=== $name ==="
  log=$(mktemp)
  "$GODOT" --headless --fixed-fps 60 --path "$PROJECT" "tests/$name.tscn" >"$log" 2>&1
  code=$?
  quiet <"$log"
  [ "$code" -ne 0 ] && status=1
  if errors_in "$log" >/dev/null; then
    echo "--- engine errors in $name (a passing tally does not excuse these) ---"
    errors_in "$log" | head -20
    status=1
  fi
  rm -f "$log"
done

echo
[ "$status" -eq 0 ] && echo "PASSED" || echo "FAILED"
exit "$status"
