----------------------------------------------------------------------
-- Ubermoc Forever: quest direction arrow.
-- A small arrow near the top right of the screen points at the objective of a quest in progress on
-- the map you are on, and turns as you turn. The maths is the documented one
-- (docs/RESEARCH-QUEST-ARROW.md, claims C7 C8 C9): the angle from north is atan2 of the yard
-- offsets, counter-clockwise, and a picture that points up turns by the angle minus your facing,
-- through the game's SetRotation with the negative, as Blizzards own quest arrow does. The art is
-- the game's own quest navigation atlas, Navigation-Tracked-Arrow (claim C10).
-- It shows only while the game can say both your own spot and the objective spot on that map; a
-- quest whose spot is on another map is not pointed at. Display only: nothing here clicks, uses or
-- targets, so nothing can taint. The Quality of life page has the row (On by default).
----------------------------------------------------------------------
local ADDON, UF = ...
local Q = {}
UF.QuestArrow = Q

-- math.atan takes (y, x) in the games Lua and in the offline test, so this is atan2.
local function atan2(y, x) return math.atan(y, x) end

local function cfg()
    local d = UF.DB()
    d.qarrow = d.qarrow or {}
    if d.qarrow.on == nil then d.qarrow.on = true end
    return d.qarrow
end
Q.cfg = cfg

-- The yards and the angle (counter-clockwise from north, 0 to 2 pi) from your spot to the spot on a
-- map of the given size in yards (claim C7).
function Q.bearing(width, height, fromX, fromY, toX, toY)
    local east = (toX - fromX) * width
    local south = (toY - fromY) * height
    return math.sqrt(east * east + south * south), atan2(-east, -south) % (2 * math.pi)
end

-- An arrow that points up by default turns by angle - facing, and the game's SetRotation takes the
-- negative (claims C7 and C9).
function Q.rotation(angle, facing) return -(angle - facing) end

function Q.facing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    return (ok and f) or nil
end

-- The first quest in progress on the map we are on, as the game reports it (claims C11 and C12).
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

local arrow
local function build()
    if arrow then return arrow end
    arrow = CreateFrame("Frame", "UbermocForeverQuestArrow", UIParent)
    arrow:SetFrameStrata("MEDIUM")
    arrow:SetSize(44, 44)
    arrow:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -24)
    arrow:EnableMouse(false)
    arrow.art = arrow:CreateTexture(nil, "OVERLAY")
    -- the games own quest navigation art (claim C10); if the atlas cannot be used the arrow never shows
    local ok, used = pcall(arrow.art.SetAtlas, arrow.art, "Navigation-Tracked-Arrow")
    if not ok or not used then arrow.art = nil end
    arrow:Hide()
    return arrow
end

local function hide()
    if arrow and arrow:IsShown() then arrow:Hide() end
end

local function update()
    if not cfg().on then hide(); return end
    local mapID, q = Q.picking()
    if not mapID then hide(); return end
    if not (C_Map and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then hide(); return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then hide(); return end
    local ok2, w, h = pcall(C_Map.GetMapWorldSize, mapID)
    if not ok2 or not w or not h then hide(); return end
    local f = Q.facing()
    if not f then hide(); return end
    local _, angle = Q.bearing(w, h, pos.x, pos.y, q.x, q.y)
    local a = build()
    if not a.art then hide(); return end
    a.art:SetRotation(Q.rotation(angle, f))
    if not a:IsShown() then a:Show() end
end

local acc = 0
local drv = CreateFrame("Frame")
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    acc = 0
    update()
end)

-- Settings buttons (the options window calls these).
function Q.toggle() local a = cfg(); a.on = not a.on end
function Q.name() return cfg().on and "On" or "Off" end
