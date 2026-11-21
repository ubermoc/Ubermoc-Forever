#!/usr/bin/env python3
"""Checks that the offline test cannot do. The test runs Lua 5.5 with stubs; the game runs Lua 5.1.

  1. Syntax with luac5.1: no goto, no // or bit operators, no <const>, no integer tricks (all fine in 5.5, errors in the game).
  2. Every global a file reads or writes (luac5.1 -l): a write is reported (an accidental global leaks into the game's shared
     space and can taint it); a read of a name that nothing defines (not Lua's own, not in the Forever API dump, not anywhere in
     Blizzard's Forever UI source, not set by the file itself) is reported as a likely typo or a missing helper.
  3. --risky: lines that use calls needing a second look for taint or secret values (hooks, SetPoint, Show/Hide, unit data ...).

Usage:  python3 tools/check_lua.py Ubermoc-Forever/Loot.lua [more files] [--risky]
Exit code 0 only when every file passes steps 1 and 2. Needs luac5.1 (package lua51) and, for step 2's lookups, the Blizzard
source made by tools/setup-research.sh (set UBF_BLIZZARD to another folder if it is elsewhere).
"""
import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESEARCH = os.environ.get("UBF_RESEARCH", os.path.join(PROJECT, "Project Support", "Ubermoc-Forever - WoW Research and Tools"))
BLIZZARD = os.environ.get("UBF_BLIZZARD", os.path.join(RESEARCH, "blizzard-ui-source-forever", "Interface"))
API_DUMP = os.path.join(RESEARCH, "forever-addon-kit", "data", "forever_api.json")

LUA51 = {
    "assert", "collectgarbage", "error", "getfenv", "getmetatable", "ipairs", "load", "loadstring", "next", "pairs", "pcall",
    "print", "rawequal", "rawget", "rawset", "select", "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack",
    "xpcall", "string", "table", "math", "os", "coroutine", "bit", "debug", "_G", "_VERSION", "newproxy", "gcinfo",
}

RISKY = [
    (r"hooksecurefunc", "hook on a game function: keep it tiny, never write game state from it"),
    (r"securecall", "securecallfunction does not make our call secure"),
    (r":SetPoint\(|:ClearAllPoints\(", "anchoring: never on a protected frame or an action button; never on the game's own pieces"),
    (r":Show\(\)|:Hide\(\)", "Show/Hide: the game toggles these itself; use alpha for the game's pieces"),
    (r":SetShown\(", "Show/Hide: the game toggles these itself; use alpha for the game's pieces"),
    (r"SetShowOnlyName|UpdateShownState|UpdateAnchors|SetUnit\(|UpdateName\(", "calls a game method: runs the game's code under our taint"),
    (r"\bUnit(Health|HealthMax|Name|Class|IsPlayer|Reaction|IsTapDenied|GUID|Power|PowerMax)\(", "unit data: a secret value for our code; test with issecretvalue before any use"),
    (r"GetTextColor|GetStatusBarColor|GetVertexColor|:GetText\(", "reads a value the game may have made secret"),
    (r":SetFont\(|:SetFontObject\(|:SetText\(", "changes text the game owns"),
    (r"SetScript\(\"OnUpdate\"|OnUpdate", "per-frame code: keep it cheap and only while needed"),
    (r"SetAttribute|RegisterStateDriver|SetOverrideBinding", "secure attribute or binding: out of combat only"),
    (r"SetCVar|C_CVar\.SetCVar", "writes a game setting: out of combat, remember the old value, give it back"),
    (r"\.ubf\w*\s*=|\.ubermoc\w*\s*=", "writes a field on a table: never on a game frame (use a weak-keyed table of ours)"),
]


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def api_names():
    names = set()
    try:
        d = json.load(open(API_DUMP))
    except (OSError, ValueError):
        return names
    names.update(d.get("functions", []))
    names.update(d.get("namespaces", {}).keys())
    return names


_seen = {}


def in_blizzard(name):
    if name in _seen:
        return _seen[name]
    found = False
    if os.path.isdir(BLIZZARD):
        r = run(["grep", "-rlw", "-m1", "--include=*.lua", "--include=*.xml", "--", name, BLIZZARD])
        found = bool(r.stdout.strip())
    _seen[name] = found
    return found


def declared_globals(path):
    """Globals a file may legitimately set: slash commands (SLASH_*) and the TOC's SavedVariables."""
    names = set()
    folder = os.path.dirname(os.path.abspath(path))
    for f in os.listdir(folder):
        if f.endswith(".toc"):
            for line in open(os.path.join(folder, f), encoding="utf-8", errors="replace"):
                m = re.match(r"##\s*SavedVariables(?:PerCharacter)?\s*:\s*(.*)", line)
                if m:
                    names.update(n.strip() for n in m.group(1).split(","))
    return names


CONSTANT = re.compile(r"^[A-Z][A-Z0-9_]+$")   # the game's text constants (GlobalStrings) are not in the Lua source copy


def check(path, luac, api, risky):
    problems = 0
    r = run([luac, "-p", path])
    if r.returncode != 0:
        print(f"{path}: SYNTAX (Lua 5.1, the game's): {r.stderr.strip()}")
        return 1
    listing = run([luac, "-l", "-p", path]).stdout
    reads, writes = {}, {}
    for m in re.finditer(r"\[(\d+)\]\s+(GETGLOBAL|SETGLOBAL)\s+[^;\n]*;\s*(\S+)", listing):
        line, op, name = int(m.group(1)), m.group(2), m.group(3)
        (reads if op == "GETGLOBAL" else writes).setdefault(name, []).append(line)
    allowed = declared_globals(path)
    for name, lines in sorted(writes.items()):
        if name in allowed or name.startswith("SLASH_"):
            continue
        problems += 1
        print(f"{path}: GLOBAL WRITE {name} (line {', '.join(map(str, lines[:5]))}): a global leaks into the game; make it local")
    own = set(writes)
    unknown = []
    for name, lines in sorted(reads.items()):
        if name in LUA51 or name in own or name in allowed or name in api or in_blizzard(name):
            continue
        if CONSTANT.match(name):
            print(f"{path}: unverified constant {name} (line {', '.join(map(str, lines[:5]))}): a game text constant? check it is guarded (`X or \"fallback\"`)")
            continue
        unknown.append(name)
        problems += 1
        print(f"{path}: UNKNOWN GLOBAL {name} (line {', '.join(map(str, lines[:5]))}): not Lua's, not in the Forever API, not in Blizzard's source: a typo or a missing helper")
    print(f"{path}: syntax ok (Lua 5.1); {len(reads)} globals read, {len(writes)} written, {len(unknown)} unknown")
    if risky:
        text = open(path, encoding="utf-8").read().splitlines()
        for pat, why in RISKY:
            hits = [i + 1 for i, l in enumerate(text) if re.search(pat, re.sub(r"--.*$", "", l))]
            if hits:
                print(f"  risky  {pat}  lines {', '.join(map(str, hits[:12]))}{' ...' if len(hits) > 12 else ''}  -> {why}")
    problems += silent_pcalls(path)
    problems += lua53_library(path)
    return problems


# Library calls that exist only in Lua 5.2/5.3 or work differently there. luac5.1 checks syntax, not library calls, and the offline test
# runs 5.5, so only this sees them. math.atan(y, x) is the one that bit: in the game the second argument is ignored (use math.atan2).
LUA53 = [
    (re.compile(r"\bmath\.atan\([^()]*(\([^()]*\)[^()]*)*,"), "math.atan takes ONE argument in the game's Lua 5.1 (the second is ignored): use math.atan2(y, x)"),
    (re.compile(r"\btable\.move\("), "table.move does not exist in Lua 5.1"),
    (re.compile(r"\bmath\.(tointeger|type|ult)\("), "this math function does not exist in Lua 5.1"),
    (re.compile(r"\bstring\.(pack|unpack|packsize)\("), "string.pack and string.unpack do not exist in Lua 5.1"),
    (re.compile(r"\butf8\."), "utf8 does not exist in Lua 5.1"),
]


def lua53_library(path):
    n = 0
    for i, line in enumerate(open(path, encoding="utf-8").read().splitlines(), 1):
        code = re.sub(r"--.*$", "", line)
        for rx, why in LUA53:
            if rx.search(code):
                print(f"{path}:{i}: LUA 5.3 LIBRARY: {why}")
                n += 1
    return n


SILENT = re.compile(r"(^|\bthen\s+|\belse\s+|\bdo\s+|;\s*)pcall\(")
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "silent-pcall-baseline.json")


def silent_pcalls(path):
    """A `pcall(...)` used as a statement throws its error away: the feature then does nothing and nothing says why. Existing ones are
    counted per file in tools/silent-pcall-baseline.json and may not grow; new code uses UF.try(label, fn, ...) (Core.lua), which keeps
    the error for `/ubf errors`, or keeps the pcall's result and reports it. Lower the baseline when a file's count drops."""
    text = open(path, encoding="utf-8").read().splitlines()
    n = sum(1 for l in text if SILENT.search(re.sub(r"--.*$", "", l)))
    try:
        base = json.load(open(BASELINE)).get(os.path.basename(path))
    except (OSError, ValueError):
        base = None
    if base is None:
        base = 0 if n == 0 else n   # a file not in the baseline yet is recorded by --update-baseline; until then it is not held back
    if n > base:
        print(f"{path}: SILENT PCALL: {n} statement-level pcall(s), the baseline is {base}. A pcall whose result is dropped hides its error: use UF.try(label, fn, ...) or read ok/err")
        return 1
    return 0


def update_baseline(files):
    out = {}
    for p in files:
        text = open(p, encoding="utf-8").read().splitlines()
        out[os.path.basename(p)] = sum(1 for l in text if SILENT.search(re.sub(r"--.*$", "", l)))
    json.dump(dict(sorted(out.items())), open(BASELINE, "w"), indent=1)
    print("baseline written:", BASELINE)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--update-baseline" in sys.argv:
        update_baseline(args)
        return 0
    risky = "--risky" in sys.argv
    if not args:
        print(__doc__)
        return 2
    luac = shutil.which("luac5.1")
    if not luac:
        print("luac5.1 not found: install the lua51 package (sudo pacman -S lua51)")
        return 2
    if not os.path.isdir(BLIZZARD):
        print(f"note: Blizzard source not found at {BLIZZARD}: unknown globals cannot be looked up (run tools/setup-research.sh)")
    api = api_names()
    total = 0
    for p in args:
        total += check(p, luac, api, risky)
    print("PASSED" if total == 0 else f"{total} PROBLEM(S)")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
