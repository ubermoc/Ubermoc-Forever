#!/usr/bin/env bash
# Puts Ubermoc Forever's saved settings back to a fresh install (the game must be closed: it writes them back when it quits).
# The old file is kept as a dated backup next to it. The game's own key binds are not touched.
set -e
SV="$(find "$HOME/.local/share/Steam/steamapps/compatdata" -path "*_forever_/WTF/Account/*/SavedVariables/Ubermoc-Forever.lua" 2>/dev/null | head -1)"
if [ -z "$SV" ]; then echo "No saved settings found."; exit 0; fi
if pgrep -f "_forever_.*Wow.exe" >/dev/null; then echo "The game is still running: close it completely first."; exit 1; fi
stamp="$(date +%Y%m%d-%H%M%S)"
cp "$SV" "$SV.fresh-backup-$stamp"
rm -f "$SV" "$SV.bak"
echo "Reset. Backup: $SV.fresh-backup-$stamp"
