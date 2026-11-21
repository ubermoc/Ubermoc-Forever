#!/usr/bin/env bash
# Cut a GitHub release of what is on main.  ONLY when the user says to release; it publishes.   Run in the MAIN folder:
#   bash tools/release.sh v1.3.141
# Needs the version to equal the .toc version, the tree clean, main pushed, and the tag not yet released.
# Notes come from the top entry of CHANGELOG.txt. The CurseForge upload is a separate, manual step (see AGENTS.md).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
tag="${1:?usage: release.sh vX.Y.Z}"; ver="${tag#v}"
[ "$(git branch --show-current)" = main ] || { echo "Not on main."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Uncommitted changes."; exit 1; }
git fetch -q origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "main and origin/main differ: push first (bash tools/ship.sh ...)."; exit 1; }
[ "$ver" = "$(grep '^## Version' Ubermoc-Forever/Ubermoc-Forever.toc | sed 's/.*: *//')" ] || { echo "The .toc version is not $ver."; exit 1; }
gh release view "$tag" >/dev/null 2>&1 && { echo "$tag is already released."; exit 1; }
zip="/tmp/Ubermoc-Forever-$tag-forever.zip"; rm -f "$zip"
python3 -I - "$zip" <<'PY'
import shutil, sys, os
base = sys.argv[1][:-4]
shutil.make_archive(base, "zip", root_dir=".", base_dir="Ubermoc-Forever")
PY
# Notes: every CHANGELOG entry from this version down to (not including) the previous release, so people who skipped versions see all of it.
# Headers before the rename still say `UbermocForever <version>`, so an entry starts at either spelling.
prev=$(gh release list --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || true); prev="${prev#v}"
notes=$(awk -v v="Ubermoc-Forever $ver" -v p="$prev" '
  index($0,v)==1 {f=1}
  f && /^(Ubermoc-Forever|UbermocForever) [0-9]/ { split($0,a," "); if (p != "" && a[2]==p) exit }
  f' CHANGELOG.txt)
[ -n "$notes" ] || { echo "No CHANGELOG entry for $ver."; exit 1; }
gh release create "$tag" "$zip" --title "Version $ver" --target main --latest --notes "$notes"
echo "Released $tag on GitHub. CurseForge: upload $zip by hand (AGENTS.md, Releasing)."
