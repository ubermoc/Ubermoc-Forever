----------------------------------------------------------------------
-- Ubermoc Forever: the level on a friendly player's plate in the game's name-only mode (UF.PlateLevel), 1.3.130.
--
-- The problem: with "Friendly: name only" on, a friendly player's plate showed no level. That is the game's own doing, not an
-- alpha of ours: our option writes the game's CVar nameplateShowOnlyNameForFriendlyPlayerUnits, and with it on
--   * NamePlateUnitFrameMixin:UpdateShowOnlyName (Blizzard_NamePlateUnitFrame.lua:565-587) hides the bar, cast bar, auras,
--     classification and raid icon and calls CompactUnitFrame_UpdatePlayerLevelDiff, which
--   * asks PlayerLevelDiffFrame:ShouldDisplay(unit) (Camelot/Blizzard_NamePlateLevelFrame.lua:3-17), and that returns false for
--     "UnitIsFriend("player", unit) and UnitIsPlayer(unit) and the CVar" (CompactUnitFrame.lua:1521-1548, Hide() at 1547, takes the badge away).
-- So the badge never appears for a friendly player in that mode, whatever we do to the pieces (the 1.3.121 change that kept the
-- level number only concerns enemies and friendly NPCs, whose plates the game does not put in that mode).
--
-- The fix: where, and only where, the game leaves its badge off for that reason, we draw the level ourselves. The condition is the
-- game's own (friend, player, CVar on), so no plate gets two numbers: everything else keeps the game's badge.
--   * the number: UnitEffectiveLevel(unit), as the game's badge (CompactUnitFrame.lua:1528). Its documentation gives no secret
--     return (UnitDocumentation.lua:1124-1137); a secret or missing answer shows nothing. A level of 0 or less is written "??".
--   * the colour: the game's own constants. UNIT_LEVEL_NON_ATTACKABLE for a unit you cannot attack (CompactUnitFrame.lua:1530), else
--     the difficulty colour by the level difference with the same limits as Camelot/Blizzard_NamePlateLevelFrame.lua:19-32.
--     (The constants are named in the game's code but defined in its data, so each is read at run time and a missing one is white.)
--   * the font: SystemFont_NamePlateLevel, the badge's own (Camelot/Blizzard_NamePlateLevelFrame.xml:19). The ring behind the number
--     is not drawn, as on the other name-only plates.
--   * the place: at the right end of the plate where the game's badge sits (it is anchored 5 units right of the health bar,
--     Camelot/Blizzard_NamePlateLevelFrame.xml:6-7), at the height of the name: the name's own right edge is the bar's right edge
--     in name-only mode (Blizzard_NamePlateUnitFrame.lua:741-749), so the number is anchored to the right of it.
--   * the events: NAME_PLATE_UNIT_ADDED / REMOVED (NamePlateManagerDocumentation.lua:120, 141), UNIT_FACTION (UnitDocumentation.lua:
--     4259), UNIT_LEVEL (4353), PLAYER_LEVEL_UP (3832) and CVAR_UPDATE (ConsoleDocumentation.lua:176): plates are reused, so each
--     is asked again, once in a short while however many events arrive together.
-- Our own frame and font string, children of the plate's unit frame so the plate's own fading carries over. Nothing is written
-- on a game frame, no hook, no update loop. Everything is inside pcall.
----------------------------------------------------------------------
local _, UF = ...
local PL = {}
UF.PlateLevel = PL

local CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
local objs = setmetatable({}, { __mode = "k" })   -- plate unit frame -> our level text

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- The game keeps its own badge off a plate in exactly this case (ShouldDisplay): a friendly player while its name-only CVar is on.
function PL.gameHidesBadge(unit)
    if type(unit) ~= "string" or not (UnitIsPlayer and UnitIsFriend and GetCVarBool) then return false end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP or plain(isPlayer) ~= true then return false end
    local okF, isFriend = pcall(UnitIsFriend, "player", unit)
    if not okF or plain(isFriend) ~= true then return false end
    local okC, on = pcall(GetCVarBool, CVAR)
    return okC and plain(on) == true
end

-- the unit's level, or nil when it cannot be read
function PL.level(unit)
    if type(unit) ~= "string" or not UnitEffectiveLevel then return nil end
    local ok, level = pcall(UnitEffectiveLevel, unit)
    if not ok then return nil end
    level = plain(level)
    if type(level) ~= "number" then return nil end
    return level
end

-- r, g, b of one of the game's colour constants; white when it is missing
local function rgb(name)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

-- the colour the game gives the number: "non attackable" unless the unit can be attacked, then by the level difference
function PL.color(unit, level)
    if UnitCanAttack and type(level) == "number" and level > 0 and UnitEffectiveLevel then
        local okA, can = pcall(UnitCanAttack, "player", unit)
        if okA and plain(can) == true then
            local okM, mine = pcall(UnitEffectiveLevel, "player")
            mine = okM and plain(mine) or nil
            if type(mine) == "number" then
                local diff = level - mine
                local trivial = 0
                if C_QuestLog and C_QuestLog.GetTrivialRange then
                    local okT, t = pcall(C_QuestLog.GetTrivialRange)
                    t = okT and plain(t) or nil
                    if type(t) == "number" then trivial = t end
                end
                if diff < -trivial then return rgb("TRIVIAL_DIFFICULTY_COLOR") end
                if diff <= -3 then return rgb("EASY_DIFFICULTY_COLOR") end
                if diff <= 2 then return rgb("FAIR_DIFFICULTY_COLOR") end
                if diff <= 4 then return rgb("DIFFICULT_DIFFICULTY_COLOR") end
                return rgb("IMPOSSIBLE_DIFFICULTY_COLOR")
            end
        end
    end
    return rgb("UNIT_LEVEL_NON_ATTACKABLE")
end

-- our text on one plate, made once
function PL.make(uf)
    if not (uf and CreateFrame) then return nil end
    local okF, holder = pcall(CreateFrame, "Frame", nil, uf)
    if not okF or not holder then return nil end
    local o = { holder = holder }
    o.text = holder:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
    o.text:Hide()
    return o
end

local function pieces(uf)
    local o = objs[uf]
    if o == nil then
        o = PL.make(uf) or false
        objs[uf] = o
    end
    return o or nil
end

function PL.clear(uf)
    local o = uf and objs[uf]
    if o then pcall(o.text.Hide, o.text) end
end

-- one plate: the level when the game leaves its badge off, else nothing of ours
function PL.show(uf, unit)
    if not uf then return end
    if not PL.gameHidesBadge(unit) then PL.clear(uf); return end
    local level = PL.level(unit)
    if not level then PL.clear(uf); return end
    local o = pieces(uf)
    if not o then return end
    local name = uf.name
    local bar = uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar
    pcall(o.text.ClearAllPoints, o.text)
    if type(name) == "table" then
        pcall(o.text.SetPoint, o.text, "LEFT", name, "RIGHT", 9, 0)
    elseif type(bar) == "table" then
        pcall(o.text.SetPoint, o.text, "LEFT", bar, "RIGHT", 8, 0)
    else
        pcall(o.text.SetPoint, o.text, "LEFT", uf, "RIGHT", 0, 0)
    end
    pcall(o.text.SetTextColor, o.text, PL.color(unit, level))
    pcall(o.text.SetText, o.text, level > 0 and tostring(level) or "??")
    pcall(o.text.Show, o.text)
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
    local token = plate.namePlateUnitToken
    if type(token) ~= "string" then token = unit end
    pcall(PL.show, uf, token)
end

function PL.applyAll()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame
        if type(uf) == "table" then
            local unit = plate.namePlateUnitToken
            if type(unit) ~= "string" then unit = uf.unit end
            pcall(PL.show, uf, unit)   -- one plate failing must not stop the rest
        end
    end
end

-- asked again at most once in a short while, however many events arrive together
local waiting = false
function PL.later()
    if waiting then return end
    waiting = true
    local function run() waiting = false; PL.applyAll() end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
end

local f = CreateFrame("Frame")
PL._frame = f   -- for the offline test
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_FACTION")
f:RegisterEvent("UNIT_LEVEL")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Nameplates writes its CVar after a fight
f:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        styleFor(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = plateOf(unit)
        local uf = plate and plate.UnitFrame
        if type(uf) == "table" then PL.clear(uf) end
    else
        PL.later()
    end
end)
