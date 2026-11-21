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

-- The game runs Lua 5.1, where math.atan takes ONE number (a second one is ignored: atan(-east, -south) came out as atan(-east), a bearing of
-- 89 degrees for an objective at 167) and the two-argument arc tangent is math.atan2. The offline test runs Lua 5.5, which has no
-- math.atan2 and a two-argument math.atan; the test stub now behaves like the game, and tools/check_lua.py refuses a two-argument math.atan.
local rawAtan = math.atan
local atan2 = math.atan2 or function(y, x) return rawAtan(y, x) end   -- the second form only where there is no math.atan2 (the offline test)

-- the three modes, in the order the options row steps through them (claim R12)
Q.MODES = { "direct", "route", "obstacle" }
Q.MODENAME = { direct = "Direct", route = "Route", obstacle = "Around obstacles" }
Q.MODENOTE = {
    direct = "the straight line from you to the objective",
    route = "the games own route data, read again as you move",
    obstacle = "straight at the objective, bending along the games route only where that route shows something in the way (the game gives no terrain data, so this is read from its route)",
}

-- the sizes the picture is drawn at, as a share of the size the game gives its own arrow (claims C39, C42)
Q.SIZESTEPS = { 16, 20, 24, 28, 32, 36, 40, 44, 48, 56, 64, 72, 80, 96, 112, 128 }   -- the arrow's size in pixels, one step per press
Q.DEFAULTPX = 40
Q.DEFAULTPLACE = { fx = 0.88, fy = 0.90 }  -- near the top right, where the game draws nothing

local function cfg()
    local d = UF.DB()
    d.qarrow = d.qarrow or {}
    local a = d.qarrow
    if a.on == nil then a.on = true end
    if not a.mode then a.mode = 1 end
    if not a.px then a.px = Q.DEFAULTPX end
    if not a.opacity then a.opacity = 100 end
    if not a.turn or a.turn > #Q.TURNS then a.turn = 3 end   -- With you until the user picks another
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

-- places a button press can choose (centre-based fractions of the screen as Q.place keeps them); a dragged place is "Custom"
Q.POSITIONS = {
    { name = "Top right", fx = 0.88, fy = 0.90 }, { name = "Top centre", fx = 0.50, fy = 0.90 }, { name = "Top left", fx = 0.12, fy = 0.90 },
    { name = "Middle left", fx = 0.12, fy = 0.55 }, { name = "Middle right", fx = 0.88, fy = 0.55 }, { name = "Above the action bars", fx = 0.50, fy = 0.28 },
}
function Q.positionName()
    local p = Q.place()
    for _, c in ipairs(Q.POSITIONS) do
        if math.abs(c.fx - p.fx) < 0.005 and math.abs(c.fy - p.fy) < 0.005 then return c.name end
    end
    return "Custom"
end
function Q.nextPosition(dir)
    local p = Q.place()
    local at = 0
    for i, c in ipairs(Q.POSITIONS) do
        if math.abs(c.fx - p.fx) < 0.005 and math.abs(c.fy - p.fy) < 0.005 then at = i end
    end
    local n = UF.stepIndex(at == 0 and 1 or at, #Q.POSITIONS, at == 0 and 0 or (dir or 1))
    Q.setPlace(Q.POSITIONS[n].fx, Q.POSITIONS[n].fy)
    return Q.POSITIONS[n].name
end

-- The arrow's picture: the old minimap quest arrow only (no other pictures, not selectable). The setting beside it is how opaque the
-- arrow is, from 100 down to 10 percent in steps of ten (a press of A is one step less opaque, X one step more, and it wraps round).
Q.ART = "Interface\\Minimap\\MiniMap-QuestArrow"
Q.OPACITY = { 100, 90, 80, 70, 60, 50, 40, 30, 20, 10 }
function Q.opacityName() return tostring(cfg().opacity) .. "%" end
function Q.nextOpacity(dir)
    local a = cfg()
    local at, best = 1, math.huge
    for i, v in ipairs(Q.OPACITY) do
        if math.abs(v - a.opacity) < best then at, best = i, math.abs(v - a.opacity) end
    end
    a.opacity = Q.OPACITY[UF.stepIndex(at, #Q.OPACITY, dir)]
    return a.opacity
end
-- the whole arrow (picture and distance) at the chosen opacity; set again only when it changed
function Q.applyOpacity(f)
    local v = cfg().opacity
    if f.opacity ~= v then
        f:SetAlpha(v / 100)
        f.opacity = v
    end
end

function Q.sizeName() return tostring(cfg().px) .. " px" end
-- one step up or down the list, from the step nearest the size now (the size is a width in pixels, whatever picture is drawn)
function Q.nextSize(dir)
    local a = cfg()
    local at, best = 1, math.huge
    for i, v in ipairs(Q.SIZESTEPS) do
        if math.abs(v - a.px) < best then at, best = i, math.abs(v - a.px) end
    end
    local n = at + ((dir or 1) < 0 and -1 or 1)
    if n < 1 then n = #Q.SIZESTEPS elseif n > #Q.SIZESTEPS then n = 1 end
    a.px = Q.SIZESTEPS[n]
    return a.px
end

function Q.sizePx() return cfg().px end

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
    return (x - left) / width, (y - bottom) / height
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

-- An arrow that points up by default. The bearing (claim C7) and GetPlayerFacing (claim C6) are both counter-clockwise from north,
-- so angle - facing is how far counter-clockwise from straight ahead the objective lies, and SetRotation turns a picture
-- counter-clockwise by what it is given (Blizzard's own arrow gives it the negative of a clockwise angle,
-- SuperTrackedFrame.lua:152; ForeverPlusPlus's waypoint arrow gives it angle - facing and works in the game). Facing east with the
-- objective north: 0 - 3 pi / 2 = a quarter turn counter-clockwise, the arrow points left, and north is on your left.
function Q.rotation(angle, facing) return angle - facing end

-- How the arrow turns. The game does not give addons the camera's direction (CameraDocumentation: no yaw), but it keeps a region at the
-- screen position of its navigation target (C_Navigation.GetFrame, InGameNavigationDocumentation.lua) and Blizzard's own arrow
-- (SuperTrackedFrame.lua UpdateArrow) turns by the angle between "up" and the offset of that region from the middle of the screen:
-- so it points the way the objective is in what you see, whichever way the character faces. "With the view" does the same; where the game
-- has no navigation target it falls back to "With the map", the compass direction as on a north-up minimap (the minimap's own quest arrow,
-- which does not turn with you either); "With you" is the old relative-to-your-facing arrow.
Q.TURNS = { "With the view", "With the map", "With you" }   -- the user chooses; With you is the first setting (ThePath / ForeverPlusPlus)
function Q.turnName() return Q.TURNS[cfg().turn] or Q.TURNS[1] end
function Q.nextTurn(dir)
    local a = cfg()
    a.turn = UF.stepIndex(a.turn, #Q.TURNS, dir)
    return a.turn
end

-- the turn that points from the middle of the screen (cx, cy) at a screen position (nx, ny): zero is up, SetRotation turns counter-clockwise,
-- so a target on the right is a negative turn. It is Blizzard's -Vector2D_CalculateAngleBetween(offset, up) = -atan2(offsetX, offsetY).
function Q.screenRotation(cx, cy, nx, ny)
    local vx, vy = nx - cx, ny - cy
    if vx == 0 and vy == 0 then return nil end
    return atan2(-vx, vy)
end

-- where the game puts its navigation target on the screen, as the turn to point at it, and the facts behind it for /ubf arrow; nil when
-- the game has no navigation target or no valid screen position for it
function Q.viewRotation()
    local N = C_Navigation
    if not (N and N.GetFrame) then return nil, "the game has no navigation system" end
    local okF, nf = pcall(N.GetFrame)
    if not okF or not nf then return nil, "the game has no navigation target (no quest selected in the tracker)" end
    if N.HasValidScreenPosition then
        local okV, valid = pcall(N.HasValidScreenPosition)
        if okV and not valid then return nil, "the game has no screen position for its target" end
    end
    local okC, nx, ny = pcall(nf.GetCenter, nf)
    if not okC or type(nx) ~= "number" or type(ny) ~= "number" then return nil, "the target has no place on the screen" end
    if issecretvalue and (issecretvalue(nx) or issecretvalue(ny)) then return nil, "the target's place is hidden from addons" end
    if not (WorldFrame and WorldFrame.GetCenter and UIParent and UIParent.GetEffectiveScale) then return nil, "no screen to measure on" end
    local okW, cx, cy = pcall(WorldFrame.GetCenter, WorldFrame)
    local okS, scale = pcall(UIParent.GetEffectiveScale, UIParent)
    if not (okW and okS and type(cx) == "number" and type(cy) == "number" and type(scale) == "number" and scale > 0) then
        return nil, "the middle of the screen is not known"
    end
    -- the same two numbers Blizzard compares in SuperTrackedFrame (GetCenterScreenPoint, and the navigation frame's own centre)
    local rot = Q.screenRotation(cx / scale, cy / scale, nx, ny)
    if not rot then return nil, "the target is at the middle of the screen" end
    return rot, nil, nx, ny, cx / scale, cy / scale
end

function Q.facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if not ok or type(f) ~= "number" then return nil end
    if issecretvalue and issecretvalue(f) then return nil end   -- the game may hide it from addons
    return f
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

-- Mode 3 on one map. The client gives no terrain, water or collision data (docs/RESEARCH-QUEST-ARROW.md), but the game's own route
-- is made with it: while the route's next step points about where the straight line points, nothing is in the way and the arrow
-- stays straight; when the next step swings away from the straight line, something blocks it and the arrow follows the route
-- step until the two agree again. The swing has to pass BEND_ON degrees to start and fall under BEND_OFF to end, so the arrow
-- does not flicker between the two near the limit. A step right under our feet says nothing about direction and is ignored.
Q.BEND_ON, Q.BEND_OFF, Q.TOO_CLOSE = 35, 20, 0.003
function Q.bends(pos, tx, ty, wp, was)
    if not (pos and wp and wp.x and wp.y) then return false end
    local ax, ay = tx - pos.x, ty - pos.y
    local bx, by = wp.x - pos.x, wp.y - pos.y
    if math.sqrt(ax * ax + ay * ay) < Q.TOO_CLOSE or math.sqrt(bx * bx + by * by) < Q.TOO_CLOSE then return false end
    local swing = math.abs(atan2(ax * by - ay * bx, ax * bx + ay * by)) * 180 / math.pi
    return swing > (was and Q.BEND_OFF or Q.BEND_ON)
end

-- the point the arrow aims at, the map it is on, how it was found, and the point the bearing is taken
-- from on that map (claims C5, C23, C24, C26, C28, C29). mode is one of Q.MODES.
function Q.aimFor(mode, hereMap, pos, targetMap, tx, ty, waypoint, parentOf, rowsOf, rectOf, wasBent)
    if not (mode and hereMap and pos and targetMap) then return nil end

    -- route: the game answer for the map we are standing on (claims C5 and C29)
    if mode == "route" and waypoint and waypoint.x and waypoint.y then
        return hereMap, waypoint.x, waypoint.y, "route", pos.x, pos.y
    end

    -- on the map the objective is on
    if hereMap == targetMap then
        if mode == "obstacle" then
            if not (waypoint and waypoint.x and waypoint.y) then return hereMap, tx, ty, "straight (no route)", pos.x, pos.y, false end
            if Q.bends(pos, tx, ty, waypoint, wasBent) then return hereMap, waypoint.x, waypoint.y, "around", pos.x, pos.y, true end
            return hereMap, tx, ty, "straight", pos.x, pos.y, false
        end
        return hereMap, tx, ty, "direct", pos.x, pos.y
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
    arrow.art:SetPoint("CENTER", arrow, "CENTER", 0, 0)   -- a texture with no point is never drawn
    arrow.art:SetTexture(Q.ART)
    -- the games own distance font (claim C39), under the arrow like Blizzard's
    arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow.text:SetPoint("TOP", arrow, "BOTTOM", 0, 4)
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
    if not a.on then Q.why = "switched off"; hide(); return end
    local f = build()
    if not f.art then Q.why = "no picture for the arrow"; hide(); return end

    -- follow the cursor while the drag is held, then the place is kept (claims C33, C35, C43)
    if f.moving then
        local fx, fy = Q.moveFromCursor()
        if fx then Q.setPlace(fx, fy) end
    end
    local p = Q.place()
    local ox, oy = Q.pointFor(p.fx, p.fy)
    if not ox then Q.why = "the screen size is not known yet"; hide(); return end
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
    if not here then Q.why = "the game does not say which map you are on"; hide(); return end

    local pos
    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, v = pcall(C_Map.GetPlayerMapPosition, here, "player")  -- claim C14
        if ok then pos = v end
    end
    if not pos or not pos.x or not pos.y then Q.why = "the game does not give your position on this map"; hide(); return end
    if issecretvalue and (issecretvalue(pos.x) or issecretvalue(pos.y)) then hide(); return end

    local quest = Q.tracking()
    local tmap, tx, ty
    if quest then
        tmap, tx, ty = Q.targetFor(quest, here, answerFor(quest), rowFor(quest, here))
    else
        local m, row = Q.picking()
        if m and row then tmap, tx, ty = m, row.x, row.y end
    end
    if not tmap then Q.why = "no quest to point at: none selected in the tracker and none in progress on this map"; hide(); return end

    local wp = waypointFor(quest, here)
    local aimMap, ax, ay, source, fromX, fromY, bent = Q.aimFor(Q.MODES[a.mode], here, pos, tmap, tx, ty,
        wp, parentOf, rowsOf, rectOf, Q.bent)
    if not aimMap then Q.why = "no way to aim with this mode"; hide(); return end
    Q.bent = bent or false
    f.source = source
    Q.last = { here = here, target = tmap, source = source, route = wp, bent = Q.bent, quest = quest }

    local w, h
    if C_Map and C_Map.GetMapWorldSize then
        local ok, ww, hh = pcall(C_Map.GetMapWorldSize, aimMap)  -- claim C15
        if ok then w, h = ww, hh end
    end
    local yards, angle = Q.bearing(w, h, fromX, fromY, ax, ay)  -- claim C7
    if not yards then Q.why = "the map size is not known"; hide(); return end
    -- which way to turn the picture: with the view (the game's own screen position of its target), else with the map (compass, north up),
    -- or with the character's facing
    local mode = a.turn
    local turn, used, face, vx, vy, cx, cy, whyNoView
    if mode == 1 then
        turn, whyNoView, vx, vy, cx, cy = Q.viewRotation()
        if turn then used = "view" else mode = 2 end
    end
    if not turn and mode == 2 then turn, used = angle, "map" end            -- the bearing is counter-clockwise from north (claim C7)
    if not turn then
        face = Q.facing()  -- claim C6
        if not face then Q.why = "the game does not give the direction you face"; hide(); return end
        turn, used = Q.rotation(angle, face), "facing"
    end
    Q.turnUsed, Q.whyNoView = used, whyNoView

    Q.why = nil
    Q.applyOpacity(f)
    f.art:SetRotation(turn)  -- claims C8 and C9
    -- The numbers behind the arrow, kept in the saved settings (DB.qarrow.debug, written at /reload or logout) and printed by /ubf arrow, so
    -- a wrong direction can be read from the real values instead of guessed: where you stand, where it aims, which way you face, what the
    -- bearing is, how far the picture was turned, what the picture reports back, and which art it is.
    local d = a.debug or {}
    a.debug = d
    d.mode, d.source, d.quest, d.here, d.aimMap = Q.MODES[a.mode], source, quest, here, aimMap
    d.px, d.py, d.ax, d.ay, d.tx, d.ty, d.tmap = pos.x, pos.y, ax, ay, tx, ty, tmap
    d.facing, d.bearing, d.turn, d.yards, d.mapW, d.mapH = face or Q.facing(), angle, turn, yards, w, h
    d.turnMode, d.turnUsed, d.whyNoView, d.viewX, d.viewY, d.centreX, d.centreY = Q.TURNS[a.turn], used, whyNoView, vx, vy, cx, cy
    local okR, applied = pcall(f.art.GetRotation, f.art)
    d.applied = (okR and type(applied) == "number") and applied or nil
    local okA, atlas = pcall(f.art.GetAtlas, f.art)
    d.atlas = (okA and type(atlas) == "string") and atlas or nil
    local okT, tex = pcall(f.art.GetTexture, f.art)
    d.texture = (okT and (type(tex) == "string" or type(tex) == "number")) and tex or nil
    Q.showDistance(f, yards, aimMap ~= here)
    if not f:IsShown() then f:Show() end
end

drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    acc = 0
    UF.try("QuestArrow.update", update)   -- an error here is kept for /ubf errors, not thrown away
end)

-- /ubf arrow: what the game answers for the arrow right now, so a mode that does nothing can be read instead of guessed
function Q.report()
    local a = cfg()
    UF.say("Quest arrow: " .. (a.on and "on" or "off") .. ", mode " .. Q.modeName())
    local function has(t, k) return (_G[t] and _G[t][k]) and "yes" or "NO" end
    UF.say("The game offers: GetNextWaypointForMap (quest) " .. has("C_QuestLog", "GetNextWaypointForMap") .. ", GetNextWaypointForMap (live route) "
        .. has("C_Navigation", "GetNextWaypointForMap") .. ", GetNextWaypoint " .. has("C_QuestLog", "GetNextWaypoint")
        .. ", GetMapRectOnMap " .. has("C_Map", "GetMapRectOnMap"))
    if Q.why then UF.say("The arrow is hidden: " .. Q.why .. ".") end
    local d = cfg().debug
    if d and d.facing then
        local function deg(r) return string.format("%.0f", (r or 0) * 180 / math.pi) end
        UF.say(string.format("Numbers: you at %.4f %.4f on map %s, aiming at %.4f %.4f on map %s (objective %.4f %.4f on map %s), %.0f yd",
            d.px or 0, d.py or 0, tostring(d.here), d.ax or 0, d.ay or 0, tostring(d.aimMap), d.tx or 0, d.ty or 0, tostring(d.tmap), d.yards or 0))
        UF.say("Turns: " .. tostring(d.turnMode) .. ", drawn by " .. tostring(d.turnUsed)
            .. (d.whyNoView and (" (the view is not used: " .. d.whyNoView .. ")") or "")
            .. (d.viewX and string.format(", the game puts its target at %.0f %.0f on a screen centred at %.0f %.0f", d.viewX, d.viewY, d.centreX or 0, d.centreY or 0) or ""))
        UF.say("You face " .. deg(d.facing) .. " deg counter-clockwise from north, the bearing is " .. deg(d.bearing) .. ", the arrow is turned "
            .. deg(d.turn) .. " (the picture reports " .. (d.applied and deg(d.applied) or "nothing") .. "), art " .. tostring(d.atlas or d.texture)
            .. ", mode " .. tostring(d.mode) .. ", aim source " .. tostring(d.source))
    end
    local l = Q.last
    if not l then UF.say("Nothing has been pointed at yet."); return end
    UF.say("Standing on map " .. tostring(l.here) .. ", objective on map " .. tostring(l.target) .. ", quest " .. tostring(l.quest)
        .. ", aiming by: " .. tostring(l.source) .. ", route step: "
        .. (l.route and string.format("%.3f %.3f", l.route.x, l.route.y) or "none from the game"))
end

-- Settings buttons (the options window calls these).
function Q.toggle() local a = cfg(); a.on = not a.on end
function Q.name() return cfg().on and "On" or "Off" end
