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
function geterrorhandler() return function() end end
function seterrorhandler() end
C_AddOns = { GetAddOnMetadata = function() return "test" end, IsAddOnLoaded = function() return false end }
SlashCmdList = {}
C_GamePad = {
    IsEnabled = function() return true end,
    GetActiveDeviceID = function() return 2 end,
    GetCombinedDeviceID = function() return 99 end,
    GetAllDeviceIDs = function() return { 2, 99 } end,
    GetDeviceMappedState = function(id)
        return { name = "Pad" .. (id or "active"), labelStyle = "Generic", buttonCount = 3, axisCount = 2, stickCount = 1,
            buttons = { false, true, false }, axes = { 0, 0.5 }, sticks = { { x = 0.5, y = 0, len = 0.5 } } }
    end,
    ButtonIndexToBinding = function(i) return "PAD" .. i end,
    AxisIndexToConfigName = function(i) return "Axis" .. i end,
    StickIndexToConfigName = function(i) return "Stick" .. i end,
    GetDeviceRawState = function() return { name = "raw", vendorID = 1118, productID = 654 } end,
}

local ns = {}
for _, f in ipairs({ "Locales/enUS.lua", "Core/Init.lua", "Core/Compat.lua", "Core/Debug.lua", "Input/GamePad.lua", "Input/PadTest.lua" }) do
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

local out = table.concat(printed, "\n")
assert(ns.isForever and ns.gameType == "Forever", "game type")
assert(ns.Pad.GetActive().id == 2, "active device")
assert(out:find("0=PAD0"), "padmap lists buttons")
assert(out:find("%(active%)") and out:find("%(combined%)"), "pad report flags")
print = nil
io.write("smoke test passed\n")
