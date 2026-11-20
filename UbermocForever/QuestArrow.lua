----------------------------------------------------------------------
-- Ubermoc Forever: quest direction arrow.
-- Blizzard's own quest arrow art (claim C10), drawn at the size the game gives that atlas (claims C39,
-- C42) and turned the way the game turns it: SetRotation of the negative angle between your facing and
-- the bearing to the point (claims C7, C8, C9). The place is dragged with the mouse and saved for this
-- character, and the size is a setting. An addon frame cannot join Move bars in Forever, so this frame
-- takes its own left-button drags (claim C22) with the games handler names (claim C37) and follows the
-- cursor with the games own conversion (claims C31, C32, C33, C34, C35, C36, C43).
-- Three routing modes (claim R12): direct is the straight bearing, route is the games own route data,
-- obstacle walks the game map areas, which is an approximation because the client gives no walkability
-- data (evidence E50). The target is the quest the game has focused on (claim C20), and it can be on
-- another map: the game answers which map its route is on (claim C23). It shows only while there is
-- something to point at, and writes the distance under it as the game does (claims C39, C40, C41).
-- Display only: nothing here clicks, uses or targets, so nothing can taint.
----------------------------------------------------------------------
local ADDON, UF = ...
local Q = {}
UF.QuestArrow = Q

-- math.atan takes (y, x) in the games Lua and in the offline test, so this is atan2.
local function atan2(y, x) return math.atan(y, x) end

-- the three modes, in the order the options row steps through them (claim R12)
Q.MODES = { "direct", "route", "obstacle" }
Q.MODENAME = { direct = "Direct", route = "Route", obstacle = "Around areas" }
Q.MODENOTE = {
    direct = "the straight line from you to the objective",
    route = "the games own route data, read again as you move",
    obstacle = "the game map areas: the closest the client allows, since it gives no walkability data",
}

-- the sizes the picture is drawn at, as a share of the size the game gives its own arrow (claims C39, C42)
Q.SIZES = { { name = "Small", times = 0.75 }, { name = "Medium", times = 1 }, { name = "Large", times = 1.35 } }
Q.FALLBACKPX = 34                          -- when the game gives no size for the atlas (claim C42)
Q.DEFAULTPLACE = { fx = 0.88, fy = 0.90 }  -- near the top right, where the game draws nothing

local function cfg()
    local d = UF.DB()
    d.qarrow = d.qarrow or {}
    local a = d.qarrow
    if a.on == nil then a.on = true end
    if not a.mode then a.mode = 1 end
    if not a.size then a.size = 2 end
    if not a.place then a.place = {} end
    return a
end
Q.cfg = cfg

function Q.modeName() return Q.MODENAME[Q.MODES[cfg().mode]] end
function Q.modeNote() return Q.MODENOTE[Q.MODES[cfg().mode]] end
function Q.nextMode(dir)
    local a = cfg()
    a.mode = UF.stepIndex(a.mode, #Q.MODES, dir)
    return a.mode
end

function Q.sizeName() return Q.SIZES[cfg().size].name end
function Q.nextSize(dir)
    local a = cfg()
    a.size = UF.stepIndex(a.size, #Q.SIZES, dir)
    return a.size
end

function Q.sizePx()
    local px = Q.FALLBACKPX
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, "Navigation-Tracked-Arrow")  -- claim C42
        if ok and info and info.width and info.width > 0 then px = info.width end
    end
    return math.floor(px * Q.SIZES[cfg().size].times + 0.5)
end

-- the place, as a fraction of the screen from its centre, kept for this character
function Q.place()
    local a = cfg()
    local g = UF.guid()
    if not g then return Q.DEFAULTPLACE end
    local p = a.place[g]
    if not p then
        p = { fx = Q.DEFAULTPLACE.fx, fy = Q.DEFAULTPLACE.fy }
        a.place[g] = p
    end
    return p
end

function Q.setPlace(fx, fy)
    if not fx or not fy then return nil end
    local a = cfg()
    local g = UF.guid()
    if not g then return nil end
    local p = a.place[g] or {}
    p.fx, p.fy = fx, fy
    a.place[g] = p
    return p
end

-- the same fractions as offsets from the centre of the screen (claims C33, C35)
function Q.pointFor(fx, fy)
    if not fx or not fy then return nil end
    local left, bottom, width, height = UIParent:GetRect()  -- claim C33
    if not left or not width or not height or width == 0 or height == 0 then return nil end
    return (fx - 0.5) * width, (fy - 0.5) * height
end

-- where the cursor is, as the same fractions: the cursor numbers are screen pixels, so divide by the
-- scale and put them in the rect (claims C31, C32, C33)
function Q.moveFromCursor()
    local left, bottom, width, height = UIParent:GetRect()
    if not left or not width or not height or width == 0 or height == 0 then return nil end
    if not GetCursorPosition then return nil end
    local ok, x, y = pcall(GetCursorPosition)
    if not ok or not x or not y then return nil end
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    x, y = x / scale, y / scale
    return ((x - left) / width) - 0.5, ((y - bottom) / height) - 0.5
end

-- the yards and the angle (counter-clockwise from north, 0 to 2 pi) from one point to another on a map
-- of the given size in yards (claim C7)
function Q.bearing(width, height, fromX, fromY, toX, toY)
    if not width or not height or width == 0 or height == 0 then return nil end
    if not (fromX and fromY and toX and toY) then return nil end
    local east = (toX - fromX) * width
    local south = (toY - fromY) * height
    return math.sqrt(east * east + south * south), atan2(-east, -south) % (2 * math.pi)
end

-- an arrow that points up by default turns by angle - facing, and the game's SetRotation takes the
-- negative (claims C7 and C9)
function Q.rotation(angle, facing) return -(angle - facing) end

function Q.facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    return (ok and f) or nil
end

-- the quest the game has focused on, if it has one (claim C20)
function Q.tracking()
    if not (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) then return nil end
    local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end

-- the map and the point to aim at for a quest: the game answers which map its route is on (claim C23),
-- otherwise the row for the map we are on (claims C11 and C12)
function Q.targetFor(questID, hereMap, answer, row)
    if answer and answer.mapID and answer.x and answer.y then return answer.mapID, answer.x, answer.y end
    if row and row.mapID and row.x and row.y then return row.mapID, row.x, row.y end
    return nil
end

-- the first quest in progress on the map we are on, as the game reports it (claims C11 and C12)
function Q.picking()
    if not (C_Map and C_QuestLog and C_Map.GetBestMapForUnit and C_QuestLog.GetQuestsOnMap) then return nil end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not mapID then return nil end
    local ok2, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
    if not ok2 or not quests then return nil end
    for _, q in ipairs(quests) do
        if q.inProgress and q.mapID == mapID then return mapID, q end
    end
    return nil
end

-- the maps from an area up to the top, as the game links them (claim C25)
function Q.ancestors(mapID, parentOf)
    local chain, seen = {}, {}
    local m = mapID
    while m and m > 0 and not seen[m] do
        seen[m] = true
        chain[#chain + 1] = m
        m = parentOf(m)
    end
    return chain
end

-- the areas walked from here to the target, and the map the two chains share (claims C24 and C25)
function Q.path(fromMap, toMap, parentOf)
    local up, down = Q.ancestors(fromMap, parentOf), Q.ancestors(toMap, parentOf)
    local share = {}
    for _, m in ipairs(down) do share[m] = true end
    local lca
    for _, m in ipairs(up) do
        if share[m] then lca = m; break end
    end
    if not lca then return nil, nil end
    local route = {}
    for _, m in ipairs(up) do
        route[#route + 1] = m
        if m == lca then break end
    end
    for i = #down, 1, -1 do
        if down[i] ~= lca then route[#route + 1] = down[i] end
    end
    return route, lca
end

-- which area listed on a map holds the target area (claim C24), from the rows the game gives
function Q.holding(lcaMap, targetMap, rows, parentOf)
    for _, r in ipairs(rows or {}) do
        if r.parentMapID == lcaMap then
            local m = targetMap
            while m and m > 0 do
                if m == r.mapID then return m end
                m = parentOf(m)
            end
        end
    end
    return nil
end

-- where a point on an area lands on the map above it (claims C26 and C28)
function Q.onParent(fx, fy, minX, maxX, minY, maxY)
    if not (minX and maxX and minY and maxY) then return nil end
    return minX + fx * (maxX - minX), minY + fy * (maxY - minY)
end

-- the nearest point inside an area rectangle on the map above (claims C26 and C28): the border you cross
function Q.crossPoint(px, py, minX, maxX, minY, maxY)
    if not (minX and maxX and minY and maxY) then return nil end
    local x, y = px, py
    if x < minX then x = minX elseif x > maxX then x = maxX end
    if y < minY then y = minY elseif y > maxY then y = maxY end
    return x, y
end

-- the point the arrow aims at, the map it is on, how it was found, and the point the bearing is taken
-- from on that map (claims C5, C23, C24, C26, C28, C29). mode is one of Q.MODES.
function Q.aimFor(mode, hereMap, pos, targetMap, tx, ty, waypoint, parentOf, rowsOf, rectOf)
    if not (mode and hereMap and pos and targetMap) then return nil end

    -- route: the game answer for the map we are standing on (claims C5 and C29)
    if mode == "route" and waypoint and waypoint.x and waypoint.y then
        return hereMap, waypoint.x, waypoint.y, "route", pos.x, pos.y
    end

    -- inside one area there is nothing to route around, so this is the straight line
    if hereMap == targetMap then
        return hereMap, tx, ty, (mode == "obstacle") and "same area" or "direct", pos.x, pos.y
    end

    -- another map: the bearing is taken on the map that holds both areas (claims C24 and C25)
    local route, lca = Q.path(hereMap, targetMap, parentOf)
    if not lca then return nil end
    local pr = rectOf(hereMap, lca)
    if not pr then return nil end
    local px, py = Q.onParent(pos.x, pos.y, pr.minX, pr.maxX, pr.minY, pr.maxY)
    if not px then return nil end

    -- obstacle: the area we walk into next, and the border of it nearest to us
    if mode == "obstacle" then
        local step = Q.holding(lca, targetMap, rowsOf(lca), parentOf) or route[2]
        if step ~= lca then
            local r = rectOf(step, lca)
            if r then
                local cx, cy = Q.crossPoint(px, py, r.minX, r.maxX, r.minY, r.maxY)
                if cx then return lca, cx, cy, "areas", px, py end
            end
        end
    end

    -- direct, or route with nothing to go on: the target area on the map that holds both
    local tr = rectOf(targetMap, lca)
    if not tr then return nil end
    return lca, tr.minX + tx * (tr.maxX - tr.minX), tr.minY + ty * (tr.maxY - tr.minY), "shared map", px, py
end

local arrow

local function build()
    if arrow then return arrow end
    arrow = CreateFrame("Frame", "UbermocForeverQuestArrow", UIParent)
    arrow:SetFrameStrata("MEDIUM")
    arrow:EnableMouse(true)              -- claim C34: a frame only hears the mouse once it is enabled
    arrow:RegisterForDrag("LeftButton")  -- claim C22
    arrow:SetClampedToScreen(true)       -- claim C38
    arrow.art = arrow:CreateTexture(nil, "OVERLAY")
    -- the games own quest navigation art (claim C10); if the atlas cannot be used the arrow never shows
    local ok, used = pcall(arrow.art.SetAtlas, arrow.art, "Navigation-Tracked-Arrow")
    if not ok or not used then arrow.art = nil end
    -- the games own distance font (claim C39)
    arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- the games handler names for a frame that registers for drags (claim C37): start keeps it moving,
    -- stop leaves the place saved for this character
    arrow:SetScript("OnDragStart", function(self)
        self.moving = true
    end)
    arrow:SetScript("OnDragStop", function(self)
        self.moving = nil
        local fx, fy = Q.moveFromCursor()
        if fx then Q.setPlace(fx, fy) end
    end)
    arrow:Hide()
    return arrow
end

function Q.frame() return build() end

local function hide()
    if arrow and arrow:IsShown() then arrow:Hide() end
end

-- the game calls for the map above an area (claim C25), the areas it lists on a map (claim C24) and the
-- rectangle of an area on the map above it (claims C26 and C28)
local function parentOf(m)
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, m)
    if not ok or not info then return nil end
    return info.parentMapID
end

local function rowsOf(lcaMap)
    if not (C_Map and C_Map.GetMapChildrenInfo) then return {} end
    local ok, rows = pcall(C_Map.GetMapChildrenInfo, lcaMap, nil, true)
    return (ok and rows) or {}
end

local function rectOf(m, topMap)
    if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
    local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, m, topMap)
    if not ok or not (minX and maxX and minY and maxY) then return nil end
    return { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
end

-- the route answer for the map we are on: claim C5 first, then the games own live route (claim C29).
-- The content tracking route (claim C18) is not used: it has no quest type (claim C30).
local function waypointFor(questID, hereMap)
    if questID and C_QuestLog and C_QuestLog.GetNextWaypointForMap then
        local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, questID, hereMap)
        if ok and x and y then return { x = x, y = y } end
    end
    if C_Navigation and C_Navigation.GetNextWaypointForMap then
        local ok, x, y = pcall(C_Navigation.GetNextWaypointForMap, hereMap)
        if ok and x and y then return { x = x, y = y } end
    end
    return nil
end

-- which map the game says the quest route is on (claim C23)
local function answerFor(questID)
    if not (C_QuestLog and C_QuestLog.GetNextWaypoint) then return nil end
    local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, questID)
    if not ok or not (mapID and x and y) then return nil end
    return { mapID = mapID, x = x, y = y }
end

-- the row for a quest on the map we are on (claims C11 and C12)
local function rowFor(questID, hereMap)
    if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return nil end
    local ok, rows = pcall(C_QuestLog.GetQuestsOnMap, hereMap)
    if not ok or not rows then return nil end
    for _, r in ipairs(rows) do
        if r.questID == questID then return r end
    end
    return nil
end

-- the distance line, as the game writes it (claims C39, C40, C41); cross-map yards are approximate
function Q.showDistance(f, yards, approximate)
    if not f.text then return end
    if not yards then
        f.text:SetText("")
        return
    end
    f.text:SetText((approximate and "~" or "") .. tostring(math.floor(yards + 0.5)) .. " yd")
end

local acc = 0
local drv = CreateFrame("Frame")

local function update()
    local a = cfg()
    if not a.on then hide(); return end
    local f = build()
    if not f.art then hide(); return end

    -- follow the cursor while the drag is held, then the place is kept (claims C33, C35, C43)
    if f.moving then
        local fx, fy = Q.moveFromCursor()
        if fx then Q.setPlace(fx, fy) end
    end
    local p = Q.place()
    local ox, oy = Q.pointFor(p.fx, p.fy)
    if not ox then hide(); return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
    local px = Q.sizePx()
    f:SetSize(px, px)
    f.art:SetSize(px, px)

    local here
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")  -- claim C13
        if ok then here = m end
    end
    if not here then hide(); return end

    local pos
    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, v = pcall(C_Map.GetPlayerMapPosition, here, "player")  -- claim C14
        if ok then pos = v end
    end
    if not pos or not pos.x or not pos.y then hide(); return end

    local quest = Q.tracking()
    local tmap, tx, ty
    if quest then
        tmap, tx, ty = Q.targetFor(quest, here, answerFor(quest), rowFor(quest, here))
    else
        local m, row = Q.picking()
        if m and row then tmap, tx, ty = m, row.x, row.y end
    end
    if not tmap then hide(); return end

    local aimMap, ax, ay, source, fromX, fromY = Q.aimFor(a.mode, here, pos, tmap, tx, ty,
        waypointFor(quest, here), parentOf, rowsOf, rectOf)
    if not aimMap then hide(); return end
    f.source = source

    local w, h
    if C_Map and C_Map.GetMapWorldSize then
        local ok, ww, hh = pcall(C_Map.GetMapWorldSize, aimMap)  -- claim C15
        if ok then w, h = ww, hh end
    end
    local yards, angle = Q.bearing(w, h, fromX, fromY, ax, ay)  -- claim C7
    if not yards then hide(); return end
    local face = Q.facing()  -- claim C6
    if not face then hide(); return end

    f.art:SetRotation(Q.rotation(angle, face))  -- claims C8 and C9
    Q.showDistance(f, yards, aimMap ~= here)
    if not f:IsShown() then f:Show() end
end

drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    acc = 0
    update()
end)

-- Settings buttons (the options window calls these).
function Q.toggle() local a = cfg(); a.on = not a.on end
function Q.name() return cfg().on and "On" or "Off" end
