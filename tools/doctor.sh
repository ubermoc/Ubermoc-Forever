#!/usr/bin/env bash
# Checks everything a worker needs and says exactly how to fix what is missing.   bash tools/doctor.sh
ok=1; say() { printf '%-34s %s\n' "$1" "$2"; }
PY="${UBF_PYTHON:-$HOME/Downloads/WoW Forever Tools and Research/.venv/bin/python}"
if [ -x "$PY" ] && "$PY" -c "import lupa" 2>/dev/null; then say "Python with lupa (offline test)" "ok"; else say "Python with lupa" "MISSING: run  bash tools/setup-research.sh"; ok=0; fi
command -v luac5.1 >/dev/null && say "luac5.1 (Lua 5.1 checker)" "ok" || { say "luac5.1" "MISSING: sudo pacman -S lua51"; ok=0; }
[ -d "$HOME/Downloads/WoW Forever Tools and Research/blizzard-ui-source-forever" ] && say "Blizzard UI source" "ok" || { say "Blizzard UI source" "MISSING: run  bash tools/setup-research.sh"; ok=0; }
git -c user.name=x -c user.email=y rev-parse --git-dir >/dev/null 2>&1 && say "git repository" "ok" || { say "git repository" "not in a repo"; ok=0; }
if bash "$(dirname "$0")/install.sh" --help >/dev/null 2>&1; then say "install script" "ok (finds the game folder when run)"; fi
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && say "gh (GitHub release, user only)" "ok" || say "gh login" "not needed by workers; the user releases"
curl -s -m 3 -o /dev/null http://127.0.0.1:8081/v1/models && say "local model server (:8081)" "up" || say "local model server (:8081)" "DOWN: strata launch --preset qwen-iq2xs --no-tui --yes"
[ "$ok" = 1 ] && echo "Everything a worker needs is in place." || echo "Fix the MISSING lines above, then run this again."
