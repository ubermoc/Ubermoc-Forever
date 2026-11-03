local _, ns = ...

-- Maps controller buttons onto the game's built-in action bars with
-- override bindings (not saved, cleared on reload), and makes two back paddles
-- act as Shift and Ctrl so that each modifier set reaches a different bar.
local Layout = {}
ns.Layout = Layout

local SLOT_COUNT = 12
local EMULATE_SHIFT = "GamePadEmulateShift"
local EMULATE_CTRL = "GamePadEmulateCtrl"

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

local DEFAULT_SHIFT_BUTTON = "PADPADDLE1"
local DEFAULT_CTRL_BUTTON = "PADPADDLE3"

local FRIENDLY = {
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
    PADDUP = "D-pad up", PADDRIGHT = "D-pad right", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left",
    PADLSHOULDER = "L1", PADRSHOULDER = "R1", PADLTRIGGER = "L2", PADRTRIGGER = "R2",
    PADPADDLE1 = "R4", PADPADDLE3 = "R5",
}

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
    if not ok then
        ns.Log("cvar rejected: " .. name)
    end
    return ok
end

local function bindAll(c)
    local count = 0
    for set, def in ipairs(SETS) do
        local command = barCommand(c.bars[set])
        for slot = 1, SLOT_COUNT do
            SetOverrideBinding(owner, true, def.prefix .. c.slots[slot], command .. slot)
            count = count + 1
        end
    end
    return count
end

-- Returns true if applied, or false and a reason.
function Layout.Apply()
    if InCombatLockdown() then
        pending = true
        return false, "combat"
    end
    pending = false
    local c = config()
    c.backup = c.backup or {}
    local shiftOk = setModifierCVar(EMULATE_SHIFT, c.shiftButton, c.backup, "shift")
    local ctrlOk = setModifierCVar(EMULATE_CTRL, c.ctrlButton, c.backup, "ctrl")
    ClearOverrideBindings(owner)
    local count = bindAll(c)
    ns.Log(("layout applied: %d bindings, shift cvar %s, ctrl cvar %s"):format(
        count, tostring(shiftOk), tostring(ctrlOk)))
    return true, count, shiftOk, ctrlOk
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
end

local function reapplyIfOn()
    if config().enabled then
        local ok, reason = Layout.Apply()
        if not ok and reason == "combat" then
            say("LAYOUT_PENDING")
        end
    end
end

-- /ubf layout <args>
function Layout.Command(args)
    local c = config()
    local word, rest = args:match("^(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "on" then
        c.enabled = true
        local ok, reason = Layout.Apply()
        say(ok and "LAYOUT_ON" or "LAYOUT_PENDING", reason)
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
        if not slot or slot < 1 or slot > SLOT_COUNT or not validKeys()[key] then
            say("LAYOUT_BIND_USAGE", SLOT_COUNT)
            return
        end
        for other = 1, SLOT_COUNT do
            if other ~= slot and c.slots[other] == key then
                say("LAYOUT_BIND_TAKEN", key, other)
                return
            end
        end
        c.slots[slot] = key
        say("LAYOUT_BIND_SET", slot, friendly(key))
        reapplyIfOn()
    elseif word == "bar" then
        local set, bar = rest:match("^(%d+)%s+(%d+)$")
        set, bar = tonumber(set), tonumber(bar)
        if not set or set < 1 or set > #SETS or not bar or bar < 1 or bar > MAX_BAR then
            say("LAYOUT_BAR_USAGE", #SETS, MAX_BAR)
            return
        end
        c.bars[set] = bar
        say("LAYOUT_BAR_SET", set, SETS[set].label, bar)
        reapplyIfOn()
    elseif word == "reset" then
        local wasOn = c.enabled
        ns.db.layout = { enabled = wasOn, backup = c.backup }
        say("LAYOUT_RESET")
        reapplyIfOn()
    else
        say("LAYOUT_HELP")
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
