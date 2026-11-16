----------------------------------------------------------------------
-- Ubermoc Forever: hold to aim, release to cast, for ground spells (Heroic Leap, Blizzard, Rain of Fire ...).
-- For each action button that holds a ground spell, our own secure button takes over that button's key: pressing starts
-- the aim as usual, letting go casts the spell at the aim point (the dot from Aim.lua). It is done with the game's own
-- press-and-hold support for secure buttons (attribute typerelease, Blizzard_FrameXML/SecureTemplates.lua). Nothing is
-- written onto the game's action buttons. Set up out of combat only; the keys are given back when it is turned off.
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

local owner = CreateFrame("Frame", "UbermocForeverGroundOwner", UIParent)
local pool = {}
local function button(i)
    if pool[i] then return pool[i] end
    local b = CreateFrame("Button", "UbermocForeverGround" .. i, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")
    -- /ubf ground debug: say what this button receives (our own button, so safe to hook)
    b:HookScript("PreClick", function(self, btn, down)
        if R.debug then
            UF.say("Ground button " .. self:GetName() .. " " .. (down and "DOWN" or "UP") .. " (" .. tostring(btn)
                .. "), aiming: " .. tostring(SpellIsTargeting and SpellIsTargeting()) .. ", spell: " .. tostring(self:GetAttribute("spell")))
        end
    end)
    pool[i] = b
    return b
end

local dirty = false
function R.apply()
    if InCombatLockdown() then dirty = true; return end
    dirty = false
    ClearOverrideBindings(owner)
    for _, b in pairs(pool) do
        b:SetAttribute("type", nil); b:SetAttribute("spell", nil); b:SetAttribute("typerelease", nil)
        b:SetAttribute("macrotext", nil); b:SetAttribute("pressAndHoldAction", nil)
    end
    if not cfg().on then return end
    local n = 0
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local f = _G[bar[1] .. i]
            local name = f and R.groundSpellOf(f.action)
            if name then
                local keys = { GetBindingKey(bar[2] .. i) }
                for _, k in ipairs({ GetBindingKey("CLICK " .. bar[1] .. i .. ":LeftButton") }) do keys[#keys + 1] = k end   -- the game also reads these
                for _, key in ipairs(keys) do
                    if key and key ~= "" then
                        n = n + 1
                        local b = button(n)
                        b:SetAttribute("pressAndHoldAction", true)
                        b:SetAttribute("type", "spell")                 -- pressing: starts the aim, as the bar button does
                        b:SetAttribute("spell", name)
                        b:SetAttribute("typerelease", "macro")          -- letting go: casts it at the aim point
                        b:SetAttribute("macrotext", "/stopspelltarget\n/cast [@cursor] " .. name)
                        SetOverrideBindingClick(owner, false, key, b:GetName(), "LeftButton")
                    end
                end
            end
        end
    end
    R.count = n
end

-- /ubf ground: what is set up, and which key a bound spell's key now goes to.
function R.report()
    local lines = {}
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local f = _G[bar[1] .. i]
            local name = f and R.groundSpellOf(f.action)
            if name then
                local keys = { GetBindingKey(bar[2] .. i) }
                for _, key in ipairs(keys) do
                    if key and key ~= "" then
                        lines[#lines + 1] = name .. " on " .. bar[2] .. i .. ", key " .. key .. " goes to: " .. tostring(GetBindingAction(key))
                    end
                end
                if #keys == 0 then lines[#lines + 1] = name .. " on " .. bar[2] .. i .. " has no key" end
            end
        end
    end
    UF.say("Release to cast is " .. (cfg().on and "on" or "off") .. ", buttons set up: " .. tostring(R.count or 0)
        .. ". Press and hold setting: " .. tostring(GetCVar and GetCVar("ActionButtonUseKeyHeldSpell")))
    if #lines == 0 then
        UF.say("No ground spell with a key was found on your action bars.")
        -- what the bars hold, so a missing spell can be added by name
        local frames, spells = 0, {}
        for _, bar in ipairs(BARS) do
            for i = 1, 12 do
                local f = _G[bar[1] .. i]
                if f then
                    frames = frames + 1
                    local ok, t, id = pcall(GetActionInfo, f.action)
                    if ok and t == "spell" and type(id) == "number" then spells[#spells + 1] = (spellName(id) or "?") .. " (" .. id .. ")" end
                end
            end
        end
        UF.say("Bar buttons found: " .. frames .. ". Spells on them: " .. (#spells > 0 and table.concat(spells, ", ") or "none read") .. ".")
        UF.say("If your ground spell is in that list, add it: /ubf ground add Spell Name")
    end
    for _, l in ipairs(lines) do UF.say(l) end
    local names = {}
    for id, n in pairs(cfg().learned) do names[#names + 1] = n .. " (" .. id .. ")" end
    UF.say("Ground spells learned so far: " .. (#names > 0 and table.concat(names, ", ") or "none yet") .. ".")
    UF.say("To watch presses and releases type /ubf ground debug, then try a spell.")
end
function R.setDebug(on) R.debug = on; UF.say("Ground spell debug is " .. (on and "on." or "off.")) end

-- Learning: while the game is waiting for a ground spot, the button of the spell that started it is the game's
-- "current action". That spell is remembered, so nobody has to add their spells by hand.
function R.learnScan()
    local isCurrent = (C_ActionBar and C_ActionBar.IsCurrentAction) or IsCurrentAction   -- the game's own button state uses C_ActionBar
    if not (SpellIsTargeting and SpellIsTargeting()) or not isCurrent then return nil end
    for slot = 1, 180 do
        local okc, cur = pcall(isCurrent, slot)
        if okc and cur then
            local ok, t, id = pcall(GetActionInfo, slot)
            if ok and t == "spell" and type(id) == "number" then
                local d = cfg()
                if not (GROUND_IDS[id] or d.learned[id]) then
                    local name = spellName(id)
                    if name then
                        d.learned[id] = name
                        return name
                    end
                end
                return nil
            end
        end
    end
end

do
    local seen, tries, acc = false, 0, 0
    local drv = CreateFrame("Frame")
    drv:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        if SpellIsTargeting and SpellIsTargeting() then
            if not seen then seen, tries = true, 0 end
            if tries < 8 then
                tries = tries + 1
                local name = R.learnScan()
                if name then
                    tries = 8
                    UF.say(name .. " is a ground spell: from now on hold its button to aim and let go to cast.")
                    if InCombatLockdown() then R.dirtyAfterCombat() else R.apply() end
                end
            end
        else
            seen = false
        end
    end)
end

local queued
local function soon()
    if queued then return end
    queued = true
    C_Timer.After(0.4, function() queued = false; R.apply() end)
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

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "SPELLS_CHANGED", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_ENABLED" then if dirty then soon() end else soon() end
end)
UF.OnLogin(function() soon() end)
