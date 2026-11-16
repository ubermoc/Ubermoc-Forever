----------------------------------------------------------------------
-- Ubermoc Forever: hold to aim, release to cast, for ground spells (Heroic Leap, Blizzard, Rain of Fire ...).
-- Pressing a ground spell's action button starts the aim as usual; letting go casts the spell at the aim point (the dot
-- from Aim.lua). The game runs the attribute "typerelease" of a button on key release when "Press and Hold Casting" is on
-- (Blizzard_FrameXML/SecureTemplates.lua), and gives it only to empower spells, so ground spells' buttons are given one
-- here (macro: /stopspelltarget, /cast [@cursor] Spell). This is the method UbermocUI uses, which works in this game.
-- Which spells are ground spells: a built-in list, plus every spell whose button starts an aim (learned by itself).
-- Attributes are set out of combat only. Nothing is stored on the game's buttons (our own tables remember them).
-- Notes: docs/RESEARCH-GROUND-SPELLS.md. Not tested in the game until the user reports.
----------------------------------------------------------------------
local ADDON, UF = ...
local R = {}
UF.GroundCast = R

-- Ground spells by spell ID (so any game language works). Taken from the list UbermocUI uses; whether each exists in this
-- game is not verified. Add or remove by name with /ubf ground add Spell Name, /ubf ground remove Spell Name.
local GROUND_IDS = {
    [6544] = true, [190356] = true, [2120] = true, [153561] = true, [113724] = true, [5740] = true, [30283] = true,
    [152108] = true, [1122] = true, [111771] = true, [43265] = true, [152280] = true, [51052] = true, [191427] = true,
    [61882] = true, [73920] = true, [32375] = true, [62618] = true, [34861] = true, [102793] = true, [114158] = true,
    [116844] = true, [115315] = true, [115313] = true, [1543] = true, [370665] = true, [358385] = true, [403631] = true,
}
-- Action bar button frames and the key binding names they use.
local BARS = {
    { "ActionButton", "ACTIONBUTTON" }, { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" }, { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" }, { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" },
    { "MultiBar6Button", "MULTIACTIONBAR6BUTTON" }, { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" },
}

local function cfg()
    local d = UF.DB()
    d.ground = d.ground or {}
    if d.ground.on == nil then d.ground.on = true end
    d.ground.extra = d.ground.extra or {}
    d.ground.learned = d.ground.learned or {}   -- spell id -> name, found by watching the game start an aim
    return d.ground
end
function R.enabled() return cfg().on end

local function spellName(id)
    local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end)
    return ok and type(n) == "string" and n or nil
end

-- The spell's name when this action slot holds a ground spell, else nil.
function R.groundSpellOf(slot)
    if not slot then return nil end
    local ok, t, id = pcall(GetActionInfo, slot)
    if not ok or t ~= "spell" or type(id) ~= "number" then return nil end
    local name = spellName(id)
    if not name then return nil end
    local extra = cfg().extra
    local lname = name:lower()
    if GROUND_IDS[id] or cfg().learned[id] then return name end
    for _, n in ipairs(extra) do if n:lower() == lname then return name end end
    local okb, base = pcall(function() return C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(id) end)
    if okb and type(base) == "number" and base ~= id then
        if GROUND_IDS[base] or cfg().learned[base] then return name end
        local bn = spellName(base)
        if bn then for _, n in ipairs(extra) do if n:lower() == bn:lower() then return name end end end
    end
    return nil
end

local groundBtn = {}   -- bar button -> true while it carries the release action (kept here, not on the game's button)
local watched = {}     -- bar button -> true once its press is watched for learning

local dirty = false
local function learnFrom(b)
    local slot = b.action
    if not slot then return end
    local ok, t, id = pcall(GetActionInfo, slot)
    if not ok or t ~= "spell" or type(id) ~= "number" then return end
    if R.groundSpellOf(slot) then return end
    local name = spellName(id)
    if not name then return end
    cfg().learned[id] = name
    UF.say(name .. " starts an aim, so it is now a ground spell: hold its button to aim and let go to cast.")
    if InCombatLockdown() then dirty = true else R.apply() end
end
R.learnFrom = learnFrom

-- Watch a bar button's press: a spell that is not known but starts an aim a moment later is a ground spell.
local function watch(b)
    if watched[b] then return end
    watched[b] = true
    b:HookScript("PreClick", function(self, btn, down)
        if R.debug then
            UF.say("Button " .. tostring(self:GetName()) .. " " .. (down and "DOWN" or "UP") .. ", aiming: " .. tostring(SpellIsTargeting and SpellIsTargeting())
                .. ", ground button: " .. tostring(groundBtn[self] == true))
        end
        if groundBtn[self] or not cfg().on then return end
        if SpellIsTargeting and SpellIsTargeting() then return end   -- an aim was already open
        C_Timer.After(0.1, function()
            if SpellIsTargeting and SpellIsTargeting() then learnFrom(self) end
        end)
    end)
end

-- The game's own settings that make the release count; saved first, put back when this is turned off.
local function holdSettings(on)
    local d = UF.DB()
    local function get(c) local f = (C_CVar and C_CVar.GetCVar) or GetCVar; return f and f(c) end
    local function set(c, v) local f = (C_CVar and C_CVar.SetCVar) or SetCVar; return f(c, v) end
    d.groundBackup = d.groundBackup or {}
    for _, c in ipairs({ "ActionButtonUseKeyDown", "ActionButtonUseKeyHeldSpell" }) do
        local cur = get(c)
        if cur ~= nil then
            if on then
                if d.groundBackup[c] == nil then d.groundBackup[c] = cur end
                if cur ~= "1" then pcall(set, c, "1") end
            elseif d.groundBackup[c] ~= nil then
                pcall(set, c, d.groundBackup[c]); d.groundBackup[c] = nil
            end
        end
    end
end

function R.apply()
    if InCombatLockdown() then dirty = true; return end
    dirty = false
    local on = cfg().on
    holdSettings(on)
    local n = 0
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[bar[1] .. i]
            if b and b.SetAttribute and not (b.IsForbidden and b:IsForbidden()) then
                if on then watch(b) end
                local name = on and R.groundSpellOf(b.action) or nil
                if name then
                    b:SetAttribute("typerelease", "macro")
                    b:SetAttribute("macrotext", "/stopspelltarget\n/cast [@cursor] " .. name)
                    groundBtn[b] = true
                    n = n + 1
                elseif groundBtn[b] then
                    b:SetAttribute("typerelease", nil)
                    b:SetAttribute("macrotext", nil)
                    groundBtn[b] = nil
                end
            end
        end
    end
    R.count = n
end

function R.dirtyAfterCombat() dirty = true end
function R.toggle() local c = cfg(); c.on = not c.on; R.apply() end

function R.addName(name, remove)
    local extra = cfg().extra
    for i = #extra, 1, -1 do if extra[i]:lower() == name:lower() then table.remove(extra, i) end end
    if not remove then extra[#extra + 1] = name end
    R.apply()
    UF.say(name .. (remove and " is no longer a ground spell." or " is now a ground spell (hold to aim, release to cast)."))
end

-- /ubf ground: what is set up.
function R.report()
    local lines = {}
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[bar[1] .. i]
            if b and groundBtn[b] then lines[#lines + 1] = bar[1] .. i .. ": " .. tostring(R.groundSpellOf(b.action)) end
        end
    end
    UF.say("Release to cast is " .. (cfg().on and "on" or "off") .. ", buttons set up: " .. tostring(R.count or 0)
        .. ". Press and hold setting: " .. tostring(GetCVar and GetCVar("ActionButtonUseKeyHeldSpell")))
    for _, l in ipairs(lines) do UF.say(l) end
    local names = {}
    for id, n in pairs(cfg().learned) do names[#names + 1] = n .. " (" .. id .. ")" end
    UF.say("Ground spells learned so far: " .. (#names > 0 and table.concat(names, ", ") or "none yet") .. ".")
    UF.say("To watch presses and releases type /ubf ground debug, then try a spell.")
end
function R.setDebug(on) R.debug = on; UF.say("Ground spell debug is " .. (on and "on." or "off.")) end

local queued
local function soon()
    if queued then return end
    queued = true
    C_Timer.After(0.4, function() queued = false; R.apply() end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_ENABLED" then if dirty then soon() end else soon() end
end)
UF.OnLogin(function() C_Timer.After(3, function() R.apply() end) end)
