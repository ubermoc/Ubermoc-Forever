#!/usr/bin/env python3
"""Read the addon's saved settings (what the game writes to WTF/.../SavedVariables/Ubermoc-Forever.lua) and print a part of it as JSON.

The game writes that file only at /reload or logout, so ask the player to /reload first. Examples:
  python3 tools/read_saved.py                      the list of top-level keys and their sizes
  python3 tools/read_saved.py learned              what the learning has kept (trail, rides, entrances, taxi, log)
  python3 tools/read_saved.py navData.taxi         one scan
  python3 tools/read_saved.py combatLog            the combat/conversation timeline
  python3 tools/read_saved.py stealthIncidents     refused Stealth casts, each with its timeline and the game's error text
  python3 tools/read_saved.py qarrow.debug         the quest arrow's numbers
  python3 tools/read_saved.py --file PATH ...      another saved-variables file
Needs lupa (the research folder's venv has it: see tools/setup-research.sh). The file is the player's own settings; it is only read.
"""
import json
import os
import sys

try:
    import lupa
    from lupa import LuaRuntime
except ImportError:
    sys.exit("lupa is missing: use the research folder's python (tools/setup-research.sh makes it)")

DEFAULT_GLOB = os.path.expanduser(
    "~/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/*/SavedVariables/Ubermoc-Forever.lua")


def find_file():
    import glob
    found = sorted(glob.glob(DEFAULT_GLOB), key=os.path.getmtime)
    return found[-1] if found else None


def convert(lua, t):
    if lupa.lua_type(t) == "table":
        keys = list(t.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [convert(lua, t[k]) for k in sorted(keys)]
        return {str(k): convert(lua, t[k]) for k in keys}
    return t


def main(argv):
    path = None
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--file":
            path = argv[i + 1]
            i += 2
        else:
            args.append(argv[i])
            i += 1
    path = path or find_file()
    if not path or not os.path.exists(path):
        sys.exit("no saved-variables file found; give one with --file PATH")
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(open(path, encoding="utf-8", errors="replace").read())   # a table assignment file written by the game
    db = convert(lua, lua.globals().UbermocForeverDB)
    print("# " + path + "  (modified " + __import__("datetime").datetime.fromtimestamp(os.path.getmtime(path)).isoformat(timespec="seconds") + ")", file=sys.stderr)
    if not args:
        for k in sorted(db):
            size = len(json.dumps(db[k]))
            print(f"{k}: {size} bytes")
        return
    node = db
    for part in args[0].split("."):
        node = node[part] if isinstance(node, dict) and part in node else (node[int(part) - 1] if isinstance(node, list) else None)
        if node is None:
            sys.exit("no such part: " + args[0])
    print(json.dumps(node, indent=1, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1:])
