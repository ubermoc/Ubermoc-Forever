----------------------------------------------------------------------
-- Ubermoc Forever: navigation scans (author tools, one at a time). Each one walks every map the game knows, reads what the game itself says
-- about one kind of place, and saves it in the saved settings (DB.navData.<name>), so the routing for the quest arrow can be built from the
-- game's own data instead of from guesses or from other addons' tables. The file under WTF/.../SavedVariables is written at /reload or logout.
--   /ubf docks      every area point of interest on every map: boats, zeppelins, skyships, trams, portals and the rest (the icon names of all
--                   of them are counted too, so the transport ones can be told apart from what the game calls them)
--   /ubf taxi       every flight point the game shows on each map (C_TaxiMap.GetTaxiNodesForMap: works anywhere, not only at a flight master)
--   /ubf maps       the map tree: name, type, parent, size in yards, place on its parent, and the continent position of its middle
--   /ubf entrances  every dungeon and raid entrance (C_EncounterJournal.GetDungeonEntrancesForMap)
--   /ubf scans      what is saved and when; /ubf scans stop ends a running scan
-- Slow on purpose (a few maps per frame) so the game stays smooth. Every call is guarded: a map that answers nothing is skipped.
----------------------------------------------------------------------
local _, UF = ...

local N = { running = nil, maxMap = 3500, perFrame = 20 }
UF.NavScan = N

-- a plain number, never a secret value
local function num(v)
    if type(v) ~= "number" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function str(v)
    if type(v) ~= "string" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function xy(pos)
    if type(pos) ~= "table" then return nil end
    return num(pos.x), num(pos.y)
end

-- the continent and the world position (yards) of a spot on a map, as the game converts it
local function world(mapID, x, y)
    if not (x and y and C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, mapID, { x = x, y = y })
    if not ok or type(wp) ~= "table" then return nil end
    return num(cont), num(wp.x), num(wp.y)
end

local function round(v, n) if not v then return nil end local m = 10 ^ (n or 4) return math.floor(v * m + 0.5) / m end

----------------------------------------------------------------------
-- What counts as a transport on the map (boat, zeppelin, skyship, tram, dock, portal), from the icon name or the words the game uses
----------------------------------------------------------------------
local WORDS = { "boat", "ship", "zeppelin", "tram", "dock", "portal", "harbor", "harbour", "airship", "skyship", "ferry", "transport", "port " }
function N.transportLike(atlas, name, desc)
    local t = ((atlas or "") .. " " .. (name or "") .. " " .. (desc or "")):lower()
    for _, w in ipairs(WORDS) do
        if t:find(w, 1, true) then return true end
    end
    return false
end

----------------------------------------------------------------------
-- The four scans: begin(data) makes the result tables, map(id, info, data) reads one map, finish(data) closes it
----------------------------------------------------------------------
local SCANS = {}

SCANS.docks = {
    title = "area points of interest",
    begin = function(d) d.rows, d.all, d.atlases = {}, {}, {} end,
    map = function(id, info, d)
        if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return end
        local ok, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, id)
        if not ok or type(ids) ~= "table" then return end
        for _, poi in ipairs(ids) do
            local okI, p = pcall(C_AreaPoiInfo.GetAreaPOIInfo, id, poi)
            if okI and type(p) == "table" then
                local x, y = xy(p.position)
                local name, desc, atlas = str(p.name), str(p.description), str(p.atlasName)
                d.all[#d.all + 1] = table.concat({ id, poi, round(x) or "", round(y) or "", atlas or "", name or "" }, "|")
                if atlas then
                    local a = d.atlases[atlas]
                    if not a then a = { n = 0, example = name }; d.atlases[atlas] = a end
                    a.n = a.n + 1
                end
                if N.transportLike(atlas, name, desc) then
                    local cont, wx, wy = world(id, x, y)
                    d.rows[#d.rows + 1] = { map = id, mapName = info.name, poi = poi, name = name, desc = desc, x = round(x), y = round(y),
                        atlas = atlas, faction = num(p.factionID), linked = num(p.linkedUiMapID), cont = cont, wx = round(wx, 1), wy = round(wy, 1) }
                end
            end
        end
    end,
    summary = function(d) return #d.all .. " points of interest, " .. #d.rows .. " that look like transport" end,
    lines = function(d)
        local out = {}
        for i = 1, math.min(#d.rows, 12) do
            local r = d.rows[i]
            out[#out + 1] = string.format("%s (%s) %s at %.3f %.3f", tostring(r.name), tostring(r.mapName), tostring(r.atlas), r.x or 0, r.y or 0)
        end
        return out
    end,
}

SCANS.taxi = {
    title = "flight points",
    begin = function(d) d.rows = {} end,
    map = function(id, info, d)
        if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, id)
        if not ok or type(nodes) ~= "table" then return end
        for _, n in ipairs(nodes) do
            if type(n) == "table" then
                local x, y = xy(n.position)
                local cont, wx, wy = world(id, x, y)
                d.rows[#d.rows + 1] = { map = id, mapName = info.name, node = num(n.nodeID), name = str(n.name), x = round(x), y = round(y),
                    atlas = str(n.atlasName), faction = num(n.faction), undiscovered = n.isUndiscovered and true or false,
                    cont = cont, wx = round(wx, 1), wy = round(wy, 1) }
            end
        end
    end,
    summary = function(d) return #d.rows .. " flight points" end,
    lines = function(d)
        local out = {}
        for i = 1, math.min(#d.rows, 12) do
            local r = d.rows[i]
            out[#out + 1] = string.format("%s (%s) at %.3f %.3f%s", tostring(r.name), tostring(r.mapName), r.x or 0, r.y or 0, r.undiscovered and ", not discovered" or "")
        end
        return out
    end,
}

SCANS.maps = {
    title = "maps",
    begin = function(d) d.rows = {} end,
    map = function(id, info, d)
        local w, h
        if C_Map and C_Map.GetMapWorldSize then
            local ok, ww, hh = pcall(C_Map.GetMapWorldSize, id)
            if ok then w, h = num(ww), num(hh) end
        end
        local r = { id = id, name = info.name, mapType = num(info.mapType), parent = num(info.parentMapID), flags = num(info.flags), w = round(w, 1), h = round(h, 1) }
        if r.parent and r.parent > 0 and C_Map and C_Map.GetMapRectOnMap then
            local ok, a, b, c, e = pcall(C_Map.GetMapRectOnMap, id, r.parent)
            if ok and num(a) then r.minX, r.maxX, r.minY, r.maxY = round(a), round(b), round(c), round(e) end
        end
        local cont, wx, wy = world(id, 0.5, 0.5)
        r.cont, r.cx, r.cy = cont, round(wx, 1), round(wy, 1)
        d.rows[#d.rows + 1] = r
    end,
    summary = function(d) return #d.rows .. " maps" end,
    lines = function(d)
        local byType = {}
        for _, r in ipairs(d.rows) do byType[r.mapType or -1] = (byType[r.mapType or -1] or 0) + 1 end
        local keys = {}
        for k in pairs(byType) do keys[#keys + 1] = k end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do out[#out + 1] = "map type " .. k .. ": " .. byType[k] end
        return out
    end,
}

SCANS.entrances = {
    title = "dungeon and raid entrances",
    begin = function(d) d.rows = {} end,
    map = function(id, info, d)
        if not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return end
        local ok, list = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, id)
        if not ok or type(list) ~= "table" then return end
        for _, e in ipairs(list) do
            if type(e) == "table" then
                local x, y = xy(e.position)
                local cont, wx, wy = world(id, x, y)
                d.rows[#d.rows + 1] = { map = id, mapName = info.name, poi = num(e.areaPoiID), name = str(e.name), desc = str(e.description), x = round(x), y = round(y),
                    atlas = str(e.atlasName), instance = num(e.journalInstanceID), cont = cont, wx = round(wx, 1), wy = round(wy, 1) }
            end
        end
    end,
    summary = function(d) return #d.rows .. " entrances" end,
    lines = function(d)
        local out = {}
        for i = 1, math.min(#d.rows, 12) do
            local r = d.rows[i]
            out[#out + 1] = string.format("%s (%s) at %.3f %.3f", tostring(r.name), tostring(r.mapName), r.x or 0, r.y or 0)
        end
        return out
    end,
}

N.names = { "docks", "taxi", "maps", "entrances" }
N.SCANS = SCANS

----------------------------------------------------------------------
-- Running one: a few maps per frame, one scan at a time
----------------------------------------------------------------------
local frame

local function db()
    local d = UF.DB()
    d.navData = d.navData or {}
    return d.navData
end

local function finish(r)
    local scan = SCANS[r.name]
    local ok, err = pcall(function()
        local saved = { at = time and time() or 0, version = UF.getVersion and UF.getVersion() or "?", maps = r.mapsSeen, data = r.data }
        db()[r.name] = saved
    end)
    N.running = nil
    if frame then frame:SetScript("OnUpdate", nil) end
    if not ok then UF.fail("NavScans.save", err); UF.say("The " .. r.name .. " scan could not be saved: " .. tostring(err)); return end
    UF.say(string.format("Scan %s done: %s on %d maps. Type /reload to write it to disk.", r.name, scan.summary(r.data), r.mapsSeen))
    for _, line in ipairs(scan.lines(r.data)) do UF.say("  " .. line) end
end

-- one frame of work; returns true while there is more
function N.step()
    local r = N.running
    if not r then return false end
    local scan = SCANS[r.name]
    local done = 0
    while r.nextMap <= N.maxMap and done < N.perFrame do
        local id = r.nextMap
        r.nextMap = id + 1
        done = done + 1
        local okI, info = pcall(C_Map.GetMapInfo, id)
        if okI and type(info) == "table" and info.name then
            r.mapsSeen = r.mapsSeen + 1
            local okM, err = pcall(scan.map, id, info, r.data)
            if not okM then UF.fail("NavScans." .. r.name, err) end
        end
    end
    if r.nextMap > N.maxMap then finish(r); return false end
    local pct = math.floor(r.nextMap * 100 / N.maxMap)
    if pct >= r.nextReport then
        r.nextReport = r.nextReport + 25
        UF.say("Scan " .. r.name .. ": " .. pct .. "%")
    end
    return true
end

function N.start(name)
    local scan = SCANS[name]
    if not scan then UF.say("No scan called " .. tostring(name) .. ". They are: " .. table.concat(N.names, ", ") .. "."); return false end
    if N.running then UF.say("The " .. N.running.name .. " scan is still running: one scan at a time. /ubf scans stop ends it."); return false end
    if not (C_Map and C_Map.GetMapInfo) then UF.say("This client has no map information to scan."); return false end
    local data = {}
    scan.begin(data)
    N.running = { name = name, nextMap = 1, mapsSeen = 0, data = data, nextReport = 25 }
    UF.say("Scan " .. name .. " (" .. scan.title .. ") started: a few maps a frame, a few seconds.")
    if not frame then frame = CreateFrame("Frame") end
    frame:SetScript("OnUpdate", function() UF.try("NavScans.step", N.step) end)
    return true
end

-- /ubf scans: what is saved; /ubf scans stop: end the running one
function N.status(stop)
    if stop then
        if N.running then
            UF.say("Scan " .. N.running.name .. " stopped; nothing was saved for it.")
            N.running = nil
            if frame then frame:SetScript("OnUpdate", nil) end
        else
            UF.say("No scan is running.")
        end
        return
    end
    if N.running then UF.say("Running: " .. N.running.name .. " (map " .. N.running.nextMap .. " of " .. N.maxMap .. ").") end
    local any = false
    for _, name in ipairs(N.names) do
        local s = db()[name]
        if s then
            any = true
            UF.say(string.format("%s: %s, %d maps, version %s", name, SCANS[name].summary(s.data), s.maps or 0, tostring(s.version)))
        else
            UF.say(name .. ": not scanned (/ubf " .. name .. ")")
        end
    end
    if not any then UF.say("Scans save to disk at /reload or logout.") end
end
