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

# --fixed-fps lets a minute of play run in a couple of seconds.
echo
echo "=== soak test ==="
"$GODOT" --headless --fixed-fps 60 --path "$PROJECT" "tests/soak_test.tscn" 2>&1 | quiet
[ "${PIPESTATUS[0]}" -ne 0 ] && status=1

echo
[ "$status" -eq 0 ] && echo "PASSED" || echo "FAILED"
exit "$status"
