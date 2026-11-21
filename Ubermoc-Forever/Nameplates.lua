----------------------------------------------------------------------
-- Ubermoc Forever: name-only nameplates (UF.Nameplates)
--
-- Two settings on the Quality of life page, both On by default (the author's settings, in UF.SEED): an enemy plate and a
-- friendly plate show the unit's name with no health bar. Off gives every piece we hid back the alpha it had BEFORE we hid it.
--
-- Friendly players already have the game's own name-only mode: CVar nameplateShowOnlyNameForFriendlyPlayerUnits
-- (Blizzard_NamePlateConstants.lua:20) and NamePlateUnitFrameMixin:UpdateShowOnlyName
-- (Blizzard_NamePlateUnitFrame.lua:565), which hides the bar, cast bar, auras and classification and clears the click area
-- by itself (the raid icon stays: Blizzard_NamePlateRaidTarget.lua:17). For them our part is only the CVar, no taint.
-- Enemies and friendly NPCs have no such mode, so we put the pieces to alpha 0 with SetAlpha: a plain C call, no game
-- Lua runs and nothing is written on the game's frames. Nothing in Blizzard_NamePlates calls SetAlpha (the only
-- SetAlpha in Blizzard_UnitFrame/Shared/CompactUnitFrame.lua - 1518, 1884, 2001 - hits the compact unit frame itself,
-- which a nameplate never uses), so the game never puts an alpha back for us. The plates are reused frames, so every
-- plate is set both ways on each add.
-- Pieces we hide: HealthBarsContainer (Blizzard_NamePlates.xml:103, no child there ignores its parent alpha),
-- selectionHighlight (299, alpha .25 and ignoreParentAlpha, so it needs its own call), aggroHighlight (307) and the ring
-- behind the player level badge (PlayerLevelDiffFrame.playerLevelDiffIcon, Blizzard_NamePlateLevelFrame.xml:11, a plain
-- texture; its number is anchored to it, not a child, so the number stays). The level (LevelFrame, 273: text only, no
-- border or background in the XML) and the badge number are kept. name (294), CastBarsContainer (173),
-- WidgetContainer (180), RaidTargetFrame (186), ClassificationFrame (196) and AurasFrame (217) are never touched.
-- No unit data is read: the health, name and class answers are secret for our code (UnitDocumentation.lua:1526, 2489,
-- 911). The unit calls are UnitCanAttack (763), as Fade.lua's applyPlates, and UnitIsPlayer (PlateLevel.lua draws the level of
-- a friendly player, which the game hides under its own name-only setting).
-- Our state lives in our own weak-keyed table; nothing is written on a game frame.
----------------------------------------------------------------------
local _, UF = ...
local N = {}
UF.Nameplates = N

local CVAR = "nameplateShowOnlyNameForFriendlyPlayerUnits"
-- the pieces we hide, by the name the game gives them on the plate's unit frame
-- (a dotted name is a child of a piece: the ring of the player level badge, so its number stays)
local PIECES = { "HealthBarsContainer", "selectionHighlight", "aggroHighlight", "PlayerLevelDiffFrame.playerLevelDiffIcon" }

local orig = setmetatable({}, { __mode = "k" })   -- piece -> the alpha it had before we hid it (kept the first time only)
N.pending = false                                  -- a CVar change waiting for the fight to end

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function db()
    local d = UF.DB()
    d.plates = d.plates or {}
    if d.plates.enemy == nil then d.plates.enemy = true end
    if d.plates.friendly == nil then d.plates.friendly = true end
    if d.plates.health == nil then d.plates.health = true end
    if d.plates.percent == nil then d.plates.percent = true end
    return d.plates
end
N.db = db

function N.enabled(kind) return db()[kind] == true end
-- is a piece hidden for this kind of unit? an unknown kind is never wanted
function N.wanted(kind)
    if kind ~= "enemy" and kind ~= "friendly" then return false end
    return db()[kind] == true
end

-- enemy, friendly or nil (unknown). UnitCanAttack is the only unit call allowed here, and its answer can be secret.
function N.kindOf(unit)
    if type(unit) ~= "string" or not UnitCanAttack then return nil end
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if not ok then return nil end
    can = plain(can)
    if can == nil then return nil end
    return can and "enemy" or "friendly"
end

-- the pieces of a unit frame that are there and can be set; a missing piece is skipped
function N.parts(uf)
    local out = {}
    if not uf then return out end
    for _, name in ipairs(PIECES) do
        local p = uf
        for key in string.gmatch(name, "[^%.]+") do
            if type(p) ~= "table" then p = nil; break end
            p = p[key]
        end
        if p and p.SetAlpha then out[#out + 1] = p end
    end
    return out
end

function N.hide(piece)
    if not (piece and piece.SetAlpha) then return end
    if orig[piece] == nil then
        local ok, was = pcall(piece.GetAlpha, piece)
        local v = ok and plain(was) or nil
        if type(v) ~= "number" then v = 1 end   -- a secret or an odd answer: put back 1
        orig[piece] = v
    end
    pcall(piece.SetAlpha, piece, 0)
end

function N.restore(piece)
    if not (piece and piece.SetAlpha) then return end
    local v = orig[piece]
    if v == nil then return end
    pcall(piece.SetAlpha, piece, v)
    orig[piece] = nil
end

-- one plate, both ways: hide what is wanted hidden, else give each piece we hid its own original alpha
function N.style(plate)
    if not plate then return end
    local uf = plate.UnitFrame
    if not uf then return end
    if uf.IsForbidden then
        local ok, forbidden = pcall(uf.IsForbidden, uf)
        if ok and plain(forbidden) then return end
    end
    local unit = plate.namePlateUnitToken
    if type(unit) ~= "string" then unit = uf.unit end
    local kind = N.kindOf(unit)
    local list = N.parts(uf)
    local NH = UF.NameHealth
    local PL = UF.PlateLevel
    if PL then
        -- a friendly PLAYER under "Friendly: name only": the game hides its level itself in that mode (PlateLevel.lua)
        local isPlayer = false
        if kind == "friendly" and N.wanted("friendly") and UnitIsPlayer then
            local okP, p = pcall(UnitIsPlayer, unit)
            isPlayer = okP and plain(p) == true
        end
        pcall(PL.show, uf, unit, isPlayer)
    end
    if N.wanted(kind) then
        for _, p in ipairs(list) do N.hide(p) end
        if not NH then return end
        local d = db()
        if d.health or d.percent then NH.show(uf, unit, d) else NH.clear(uf) end
    else
        for _, p in ipairs(list) do N.restore(p) end
        if NH then NH.clear(uf) end
    end
end

function N.applyAll()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do pcall(N.style, plate) end   -- one plate failing must not stop the rest
end

-- a plate the game will not show us (includeForbidden defaults to false, NamePlateDocumentation.lua:11): nil, do nothing
local function styleFor(unit)
    if type(unit) ~= "string" or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok then return end
    pcall(N.style, plate)
end

-- only the one CVar, only out of combat. The value the player had before we first wrote it is kept in the settings
-- and given back when the option goes Off. If it cannot be read, nothing is written.
function N.syncCVar()
    if InCombatLockdown and InCombatLockdown() then N.pending = true; return end
    local d = db()
    local value
    if N.enabled("friendly") then
        if d.prevOnlyName == nil then
            local ok, was = pcall(GetCVar, CVAR)
            if not ok then return end
            was = plain(was)
            if type(was) ~= "string" then return end
            d.prevOnlyName = was
        end
        value = "1"
    elseif d.prevOnlyName == nil then
        return   -- we never wrote it: nothing to give back
    else
        value = d.prevOnlyName
        d.prevOnlyName = nil
    end
    N.pending = false
    pcall(SetCVar, CVAR, value)
end

function N.toggle(kind)
    if kind ~= "enemy" and kind ~= "friendly" then return end
    local d = db()
    d[kind] = not N.enabled(kind)
    N.syncCVar()
    N.applyAll()
end

local f = CreateFrame("Frame")
N._frame = f   -- for the offline test
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("UNIT_FACTION")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")   -- NameHealth: a plate that goes away lets go of its unit's health events
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if N.pending then
            if UF.diag then UF.diag("ours", "nameplate setting written") end
            N.syncCVar()
        end
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        N.syncCVar()
        N.applyAll()
        return
    end
    -- NAME_PLATE_UNIT_ADDED and UNIT_FACTION both hand a unit token
    if event == "NAME_PLATE_UNIT_REMOVED" then
        -- best effort: the game may have taken the plate away already, and then the weak table lets
        -- our objects go with it
        local NH = UF.NameHealth
        if not NH or type(unit) ~= "string" or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and type(plate) == "table" and type(plate.UnitFrame) == "table" then NH.clear(plate.UnitFrame) end
        return
    end
    styleFor(unit)
end)
