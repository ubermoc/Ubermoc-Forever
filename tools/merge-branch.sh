#!/usr/bin/env bash
# Merge a finished worker branch into main safely. Run it in the MAIN folder (the one on branch main, nothing uncommitted).
# Usage: bash tools/merge-branch.sh <branch>
# Merges, runs the offline test and the Lua checker on the result, and keeps the merge only if they pass.
# Nothing is pushed. A failure puts main back exactly as it was.
set -u
branch="${1:?usage: merge-branch.sh <branch>}"
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
[ "$(git branch --show-current)" = main ] || { echo "Not on main. Run: git switch main"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Uncommitted changes here: commit or stash them first."; git status --short; exit 1; }
git rev-parse --verify -q "$branch" >/dev/null || { echo "No branch $branch"; exit 1; }
PY="${UBF_PYTHON:-$HOME/Downloads/WoW Forever Tools and Research/.venv/bin/python}"
[ -x "$PY" ] || PY=python3
before=$(git rev-parse HEAD)
if ! git -c user.name=Claude -c user.email=noreply@anthropic.com merge --no-ff -m "Merge $branch" "$branch"; then
  echo; echo "CONFLICT in:"; git diff --name-only --diff-filter=U
  git merge --abort; echo "Main is unchanged. Ask Claude to resolve it: both branches changed the same lines."; exit 1
fi
fail=0
"$PY" tools/smoke_test.py 2>&1 | tail -3 | grep -q "ALL TESTS PASSED" || { echo "Offline test FAILED after the merge."; fail=1; }
for f in UbermocForever/*.lua; do python3 tools/check_lua.py "$f" 2>&1 | tail -1 | grep -q PASSED || { echo "check_lua FAILED on $f"; fail=1; }; done
if [ "$fail" = 1 ]; then git reset -q --hard "$before"; echo "Main put back as it was ($before). Nothing merged."; exit 1; fi
echo; echo "Merged $branch into main and everything passes. Not pushed. Install: bash tools/install.sh   Push: git push origin main"
