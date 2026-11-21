#!/usr/bin/env bash
# Installs the Ubermoc Forever addon into your World of Warcraft: Forever addon folder.
#
#   bash tools/install.sh              delete the addon folder in the game's AddOns and copy the WHOLE addon folder you are working in (run again to update)
#                                      the folder copied is the project folder this script lives in, so running it from a worker copy installs that worker's work, not main
#   bash tools/install.sh --link       link it instead of copying, so every change shows up after /reload
#   bash tools/install.sh --uninstall  remove it again (your saved settings are not touched)
#   bash tools/install.sh "/path/to/_forever_/Interface/AddOns"   use this folder, skip the search
#
# Works from any shell (run it as `bash ...` in fish). Needs only bash and standard tools.
# Where it looks: Steam's Proton prefixes (every Steam library, including an SD card), Lutris-style folders under
# ~/Games, and /Applications on a Mac. A game folder counts as Forever when its .flavor.info names the product
# `wowf` (the same test the Ubermoc Warcraft Mod Updater uses).
set -euo pipefail

ADDON="Ubermoc-Forever"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(cd "$HERE/.." && pwd -P)"    # the project folder this script belongs to: a worker copy, or main
SRC="${UBF_SRC:-$WORK/$ADDON}"        # what gets copied into the game

MODE="copy"
EXPLICIT="${WOW_ADDONS:-}"
while [ $# -gt 0 ]; do
  arg="$1"; shift
  case "$arg" in
    --link) MODE="link" ;;
    --uninstall) MODE="uninstall" ;;
    --from) SRC="$(cd "$1" && pwd -P)"; shift ;;   # install this folder instead of the one the script lives in
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) EXPLICIT="$arg" ;;
  esac
done

if [ "$MODE" != "uninstall" ] && [ ! -f "$SRC/$ADDON.toc" ]; then
  echo "Can't find the addon at $SRC (no $ADDON.toc). Run this from a full clone of the repo."
  exit 1
fi

# --- find the Forever AddOns folders -------------------------------------------------------------------------
declare -a ROOTS=()   # World of Warcraft folders (the ones holding .build.info)
declare -a FOUND=()   # .../_forever_/Interface/AddOns

add_root() {
  local r="$1" real
  [ -f "$r/.build.info" ] || return 0
  real="$(cd "$r" && pwd -P)" || return 0
  local x
  for x in "${ROOTS[@]:-}"; do [ "$x" = "$real" ] && return 0; done
  ROOTS+=("$real")
}

steam_libraries() {
  local sub root vdf p
  for sub in ".local/share/Steam" ".steam/steam" ".steam/root" ".var/app/com.valvesoftware.Steam/.local/share/Steam" ".var/app/com.valve.Steam/.local/share/Steam"; do
    root="$HOME/$sub"
    [ -d "$root" ] || continue
    echo "$root"
    vdf="$root/steamapps/libraryfolders.vdf"
    [ -f "$vdf" ] || continue
    # lines like:   "path"   "/run/media/mmcblk0p1"
    sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$vdf" | while IFS= read -r p; do
      [ -n "$p" ] && echo "${p//\\\\//}"
    done
  done
}

find_roots() {
  local lib pfx sub
  while IFS= read -r lib; do
    [ -d "$lib/steamapps/compatdata" ] || continue
    for pfx in "$lib"/steamapps/compatdata/*/pfx; do
      [ -d "$pfx" ] || continue
      for sub in "drive_c/Program Files (x86)/World of Warcraft" "drive_c/Program Files/World of Warcraft"; do
        add_root "$pfx/$sub"
      done
      # an install somewhere else inside the same prefix
      while IFS= read -r f; do add_root "$(dirname "$f")"; done < <(find "$pfx/drive_c" -maxdepth 4 -name .build.info 2>/dev/null)
    done
  done < <(steam_libraries | awk '!seen[$0]++')
  if [ -d "$HOME/Games" ]; then
    while IFS= read -r f; do add_root "$(dirname "$f")"; done < <(find "$HOME/Games" -maxdepth 7 -name .build.info 2>/dev/null)
  fi
  add_root "/Applications/World of Warcraft"
}

is_forever() { # a game folder whose .flavor.info names the product wowf
  local flavor="$1/.flavor.info"
  [ -f "$flavor" ] && [ "$(sed -n '2p' "$flavor" | tr -d '\r[:space:]')" = "wowf" ]
}

if [ -n "$EXPLICIT" ]; then
  if [ ! -d "$EXPLICIT" ]; then echo "That folder doesn't exist: $EXPLICIT"; exit 1; fi
  FOUND+=("$EXPLICIT")
else
  find_roots
  for root in "${ROOTS[@]:-}"; do
    [ -n "$root" ] || continue
    for game in "$root"/_*_; do
      [ -d "$game" ] || continue
      if is_forever "$game"; then
        mkdir -p "$game/Interface/AddOns"
        FOUND+=("$game/Interface/AddOns")
      fi
    done
  done
fi

if [ "${#FOUND[@]}" -eq 0 ]; then
  echo "Couldn't find a World of Warcraft: Forever install."
  if [ "${#ROOTS[@]}" -gt 0 ]; then
    echo "Found these World of Warcraft folders, but none is a Forever client (.flavor.info doesn't say wowf):"
    printf '  %s\n' "${ROOTS[@]}"
  fi
  echo "Start Forever once so it creates its folders, or pass the folder yourself:"
  echo "  bash tools/install.sh \"/path/to/World of Warcraft/_forever_/Interface/AddOns\""
  exit 1
fi

# --- do it ---------------------------------------------------------------------------------------------------
if pgrep -f "Wow.exe" >/dev/null 2>&1; then
  echo "Note: the game is running. Type /reload in the game (or restart it) to load the new files."
fi

for dest in "${FOUND[@]}"; do
  target="$dest/$ADDON"
  case "$MODE" in
    uninstall)
      if [ -e "$target" ] || [ -L "$target" ]; then rm -rf "$target"; echo "removed   $target"; else echo "not installed in $dest"; fi
      ;;
    link)
      rm -rf "$target"
      ln -s "$(cd "$SRC" && pwd -P)" "$target"
      echo "linked    $target -> $(cd "$SRC" && pwd -P)"
      ;;
    copy)
      # the whole folder, not single files: remove the game's folder, then copy the whole folder you are working in as one unit
      echo "copy from $SRC (project folder $(basename "$WORK"), branch $(git -C "$WORK" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown))"
      if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target" || { echo "Could not remove $target"; exit 1; }
        echo "removed   $target"
      fi
      cp -a "$SRC" "$dest" || { echo "Copy failed into $dest"; exit 1; }
      [ -f "$target/$ADDON.toc" ] || { echo "Copy failed: $target/$ADDON.toc is missing."; exit 1; }
      if diff -rq "$SRC" "$target" >/dev/null 2>&1; then
        echo "installed $target ($(find "$target" -type f | wc -l | tr -d ' ') files, identical to $(cd "$SRC" && pwd -P), version $(sed -n 's/^## Version: *//p' "$target/$ADDON.toc" | tr -d '\r'))"
      else
        echo "Copy is NOT identical to $(cd "$SRC" && pwd -P):"
        diff -rq "$SRC" "$target"
        exit 1
      fi
      ;;
  esac
done

if [ "$MODE" != "uninstall" ]; then
  echo
  echo "Done. In the game: Esc > Ubermoc Forever, or the first time with a controller, answer the prompt."
  echo "If the game was already running, type /reload."
fi
