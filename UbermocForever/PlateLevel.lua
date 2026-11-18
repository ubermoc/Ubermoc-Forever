----------------------------------------------------------------------
-- Ubermoc Forever: the level on friendly player nameplates (UF.PlateLevel), 1.3.136.
-- Why it is missing: on Forever the game's own level badge (Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.lua,
-- ShouldDisplay) answers "no" for a friendly player while the game's setting nameplateShowOnlyNameForFriendlyPlayerUnits is
-- on (lines 9-11), and the "Friendly: name only" option (Nameplates.lua) switches exactly that setting on. NPCs and enemies
-- keep their level (the same function answers yes for them).
-- So for those plates we draw the level ourselves: our own font string, to the left of the name, in the game's colour for a
-- unit you cannot attack (UNIT_LEVEL_NON_ATTACKABLE, used by CompactUnitFrame_UpdateLevel, CompactUnitFrame.lua:1726-1728).
-- The level comes from UnitLevel(unit), whose documentation gives no secret return (UnitDocumentation.lua:2474-2490); a secret
-- or odd answer shows nothing. 0 or less is a unit too high to tell ("??"), as the game's own skull stands for.
-- Nothing is written on a game frame; our font string is a child of the plate's unit frame, so the plate's fading carries over.
----------------------------------------------------------------------
local _, UF = ...
local PL = {}
UF.PlateLevel = PL

local objs = setmetatable({}, { __mode = "k" })   -- plate unit frame -> our level text

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function db()
    local d = UF.DB()
    d.plates = d.plates or {}
    if d.plates.friendlyLevel == nil then d.plates.friendlyLevel = true end
    return d.plates
end

function PL.enabled() return db().friendlyLevel == true end
function PL.toggle()
    local d = db()
    d.friendlyLevel = not d.friendlyLevel
    local N = UF.Nameplates
    if N and N.applyAll then N.applyAll() end
end

-- "37", "??" or nil for a unit whose level cannot be read
function PL.levelText(unit)
    if type(unit) ~= "string" or not UnitLevel then return nil end
    local ok, level = pcall(UnitLevel, unit)
    if not ok then return nil end
    level = plain(level)
    if type(level) ~= "number" then return nil end
    if level <= 0 then return "??" end
    return tostring(level)
end

local function color()
    local c = _G.UNIT_LEVEL_NON_ATTACKABLE
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return 0.75, 0.75, 0.75
end

-- our text on one plate, made once (a factory so the offline test can swap it)
function PL.make(uf)
    if not (uf and CreateFrame) then return nil end
    local okF, holder = pcall(CreateFrame, "Frame", nil, uf)
    if not okF or not holder then return nil end
    local o = { holder = holder }
    o.fs = holder:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
    if uf.name then
        pcall(o.fs.SetPoint, o.fs, "RIGHT", uf.name, "LEFT", -4, 0)
    else
        pcall(o.fs.SetPoint, o.fs, "LEFT", uf, "LEFT", 0, 0)
    end
    pcall(o.fs.SetTextColor, o.fs, color())
    o.fs:Hide()
    return o
end

function PL.piece(uf)
    local o = uf and objs[uf]
    return o or nil
end

function PL.clear(uf)
    local o = uf and objs[uf]
    if o then pcall(o.fs.Hide, o.fs) end
end

-- `wanted`: this plate is one whose level the game hides (a friendly player under the game's name-only setting)
function PL.show(uf, unit, wanted)
    if not uf then return end
    if not (wanted and PL.enabled()) then PL.clear(uf); return end
    local text = PL.levelText(unit)
    if not text then PL.clear(uf); return end
    local o = objs[uf]
    if o == nil then
        o = PL.make(uf) or false
        objs[uf] = o
    end
    if not o then return end
    pcall(o.fs.SetTextColor, o.fs, color())
    pcall(o.fs.SetText, o.fs, text)
    pcall(o.fs.Show, o.fs)
end
