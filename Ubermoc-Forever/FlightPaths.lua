----------------------------------------------------------------------
-- Ubermoc Forever: flight paths you have not found yet. The positions of every flight master come from the game itself
-- (C_TaxiMap.GetTaxiNodesForMap, on the two continent maps), and which of them you already know is learned from what the game says:
--   * the flight map: every flight point it lists is one you have discovered (ThePath's finding for Forever, kept as a rule here), so opening
--     the flight map at any master marks them all, and the master you are talking to
--   * the world map's own flag (isUndiscovered), used only when the game really says: a list with at least one `true` in it. A flag that is
--     always false or missing says nothing (the scan of 1.3.171 could not tell: it turned "missing" into false), so it is then ignored
--   * the moment of discovery: TAXI_NODE_STATUS_CHANGED while you stand at a flight master marks the nearest one
-- What is known is kept in DB.learned.taxi and only grows. The world map then shows the flight masters of your faction that you have not found
-- as pins (the layer at the end of this file, drawn the way ForeverPlusPlus draws its own, which is MIT-licensed like this addon: our frames
-- on the map canvas through a map data provider). A pin goes away when you find the flight path. You can always remove them: the button turns
-- all of them off, a right click hides one pin, `/ubf flightpaths show` brings the hidden ones back. A left click puts the game's own map
-- waypoint on the pin if you want to go there, and the quest arrow follows that waypoint when no quest is selected.
-- `/ubf flightpaths` says what the game reports.
----------------------------------------------------------------------
local _, UF = ...

local FP = { MAPS = { 1414, 1415 }, NEAR = 60 }
UF.FlightPaths = FP

local FACTION = { Horde = 1, Alliance = 2 }

local function plain(v)
    if type(v) ~= "number" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function known()
    local d = UF.DB()
    d.learned = d.learned or {}
    d.learned.taxi = d.learned.taxi or {}
    return d.learned.taxi
end
FP.known = known

-- every flight master the game puts on the continent maps: { id, name, map, x, y, faction, flag }, flag being the game's isUndiscovered as it
-- is: true, false or nil
function FP.nodes()
    local list, seen = {}, {}
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return list end
    for _, map in ipairs(FP.MAPS) do
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, map)
        if ok and type(nodes) == "table" then
            for _, n in ipairs(nodes) do
                if type(n) == "table" then
                    local id = plain(n.nodeID)
                    local pos = n.position
                    local x, y = type(pos) == "table" and plain(pos.x), type(pos) == "table" and plain(pos.y)
                    local name = type(n.name) == "string" and n.name or nil
                    if id and x and y and name and not seen[id] and not name:find("^zz") then
                        seen[id] = true
                        list[#list + 1] = { id = id, name = name, map = map, x = x, y = y, faction = plain(n.faction) or 0, flag = n.isUndiscovered,
                                        atlas = type(n.atlasName) == "string" and n.atlasName or nil }
                    end
                end
            end
        end
    end
    return list
end

-- the world position of a node (continent, x, y), as the game converts it
local function world(n)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, n.map, { x = n.x, y = n.y })
    if ok and type(wp) == "table" and plain(wp.x) and plain(wp.y) then return cont, wp.x, wp.y end
end

-- the flag of the world map counts only when the game really says (some `true` among them)
function FP.flagsTrusted(list)
    for _, n in ipairs(list) do if n.flag == true then return true end end
    return false
end

-- mark nodes as known from the world map's flags, when they can be trusted
function FP.learnFromWorldMap(list)
    if not FP.flagsTrusted(list) then return 0 end
    local k, added = known(), 0
    for _, n in ipairs(list) do
        if n.flag == false and not k[n.id] then k[n.id] = true; added = added + 1 end
    end
    return added
end

-- the flight map is open: every node it lists is discovered (the ones listed by GetAllTaxiNodes, whatever their state)
function FP.learnFromFlightMap(nodes)
    local k, added = known(), 0
    if type(nodes) ~= "table" then return 0 end
    for _, n in ipairs(nodes) do
        local id = type(n) == "table" and plain(n.nodeID)
        if id and not k[id] then k[id] = true; added = added + 1 end
    end
    return added
end

-- the node nearest to a world position within `radius` yards, among a node list
function FP.nearestTo(list, cont, wx, wy, radius)
    local best, bd = nil, radius or FP.NEAR
    for _, n in ipairs(list) do
        local c, x, y = world(n)
        if c == cont then
            local d = math.sqrt((x - wx) ^ 2 + (y - wy) ^ 2)
            if d <= bd then best, bd = n, d end
        end
    end
    return best, best and bd
end

-- the nodes of the player's faction (or neutral) that are not known yet
function FP.undiscovered(list, playerFaction)
    local mine = FACTION[playerFaction]
    local k, out = known(), {}
    for _, n in ipairs(list) do
        if (n.faction == 0 or n.faction == mine) and not k[n.id] then out[#out + 1] = n end
    end
    return out
end

-- the nearest one to a world position on the same continent: node, yards
function FP.nearestUndiscovered(list, playerFaction, cont, wx, wy)
    local best, bd
    for _, n in ipairs(FP.undiscovered(list, playerFaction)) do
        local c, x, y = world(n)
        if c == cont then
            local d = math.sqrt((x - wx) ^ 2 + (y - wy) ^ 2)
            if not bd or d < bd then best, bd = n, d end
        end
    end
    return best, bd
end

-- the discovery moment, and the flight map
function FP.onStatusChanged()
    local T = UF.Trail
    local p = T and T.read and T.read()
    if not p then return end
    local n = FP.nearestTo(FP.nodes(), p.cont, p.wx, p.wy, FP.NEAR)
    if n and not known()[n.id] then
        known()[n.id] = true
        UF.say("Flight path found: " .. n.name)
        FP.refreshPins()
    end
end

-- 1.5.4: opening a flight map no longer marks its masters as found. GetAllTaxiNodes lists masters you have not found too
-- (the 1.5.3 report counted 37 as known), so a master counts as found only when the game reports it or you talk to it.
function FP.onFlightMap()
    FP.onStatusChanged()
    FP.refreshPins()      -- the master you are standing at is one you know now
end

function FP.report()
    local list = FP.nodes()
    local f = (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
    local t, fa, nl = 0, 0, 0
    for _, n in ipairs(list) do
        if n.flag == true then t = t + 1 elseif n.flag == false then fa = fa + 1 else nl = nl + 1 end
    end
    local k = known()
    local nk = 0
    for _ in pairs(k) do nk = nk + 1 end
    local un = FP.undiscovered(list, f)
    UF.say(string.format("Flight masters the game lists: %d. The world map's flag: %d true, %d false, %d missing (%s).", #list, t, fa, nl,
        FP.flagsTrusted(list) and "used" or "not used: it never says undiscovered"))
    UF.say(string.format("You know %d (learned from the flight map and from finding them). Not found yet for the %s: %d.", nk, f, #un))
    local T = UF.Trail
    local p = T and T.read and T.read()
    if p then
        local rows = {}
        for _, n in ipairs(un) do
            local c, x, y = world(n)
            if c == p.cont then rows[#rows + 1] = { n = n, d = math.sqrt((x - p.wx) ^ 2 + (y - p.wy) ^ 2) } end
        end
        table.sort(rows, function(a, b) return a.d < b.d end)
        for i = 1, math.min(5, #rows) do UF.say(string.format("  %s: %d yd", rows[i].n.name, math.floor(rows[i].d))) end
    end
end


----------------------------------------------------------------------
-- The pins on the world map
----------------------------------------------------------------------
local function cfg()
    local d = UF.DB()
    d.flightPins = d.flightPins or { on = true, hidden = {} }
    d.flightPins.hidden = d.flightPins.hidden or {}
    if d.flightPins.on == nil then d.flightPins.on = true end
    return d.flightPins
end
function FP.pinsName() return cfg().on and "On" or "Off" end
function FP.togglePins() local c = cfg(); c.on = not c.on; FP.refreshPins(); return c.on end
function FP.hide(id) cfg().hidden[id] = true; FP.refreshPins() end
function FP.unhideAll() cfg().hidden = {}; FP.refreshPins() end

-- where a node is on a map being shown (x, y from 0 to 1), or nil when it is not on that map: the continent map itself, a zone inside the
-- continent (the zone's rectangle on the continent), or a map above the continent (the continent's rectangle on it)
function FP.placeOn(mapID, n)
    if mapID == n.map then return n.x, n.y end
    if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
    local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, mapID, n.map)
    if ok and plain(l) and plain(r) and plain(t) and plain(b) and r > l and b > t then
        local x, y = (n.x - l) / (r - l), (n.y - t) / (b - t)
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
        return nil
    end
    local ok2, l2, r2, t2, b2 = pcall(C_Map.GetMapRectOnMap, n.map, mapID)
    if ok2 and plain(l2) and plain(r2) and plain(t2) and plain(b2) and r2 > l2 and b2 > t2 then
        return l2 + n.x * (r2 - l2), t2 + n.y * (b2 - t2)
    end
    return nil
end

-- the nodes to draw for a map: the faction's, not found, not hidden, and on that map: { node, x, y }
function FP.pinsFor(mapID, playerFaction)
    local out, c = {}, cfg()
    if not c.on then return out end
    local list = FP.nodes()
    FP.learnFromWorldMap(list)
    for _, n in ipairs(FP.undiscovered(list, playerFaction)) do
        if not c.hidden[n.id] then
            local x, y = FP.placeOn(mapID, n)
            if x then out[#out + 1] = { node = n, x = x, y = y } end
        end
    end
    return out
end

-- the map waypoint on a pin: the game's own, so its marker shows and the quest arrow can follow it
function FP.goTo(n, mapID, x, y)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
    if C_Map.CanSetUserWaypointOnMap and mapID and not C_Map.CanSetUserWaypointOnMap(mapID) then mapID = nil end
    if not mapID then mapID, x, y = n.map, n.x, n.y end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    UF.say("Waypoint set on " .. n.name .. ".")
    return true
end

local pins, count, provider = {}, 0, nil
local PIN_SIZE = 22
local FALLBACK = "Interface\\Minimap\\Tracking\\FlightMaster"

local function release()
    for i = 1, count do
        local pin = pins[i]
        if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
        pin:Hide()
        pin.node = nil
    end
    count = 0
end

local function onEnter(pin)
    local n = pin.node
    if not (n and GameTooltip) then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(n.name)
    GameTooltip:AddLine("Flight path not found yet", 1, 0.82, 0)
    GameTooltip:AddLine("Click: put your map waypoint here", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: hide this pin", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function onMouseUp(pin, button)
    local n = pin.node
    if not n then return end
    if button == "RightButton" then FP.hide(n.id)
    elseif button == "LeftButton" then UF.try("FlightPaths.goTo", FP.goTo, n, pin.mapID, pin.x, pin.y) end
end

local function newPin(canvas)
    local pin = CreateFrame("Frame", nil, canvas)
    pin.tex = pin:CreateTexture(nil, "ARTWORK")
    pin.tex:SetAllPoints()
    pin:EnableMouse(true)
    pin:SetScript("OnEnter", onEnter)
    pin:SetScript("OnLeave", function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    pin:SetScript("OnMouseUp", onMouseUp)
    return pin
end

local function place(pin, map)
    local canvas = map:GetCanvas()
    local scale = map.GetCanvasScale and map:GetCanvasScale() or 1
    local size = PIN_SIZE / (scale > 0 and scale or 1)      -- the same size on screen at every zoom
    pin:SetSize(size, size)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * pin.x, -canvas:GetHeight() * pin.y)
end

local function draw()
    release()
    if not provider then return end
    local map = provider:GetMap()
    local mapID = map and map:GetMapID()
    if not mapID then return end
    local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
    for _, p in ipairs(FP.pinsFor(mapID, faction)) do
        count = count + 1
        local pin = pins[count]
        if not pin then pin = newPin(map:GetCanvas()); pins[count] = pin end
        pin.node, pin.x, pin.y, pin.mapID = p.node, p.x, p.y, mapID
        local art = p.node.atlas
        local okS = art and pcall(pin.tex.SetAtlas, pin.tex, art)
        local okG, got = pcall(pin.tex.GetAtlas, pin.tex)
        if not (okS and okG and got == art) then pin.tex:SetTexture(FALLBACK) end
        local manager = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
        if manager and manager.GetValidFrameLevel then
            local okL, level = pcall(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
            if okL and level then pin:SetFrameLevel(level) end
        end
        place(pin, map)
        pin:Show()
    end
end

local function replace()
    if not provider then return end
    local map = provider:GetMap()
    if not map then return end
    for i = 1, count do place(pins[i], map) end
end

function FP.refreshPins()
    local map = _G.WorldMapFrame
    if map and map.IsShown and map:IsShown() and map.RefreshAllDataProviders then map:RefreshAllDataProviders() end
end

-- attach to the world map once it exists (it is a load-on-demand Blizzard addon: also on its ADDON_LOADED)
function FP.attach()
    local map = _G.WorldMapFrame
    if provider or not (map and map.AddDataProvider and _G.CreateFromMixins and _G.MapCanvasDataProviderMixin) then return end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.RemoveAllData = function() release() end
    provider.RefreshAllData = function() UF.try("FlightPaths.draw", draw) end
    provider.OnCanvasScaleChanged = function() UF.try("FlightPaths.place", replace) end
    provider.OnCanvasSizeChanged = function() UF.try("FlightPaths.place", replace) end
    map:AddDataProvider(provider)
    if map:IsShown() then UF.try("FlightPaths.draw", draw) end
end

local started = false
function FP.start()
    if started then return end
    started = true
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("TAXIMAP_OPENED")
    ev:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(_, event, name)
        if event == "TAXIMAP_OPENED" then UF.try("FlightPaths.map", FP.onFlightMap)
        elseif event == "ADDON_LOADED" then if name == "Blizzard_WorldMap" then UF.try("FlightPaths.attach", FP.attach) end
        else UF.try("FlightPaths.status", FP.onStatusChanged) end
    end)
    UF.try("FlightPaths.attach", FP.attach)
end
-- 1.5.4: the list built by 1.5.0-1.5.3 counted masters found when they were not; cleared once so they come back as pins
local function resetWrongLearned()
    local d = UF.DB()
    if d.flightLearnFix ~= true then
        d.learned = d.learned or {}
        d.learned.taxi = {}
        d.flightLearnFix = true
    end
end

if UF.OnLogin then UF.OnLogin(function() resetWrongLearned(); FP.start() end) end
