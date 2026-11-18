----------------------------------------------------------------------
-- Ubermoc Forever: how far away nameplates show (UF.PlateRange)
--
-- The distance is a game setting we can only reach through a CVar: nameplateMaxDistance (units, default
-- 45.000000 yards from the camera) and nameplatePlayerMaxDistance (players, default 40.000000). The game's
-- options window has no row for them, so SetCVar is the only way, as Nameplates.lua and Cinematic.lua already
-- do for other nameplate settings. Our code may write them: SetCVar takes cvars that are not read only and
-- not secure (CVarDocumentation.lua:131-148, claim C1), and GetCVarInfo flags nameplateMaxDistance as a
-- character cvar, not secure (ForeverPlusPlus docs/forever-api.md:207, claim C3); the defaults are from
-- Ketho's Forever cvar dump (claim C2). Values are strings, so we write tostring.
-- Quality of life page, under Nameplates: "Plate range: Off/On" and "Plate distance" (30, 45 or 60 yards; no
-- values above 60 are offered, nothing checked here shows the game keeps them). On writes the number, Off gives back the value the
-- player had before we first wrote it. Nothing is written during combat and what waits is applied when the
-- fight ends, as in Nameplates.lua. Untested in the game.
-- Notes: docs/RESEARCH-NAVIGATION.md, "Nameplate distance (1.3.120)".
----------------------------------------------------------------------
local _, UF = ...
local PR = {}
UF.PlateRange = PR

PR.CVARS = { "nameplateMaxDistance", "nameplatePlayerMaxDistance" }
PR.STEPS = { 30, 45, 60 }
PR.pending = false

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function db()
    local d = UF.DB()
    d.platerange = d.platerange or {}
    local p = d.platerange
    if p.on == nil then p.on = false end
    if p.step == nil then p.step = 3 end          -- 60 yards
    if p.backup == nil then p.backup = {} end
    return p
end
PR.db = db

function PR.enabled() return db().on == true end
function PR.name() return tostring(PR.STEPS[db().step]) end

-- one cvar: remember the player's value the first time we write, give it back when Off, write the number when On
local function one(p, cvar)
    local value
    if p.on then
        if p.backup[cvar] == nil then
            local ok, was = pcall(GetCVar, cvar)
            was = ok and plain(was) or nil
            if type(was) ~= "string" then return end   -- cannot read it: nothing is remembered, nothing written
            p.backup[cvar] = was
        end
        value = tostring(PR.STEPS[p.step])
    elseif p.backup[cvar] ~= nil then
        value = p.backup[cvar]
        p.backup[cvar] = nil
    end
    if value ~= nil then pcall(SetCVar, cvar, value) end
end

function PR.sync()
    if InCombatLockdown and InCombatLockdown() then PR.pending = true; return end
    local p = db()
    for _, cvar in ipairs(PR.CVARS) do one(p, cvar) end
    PR.pending = false
end

function PR.toggle()
    local p = db()
    p.on = not PR.enabled()
    PR.sync()
end

function PR.nextYards(dir)
    local p = db()
    p.step = UF.stepIndex(p.step, #PR.STEPS, dir)
    if p.on then PR.sync() end
end

local f = CreateFrame("Frame")
PR._frame = f   -- for the offline test
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if PR.pending then PR.sync() end
        return
    end
    if PR.enabled() then PR.sync() end   -- login: the player's values are remembered again and the number rewritten
end)
