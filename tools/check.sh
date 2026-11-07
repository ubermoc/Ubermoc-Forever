#!/bin/sh
# Bug checks run before every release.
set -e
cd "$(dirname "$0")/.."

echo "== TOC / file list"
python3 -I tools/check.py 2>&1 | grep -q "TOC check passed"

echo "== Lua syntax"
for f in $(find Core Input Locales UI -name '*.lua'); do
    lua -e "assert(loadfile('$f'))"
    echo "ok $f"
done

echo "== Offline smoke test"
lua tools/test.lua

echo "== luacheck"
if command -v luacheck >/dev/null 2>&1; then
    luacheck . --no-color
elif [ -x tools/bin/luacheck ]; then
    tools/bin/luacheck . --no-color
elif MAIN_ROOT=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd) && [ -x "$MAIN_ROOT/tools/bin/luacheck" ]; then
    # Feature worktrees do not get the git-ignored tools/bin; use the main folder's copy.
    "$MAIN_ROOT/tools/bin/luacheck" . --no-color
else
    echo "luacheck not installed, skipped (this is NOT a pass)"
    exit 2
fi
