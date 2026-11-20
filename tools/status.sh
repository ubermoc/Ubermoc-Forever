#!/usr/bin/env bash
# One screen: where everything stands. Run it at the START and at the END of every session (Ubermoc and the local model):
#   bash tools/status.sh
# Read-only. Works from any worker folder or the main folder.
common=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "Not in the repo."; exit 1; }
main_dir=$(cd "$common/.." && pwd)
g() { git -C "$main_dir" "$@"; }
ver=$(git -C "$main_dir" show main:Ubermoc-Forever/Ubermoc-Forever.toc | grep '^## Version' | sed 's/.*: *//')
rel=$(gh release list --limit 1 2>/dev/null | awk '{print $1" "$2}' | head -1)
g fetch -q origin 2>/dev/null
ahead=$(g rev-list --count origin/main..main 2>/dev/null); behind=$(g rev-list --count main..origin/main 2>/dev/null)
echo "main is version $ver   | last release: ${rel:-unknown (gh not logged in)}"
[ "$ahead" = 0 ] && [ "$behind" = 0 ] && echo "main = GitHub (pushed)" || echo "main vs GitHub: $ahead not pushed, $behind not pulled  -> push: git push origin main"
tag=$(g tag --list "v$ver"); [ -n "$tag" ] || echo "version $ver is NOT released yet (release only when the user says: bash tools/release.sh v$ver)"
un=$(g branch --no-merged main --format='%(refname:short)')
if [ -n "$un" ]; then echo "finished but NOT merged into main (merge: bash tools/ship.sh <branch>):"; echo "$un" | sed 's/^/   /'; else echo "no unmerged branches"; fi
dirty=""; for w in $(g worktree list --porcelain | awk '/^worktree /{print $2}'); do
  n=$(git -C "$w" status --porcelain 2>/dev/null | wc -l); [ "$n" -gt 0 ] && dirty="$dirty\n   $(basename "$w"): $n uncommitted file(s)"; done
[ -n "$dirty" ] && printf "work in progress (not committed):$dirty\n" || echo "nothing uncommitted anywhere"
curl -s -m 3 -o /dev/null http://127.0.0.1:8081/v1/models && echo "local model: up" || echo "local model: DOWN (strata launch --preset qwen-iq2xs --no-tui --yes)"
