local _, ns = ...

-- Maps controller buttons onto the game's built-in action bars with
-- override bindings (not saved, cleared on reload), and makes two back paddles
-- act as Shift and Ctrl so that each modifier set reaches a different bar.
local Layout = {}
ns.Layout = Layout

local SLOT_COUNT = 12
local EMULATE_SHIFT = "GamePadEmulateShift"
local EMULATE_CTRL = "GamePadEmulateCtrl"

-- WoW APIs (external globals, see Gethe/wow-ui-source)
local C_ActionBar = _G and _G.C_ActionBar  -- nil in offline test; guarded at use site
local GetMultiActionBars = _G and _G.GetMultiActionBars

-- Pad key for each main bar slot, in slot order.
local DEFAULT_SLOTS = {
    "PAD3", "PAD1", "PAD2", "PAD4",
    "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
    "PADRSHOULDER", "PADRTRIGGER", "PADLSHOULDER", "PADLTRIGGER",
}

-- Modifier sets: key prefix, and which bar each set reaches. Bar 1 is the main
-- bar (ACTIONBUTTON); bars 2 to 8 are MULTIACTIONBAR1 to MULTIACTIONBAR7.
local SETS = {
    { prefix = "", label = "none" },
    { prefix = "SHIFT-", label = "Shift" },
    { prefix = "CTRL-", label = "Ctrl" },
    { prefix = "CTRL-SHIFT-", label = "Ctrl+Shift" },
}
local DEFAULT_BARS = { 1, 2, 3, 4 }
local MAX_BAR = 8

-- Buttons outside the 12 bar slots, with the game command each one runs. They
-- are bound in every modifier set, so they work while a paddle is held too.
-- Order is the order they are listed in.
local EXTRA_ORDER = { "PADFORWARD", "PADBACK", "PADLSTICK", "PADPADDLE2", "PADPADDLE4" }
local DEFAULT_EXTRAS = {
    PADFORWARD = "UBFMENU",
    PADBACK = "TOGGLEWORLDMAP",
    PADLSTICK = "TOGGLEAUTORUN",
    PADPADDLE2 = "INTERACTTARGET",
    PADPADDLE4 = "JUMP",
}
-- Commands that can be chosen for an extra button, checked against the game's
-- own binding list. NONE leaves the button unbound.
local EXTRA_COMMANDS = {
    NONE = true, UBFMENU = true, TOGGLEGAMEMENU = true, TOGGLEWORLDMAP = true,
    TOGGLEAUTORUN = true, INTERACTTARGET = true, JUMP = true,
    -- TODO (Phase 07): implement proper multi-slot click bindings.
    -- LEFTCLICK/RIGHTCLICK currently iterate SLOT_COUNT times per modifier set,
    -- leaving only the last slot bound — not useful as-is.
}

-- UBFMENU is Start in steps: close panels, clear the target and stop a cast, then open the menu on
-- the next press. The game's own TOGGLEGAMEMENU is the Esc key, and on a controller its first steps
-- can use up every press so the menu never opens.
local BIND_AS = { UBFMENU = "CLICK UbermocForeverMenu:LeftButton" }

local function bindingFor(command)
    return BIND_AS[command] or command
end

local DEFAULT_SHIFT_BUTTON = "PADPADDLE1"
local DEFAULT_CTRL_BUTTON = "PADPADDLE3"

-- The game binds its pad buttons in the "GamepadModeInGameCore" context
-- (Blizzard_Gamepad/Bindings.xml, Blizzard_GamepadActionBars/Bindings.xml),
-- and action buttons show their hotkey from GetBindingKey(action), which sees
-- global bindings, not frame overrides. So the plain pad key for each main bar
-- slot is also set as a global binding in that context: the button then shows
-- the pad glyph (IsBindingForGamePad / GetBindingText in
-- Blizzard_ActionBar/Shared/ActionButton.lua). The game's own keybinding
-- settings use the same calls to bind and unbind
-- (Blizzard_Settings_Shared/Blizzard_Keybindings.lua):
--   SetBinding(key, action, context) / SetBinding(key, nil, context)
local GAMEPAD_CONTEXT = "GamepadModeInGameCore"

local FRIENDLY = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADDUP = "D-pad up", PADDRIGHT = "D-pad right", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left",
    PADLSHOULDER = "L1", PADRSHOULDER = "R1", PADLTRIGGER = "L2", PADRTRIGGER = "R2",
    PADPADDLE1 = "R4", PADPADDLE2 = "L4", PADPADDLE3 = "R5", PADPADDLE4 = "L5",
    PADFORWARD = "Start", PADBACK = "Select", PADLSTICK = "L3", PADRSTICK = "R3",
}

-- Per-class layout data: ns.LAYOUTS["Class"] populated by Layouts/*/default.lua files.
-- Load() merges the class defaults into db.layout for any field not yet customized,
-- and filters the layout's per-spec spells down to the ones the character knows.
local DEFAULTS_LOADED = false

-- Keep only spells the character knows. C_Spell.GetSpellInfo(spellID) returns
-- nil for spells the character does not have (SpellDocumentation.lua:
-- "Returns nil if spell is not found"; same call in Blizzard_BoostTutorial.lua).
local function knownSpells(list)
    local get = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
    if type(get) ~= "function" then return {} end
    local out = {}
    for _, id in ipairs(list or {}) do
        local ok, info = pcall(get, id)
        if ok and info then out[#out + 1] = id end
    end
    return out
end

-- Current spec ID and name, or nil/nil. Same call Blizzard itself uses
-- (Blizzard_SharedXML/UnitUtil.lua, PlayerUtil.GetCurrentSpecID):
--   GetSpecializationInfo(GetSpecialization()) -> (specId, specName, ...)
-- IMPORTANT (verified in-game, build 70790): the spec ID the live API returns
-- is in the NEW range — an Outlaw Rogue reports 1488, NOT the legacy 259/260/261
-- keys of TrackedCooldownsBySpec. New specs take 1467+ IDs (1480 Devourer DH in
-- TrackedCooldowns.lua) and this branch's Camelot talent data is keyed per-class
-- (1488 Rogue, Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentUtil.lua).
-- So the spec NAME (second return) is the stable identifier: specByName()
-- matches on it, and the numeric key is only a secondary lookup.
local function currentSpec()
    local ok, specID, specName = pcall(function()
        local si = C_SpecializationInfo
        if not (si and si.GetSpecialization and si.GetSpecializationInfo) then return nil, nil end
        local index = si.GetSpecialization()
        if not index then return nil, nil end
        return si.GetSpecializationInfo(index)
    end)
    if not ok then return nil, nil end
    return specID, specName
end

-- Match a layout spec entry by its label (the spec name the game reports),
-- case-insensitive.
local function specByName(specs, name)
    if not name then return nil end
    local target = name:lower()
    for _, def in pairs(specs or {}) do
        if def.label and def.label:lower() == target then return def end
    end
    return nil
end

function Layout.Load(class)
    if not class then return false, "no class" end
    if not ns.db then return false, "db not initialized" end
    if not ns.LAYOUTS then return false, "no layout files loaded" end
    local src = ns.LAYOUTS[class]
    if not src then
        -- Case-insensitive fallback in case the class name differs (localization).
        local lower = class:lower()
        for name, data in pairs(ns.LAYOUTS) do
            if name:lower() == lower then src = data break end
        end
    end
    local c = ns.db.layout or {}
    if src then
        if src.slots then for i = 1, #src.slots do c.slots = c.slots or {}; c.slots[i] = src.slots[i] end end
        if src.extras then for k, v in pairs(src.extras) do if not (c.extras and c.extras[k]) then c.extras = c.extras or {}; c.extras[k] = v end end end
        if src.modifier_sets then for name, def in pairs(src.modifier_sets) do local bs = c.bars_by_name or {}; bs[name] = def; c.bars_by_name = bs end end
        -- Per-spec spells (checkpoint 5): pick the active spec and keep only
        -- spells the character knows, so unverified IDs can never reach a bar.
        if src.specs then
            local specID, specName = currentSpec()
            -- Match by spec name first (this build's live spec IDs are in the
            -- new range, e.g. 1488, not the layout's legacy table keys), then
            -- fall back to the numeric key if it happens to match.
            local def = specByName(src.specs, specName) or (specID and src.specs[specID])
            if not def then
                -- No spec match: use whichever spec the layout defines.
                for _, d in pairs(src.specs) do
                    if def == nil then def = d end
                end
            end
            if def then
                c.show_only_active_bar = src.show_only_active_bar ~= false
                c.spells = {
                    spec_id = specID,
                    spec_label = def.label,
                    primary = knownSpells(def.primary),
                    secondary = knownSpells(def.secondary),
                    tertiary = knownSpells(def.tertiary),
                }
            end
        end
    end
    ns.db.layout = c
    DEFAULTS_LOADED = true
    local spellCount = 0
    if c.spells then
        for _, list in pairs(c.spells) do
            if type(list) == "table" then spellCount = spellCount + #list end
        end
    end
    ns.Log(("layout loaded for %s: %d slots, %d bars, %d known spells (spec %s)"):format(
        class, (c.slots and #c.slots) or 0, (c.bars and #c.bars) or 0,
        spellCount, tostring(c.spells and c.spells.spec_id or "none")))
    return true, class
end

-- Whether class defaults have been applied at least once.
function Layout.DefaultsLoaded()
    return DEFAULTS_LOADED
end

local owner = CreateFrame("Frame")
local pending = false

local function barCommand(bar)
    if bar == 1 then
        return "ACTIONBUTTON"
    end
    return "MULTIACTIONBAR" .. (bar - 1) .. "BUTTON"
end

local function friendly(key)
    return FRIENDLY[key] and (key .. " (" .. FRIENDLY[key] .. ")") or key
end

-- Every pad button name the game defines, read from the game itself.
local function validKeys()
    local keys = {}
    local state = C_GamePad.GetDeviceMappedState()
    local count = state and state.buttonCount or 0
    for index = 0, count - 1 do
        local name = C_GamePad.ButtonIndexToBinding(index)
        if name then
            keys[name] = true
        end
    end
    return keys
end

local function config()
    local db = ns.db
    db.layout = db.layout or {}
    local c = db.layout
    if c.enabled == nil then c.enabled = false end
    c.slots = c.slots or {}
    for slot = 1, SLOT_COUNT do
        c.slots[slot] = c.slots[slot] or DEFAULT_SLOTS[slot]
    end
    c.bars = c.bars or {}
    for set = 1, #SETS do
        c.bars[set] = c.bars[set] or DEFAULT_BARS[set]
    end
    c.extras = c.extras or {}
    for _, key in ipairs(EXTRA_ORDER) do
        c.extras[key] = c.extras[key] or DEFAULT_EXTRAS[key]
    end
    if not c.menuDirect then
        -- Start used to default to the Esc action; the direct menu replaces that default once.
        if c.extras.PADFORWARD == "TOGGLEGAMEMENU" then
            c.extras.PADFORWARD = "UBFMENU"
        end
        c.menuDirect = true
    end
    c.shiftButton = c.shiftButton or DEFAULT_SHIFT_BUTTON
    c.ctrlButton = c.ctrlButton or DEFAULT_CTRL_BUTTON
    return c
end

local function setModifierCVar(name, button, backup, key)
    local current = C_CVar.GetCVar(name)
    if current == nil then
        ns.Log("cvar missing: " .. name)
        return false
    end
    if backup[key] == nil then
        backup[key] = current
    end
    local ok = pcall(C_CVar.SetCVar, name, button)
    if not ok or C_CVar.GetCVar(name) ~= button then
        ns.Log("cvar not accepted: " .. name)
        return false
    end
    return true
end

local function bindAll(c)
    local count = 0
    for set, def in ipairs(SETS) do
        local command = barCommand(c.bars[set])
        for slot = 1, SLOT_COUNT do
            SetOverrideBinding(owner, true, def.prefix .. c.slots[slot], command .. slot)
            count = count + 1
        end
        for _, key in ipairs(EXTRA_ORDER) do
            if c.extras[key] ~= "NONE" then
            -- LEFTCLICK / RIGHTCLICK → click on main action bar
            -- TODO (Phase 07): implement proper multi-slot click bindings.
            if c.extras[key] == "LEFTCLICK" then
                ns.Log("LEFTCLICK binding removed (incomplete — see Phase 07)")
            elseif c.extras[key] == "RIGHTCLICK" then
                ns.Log("RIGHTCLICK binding removed (incomplete — see Phase 07)")
            else
                SetOverrideBinding(owner, true, def.prefix .. key, bindingFor(c.extras[key]))
            end
                count = count + 1
            end
        end
    end
    return count
end

-- Expose every bar's pad keys in the gamepad binding context, so the action
-- buttons' hotkey text can show the pad glyph. This mirrors bindAll exactly
-- (same keys, same actions, same modifier prefixes) — the difference is that
-- these are global context bindings the bar display can read.
local function bindGamepadDisplay(c)
    local count = 0
    for set, def in ipairs(SETS) do
        local command = barCommand(c.bars[set])
        for slot = 1, SLOT_COUNT do
            local key = c.slots[slot]
            if key then
                local ok = pcall(SetBinding, def.prefix .. key, command .. slot, GAMEPAD_CONTEXT)
                if ok then count = count + 1 end
            end
        end
        for _, key in ipairs(EXTRA_ORDER) do
            if c.extras[key] and c.extras[key] ~= "NONE" then
                local ok = pcall(SetBinding, def.prefix .. key, bindingFor(c.extras[key]), GAMEPAD_CONTEXT)
                if ok then count = count + 1 end
            end
        end
    end
    pcall(SaveBindings)
    return count
end

-- Undo bindGamepadDisplay: unbind exactly the keys we bound, in that context.
-- (SetBinding(key, nil, context) is the game's own unbind form —
-- Blizzard_Settings_Shared/Blizzard_Keybindings.lua, ClearBindingsForKeys.)
local function unbindGamepadDisplay(c)
    for _, def in ipairs(SETS) do
        for slot = 1, SLOT_COUNT do
            local key = c.slots[slot]
            if key then pcall(SetBinding, def.prefix .. key, nil, GAMEPAD_CONTEXT) end
        end
        for _, key in ipairs(EXTRA_ORDER) do
            pcall(SetBinding, def.prefix .. key, nil, GAMEPAD_CONTEXT)
        end
    end
    pcall(SaveBindings)
end

-- Returns true if applied, or false and a reason.
function Layout.Apply()
    if InCombatLockdown() then
        pending = true
        return false, "combat"
    end

    -- Don't interfere with Blizzard's stealth bar (page 0).
    -- Rogue enters stealth via MainActionBar page 0; our bindings corrupt it.
    local curPage = (C_ActionBar and C_ActionBar.GetActionBarPage) and C_ActionBar.GetActionBarPage()
    if curPage == 0 then return true, 0 end

    pending = false
    local c = config()
    c.backup = c.backup or {}
    local shiftOk = setModifierCVar(EMULATE_SHIFT, c.shiftButton, c.backup, "shift")
    local ctrlOk = setModifierCVar(EMULATE_CTRL, c.ctrlButton, c.backup, "ctrl")

    -- Phase 6 stealth fix: clear and rebind for ALL visible bar frames,
    -- not just owner/MainActionBar. When a Rogue enters/leaves stealth
    -- Blizzard swaps which action bar frames are visible, so we must
    -- bind each one explicitly to prevent stale/unbound bars.
    ClearOverrideBindings(owner)

    local count = bindAll(c)
    local displayCount = bindGamepadDisplay(c)

    ns.Log(("layout applied: %d bindings, %d pad-display bindings, shift cvar %s, ctrl cvar %s"):format(
        count, displayCount, tostring(shiftOk), tostring(ctrlOk)))
    return true, count, shiftOk, ctrlOk
end

-- Re-apply override bindings to any visible MultiActionBar frames.
-- Call this after Apply() when entering stealth so the new bar frames
-- receive the same bindings as owner/MainActionBar.
function Layout.ApplyToMultiBars()
    -- Enumerate all MultiActionBar frames from Blizzard's caching system.
    local frames = GetMultiActionBars()
    if not frames then return end
    for _, entry in pairs(frames) do
        local bar = entry.bar
        if bar and bar.IsShown and bar:IsShown() then
            local c = config()
            for set, def in ipairs(SETS) do
                local command = barCommand(c.bars[set])
                for slot = 1, SLOT_COUNT do
                    SetOverrideBinding(bar, true, def.prefix .. c.slots[slot], command .. slot)
                end
                for _, key in ipairs(EXTRA_ORDER) do
                    if c.extras[key] ~= "NONE" then
                        SetOverrideBinding(bar, true, def.prefix .. key, bindingFor(c.extras[key]))
                    end
                end
            end
        end
    end
end

-- Removes the bindings and puts the modifier CVars back as they were.
function Layout.Remove()
    if InCombatLockdown() then
        pending = true
        return false, "combat"
    end
    pending = false
    local c = config()
    ClearOverrideBindings(owner)
    unbindGamepadDisplay(c)
    if ns.BarLabels then
        local ok, err = pcall(ns.BarLabels.Remove)
        if not ok then ns.Log("BarLabels.Remove failed: " .. tostring(err)) end
    end
    if c.backup then
        if c.backup.shift ~= nil then pcall(C_CVar.SetCVar, EMULATE_SHIFT, c.backup.shift) end
        if c.backup.ctrl ~= nil then pcall(C_CVar.SetCVar, EMULATE_CTRL, c.backup.ctrl) end
        c.backup = nil
    end
    ns.Log("layout removed")
    return true
end

local function say(key, ...)
    print(ns.L[key]:format(...))
end

function Layout.PrintStatus()
    local c = config()
    say("LAYOUT_STATE", c.enabled and ns.L.YES or ns.L.NO)
    say("LAYOUT_MOD", friendly(c.shiftButton), tostring(C_CVar.GetCVar(EMULATE_SHIFT)),
        friendly(c.ctrlButton), tostring(C_CVar.GetCVar(EMULATE_CTRL)))
    for set, def in ipairs(SETS) do
        local command = barCommand(c.bars[set])
        local ok = 0
        for slot = 1, SLOT_COUNT do
            if GetBindingAction(def.prefix .. c.slots[slot], true) == command .. slot then
                ok = ok + 1
            end
        end
        say("LAYOUT_SET", def.label, c.bars[set], ok, SLOT_COUNT)
    end
    local parts = {}
    for slot = 1, SLOT_COUNT do
        parts[#parts + 1] = slot .. "=" .. (FRIENDLY[c.slots[slot]] or c.slots[slot])
    end
    print(table.concat(parts, ", "))

    local extraOk, extraTotal, names = 0, 0, {}
    for _, key in ipairs(EXTRA_ORDER) do
        local command = c.extras[key]
        names[#names + 1] = (FRIENDLY[key] or key) .. "=" .. command
        if command ~= "NONE" then
            for _, def in ipairs(SETS) do
                extraTotal = extraTotal + 1
                if GetBindingAction(def.prefix .. key, true) == bindingFor(command) then
                    extraOk = extraOk + 1
                end
            end
        end
    end
    say("LAYOUT_EXTRAS", extraOk, extraTotal)
    print(table.concat(names, ", "))
end

local function reapplyIfOn()
    if config().enabled then
        local ok, reason = Layout.Apply()
        if not ok and reason == "combat" then
            say("LAYOUT_PENDING")
        end
    end
end

-- Editing API, used by the slash command and the options window. Each change
-- is applied at once when the layout is on.
Layout.SLOT_COUNT = SLOT_COUNT
Layout.MAX_BAR = MAX_BAR
Layout.SETS = SETS
Layout.EXTRA_ORDER = EXTRA_ORDER
Layout.EXTRA_COMMAND_LIST = { "NONE", "UBFMENU", "TOGGLEGAMEMENU", "TOGGLEWORLDMAP", "TOGGLEAUTORUN", "INTERACTTARGET", "JUMP" }
Layout.PADDLES = { "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }
Layout.Config = config
Layout.Friendly = friendly
Layout.BindingFor = bindingFor
function Layout.CommandName(command)
    return ns.L["CMD_" .. command] or command
end
Layout.ValidKeys = validKeys

-- True when the key is already used by the layout (a bar slot, an other button, or a modifier paddle).
function Layout.UsesKey(key)
    local c = config()
    for slot = 1, SLOT_COUNT do
        if c.slots[slot] == key then
            return true
        end
    end
    return c.extras[key] ~= nil or key == c.shiftButton or key == c.ctrlButton
end

function Layout.SetEnabled(on)
    local c = config()
    c.enabled = on and true or false
    if c.enabled then
        return Layout.Apply()
    end
    return Layout.Remove()
end

-- Returns true, or false and a reason: "invalid", "extra". Binding a key that
-- another slot already uses swaps the two slots.
function Layout.SetSlot(slot, key)
    local c = config()
    if not slot or slot < 1 or slot > SLOT_COUNT or not validKeys()[key] then
        return false, "invalid"
    end
    if c.extras[key] then
        return false, "extra"
    end
    if key == c.shiftButton or key == c.ctrlButton then
        return false, "modifier"
    end
    for other = 1, SLOT_COUNT do
        if other ~= slot and c.slots[other] == key then
            c.slots[other] = c.slots[slot]
        end
    end
    c.slots[slot] = key
    reapplyIfOn()
    return true
end

function Layout.SetBar(set, bar)
    local c = config()
    if not set or set < 1 or set > #SETS or not bar or bar < 1 or bar > MAX_BAR then
        return false
    end
    c.bars[set] = bar
    reapplyIfOn()
    return true
end

function Layout.SetExtra(key, command)
    local c = config()
    if not c.extras[key] or not EXTRA_COMMANDS[command] then
        return false
    end
    c.extras[key] = command
    reapplyIfOn()
    return true
end

-- which is "shift" or "ctrl"; key is one of PADDLES and must differ from the other modifier.
function Layout.SetModifier(which, key)
    local c = config()
    local field = which == "shift" and "shiftButton" or "ctrlButton"
    local otherField = which == "shift" and "ctrlButton" or "shiftButton"
    if not key or c[otherField] == key or not key:match("^PADPADDLE%d$") then
        return false
    end
    c[field] = key
    reapplyIfOn()
    return true
end

function Layout.ResetDefaults()
    local c = config()
    ns.db.layout = { enabled = c.enabled, backup = c.backup }
    config()
    reapplyIfOn()
end

-- /ubf layout <args>
function Layout.Command(args)
    local c = config()
    local word, rest = args:match("^(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "on" then
        c.enabled = true
        local ok, _, shiftOk, ctrlOk = Layout.Apply()
        if not ok then
            say("LAYOUT_PENDING")
        elseif shiftOk and ctrlOk then
            say("LAYOUT_ON")
        else
            say("LAYOUT_ON_NO_MOD")
        end
    elseif word == "off" then
        c.enabled = false
        local ok = Layout.Remove()
        say(ok and "LAYOUT_OFF" or "LAYOUT_PENDING")
    elseif word == "status" then
        Layout.PrintStatus()
    elseif word == "bind" then
        local slot, key = rest:match("^(%d+)%s+(%S+)$")
        slot = tonumber(slot)
        key = key and key:upper()
        local ok, reason = Layout.SetSlot(slot, key)
        if ok then
            say("LAYOUT_BIND_SET", slot, friendly(key))
        elseif reason == "extra" then
            say("LAYOUT_KEY_EXTRA", friendly(key))
        else
            say("LAYOUT_BIND_USAGE", SLOT_COUNT)
        end
    elseif word == "bar" then
        local set, bar = rest:match("^(%d+)%s+(%d+)$")
        set, bar = tonumber(set), tonumber(bar)
        if Layout.SetBar(set, bar) then
            say("LAYOUT_BAR_SET", set, SETS[set].label, bar)
        else
            say("LAYOUT_BAR_USAGE", #SETS, MAX_BAR)
        end
    elseif word == "extra" then
        local key, command = rest:match("^(%S+)%s+(%S+)$")
        if not key then
            for _, extraKey in ipairs(EXTRA_ORDER) do
                print(("%s = %s"):format(friendly(extraKey), c.extras[extraKey]))
            end
            say("LAYOUT_EXTRA_USAGE")
            return
        end
        key, command = key:upper(), command:upper()
        if Layout.SetExtra(key, command) then
            say("LAYOUT_EXTRA_SET", friendly(key), command)
        else
            say("LAYOUT_EXTRA_USAGE")
        end
    elseif word == "reset" then
        Layout.ResetDefaults()
        say("LAYOUT_RESET")
    elseif word == "spells" then
        Layout.PrintSpells()
    else
        say("LAYOUT_HELP")
    end
end

-- /ubf layout spells: the class layout's spell list for the active spec, with
-- the names the game resolves them to (C_Spell.GetSpellInfo).
function Layout.PrintSpells()
    local c = config()
    local s = c.spells
    if not s then
        print("no layout spells loaded (class layout missing, or no matching spec)")
        return
    end
    local nameOf = function(id)
        local ok, info = pcall(function()
            return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        end)
        return ok and info and info.name or ("spell " .. tostring(id))
    end
    print(("layout spells (%s, spec %s):"):format(tostring(s.spec_label), tostring(s.spec_id)))
    for _, bar in ipairs({ "primary", "secondary", "tertiary" }) do
        local list = s[bar] or {}
        local names = {}
        for i, id in ipairs(list) do
            names[#names + 1] = ("%d. %s (%d)"):format(i, nameOf(id), id)
        end
        print(("  %s (%d): %s"):format(bar, #list, (next(list) and table.concat(names, ", ")) or "-"))
    end
end

owner:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        reapplyIfOn()
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        if config().enabled then
            Layout.Apply()
        else
            Layout.Remove()
        end
    end
end)
owner:RegisterEvent("PLAYER_LOGIN")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
