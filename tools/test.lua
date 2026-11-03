-- Offline smoke test: loads the addon files against stubbed WoW APIs.
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local handlers = {}
local function proxy()
    return setmetatable({}, { __index = function(t) return t end, __call = function(t) return t end })
end
UIParent = {}
UISpecialFrames = {}
function CreateFrame(_, name)
    local f = setmetatable({ events = {}, scripts = {}, name = name, shown = false },
        { __index = function() return proxy() end })
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(kind, fn)
        self.scripts[kind] = fn
        if kind == "OnEvent" then self.fn = fn elseif kind == "OnUpdate" then self.onUpdate = fn end
    end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    handlers[#handlers + 1] = f
    return f
end
function GetBuildInfo() return "1.60.1", "70707", "x", 16001 end
function GetTime() return 1 end
function date() return "2026-01-01 00:00:00" end
C_Texture = { GetAtlasInfo = function(a) if a:find("xbox") then return {} end end }
function geterrorhandler() return function() end end
function seterrorhandler() end
C_AddOns = { GetAddOnMetadata = function() return "test" end, IsAddOnLoaded = function() return false end }
SlashCmdList = {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADLSHOULDER" }
C_CVar = {
    GetCVar = function(n) return cvars[n] end,
    SetCVar = function(n, v) assert(cvars[n] ~= nil, "unknown cvar") cvars[n] = v end,
}
local inCombat = false
function InCombatLockdown() return inCombat end
local bindings = {}
function SetOverrideBinding(_, _, key, command) bindings[key] = command end
function ClearOverrideBindings() bindings = {} end
function GetBindingAction(key) return bindings[key] or "" end
C_GamePad = {
    IsEnabled = function() return true end,
    GetActiveDeviceID = function() return 2 end,
    GetCombinedDeviceID = function() return 99 end,
    GetAllDeviceIDs = function() return { 2, 99 } end,
    GetDeviceMappedState = function(id)
        return { name = "Pad" .. (id or "active"), labelStyle = "Generic", buttonCount = 32, axisCount = 2, stickCount = 1,
            buttons = { false, true, false }, axes = { 0, 0.5 }, sticks = { { x = 0.5, y = 0, len = 0.5 } } }
    end,
    ButtonIndexToBinding = function(i)
        local names = { [0] = "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
            "PADLSTICK", "PADRSTICK", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
            "PADLSTICKUP", "PADLSTICKRIGHT", "PADLSTICKDOWN", "PADLSTICKLEFT",
            "PADRSTICKUP", "PADRSTICKRIGHT", "PADRSTICKDOWN", "PADRSTICKLEFT",
            "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PADFORWARD", "PADBACK", "PADSYSTEM", "PADSOCIAL" }
        return names[i] or ("PADX" .. i)
    end,
    AxisIndexToConfigName = function(i) return "Axis" .. i end,
    StickIndexToConfigName = function(i) return "Stick" .. i end,
    GetDeviceRawState = function() return { name = "raw", vendorID = 1118, productID = 654 } end,
}

local ns = {}
for _, f in ipairs({ "Locales/enUS.lua", "Core/Init.lua", "Core/Compat.lua", "Core/Debug.lua", "Core/SelfTest.lua", "Input/GamePad.lua", "Input/PadTest.lua", "Input/Layout.lua", "UI/Options.lua" }) do
    assert(loadfile(f))("UbermocForever", ns)
end
local function fire(event, arg)
    for _, h in ipairs(handlers) do
        if h.events[event] and h.fn then h.fn(h, event, arg) end
    end
end
fire("ADDON_LOADED", "UbermocForever")
fire("PLAYER_LOGIN")
fire("GAME_PAD_CONNECTED")
SlashCmdList["UBERMOCFOREVER"]("pad")
SlashCmdList["UBERMOCFOREVER"]("debug")
SlashCmdList["UBERMOCFOREVER"]("log")
SlashCmdList["UBERMOCFOREVER"]("padtest")
SlashCmdList["UBERMOCFOREVER"]("padmap")
for _, h in ipairs(handlers) do
    if h.onUpdate then h.onUpdate(h, 1) end
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local layout = ns.Layout

-- layout is off until enabled
assert(count(bindings) == 0, "layout starts off")
layout.Command("on")
assert(count(bindings) == 68, "68 bindings, got " .. count(bindings))
assert(bindings["PAD3"] == "ACTIONBUTTON1", "X is slot 1")
assert(bindings["PAD1"] == "ACTIONBUTTON2", "A is slot 2")
assert(bindings["PADLTRIGGER"] == "ACTIONBUTTON12", "L2 is slot 12")
assert(bindings["SHIFT-PAD3"] == "MULTIACTIONBAR1BUTTON1", "shift set is bar 2")
assert(bindings["CTRL-PAD3"] == "MULTIACTIONBAR2BUTTON1", "ctrl set is bar 3")
assert(bindings["CTRL-SHIFT-PADDUP"] == "MULTIACTIONBAR3BUTTON8", "both set is bar 4")
assert(cvars.GamePadEmulateShift == "PADPADDLE1" and cvars.GamePadEmulateCtrl == "PADPADDLE3", "paddles emulate modifiers")

assert(bindings["PADFORWARD"] == "TOGGLEGAMEMENU", "Start opens the game menu")
assert(bindings["PADBACK"] == "TOGGLEWORLDMAP", "Select opens the map")
assert(bindings["PADLSTICK"] == "TOGGLEAUTORUN", "L3 auto-runs")
assert(bindings["PADPADDLE2"] == "INTERACTTARGET", "L4 interacts")
assert(bindings["PADPADDLE4"] == "JUMP", "L5 jumps")
assert(bindings["CTRL-SHIFT-PADPADDLE4"] == "JUMP", "L5 jumps with both modifiers held")
layout.Command("extra PADPADDLE4 NONE")
assert(bindings["PADPADDLE4"] == nil and count(bindings) == 64, "extra can be unbound")
layout.Command("extra PADPADDLE4 JUMP")
layout.Command("extra PAD1 JUMP")
layout.Command("bind 2 PADFORWARD")
assert(bindings["PAD1"] == "ACTIONBUTTON2", "extra keys are protected from slot binds")
layout.Command("status")
layout.Command("off")
cvars.GamePadEmulateShift = nil
cvars.GamePadEmulateCtrl = nil
local mark = #printed
layout.Command("on")
assert(table.concat(printed, "\n", mark + 1):find("did not accept"), "missing cvars reported")
assert(count(bindings) == 68, "bindings still applied without cvars")
layout.Command("off")
cvars.GamePadEmulateShift = "PADLTRIGGER"
cvars.GamePadEmulateCtrl = "PADLSHOULDER"
layout.Command("on")
layout.Command("bind 1 PAD5")
assert(bindings["PAD5"] == "ACTIONBUTTON1", "free key can be bound")
assert(bindings["PAD3"] == nil, "old key released")
layout.Command("bind 1 PAD4")  -- used by slot 4, so the two swap
assert(bindings["PAD4"] == "ACTIONBUTTON1" and bindings["PAD5"] == "ACTIONBUTTON4", "duplicate swaps slots")
layout.Command("bind 1 PAD5")
assert(bindings["PAD5"] == "ACTIONBUTTON1" and bindings["PAD4"] == "ACTIONBUTTON4", "swap back")
layout.Command("bind 1 NOPE")  -- unknown
layout.Command("bar 2 5")
assert(bindings["SHIFT-PAD5"] == "MULTIACTIONBAR4BUTTON1", "custom slot and bar")

inCombat = true
layout.Command("reset")
assert(bindings["SHIFT-PAD5"] == "MULTIACTIONBAR4BUTTON1", "no change while in combat")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(bindings["SHIFT-PAD3"] == "MULTIACTIONBAR1BUTTON1", "pending reset applies after combat")
assert(bindings["SHIFT-PAD5"] == nil, "custom binding gone after reset")

layout.Command("off")
assert(count(bindings) == 0, "off clears bindings")
assert(cvars.GamePadEmulateShift == "PADLTRIGGER" and cvars.GamePadEmulateCtrl == "PADLSHOULDER", "off restores cvars")

-- options window
inCombat = true
ns.Options.Toggle()
local win
for _, h in ipairs(handlers) do if h.name == "UbermocForeverOptions" then win = h end end
assert(win == nil, "options window does not open in combat")
inCombat = false
ns.Options.Toggle()
for _, h in ipairs(handlers) do if h.name == "UbermocForeverOptions" then win = h end end
assert(win and win.shown, "options window opens")
local press = win.scripts.OnGamePadButtonDown
local cfg = ns.Layout.Config()
press(win, "PADDDOWN")            -- slot 1 row
press(win, "PAD1")                -- start capture
press(win, "PADPADDLE1")          -- a modifier paddle is refused
assert(cfg.slots[1] ~= "PADPADDLE1", "modifier paddle refused")
press(win, "PADLSTICKUP")         -- stick direction is a valid slot button
assert(cfg.slots[1] == "PADLSTICKUP", "capture assigns slot 1")
press(win, "PADRSHOULDER")        -- page 2
press(win, "PADDRIGHT")
assert(cfg.shiftButton == "PADPADDLE2", "shift paddle cycles")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cfg.ctrlButton == "PADPADDLE4", "ctrl paddle cycles")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cfg.bars[1] == 2, "bar cycles")
press(win, "PADRSHOULDER")        -- page 3
press(win, "PADDRIGHT")
assert(cfg.extras.PADFORWARD == "TOGGLEWORLDMAP", "extra command cycles")
press(win, "PAD2")
assert(not win.shown, "B closes the window")
ns.Layout.ResetDefaults()

ns.RunSelfTest()
local saved = ns.db.selftest
assert(saved and #saved.results >= 10, "self test stored results")
assert(saved.failed >= 1, "missing atlas reported as failure")
assert(#ns.db.log > 0, "log persisted to saved variables")

local out = table.concat(printed, "\n")
assert(ns.isForever and ns.gameType == "Forever", "game type")
assert(ns.Pad.GetActive().id == 2, "active device")
assert(out:find("0=PADDUP"), "padmap lists buttons")
assert(out:find("%(active%)") and out:find("%(combined%)"), "pad report flags")
print = nil
io.write("smoke test passed\n")
