#!/usr/bin/env bash
# Rebuilds Ubermoc-Forever/QuestData.lua from QuestieDB's Forever data (GPL-3.0), with QuestieDB's own corrections folded in.
# Needs a QuestieDB checkout: UBF_QUESTIEDB, default "<research folder>/quest-addons/QuestieDB" (git clone https://github.com/Questie/QuestieDB).
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
research=${UBF_RESEARCH:-$HOME/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - WoW Research and Tools}
qdb=${UBF_QUESTIEDB:-$research/quest-addons/QuestieDB}
[ -f "$qdb/generator/flavor.lua" ] || { echo "No QuestieDB checkout at $qdb (set UBF_QUESTIEDB)"; exit 1; }
lua=${LUA:-$qdb/tools/lua-binary/linux-x64/lua}
cd "$qdb"
"$lua" "$here/tools/build_questdata.lua" "$here/Ubermoc-Forever/QuestData.lua"
