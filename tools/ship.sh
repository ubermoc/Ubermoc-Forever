#!/usr/bin/env bash
# Merge a finished worker branch into main, run the checks, and push main.   Run in the MAIN folder:
#   bash tools/ship.sh <branch>
# Same safety as merge-branch.sh (the merge is undone if the offline test or the Lua checker fail), then pushes main.
# It does NOT release (tools/release.sh does that, only when the user says so). Workers do not run this one.
set -u
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
branch="${1:?usage: ship.sh <branch>}"
bash tools/merge-branch.sh "$branch" || exit 1
git push origin main || { echo "Merged here, but the push failed. Retry: git push origin main"; exit 1; }
git push origin "$branch" 2>/dev/null || true
ver=$(grep '^## Version' Ubermoc-Forever/Ubermoc-Forever.toc | sed 's/.*: *//')
echo "Pushed main ($ver). Install into the game from here: bash tools/install.sh"
echo "Release it only if the user asks: bash tools/release.sh v$ver"
