#!/usr/bin/env bash
# Tests tools/install.sh against a throw-away AddOns folder (never the game's): the old folder, including a stale file and the
# pre-rename UbermocForever folder, is replaced by exactly the folder this script's project holds. Run: bash tools/test_install.sh
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ADD="$T/_forever_/Interface/AddOns"
mkdir -p "$ADD/Ubermoc-Forever" "$ADD/UbermocForever" "$ADD/OtherAddon"
echo stale > "$ADD/Ubermoc-Forever/OldFileThatNoLongerExists.lua"
echo old > "$ADD/UbermocForever/UbermocForever.toc"
echo keep > "$ADD/OtherAddon/Keep.lua"
out="$(bash "$HERE/install.sh" "$ADD" 2>&1)"; echo "$out" | tail -4
fail() { echo "INSTALL TEST FAILED: $1"; exit 1; }
[ ! -e "$ADD/Ubermoc-Forever/OldFileThatNoLongerExists.lua" ] || fail "a stale file survived"
[ ! -e "$ADD/UbermocForever" ] || fail "the pre-rename folder is still there"
[ -f "$ADD/OtherAddon/Keep.lua" ] || fail "another addon was touched"
diff -rq "$HERE/../Ubermoc-Forever" "$ADD/Ubermoc-Forever" || fail "the installed folder differs from the project's"
ls -A "$T/_forever_/Interface" | grep -q '^\.ubf-install' && fail "the temporary folder was left behind"
# a source without a TOC must be refused and must leave the installed addon alone
mkdir -p "$T/bad"; before="$(find "$ADD/Ubermoc-Forever" -type f | wc -l)"
if bash "$HERE/install.sh" --from "$T/bad" "$ADD" >/dev/null 2>&1; then fail "a folder with no TOC was installed"; fi
[ "$(find "$ADD/Ubermoc-Forever" -type f | wc -l)" = "$before" ] || fail "a refused install changed the game's addon"
echo "INSTALL TEST PASSED"
