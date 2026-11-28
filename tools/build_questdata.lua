-- tools/build_questdata.lua: makes Ubermoc-Forever/QuestData.lua, the addon's own quest database, from QuestieDB's Forever data.
--
-- Run it from the QuestieDB folder with QuestieDB's bundled Lua (tools/build_questdata.sh does that):
--   <QuestieDB>/tools/lua-binary/linux-x64/lua <this file> <output file>
-- It loads QuestieDB's raw Forever entities with QuestieDB's own static corrections folded in (generator/flavor.lua), keeps only what the
-- quest guide needs, and writes one Lua file. The data is QuestieDB's (GPL-3.0); the output carries that notice.

local out = arg[1] or error("usage: lua build_questdata.lua <output QuestData.lua>")
local config = dofile("src/config.lua")
local lib = dofile("generator/lib.lua")
if lib.fileExists("src/corrections/manifest.lua") then config.correctionManifest = dofile("src/corrections/manifest.lua") end
local flavorLoader = dofile("generator/flavor.lua")

local flavor
for _, f in ipairs(config.flavors) do if f.name == "Forever" then flavor = f end end
assert(flavor, "no Forever flavor in QuestieDB's config")

local loaded = flavorLoader.load(flavor, nil, true)
local Q, N, O, I = loaded.Quest, loaded.Npc, loaded.Object, loaded.Item
assert(Q and N and O and I, "QuestieDB did not load all four entity types")
local function keys(t) return t.meta.keys or t.meta.questKeys or t.meta end
local qk, nk, ok_, ik = keys(Q), keys(N), keys(O), keys(I)
local function K(k, name) local v = k[name]; assert(v, "missing key " .. name); return v end

-- zone (AreaTable id) -> UiMapID, as QuestieDB's Forever support data says
local ZoneDB = { private = {} }
QuestieLoader = { ImportModule = function(_, name) if name == "ZoneDB" then return ZoneDB end return { } end }
UnitFactionGroup = function() return "Alliance" end
dofile("support/Forever/Zones/areaIdToUiMapId.lua")
local zmap = {}
local function merge(src) if type(src) == "string" then src = assert(loadstring(src))() end for k, v in pairs(src or {}) do zmap[k] = v end end
merge(ZoneDB.private.areaIdToUiMapId)
merge(ZoneDB.private.areaIdToUiMapIdOverride)

-- dungeon entrances, for spawns QuestieDB writes as -1,-1 (inside an instance)
local dungeonsSrc = lib.readAll("support/Forever/Zones/dungeons.lua")
local dtable = dungeonsSrc:match("local dungeons = (%b{})")
local entrances = {}
if dtable then
    local d = assert(loadstring("return " .. dtable))()
    for area, e in pairs(d) do
        local locs = e[4]
        if type(locs) == "table" and locs[1] then
            entrances[area] = { locs[1][1], locs[1][2], locs[1][3] }
            for _, alt in ipairs(e[2] or {}) do entrances[alt] = entrances[area] end
        end
    end
end

local function round1(x) return math.floor(x * 10 + 0.5) / 10 end

-- what is kept for a quest
local quests, needN, needO, needI = {}, {}, {}, {}
local count = 0
for id, q in pairs(Q.entities) do
    local name = q[K(qk, "name")]
    if type(name) == "string" and name ~= "" then
        local sb, fb, obj = q[K(qk, "startedBy")] or {}, q[K(qk, "finishedBy")] or {}, q[K(qk, "objectives")] or {}
        local e = {
            n = name, l = q[K(qk, "questLevel")], r = q[K(qk, "requiredLevel")], ra = q[K(qk, "requiredRaces")], cl = q[K(qk, "requiredClasses")],
            s = { sb[1], sb[2], sb[3] }, f = { fb[1], fb[2] },
            c = {}, o = {}, i = {}, k = {},
            pg = q[K(qk, "preQuestGroup")], ps = q[K(qk, "preQuestSingle")], ex = q[K(qk, "exclusiveTo")],
            z = q[K(qk, "zoneOrSort")], sf = q[K(qk, "specialFlags")], mx = q[K(qk, "requiredMaxLevel")], nx = q[K(qk, "nextQuestInChain")],
        }
        for _, row in ipairs(obj[1] or {}) do e.c[#e.c + 1] = row[1]; needN[row[1]] = true end
        for _, row in ipairs(obj[2] or {}) do e.o[#e.o + 1] = row[1]; needO[row[1]] = true end
        for _, row in ipairs(obj[3] or {}) do e.i[#e.i + 1] = row[1]; needI[row[1]] = true end
        for _, row in ipairs(obj[5] or {}) do for _, c in ipairs(row[1] or {}) do e.k[#e.k + 1] = c; needN[c] = true end end
        for _, x in ipairs(e.s[1] or {}) do needN[x] = true end
        for _, x in ipairs(e.s[2] or {}) do needO[x] = true end
        for _, x in ipairs(e.f[1] or {}) do needN[x] = true end
        for _, x in ipairs(e.f[2] or {}) do needO[x] = true end
        local te = q[K(qk, "triggerEnd")]
        if type(te) == "table" and type(te[2]) == "table" then e.t = { te[1], te[2] } end   -- "go to this place" objectives
        quests[id] = e
        count = count + 1
    end
end

-- items: who drops them (creatures and objects)
local items = {}
for id in pairs(needI) do
    local it = I.entities[id]
    if it then
        local nd, od = it[K(ik, "npcDrops")], it[K(ik, "objectDrops")]
        items[id] = { n = it[K(ik, "name")], d = nd, od = od }
        for _, x in ipairs(nd or {}) do needN[x] = true end
        for _, x in ipairs(od or {}) do needO[x] = true end
    end
end

local function spawns(raw)
    if type(raw) ~= "table" then return nil end
    local s, any = {}, false
    for zone, list in pairs(raw) do
        local pts = {}
        for _, p in ipairs(list) do
            if type(p) == "table" and p[1] and p[2] then pts[#pts + 1] = { round1(p[1]), round1(p[2]) } end
        end
        if #pts > 0 then s[zone] = pts; any = true end
    end
    return any and s or nil
end

local npcs, objs = {}, {}
for id in pairs(needN) do
    local n = N.entities[id]
    if n then npcs[id] = { n = n[K(nk, "name")], s = spawns(n[K(nk, "spawns")]), fr = n[K(nk, "friendlyToFaction")], lv = n[K(nk, "maxLevel")] } end
end
for id in pairs(needO) do
    local o = O.entities[id]
    if o then objs[id] = { n = o[K(ok_, "name")], s = spawns(o[K(ok_, "spawns")]) } end
end

-- a compact, deterministic Lua writer
local function ser(v)
    local t = type(v)
    if t == "number" then return (v == math.floor(v)) and string.format("%d", v) or string.format("%.1f", v) end
    if t == "string" then return string.format("%q", v) end
    if t == "boolean" then return v and "true" or "false" end
    if t ~= "table" then return "nil" end
    local parts, n = {}, #v
    for i = 1, n do parts[#parts + 1] = ser(v[i]) end
    local ks = {}
    for k in pairs(v) do if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then ks[#ks + 1] = k end end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
        local kk = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. ser(k) .. "]")
        parts[#parts + 1] = kk .. "=" .. ser(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function block(name, tbl)
    local ids = {}
    for id in pairs(tbl) do ids[#ids + 1] = id end
    table.sort(ids)
    local lines = { "D." .. name .. " = {" }
    for _, id in ipairs(ids) do lines[#lines + 1] = "[" .. id .. "]=" .. ser(tbl[id]) .. "," end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

local commit = (lib.gitCommit and lib.gitCommit(".")) or "unknown"
local f = assert(io.open(out, "w"))
f:write("-- Ubermoc Forever quest data, generated by tools/build_questdata.lua from QuestieDB's Forever data (commit ", commit, ").\n")
f:write("-- The data is QuestieDB's (https://github.com/Questie/QuestieDB), licensed GPL-3.0; see LICENSE and THIRD-PARTY.md. Do not edit by hand.\n")
f:write("local _, UF = ...\nlocal D = {}\nUF.QuestData = D\n")
f:write("D.source = ", string.format("%q", commit), "\n")
f:write(block("Q", quests), "\n", block("N", npcs), "\n", block("O", objs), "\n", block("I", items), "\n")
f:write("D.Z = ", ser(zmap), "\n")
f:write("D.E = ", ser(entrances), "\n")
f:close()
local function size(t) local c = 0 for _ in pairs(t) do c = c + 1 end return c end
print(string.format("quests %d, npcs %d, objects %d, items %d, zones %d, entrances %d -> %s", count, size(npcs), size(objs), size(items), size(zmap), size(entrances), out))
