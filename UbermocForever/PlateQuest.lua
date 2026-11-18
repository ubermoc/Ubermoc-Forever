----------------------------------------------------------------------
-- Ubermoc Forever: a quest mark and the quest progress on nameplates (UF.PlateQuest), 1.3.129.
-- A unit that one of your active quests is about gets a small quest icon beside its name, and the progress of its objective
-- ("3/8", "45%") is written next to the icon. Two settings on the Quality of life page, both on by default.
--
-- Where the answers come from (Blizzard_APIDocumentationGenerated):
--   * C_QuestLog.UnitIsRelatedToActiveQuest(unit) -> bool (QuestLogDocumentation.lua:1287-1299): is this unit part of an active quest.
--     Its documentation gives no secret return, so the answer is read like any plain value (a secret one is treated as "no").
--   * C_TooltipInfo.GetUnit(unit) -> TooltipData (TooltipInfoDocumentation.lua:1181-1196) whose lines carry a type and a leftText; the
--     line types QuestObjective (8) and QuestTitle (17) are in TooltipInfoSharedDocumentation.lua:34-52. The objective line is
--     the same text the unit's tooltip shows ("Defias Thug slain: 3/8"), so the progress is taken from it: "a/b" or "n%".
--   * UNIT_QUEST_LOG_CHANGED (UnitDocumentation.lua:4563) and QUEST_LOG_UPDATE: when progress changes the plates are asked again.
-- The game's own nameplate code has nothing about quests (nothing in Blizzard_NamePlates), so this is ours entirely: our own
-- icon (the game's "QuestNormal" atlas) and our own font string, children of the plate's unit frame so the plate's own fading
-- carries over. Nothing is written on a game frame, no hook, no update loop. Everything is inside pcall.
-- A unit whose objectives are all finished is not marked any more.
----------------------------------------------------------------------
local _, UF = ...
local PQ = {}
UF.PlateQuest = PQ

local objs = setmetatable({}, { __mode = "k" })   -- plate unit frame -> our icon and text

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function db()
    local d = UF.DB()
    d.plates = d.plates or {}
    if d.plates.quest == nil then d.plates.quest = true end
    if d.plates.questText == nil then d.plates.questText = true end
    return d.plates
end
PQ.db = db

function PQ.enabled() return db().quest == true end
function PQ.textEnabled() return db().questText == true end

-- one of the two settings ("quest" = the icon, "text" = the progress); the plates on screen are redone at once
function PQ.toggle(which)
    local d = db()
    if which == "quest" then d.quest = not d.quest
    elseif which == "text" then d.questText = not d.questText
    else return end
    PQ.applyAll()
end

-- The progress in the objective lines of a unit's tooltip: { any = an objective line was there, done = every one is finished,
-- text = the first unfinished one's progress }.
function PQ.parse(lines)
    local want = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective) or 8
    local any, open, text = false, false, nil
    for _, l in ipairs(type(lines) == "table" and lines or {}) do
        if type(l) == "table" and plain(l.type) == want then
            local t = plain(l.leftText)
            if type(t) == "string" then
                local a, b = t:match("(%d+)%s*/%s*(%d+)")
                if a then
                    any = true
                    if tonumber(a) < tonumber(b) then
                        open = true
                        text = text or (a .. "/" .. b)
                    end
                else
                    local p = t:match("(%d+)%s*%%")
                    if p then
                        any = true
                        if tonumber(p) < 100 then open = true; text = text or (p .. "%") end
                    end
                end
            end
        end
    end
    return { any = any, done = any and not open, text = text }
end

-- nil when the unit has nothing to do with an active quest; else { done = bool, text = string or nil }
function PQ.state(unit)
    if type(unit) ~= "string" or not (C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest) then return nil end
    local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
    if not ok or plain(related) ~= true then return nil end
    local lines
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local okT, data = pcall(C_TooltipInfo.GetUnit, unit)
        data = okT and plain(data) or nil
        if type(data) == "table" then lines = plain(data.lines) end
    end
    local p = PQ.parse(lines)
    return { done = p.done == true, text = p.text }
end

-- our two pieces on one plate, made once (a hidden icon still holds its place, so the text stays where it is when only the text is on)
function PQ.make(uf)
    if not (uf and CreateFrame) then return nil end
    local okF, holder = pcall(CreateFrame, "Frame", nil, uf)
    if not okF or not holder then return nil end
    local o = { holder = holder }
    o.icon = holder:CreateTexture(nil, "OVERLAY")
    o.icon:SetSize(16, 16)
    if o.icon.SetAtlas then pcall(o.icon.SetAtlas, o.icon, "QuestNormal") end
    o.text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local name = uf.name
    if name then
        pcall(o.icon.SetPoint, o.icon, "RIGHT", name, "LEFT", -2, 0)
    else
        pcall(o.icon.SetPoint, o.icon, "LEFT", uf, "LEFT", 0, 0)
    end
    pcall(o.text.SetPoint, o.text, "RIGHT", o.icon, "LEFT", -2, 0)
    pcall(o.text.SetTextColor, o.text, 1, 0.82, 0)
    o.icon:Hide(); o.text:Hide()
    return o
end

local function pieces(uf)
    local o = objs[uf]
    if o == nil then
        o = PQ.make(uf) or false
        objs[uf] = o
    end
    return o or nil
end

function PQ.clear(uf)
    local o = uf and objs[uf]
    if o then
        pcall(o.icon.Hide, o.icon)
        pcall(o.text.Hide, o.text)
    end
end

-- one plate: the mark and the progress for its unit, or nothing
function PQ.show(uf, unit)
    if not uf then return end
    local want = (PQ.enabled() or PQ.textEnabled()) and PQ.state(unit) or nil
    if not want or want.done then PQ.clear(uf); return end
    local o = pieces(uf)
    if not o then return end
    -- beside the level text we draw on friendly player plates (PlateLevel.lua), else beside the name
    local lv = UF.PlateLevel and UF.PlateLevel.piece(uf)
    local anchor = (lv and lv.fs and lv.fs.IsShown and lv.fs:IsShown()) and lv.fs or uf.name
    if anchor then
        pcall(o.icon.ClearAllPoints, o.icon)
        pcall(o.icon.SetPoint, o.icon, "RIGHT", anchor, "LEFT", -2, 0)
    end
    if PQ.enabled() then pcall(o.icon.Show, o.icon) else pcall(o.icon.Hide, o.icon) end
    if PQ.textEnabled() and want.text then
        pcall(o.text.SetText, o.text, want.text)
        pcall(o.text.Show, o.text)
    else
        pcall(o.text.Hide, o.text)
    end
end

local function plateOf(unit)
    if type(unit) ~= "string" or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and type(plate) == "table" then return plate end
end

local function styleFor(unit)
    local plate = plateOf(unit)
    local uf = plate and plate.UnitFrame
    if type(uf) ~= "table" then return end
    pcall(PQ.show, uf, unit)
end

function PQ.applyAll()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame
        if type(uf) == "table" then
            local unit = plate.namePlateUnitToken
            if type(unit) ~= "string" then unit = uf.unit end
            pcall(PQ.show, uf, unit)
        end
    end
end

-- asked again at most once in a short while, however many events arrive together
local waiting = false
function PQ.later()
    if waiting then return end
    waiting = true
    local function run() waiting = false; PQ.applyAll() end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
end

local f = CreateFrame("Frame")
PQ._frame = f   -- for the offline test
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        styleFor(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = plateOf(unit)
        local uf = plate and plate.UnitFrame
        if type(uf) == "table" then PQ.clear(uf) end
    else
        PQ.later()
    end
end)
