----------------------------------------------------------------------
-- Ubermoc Forever: default key binds
-- The same layout and order as Ubermoc UI. Four layers: nothing held, the Shift button held, the Ctrl button
-- held, and both held. Each layer fills one of the first four action bars with the buttons below, in order.
-- Right bumper targets the nearest enemy and left bumper the nearest friend, on every layer.
-- A Steam Controller / Steam Deck holds R4 for Shift and R5 for Ctrl; every other controller holds the left
-- trigger for Shift and the right trigger for Ctrl.
-- Interact and jump are on L4 / L5 (or the stick clicks on a controller without back buttons).
-- Start alone is Exit: the game's own Escape (it is not a bind, so Start has no bind and the game's Escape setting
-- points at it). Select is the map, and auto-run is the left stick click (Shift + left stick click on controllers whose
-- left stick click interacts).
----------------------------------------------------------------------
local _, UF = ...

local LAYERS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }
UF.LAYERS = LAYERS
local MAIN_BARS = { "ACTIONBUTTON", "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON", "MULTIACTIONBAR3BUTTON" }

-- X, A, B, Y, D-pad left / down / right / up, R1, R2, L1, L2
local STEAM_SLOTS = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
                      "PADRSHOULDER", "PADRTRIGGER", "PADLSHOULDER", "PADLTRIGGER" }
local STEAM_SPILL = { "PADRSTICK" }
-- The triggers are the modifiers on every other controller, so they carry no actions there.
local PAD_SLOTS = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
                    "PADRSHOULDER", "PADLSHOULDER" }
local PAD_SPILL = {}
local STEAM_INTERACT, STEAM_JUMP = { "F6" }, { "SPACE", "PADPADDLE4" }
local PAD_INTERACT, PAD_JUMP = { "PADLSTICK" }, { "PADRSTICK" }
local TARGET = { PADRSHOULDER = "TARGETNEARESTENEMY", PADLSHOULDER = "TARGETNEARESTFRIEND" }

-- The order the buttons are listed in the options.
UF.PAD_ORDER = { "PAD3", "PAD1", "PAD2", "PAD4", "PADDLEFT", "PADDDOWN", "PADDRIGHT", "PADDUP",
                 "PADRSHOULDER", "PADLSHOULDER", "PADRTRIGGER", "PADLTRIGGER", "PADLSTICK", "PADRSTICK",
                 "PADFORWARD", "PADBACK", "PADPADDLE2", "PADPADDLE4" }

local function isPadKey(key)
    local base = key:match("([^-]+)$")
    return base ~= nil and base:find("^PAD") ~= nil
end

local function save()
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
end
UF.saveBinds = save

local function clearPadBinds()
    local keys = {}
    for i = 1, GetNumBindings() do
        local t = { GetBinding(i) }
        for j = 3, #t do
            if type(t[j]) == "string" and isPadKey(t[j]) then keys[#keys + 1] = t[j] end
        end
    end
    for _, k in ipairs(keys) do SetBinding(k) end
end

local function bindLayers(slots, spill)
    local n = 0
    for li, layer in ipairs(LAYERS) do
        for key, cmd in pairs(TARGET) do SetBinding(layer .. key, cmd) end
        for i, key in ipairs(slots) do
            if not TARGET[key] then SetBinding(layer .. key, MAIN_BARS[li] .. i) end
        end
        for _, key in ipairs(spill) do
            n = n + 1
            SetBinding(layer .. key, "MULTIACTIONBAR" .. (3 + math.ceil(n / 12)) .. "BUTTON" .. ((n - 1) % 12 + 1))
        end
    end
end

local function bindRoles(interact, jump)
    for _, layer in ipairs(LAYERS) do
        for _, key in ipairs(interact) do SetBinding(layer .. key, "INTERACTTARGET") end
        for _, key in ipairs(jump) do SetBinding(layer .. key, "JUMP") end
    end
end

local function bindSystem(steam)
    -- Start is Exit, the game's own Escape: no bind on it, and the game's Escape setting points at it.
    SetBinding("PADFORWARD")
    pcall(SetCVar, "GamePadEmulateEsc", "PADFORWARD")
    SetBinding("PADBACK", "TOGGLEWORLDMAP")
    SetBinding(steam and "PADLSTICK" or "SHIFT-PADLSTICK", "TOGGLEAUTORUN")
end

local function setModifiers(shift, ctrl)
    pcall(SetCVar, "GamePadEmulateShift", shift)
    pcall(SetCVar, "GamePadEmulateCtrl", ctrl)
    pcall(SetCVar, "GamePadEmulateAlt", "NONE")
end

local function enablePad()
    local ok, v = pcall(GetCVar, "GamePadEnable")
    if ok and v ~= "1" then pcall(SetCVar, "GamePadEnable", "1") end
end

-- Removes every controller bind, then sets the default layout for the controller kind.
-- Returns true when it was applied. Never runs in combat (the game blocks binding changes there).
function UF.applyDefaults(setId)
    if InCombatLockdown() then UF.say("Controller binds can't be set in combat."); return false end
    setId = setId or UF.activeSet()
    local steam = setId == "steam"
    enablePad()
    clearPadBinds()
    if steam then
        setModifiers("PADPADDLE1", "PADPADDLE3")
        for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do SetBinding(k) end
        bindLayers(STEAM_SLOTS, STEAM_SPILL)
        bindRoles(STEAM_INTERACT, STEAM_JUMP)
    else
        setModifiers("PADLTRIGGER", "PADRTRIGGER")
        bindLayers(PAD_SLOTS, PAD_SPILL)
        bindRoles(PAD_INTERACT, PAD_JUMP)
    end
    bindSystem(steam)
    save()
    local g = UF.guid()
    if g then UF.DB().applied[g] = steam and "steam" or "standard" end
    return true
end

-- The key a layer and button make, e.g. "SHIFT-PAD1".
function UF.combo(layerIndex, pad) return LAYERS[layerIndex] .. pad end

function UF.actionOf(combo)
    local a = GetBindingAction(combo)
    if a == nil or a == "" then return nil end
    return a
end

-- Plain names for binds that would otherwise show as a code.
local FRIENDLY = {
    ["CLICK UbermocMenu:LeftButton"] = "Game menu (Start)",   -- Ubermoc UI's Start button
}

-- The game's own name for an action ("Action Button 1", "Jump", ...), else a plain version of the action's code.
function UF.actionName(cmd)
    if not cmd then return nil end
    if FRIENDLY[cmd] then return FRIENDLY[cmd] end
    local n = _G["BINDING_NAME_" .. cmd]
    if type(n) == "string" and n ~= "" then return n end
    local kind, rest = cmd:match("^(%u+) (.+)$")
    if kind == "SPELL" or kind == "MACRO" or kind == "ITEM" then return rest end
    if kind == "CLICK" then
        -- "CLICK SomeButton:LeftButton" is a press of a button an addon made
        local frame = rest:match("^([^:]+)")
        return "Press: " .. (frame or rest)
    end
    return cmd
end

-- The Exit option. The game can make one controller button its Escape (the setting GamePadEmulateEsc holds that
-- button's name, or NONE). It is not a key bind, so it needs its own handling. What is seen in the game: on a layer
-- where that button has no bind of its own, pressing it acts as Escape (closes windows, clears the target, stops a
-- cast, then opens the game menu), so a row for that button that has no bind is shown as Exit (Escape). Choosing Exit
-- for a button makes it the game's Escape button and removes the bind on that layer; clearing an Exit row turns the
-- Escape button off. Binding something to a layer takes Escape away on that layer only.
function UF.exitButton()
    local ok, v = pcall(GetCVar, "GamePadEmulateEsc")
    if ok and type(v) == "string" and v:find("^PAD") then return v end
    return nil
end

function UF.setExit(pad, combo)
    if InCombatLockdown() then UF.say("Binds can't be changed in combat."); return false end
    pcall(SetCVar, "GamePadEmulateEsc", pad)
    SetBinding(combo or pad)
    save()
    return true
end

-- Turn the game's Escape button off.
function UF.clearExit()
    if InCombatLockdown() then UF.say("Binds can't be changed in combat."); return false end
    pcall(SetCVar, "GamePadEmulateEsc", "NONE")
    return true
end

-- True when a row (a layer and a button) is the game's Escape: that button is its Escape button and nothing is bound there.
function UF.isExitRow(combo, pad)
    return UF.exitButton() == pad and UF.actionOf(combo) == nil
end

function UF.setBind(combo, cmd)
    if InCombatLockdown() then UF.say("Binds can't be changed in combat."); return false end
    if cmd then SetBinding(combo, cmd) else SetBinding(combo) end
    save()
    return true
end

-- True for the buttons that are standing in for Shift / Ctrl, so they cannot carry an action themselves.
function UF.isModifierButton(pad)
    local ok1, s = pcall(GetCVar, "GamePadEmulateShift")
    local ok2, c = pcall(GetCVar, "GamePadEmulateCtrl")
    return (ok1 and s == pad) or (ok2 and c == pad)
end
