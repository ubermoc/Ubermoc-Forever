#!/usr/bin/env python3
"""Check that every WoW API we use really exists in the Forever UI source.

Usage:  python3 -I tools/api_check.py            (checks the addon, prints unknown names)
        python3 -I tools/api_check.py --rebuild  (rebuild tools/forever-api-index.txt from the source mirror)

Source mirror (branch `forever`): ~/local-ai/reference/wow-ui-source-forever
A name is "known" if the Forever UI source defines or documents it, if it is standard Lua 5.1, or if it is listed
with a source citation in tools/api-known-extra.txt (for engine functions the Lua source only calls, never defines).
Exit code 1 if anything is unknown.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIRROR = os.path.expanduser("~/local-ai/reference/wow-ui-source-forever/Interface")
INDEX = os.path.join(ROOT, "tools", "forever-api-index.txt")
EXTRA = os.path.join(ROOT, "tools", "api-known-extra.txt")
ADDON_DIRS = ["Core", "Input", "Locales", "UI", "Layouts"]

LUA_STD = set("""
assert collectgarbage error getfenv getmetatable ipairs load loadstring next pairs pcall print rawequal rawget rawset
select setfenv setmetatable tonumber tostring type unpack xpcall _G _VERSION
string table math os coroutine bit
""".split())
LUA_LIB_FIELDS = set("""
string.byte string.char string.find string.format string.gmatch string.gsub string.len string.lower string.match string.rep string.reverse string.sub string.upper
table.concat table.insert table.remove table.sort table.getn table.wipe table.maxn
math.abs math.ceil math.floor math.max math.min math.random math.sqrt math.pi math.huge math.fmod math.sin math.cos math.atan2 math.pow math.exp math.log
os.time os.date os.clock coroutine.create coroutine.resume coroutine.yield coroutine.wrap coroutine.status
""".split())

# Words that follow "function"/"local" etc. are handled by stripping; these are Lua keywords.
KEYWORDS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while".split())


def build_index():
    names = set()
    if not os.path.isdir(MIRROR):
        sys.exit("Source mirror not found: " + MIRROR)
    fn_def = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*[(.:]", re.M)
    glob_assign = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", re.M)
    ns_def = re.compile(r'Namespace = "([A-Za-z0-9_]+)"')
    api_fn = re.compile(r'\n\t\t\{\s*\n\t\t\tName = "([A-Za-z0-9_]+)",\s*\n\t\t\tType = "Function"')
    api_top = re.compile(r'\n\t\t\{\s*\n\t\t\tName = "([A-Za-z0-9_]+)",\s*\n\t\t\tType = "Function"')
    pad = re.compile(r'KEY_(PAD[A-Z0-9]+)|"(PAD[A-Z0-9]+)"')
    event = re.compile(r'LiteralName = "([A-Z0-9_]+)"')
    xml_name = re.compile(r'\bname="([A-Za-z_][A-Za-z0-9_]*)"')
    called = re.compile(r"(?<![\w.:])([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    other_games = {"Mainline", "Mists", "Cata", "Standard", "Wrath", "TBC", "Vanilla", "WoWLabs", "Plunderstorm"}
    for dp, _, files in os.walk(MIRROR):
        in_other_game = bool(other_games & set(os.path.relpath(dp, MIRROR).split(os.sep)))
        for f in files:
            p = os.path.join(dp, f)
            if f.endswith(".lua"):
                t = open(p, encoding="utf-8", errors="replace").read()
                for m in pad.finditer(t):
                    names.add("PAD:" + (m.group(1) or m.group(2)))
                if not in_other_game:
                    # engine functions: anything Forever-loaded Blizzard code calls exists
                    for m in called.finditer(t):
                        names.add(m.group(1))
                for m in fn_def.finditer(t):
                    names.add(m.group(1))
                for m in glob_assign.finditer(t):
                    names.add(m.group(1))
                if "Documentation" in f:
                    ns = ns_def.search(t)
                    fns = api_fn.findall(t)
                    for fn in fns:
                        names.add((ns.group(1) + "." + fn) if ns else fn)
                        names.add(fn)
                    if ns:
                        names.add(ns.group(1))
                    for e in event.findall(t):
                        names.add("EVENT:" + e)
            elif f.endswith(".xml"):
                t = open(p, encoding="utf-8", errors="replace").read()
                for m in xml_name.finditer(t):
                    names.add(m.group(1))
    with open(INDEX, "w") as fh:
        fh.write("\n".join(sorted(names)) + "\n")
    print("index rebuilt: %d names" % len(names))


def load_index():
    if not os.path.exists(INDEX):
        sys.exit("tools/forever-api-index.txt missing: run  python3 -I tools/api_check.py --rebuild")
    known = set(open(INDEX).read().split())
    if os.path.exists(EXTRA):
        for line in open(EXTRA):
            line = line.split("#")[0].strip()
            if line:
                known.add(line.split()[0])
    return known


def strip_lua(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    strings = []

    def keep(m):
        strings.append(m.group(0))
        return '""'
    src = re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', keep, src)
    return src, strings


def main():
    if "--rebuild" in sys.argv:
        build_index()
        return 0
    known = load_index()
    problems = []
    for d in ADDON_DIRS:
        for dp, _, files in os.walk(os.path.join(ROOT, d)):
            for f in files:
                if not f.endswith(".lua"):
                    continue
                p = os.path.join(dp, f)
                raw = open(p, encoding="utf-8", errors="replace").read()
                locals_ = set(re.findall(r"\blocal\s+function\s+([A-Za-z_]\w*)", raw))
                for decl in re.findall(r"\blocal\s+([A-Za-z_][\w\s,]*?)(?:=|\n|;)", raw):
                    locals_.update(x.strip() for x in decl.split(","))
                for args in re.findall(r"function\s*[\w.:]*\(([^)]*)\)", raw):
                    locals_.update(a.strip() for a in args.split(","))
                for loopvars in re.findall(r"\bfor\s+([\w\s,]+?)\s+in\b", raw):
                    locals_.update(x.strip() for x in loopvars.split(","))
                for loopvar in re.findall(r"\bfor\s+(\w+)\s*=", raw):
                    locals_.add(loopvar)
                code, _ = strip_lua(raw)
                # self-defined globals
                for m in re.finditer(r"^\s*function\s+([A-Za-z_]\w*)", code, re.M):
                    locals_.add(m.group(1))
                for m in re.finditer(r"^([A-Za-z_]\w*)\s*=", code, re.M):
                    locals_.add(m.group(1))
                # function calls on bare globals or C_ namespaces
                for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)((?:\.[A-Za-z_]\w*)?)\s*[({\"']", code):
                    base, field = m.group(1), m.group(2)
                    if base in KEYWORDS or base in locals_ or base == "ns" or base == "self":
                        continue
                    if base in LUA_STD:
                        if field and (base + field) not in LUA_LIB_FIELDS and base in ("string", "table", "math", "os", "coroutine"):
                            problems.append((p, "Lua library function not in Lua 5.1 list: " + base + field))
                        continue
                    full = base + field
                    if base.startswith("C_") and field:
                        if full not in known:
                            problems.append((p, "unknown namespaced API: " + full))
                    elif base not in known:
                        problems.append((p, "unknown global: " + base))
                # events
                for m in re.finditer(r'RegisterEvent\(\s*"([A-Z0-9_]+)"', raw):
                    if "EVENT:" + m.group(1) not in known:
                        problems.append((p, "unknown event: " + m.group(1)))
                # binding / key names
                for m in re.finditer(r'"(PAD[A-Z0-9]+)"', raw):
                    if "PAD:" + m.group(1) not in known:
                        problems.append((p, "unverified pad button name: " + m.group(1)))
    seen = set()
    for p, msg in problems:
        key = (os.path.relpath(p, ROOT), msg)
        if key in seen:
            continue
        seen.add(key)
        print("%s: %s" % key)
    if seen:
        print("\n%d unknown API names. For each: grep the Forever source mirror, read the hit, then either fix the code or add the name"
              " plus the source file:line to tools/api-known-extra.txt." % len(seen))
        return 1
    print("api_check: all API names found in the Forever source")
    return 0


if __name__ == "__main__":
    sys.exit(main())
