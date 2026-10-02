#!/usr/bin/env bash
# Parse Lua files with a real Lua 5.1 compiler.
#
# love.js runs the game on PUC Lua 5.1, not LuaJIT, so anything LuaJIT accepts
# but 5.1 rejects (goto, ::labels::, 5.2 escapes) only blows up in the browser.
# `luac -p` parses without running, so this catches it on the desktop.
#
#   scripts/lint-lua51.sh file.lua ...   # check the given files
#   scripts/lint-lua51.sh                # check every tracked .lua file
#
# Homebrew no longer ships lua@5.1, so the compiler is built once from the
# official 5.1.5 tarball into the same cache the release script uses.
set -euo pipefail

LUA_VERSION=5.1.5
CACHE="${LOVE_RELEASE_CACHE:-$HOME/.cache/love-release}"
LUAC="$CACHE/lua-$LUA_VERSION/src/luac"

if [[ ! -x "$LUAC" ]]; then
  echo "building Lua $LUA_VERSION for luac -p (one-off)..." >&2
  mkdir -p "$CACHE"
  tarball="$CACHE/lua-$LUA_VERSION.tar.gz"
  [[ -f "$tarball" ]] || curl -fsSL -o "$tarball" "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz"
  tar -xzf "$tarball" -C "$CACHE"
  log="$CACHE/lua-$LUA_VERSION-build.log"
  make -s -C "$CACHE/lua-$LUA_VERSION" macosx >"$log" 2>&1 || { cat "$log" >&2; exit 1; }
  [[ -x "$LUAC" ]] || { echo "failed to build $LUAC" >&2; exit 1; }
fi

if [[ $# -eq 0 ]]; then
  set -- $(git ls-files '*.lua')
fi

err=$(mktemp)
trap 'rm -f "$err"' EXIT
status=0
for f in "$@"; do
  [[ "$f" == *.lua ]] || continue
  if ! "$LUAC" -p "$f" 2>"$err"; then
    sed "s|^$LUAC: ||" "$err" >&2
    status=1
  fi
done
[[ $status -eq 0 ]] && echo "lua 5.1 parse OK ($# files)"
exit $status
