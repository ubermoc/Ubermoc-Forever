#!/usr/bin/env bash
# The ONE command a worker (Claude or the local model) runs when a feature or fix is finished and committed.
#   bash tools/finish.sh
# Run it in YOUR worker folder (made by tools/work-start.sh), never in the main folder. It:
#   1. checks everything is committed,
#   2. brings your branch up to date with main (tools/sync-main.sh) and renumbers your version if main moved on,
#   3. runs the offline test and the Lua 5.1 checker,
#   4. installs the addon into the game FROM YOUR FOLDER so the user can test it after /reload,
#   5. prints the one line the user (or Claude) runs to merge and push it.
# It never merges into main, never pushes and never releases. Stop and report if any step says FAILED.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
branch=$(git branch --show-current)
case "$branch" in ""|main) echo "FAILED: run this in your own worker folder on your own branch (not main)."; exit 1;; esac
[ -z "$(git status --porcelain)" ] || { echo "FAILED: uncommitted changes. Commit them first (git add <files>; git commit -m ...)."; git status --short; exit 1; }
echo "== 1/4 bring $branch up to date with main"
bash tools/sync-main.sh || { echo "FAILED: could not bring the branch up to date. Report this to the user."; exit 1; }
PY="${UBF_PYTHON:-$HOME/Downloads/WoW Forever Tools and Research/.venv/bin/python}"
[ -x "$PY" ] || { echo "FAILED: no Python with lupa at $PY. Run: bash tools/doctor.sh"; exit 1; }
echo "== 2/4 offline test"
out=$("$PY" tools/smoke_test.py 2>&1 | tail -3); echo "$out" | tail -1
echo "$out" | grep -q "ALL TESTS PASSED" || { echo "FAILED: the offline test did not pass."; exit 1; }
echo "== 3/4 Lua 5.1 checker"
bad=0; for f in UbermocForever/*.lua; do python3 tools/check_lua.py "$f" 2>&1 | tail -1 | grep -q PASSED || { echo "check_lua FAILED on $f"; bad=1; }; done
[ "$bad" = 0 ] || exit 1
echo "all files PASSED"
echo "== 4/4 install into the game from this folder"
bash tools/install.sh || { echo "FAILED: install did not work. Run: bash tools/doctor.sh"; exit 1; }
ver=$(grep '^## Version' UbermocForever/UbermocForever.toc | sed 's/.*: *//')
echo
echo "DONE: $branch is version $ver, tested offline and installed in the game (type /reload there)."
echo "Not merged, not pushed, not released. To merge and push (user or Claude), in the main folder:"
echo "    bash tools/ship.sh $branch"
