#!/usr/bin/env bash
# Runs the Lua 5.1 parse check and the examples regression suite.
#
#   scripts/test.sh                              # everything
#   scripts/test.sh camera ui/buttons            # categories and/or example ids
#   scripts/test.sh --update-snapshots [ids...]  # rewrite the golden screenshots
#
# LOVE=/path/to/love overrides the LÖVE binary (defaults to the macOS app,
# then `love` on PATH). Exit status: 0 pass, 1 failures, 2 harness error.
set -euo pipefail
cd "$(dirname "$0")/.."

LOVE="${LOVE:-/Applications/love.app/Contents/MacOS/love}"
if [[ ! -x "$LOVE" ]]; then
  command -v love >/dev/null || { echo "test.sh: LÖVE not found; set LOVE=/path/to/love" >&2; exit 2; }
  LOVE=love
fi

scripts/lint-lua51.sh
exec "$LOVE" . --test "$@"
