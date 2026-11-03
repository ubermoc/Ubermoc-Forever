-- Offline smoke test: loads the addon files against stubbed WoW APIs.
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local handlers = {}
local noop = function() end
UIParent = {}
function CreateFrame()
    local f = setmetatable({ events = {} }, { __index = function() return function() return setmetatable({}, { __index = function() return noop end }) end end })
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(kind, fn) if kind == "OnUpdate" then self.onUpdate = fn else self.fn = fn end end
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
        local names = { [0] = "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6" }
        return names[i] or ("PADX" .. i)
    end,
    AxisIndexToConfigName = function(i) return "Axis" .. i end,
    StickIndexToConfigName = function(i) return "Stick" .. i end,
    GetDeviceRawState = function() return { name = "raw", vendorID = 1118, productID = 654 } end,
}

local ns = {}
for _, f in ipairs({ "Locales/enUS.lua", "Core/Init.lua", "Core/Compat.lua", "Core/Debug.lua", "Core/SelfTest.lua", "Input/GamePad.lua", "Input/PadTest.lua", "Input/Layout.lua" }) do
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
assert(count(bindings) == 48, "48 bindings, got " .. count(bindings))
assert(bindings["PAD3"] == "ACTIONBUTTON1", "X is slot 1")
assert(bindings["PAD1"] == "ACTIONBUTTON2", "A is slot 2")
assert(bindings["PADLTRIGGER"] == "ACTIONBUTTON12", "L2 is slot 12")
assert(bindings["SHIFT-PAD3"] == "MULTIACTIONBAR1BUTTON1", "shift set is bar 2")
assert(bindings["CTRL-PAD3"] == "MULTIACTIONBAR2BUTTON1", "ctrl set is bar 3")
assert(bindings["CTRL-SHIFT-PADDUP"] == "MULTIACTIONBAR3BUTTON8", "both set is bar 4")
assert(cvars.GamePadEmulateShift == "PADPADDLE1" and cvars.GamePadEmulateCtrl == "PADPADDLE3", "paddles emulate modifiers")

layout.Command("status")
layout.Command("off")
cvars.GamePadEmulateShift = nil
cvars.GamePadEmulateCtrl = nil
local mark = #printed
layout.Command("on")
assert(table.concat(printed, "\n", mark + 1):find("did not accept"), "missing cvars reported")
assert(count(bindings) == 48, "bindings still applied without cvars")
layout.Command("off")
cvars.GamePadEmulateShift = "PADLTRIGGER"
cvars.GamePadEmulateCtrl = "PADLSHOULDER"
layout.Command("on")
layout.Command("bind 1 PAD5")
assert(bindings["PAD5"] == "ACTIONBUTTON1", "free key can be bound")
assert(bindings["PAD3"] == nil, "old key released")
layout.Command("bind 1 PAD4")  -- taken by slot 4
assert(bindings["PAD5"] == "ACTIONBUTTON1", "duplicate rejected")
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
