----------------------------------------------------------------------
-- Ubermoc Forever: the level on a player's nameplate (UF.PlateLevel), 1.3.131.
--
-- The problem: a player's nameplate, friendly or enemy, showed no level. The game's own badge is meant to (Camelot/
-- Blizzard_NamePlateLevelFrame.lua:3-17 ShouldDisplay is true for everything but a game object and, with the game's own
-- name-only setting on, a friendly player), but it is not on the plates we see, and the cause on enemy players is not in the
-- game's code that was read (nothing there treats a player differently, apart from that one case).
-- 1.3.130 only handled the friendly-player case, by predicting it from the setting. That was a guess about the cause; this
-- version does not guess. It looks at what is really on the plate:
--   * if the game's own level is showing on a plate (its badge, PlayerLevelDiffFrame, or the level inside the bar, LevelFrame, as
--     CompactUnitFrame.lua:1521 and 1713 show them), we draw nothing: no plate gets two numbers;
--   * if neither is showing on a PLAYER's plate, we draw the level ourselves.
-- Whatever the reason the game's badge is missing (its name-only mode, a setting, a plate state), the level appears. Only players:
-- other units are left exactly as they were. `/ubf plates` prints what is on each plate in view, so a plate that still shows no
-- level can be read instead of guessed at.
--
-- What we draw, as the game draws its badge:
--   * the number: UnitEffectiveLevel(unit) (CompactUnitFrame.lua:1528). Its documentation gives no secret return
--     (UnitDocumentation.lua:1124-1137); a secret or missing answer shows nothing. A level of 0 or less is written "??".
--   * the colour: the game's own constants. UNIT_LEVEL_NON_ATTACKABLE for a unit you cannot attack (CompactUnitFrame.lua:1530), else
--     the difficulty colour by the level difference with the same limits as Camelot/Blizzard_NamePlateLevelFrame.lua:19-32.
--     (The constants are named in the game's code but defined in its data, so each is read at run time and a missing one is white.)
--   * the font: SystemFont_NamePlateLevel, the badge's own (Camelot/Blizzard_NamePlateLevelFrame.xml:19). No ring behind it.
--   * the place: at the right end of the plate where the game's badge sits (anchored 5 units right of the health bar,
--     Camelot/Blizzard_NamePlateLevelFrame.xml:6-7), at the height of the name: in name-only mode the name's right edge is the bar's
--     right edge (Blizzard_NamePlateUnitFrame.lua:741-749), so the number is anchored to the right of the name.
--   * when: NAME_PLATE_UNIT_ADDED / REMOVED (NamePlateManagerDocumentation.lua:120, 141), UNIT_FACTION (UnitDocumentation.lua:4259),
--     UNIT_LEVEL (4353), PLAYER_LEVEL_UP (3832) and CVAR_UPDATE (ConsoleDocumentation.lua:176). Plates are reused and the game fills its
--     own badge in its own time, so a plate's text is cleared at once when the plate is added and every plate is looked at again
--     after 0.2 s and once more after 1 s, however many events arrive together.
-- What we read of the game: whether its two level pieces are shown (IsShown, a plain answer). Our own frame and font string are
-- children of the plate's unit frame so the plate's fading carries over. Nothing is written on a game frame, no hook, no update
-- loop. Everything is inside pcall.
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

-- true / false when the answer is plain, nil when it cannot be read
local function askBool(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    v = plain(v)
    if v == nil then return nil end
    return v == true
end

function PL.isPlayer(unit)
    if type(unit) ~= "string" then return false end
    return askBool(UnitIsPlayer, unit) == true
end

-- is a piece of the game's plate shown? false when there is no such piece, nil when it cannot be read
local function pieceShown(piece)
    if type(piece) ~= "table" or not piece.IsShown then return false end
    return askBool(piece.IsShown, piece)
end

-- Is the game showing a level on this plate (its badge, or the level inside the bar)? true / false / nil (unknown)
function PL.gameShowsLevel(uf)
    if type(uf) ~= "table" then return nil end
    local badge = pieceShown(uf.PlayerLevelDiffFrame)
    local inBar = pieceShown(uf.LevelFrame)
    if badge == true or inBar == true then return true end
    if badge == nil or inBar == nil then return nil end
    return false
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
        if askBool(UnitCanAttack, "player", unit) == true then
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

-- one plate: the level of a player's plate when the game shows none, else nothing of ours
function PL.show(uf, unit)
    if not uf then return end
    if not PL.isPlayer(unit) then PL.clear(uf); return end
    local level = PL.level(unit)
    if not level then PL.clear(uf); return end
    -- only when the game's own level is certainly not there: shown, or unreadable, is left to the game
    if PL.gameShowsLevel(uf) ~= false then PL.clear(uf); return end
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

local function tokenOf(plate, uf)
    local unit = plate.namePlateUnitToken
    if type(unit) ~= "string" then unit = uf.unit end
    return unit
end

function PL.applyAll()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame
        if type(uf) == "table" then
            pcall(PL.show, uf, tokenOf(plate, uf))   -- one plate failing must not stop the rest
        end
    end
end

-- asked again at most once in a short while however many events arrive together, and once more after the game has settled
local waiting = false
function PL.later()
    if waiting then return end
    waiting = true
    local function run() waiting = false; PL.applyAll() end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, run)
        C_Timer.After(1.0, PL.applyAll)
    else
        run()
    end
end

----------------------------------------------------------------------
-- /ubf plates: what is on each plate in view, so a plate with no level can be read
----------------------------------------------------------------------
local function word(v)
    if issecretvalue and issecretvalue(v) then return "secret" end
    if v == nil then return "?" end
    return tostring(v)
end

local function shownWord(piece)
    local s = pieceShown(piece)
    if s == nil then return "?" end
    return s and "yes" or "no"
end

local function alphaWord(piece)
    if type(piece) ~= "table" or not piece.GetAlpha then return "-" end
    local ok, a = pcall(piece.GetAlpha, piece)
    if not ok then return "?" end
    return word(a)
end

local function ask(fn, ...)
    if not fn then return "?" end
    local ok, v = pcall(fn, ...)
    if not ok then return "?" end
    return word(v)
end

function PL.report()
    local say = UF.say
    local function cv(name)
        if not GetCVar then return "?" end
        local ok, v = pcall(GetCVar, name)
        return ok and word(v) or "?"
    end
    local d = UF.DB().plates or {}
    say("Plate levels. Our options: enemies name-only " .. tostring(d.enemy == true) .. ", friendly name-only " .. tostring(d.friendly == true)
        .. ". The game: only-name for friendly players " .. cv(CVAR) .. ", style " .. cv("nameplateStyle")
        .. ", simplified " .. cv("nameplateSimplifiedTypes") .. ".")
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then say("No nameplate list from the game."); return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" or #plates == 0 then say("No nameplates in view."); return end
    for i, plate in ipairs(plates) do
        if i > 8 then say("(" .. (#plates - 8) .. " more plates not listed)"); break end
        local uf = plate.UnitFrame
        if type(uf) ~= "table" then
            say("plate " .. i .. ": no unit frame")
        else
            local unit = tokenOf(plate, uf)
            local mine = objs[uf]
            local badge, text = uf.PlayerLevelDiffFrame, uf.PlayerLevelDiffFrame and uf.PlayerLevelDiffFrame.playerLevelDiffText
            say(word(unit) .. ": player " .. ask(UnitIsPlayer, unit) .. ", friend " .. ask(UnitIsFriend, "player", unit)
                .. ", attackable " .. ask(UnitCanAttack, "player", unit) .. ", level " .. ask(UnitEffectiveLevel, unit)
                .. " | game badge shown " .. shownWord(badge) .. " (alpha " .. alphaWord(badge) .. ", number shown " .. shownWord(text)
                .. ", number alpha " .. alphaWord(text) .. "), level in bar shown " .. shownWord(uf.LevelFrame)
                .. " | ours " .. (mine and mine.text and shownWord(mine.text) or "not made"))
        end
    end
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
    if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        -- a plate is reused for another unit: whatever we drew for the last one goes at once, the game fills its own badge in its
        -- own time, and the plate is looked at again shortly
        local plate = plateOf(unit)
        local uf = plate and plate.UnitFrame
        if type(uf) == "table" then PL.clear(uf) end
        if event == "NAME_PLATE_UNIT_ADDED" then PL.later() end
    else
        PL.later()
    end
end)
