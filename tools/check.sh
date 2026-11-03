#!/bin/sh
# Bug checks run before every release.
set -e
cd "$(dirname "$0")/.."

echo "== TOC / file list"
python3 -I tools/check.py

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
else
    echo "luacheck not installed, skipped (this is NOT a pass)"
    exit 2
fi
