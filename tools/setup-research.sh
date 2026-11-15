#!/usr/bin/env bash
# Builds the "WoW Forever Tools and Research" folder in your Downloads and keeps it up to date.
#
#   bash tools/setup-research.sh
#
# It works from any shell (run it as `bash ...` in fish). Run it again any time to update everything.
# Change the folder with:  DEST=/some/folder bash tools/setup-research.sh
# Also fetch Blizzard's texture repository (large):  WITH_TEXTURES=1 bash tools/setup-research.sh
set -euo pipefail

DEST="${DEST:-$HOME/Downloads/WoW Forever Tools and Research}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GIT_LFS_SKIP_SMUDGE=1

command -v git >/dev/null || { echo "git is needed. Install it first."; exit 1; }
mkdir -p "$DEST"

clone() { # name url [branch]
  local name="$1" url="$2" branch="${3:-}" target="$DEST/$1"
  if [ -d "$target/.git" ]; then
    echo "update  $name"
    git -C "$target" pull --ff-only -q || echo "        (could not update $name; left as it was)"
    return
  fi
  echo "clone   $name"
  if [ -n "$branch" ]; then
    git clone -q --depth 1 --branch "$branch" --single-branch "$url" "$target"
  else
    git clone -q --depth 1 "$url" "$target"
  fi
}

# Blizzard's own UI code for the Forever client (the `forever` branch). The first place to look for any
# template, atlas, function or event: nothing here is guessed.
clone blizzard-ui-source-forever https://github.com/Gethe/wow-ui-source forever
# A list of every function and frame in the Forever client, plus findings and porting notes.
clone forever-addon-kit https://github.com/Thunderz96/forever-addon-kit
# A shipped Forever addon whose docs/forever-api.md lists each Forever fact and how it was verified.
clone ForeverPlusPlus https://github.com/xIGBClutchIx/ForeverPlusPlus
# A generated API reference for the modern client, plus deploy tooling.
clone Atraeau-WoW-Addons https://github.com/Atraeau/WoW-Addons
# A WoW-aware Lua checker (understands the game's API). Build or install it from its README.
clone wowlua-ls https://github.com/TradeSkillMaster/wowlua-ls
if [ "${WITH_TEXTURES:-0}" = "1" ]; then
  # Blizzard's texture files. Large; the addon does not need them (it uses the game's atlases by name).
  clone blizzard-ui-textures https://github.com/Gethe/wow-ui-textures
fi

# Our own notes and the offline test.
mkdir -p "$DEST/ubermoc-forever-notes"
cp "$HERE/../docs/RESEARCH.md" "$DEST/ubermoc-forever-notes/RESEARCH.md" 2>/dev/null || true
cp "$HERE/smoke_test.py" "$DEST/ubermoc-forever-notes/smoke_test.py"

# A private Python with the Lua runtime the offline test needs (nothing is installed system-wide).
if command -v python3 >/dev/null; then
  if [ ! -x "$DEST/.venv/bin/python" ]; then
    echo "make    private Python (for the offline test)"
    python3 -m venv "$DEST/.venv" || echo "        (python3 venv is not available; skip the offline test)"
  fi
  if [ -x "$DEST/.venv/bin/pip" ]; then
    "$DEST/.venv/bin/pip" install -q --upgrade lupa || echo "        (could not install lupa)"
  fi
fi

cat <<EOF

Done. Everything is in:
  $DEST

Run the offline test on the addon (from the repo folder):
  "$DEST/.venv/bin/python" tools/smoke_test.py

Look something up in Blizzard's Forever UI code:
  grep -rn "SomeFunctionName" "$DEST/blizzard-ui-source-forever/Interface/AddOns" | head
EOF
