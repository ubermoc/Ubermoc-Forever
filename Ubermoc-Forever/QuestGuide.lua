-- QuestGuide.lua: where to go next for your quests, from the addon's own quest data (QuestData.lua, built from QuestieDB's Forever data).
--
-- What it answers (the arrow, QuestArrow.lua, points at the first stop):
--   * the quest you focused in the tracker: its nearest unfinished objective, or where it is turned in once it is complete
--   * nothing focused: the nearest unfinished objective or turn-in over every quest in your log
--   * an empty log (or nothing on this continent): the nearest quest you can pick up that suits your level
--   * the trail: the next few stops in closest-first order
--   * where to level: zones ranked by how many quests suit your level there
-- How "nearest" is measured: world yards on the same continent (C_Map.GetWorldPosFromMapPos), as Questie's DistanceUtils does with
-- HereBeDragons. Map positions in the data are percentages of a zone (AreaTable id), turned into a UiMapID by the data's zone table.

local _, UF = ...
local G = {}
UF.QuestGuide = G

G.TRAIL = 5              -- stops shown in the trail
G.ARRIVE = 15            -- yards: closer than this to a stop and the next one is taken
G.PICKUP_ABOVE = 3       -- a quest up to this many levels above you still counts as suitable

local function D() return UF.QuestData end

-- ---------------------------------------------------------------------------------------------- facts about the player
-- QuestieDB's race masks: the legacy bit (race id - 1) for the classic races, bits 32 and 33 for Alliance and Horde Skyborne (95, 96)
-- (QuestieDB docs/api.md, "Race mask encoding"). Masks can exceed 32 bits, so the test is arithmetic, not bit.band.
function G.raceBit(raceID)
    if raceID == 95 then return 32 elseif raceID == 96 then return 33 end
    if type(raceID) == "number" and raceID >= 1 then return raceID - 1 end
end
function G.hasBit(mask, bitIndex)
    if not mask or mask == 0 or not bitIndex then return true end    -- no restriction
    return math.floor(mask / 2 ^ bitIndex) % 2 == 1
end

local function player()
    -- each call stands alone: "UnitRace and UnitRace(...)" would keep only the first of its answers, and the race id is the third
    local level = UnitLevel and UnitLevel("player") or 1
    local raceID, classID, faction
    if UnitRace then raceID = select(3, UnitRace("player")) end
    if UnitClass then classID = select(3, UnitClass("player")) end
    if UnitFactionGroup then faction = UnitFactionGroup("player") end
    return { level = level, race = raceID, class = classID, faction = faction == "Horde" and "H" or "A" }
end
G.player = player

-- ---------------------------------------------------------------------------------------------- positions
local worldCache = {}
-- continent and world yards for a point on a UiMap (x and y as fractions 0-1)
function G.world(uiMap, x, y)
    if not (uiMap and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local key = uiMap * 1e8 + math.floor(x * 1e4) * 1e4 + math.floor(y * 1e4)
    local c = worldCache[key]
    if c == nil then
        local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(x, y))
        if ok and cont and pos then
            local wx, wy = pos.x, pos.y
            if pos.GetXY then wx, wy = pos:GetXY() end
            c = { cont, wx, wy }
        else
            c = false
        end
        worldCache[key] = c
    end
    if c then return c[1], c[2], c[3] end
end

function G.here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not (pos and pos.x and pos.y) then return nil end
    if issecretvalue and (issecretvalue(pos.x) or issecretvalue(pos.y)) then return nil end
    local cont, wx, wy = G.world(map, pos.x, pos.y)
    if not cont then return nil end
    return { map = map, x = pos.x, y = pos.y, cont = cont, wx = wx, wy = wy }
end

-- a data spawn (zone id, x %, y %) as a point the guide can measure; -1,-1 means inside an instance: its entrance stands in
function G.point(zone, x, y, label, quest, kind)
    local d = D()
    if x == -1 or y == -1 then
        local e = d.E and d.E[zone]
        if not e then return nil end
        zone, x, y = e[1], e[2], e[3]
    end
    local map = d.Z and d.Z[zone]
    if not map or map == 0 then return nil end
    return { map = map, x = x / 100, y = y / 100, label = label, quest = quest, kind = kind }
end

local function spawnsOf(entity, label, quest, kind, out)
    if not (entity and entity.s) then return end
    for zone, pts in pairs(entity.s) do
        for _, p in ipairs(pts) do
            local pt = G.point(zone, p[1], p[2], label, quest, kind)
            if pt then out[#out + 1] = pt end
        end
    end
end

-- ---------------------------------------------------------------------------------------------- what a quest needs from you
-- the game's objective types mapped to the data's lists: monster -> creatures (and kill credit), item -> who drops it, object -> objects,
-- event / log -> the place in the data's "go here" entry. A type whose objectives are all finished drops out.
local function unfinishedTypes(questID)
    local left = {}
    local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    if type(objs) ~= "table" or #objs == 0 then return nil end
    for _, o in ipairs(objs) do
        if not o.finished then left[o.type or "?"] = (left[o.type or "?"] or 0) + 1 end
    end
    return left
end

local function isComplete(questID)
    if C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) then return true end
    if C_QuestLog and C_QuestLog.IsComplete then return C_QuestLog.IsComplete(questID) and true or false end
    return false
end

-- every place that would move a quest in your log forward right now
function G.targetsFor(questID, complete, left, me)
    local d, out = D(), {}
    local q = d.Q[questID]
    if not q then return out end
    me = me or player()
    if complete then
        for _, id in ipairs(q.f[1] or {}) do
            local n = d.N[id]
            if n and (not n.fr or n.fr:find(me.faction, 1, true)) then spawnsOf(n, "Turn in: " .. q.n .. " (" .. n.n .. ")", questID, "turnin", out) end
        end
        for _, id in ipairs(q.f[2] or {}) do
            local o = d.O[id]
            if o then spawnsOf(o, "Turn in: " .. q.n .. " (" .. o.n .. ")", questID, "turnin", out) end
        end
        return out
    end
    local want = function(t) return (left == nil) or (left[t] or 0) > 0 end
    if want("monster") then
        for _, id in ipairs(q.c) do local n = d.N[id]; if n then spawnsOf(n, q.n .. ": " .. n.n, questID, "kill", out) end end
        for _, id in ipairs(q.k) do local n = d.N[id]; if n then spawnsOf(n, q.n .. ": " .. n.n, questID, "kill", out) end end
    end
    if want("item") then
        for _, id in ipairs(q.i) do
            local it = d.I[id]
            if it then
                for _, nid in ipairs(it.d or {}) do local n = d.N[nid]; if n then spawnsOf(n, q.n .. ": " .. (it.n or "item") .. " from " .. n.n, questID, "loot", out) end end
                for _, oid in ipairs(it.od or {}) do local o = d.O[oid]; if o then spawnsOf(o, q.n .. ": " .. (it.n or "item") .. " from " .. o.n, questID, "loot", out) end end
            end
        end
    end
    if want("object") then
        for _, id in ipairs(q.o) do local o = d.O[id]; if o then spawnsOf(o, q.n .. ": " .. o.n, questID, "use", out) end end
    end
    if (want("event") or want("log")) and q.t then
        for zone, pts in pairs(q.t[2]) do
            for _, p in ipairs(pts) do
                local pt = G.point(zone, p[1], p[2], q.n .. ": " .. tostring(q.t[1] or "go here"), questID, "go")
                if pt then out[#out + 1] = pt end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------- nearest
local function yardsFrom(here, pt)
    local cont, wx, wy = G.world(pt.map, pt.x, pt.y)
    if not cont or cont ~= here.cont then return nil end
    local dx, dy = wx - here.wx, wy - here.wy
    return math.sqrt(dx * dx + dy * dy), dx, dy
end

-- the nearest of `points` to `here` on the same continent: point, yards, bearing (counter-clockwise from north)
function G.nearest(here, points)
    local best, bestY, bdx, bdy
    for _, pt in ipairs(points) do
        local y, dx, dy = yardsFrom(here, pt)
        if y and (not bestY or y < bestY) then best, bestY, bdx, bdy = pt, y, dx, dy end
    end
    if not best then return nil end
    return best, bestY, G.bearing(bdx, bdy)
end

-- world x is north and y is west (HANDOFF: regression on the maps scan), so the bearing counter-clockwise from north is atan2(dy, dx)
function G.bearing(dx, dy)
    if not dx then return nil end
    local a = math.atan2(dy, dx)
    if a < 0 then a = a + 2 * math.pi end
    return a
end

-- ---------------------------------------------------------------------------------------------- your quest log
function G.logQuests()
    local out = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return out end
    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then out[#out + 1] = info.questID end
    end
    return out
end

local targetCache, cacheValid = {}, false
function G.invalidate() cacheValid = false end

local function questTargets()
    if cacheValid then return targetCache end
    targetCache = {}
    local me = player()
    for _, id in ipairs(G.logQuests()) do
        local complete = isComplete(id)
        targetCache[id] = G.targetsFor(id, complete, (not complete) and unfinishedTypes(id) or nil, me)
    end
    cacheValid = true
    return targetCache
end

function G.focused()
    if not (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) then return nil end
    local id = C_SuperTrack.GetSuperTrackedQuestID()
    if type(id) == "number" and id > 0 then return id end
end

-- ---------------------------------------------------------------------------------------------- quests you can pick up
local function done(id) return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) end

function G.trivialBelow(level)
    if UnitQuestTrivialLevelRange then
        local ok, r = pcall(UnitQuestTrivialLevelRange, "player")
        if ok and type(r) == "number" then return level - r end
    end
    return level - 5 - math.floor(level / 10)
end

-- true when a quest in the data could be picked up by you now and is worth your time at your level
function G.suits(q, id, me, isDone, isOn)
    if not q.s or not (q.s[1] or q.s[2]) then return false end           -- started by an item: nothing to walk to
    if (q.r or 1) > me.level then return false end
    if q.mx and q.mx > 0 and me.level > q.mx then return false end
    local lvl = q.l or q.r or 1
    if lvl > 0 and (lvl < G.trivialBelow(me.level) or lvl > me.level + G.PICKUP_ABOVE) then return false end
    if not G.hasBit(q.ra, G.raceBit(me.race)) then return false end
    if q.cl and q.cl > 0 and not G.hasBit(q.cl, (me.class or 1) - 1) then return false end
    if q.sf and q.sf % 2 == 1 then return false end                      -- repeatable
    if isDone(id) or isOn(id) then return false end
    for _, p in ipairs(q.pg or {}) do if not isDone(p) then return false end end
    if q.ps and #q.ps > 0 then
        local any = false
        for _, p in ipairs(q.ps) do if isDone(p) then any = true break end end
        if not any then return false end
    end
    for _, x in ipairs(q.ex or {}) do if isDone(x) or isOn(x) then return false end end
    return true
end

local availCache, availFor
function G.available(me)
    me = me or player()
    local key = me.level .. ":" .. tostring(me.race) .. ":" .. tostring(me.class)
    if availCache and availFor == key then return availCache end
    local out, d = {}, D()
    for id, q in pairs(d.Q) do
        if G.suits(q, id, me, done, onQuest) then out[#out + 1] = id end
    end
    availCache, availFor = out, key
    return out
end
function G.invalidateAvailable() availCache = nil end

function G.pickupPoints(ids, me)
    local d, out = D(), {}
    me = me or player()
    for _, id in ipairs(ids) do
        local q = d.Q[id]
        for _, nid in ipairs(q.s[1] or {}) do
            local n = d.N[nid]
            if n and (not n.fr or n.fr:find(me.faction, 1, true)) then spawnsOf(n, "Pick up: " .. q.n .. " (" .. n.n .. ", level " .. tostring(q.l) .. ")", id, "pickup", out) end
        end
        for _, oid in ipairs(q.s[2] or {}) do
            local o = d.O[oid]
            if o then spawnsOf(o, "Pick up: " .. q.n .. " (" .. o.n .. ", level " .. tostring(q.l) .. ")", id, "pickup", out) end
        end
    end
    return out
end

-- zones ranked by how many suitable quests start there: { {map, name, count, low, high}, ... }
function G.zones(me)
    local d = D()
    local per = {}
    for _, id in ipairs(G.available(me)) do
        local q = d.Q[id]
        local map = q.z and q.z > 0 and d.Z[q.z]
        if map and map > 0 then
            local z = per[map] or { map = map, count = 0, low = 999, high = 0 }
            z.count = z.count + 1
            local l = q.l or 0
            if l > 0 then z.low, z.high = math.min(z.low, l), math.max(z.high, l) end
            per[map] = z
        end
    end
    local list = {}
    for _, z in pairs(per) do
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(z.map)
        z.name = info and info.name or ("map " .. z.map)
        list[#list + 1] = z
    end
    table.sort(list, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.map < b.map end)
    return list
end

-- ---------------------------------------------------------------------------------------------- the answer
-- the trail: from where you stand, the nearest stop of any quest, then the nearest of the remaining quests from there, and so on
function G.trail(here, perQuest, limit)
    local stops, used, from = {}, {}, here
    for _ = 1, limit or G.TRAIL do
        local best, bestY, bestQ
        for qid, pts in pairs(perQuest) do
            if not used[qid] then
                local pt, y = G.nearest(from, pts)
                if pt and (not bestY or y < bestY) then best, bestY, bestQ = pt, y, qid end
            end
        end
        if not best then break end
        used[bestQ] = true
        best.yards = bestY
        stops[#stops + 1] = best
        local cont, wx, wy = G.world(best.map, best.x, best.y)
        from = { cont = cont, wx = wx, wy = wy }
    end
    return stops
end

-- what the arrow should point at now: { point, yards, bearing, why, trail, mode } or nil, reason.
-- The search over every spawn runs at most twice a second (G.RESEARCH); in between only the distance and bearing to the chosen stop are
-- measured again, so the arrow still turns smoothly every frame.
G.RESEARCH = 0.5
local lastAim, lastAt = nil, -1
function G.aim()
    local now = GetTime and GetTime() or 0
    if lastAim and cacheValid and now - lastAt < G.RESEARCH then
        local here = G.here()
        if not here then return nil, "the game does not give your position here" end
        local _, y, b = G.nearest(here, { lastAim.point })
        if y then lastAim.yards, lastAim.bearing = y, b; return lastAim end
    end
    local a, why = G.search()
    lastAim, lastAt = a, now
    return a, why
end

function G.search()
    local d = D()
    if not (d and d.Q) then return nil, "the quest data is not loaded" end
    local here = G.here()
    if not here then return nil, "the game does not give your position here" end
    local per = questTargets()
    local focus = G.focused()
    if focus and per[focus] and #per[focus] > 0 then
        local pt, y, b = G.nearest(here, per[focus])
        if pt then
            return { point = pt, yards = y, bearing = b, mode = "focused", trail = G.trail(here, per) }
        end
    end
    local trail = G.trail(here, per)
    if trail[1] then
        local pt = trail[1]
        local _, y, b = G.nearest(here, { pt })
        return { point = pt, yards = y, bearing = b, mode = "nearest", trail = trail }
    end
    local me = player()
    local pts = G.pickupPoints(G.available(me), me)
    local pt, y, b = G.nearest(here, pts)
    if pt then return { point = pt, yards = y, bearing = b, mode = "pickup", trail = { pt } } end
    return nil, "nothing to do on this continent: no quest in your log has a place here and no suitable quest starts here"
end

-- /ubf guide: the trail and where to level
function G.report()
    local a, why = G.aim()
    if not a then UF.say("Quest guide: " .. tostring(why)) else
        UF.say(string.format("Quest guide (%s): %s, %.0f yd", a.mode, a.point.label or "?", a.yards or 0))
        for i, s in ipairs(a.trail or {}) do
            if i > 1 then UF.say(string.format("  then %s, %.0f yd from the stop before", s.label or "?", s.yards or 0)) end
        end
    end
    local me = player()
    local z = G.zones(me)
    if #z == 0 then UF.say("No quest in the data suits level " .. me.level .. " for you."); return end
    UF.say("Where to level at " .. me.level .. " (quests that suit you):")
    for i = 1, math.min(4, #z) do
        UF.say(string.format("  %s: %d quests, levels %d-%d", z[i].name, z[i].count, z[i].low, z[i].high))
    end
end

-- the quest log and levels change: the cached targets are read again
local ev = CreateFrame and CreateFrame("Frame")
if ev then
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED", "SUPER_TRACKING_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
        UF.try("QuestGuide registers " .. e, ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, e)
        G.invalidate()
        if e ~= "QUEST_LOG_UPDATE" and e ~= "UNIT_QUEST_LOG_CHANGED" and e ~= "SUPER_TRACKING_CHANGED" then G.invalidateAvailable() end
    end)
end
