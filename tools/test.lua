-- Offline smoke test: loads the addon files against stubbed WoW APIs.
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local handlers = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.fn = fn end
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
        return { name = "Pad" .. id, labelStyle = "Generic", buttonCount = 15, axisCount = 6, stickCount = 2 }
    end,
    GetDeviceRawState = function() return { name = "raw", vendorID = 1118, productID = 654 } end,
}

local ns = {}
for _, f in ipairs({ "Locales/enUS.lua", "Core/Init.lua", "Core/Compat.lua", "Core/Debug.lua", "Input/GamePad.lua" }) do
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

local out = table.concat(printed, "\n")
assert(ns.isForever and ns.gameType == "Forever", "game type")
assert(ns.Pad.GetActive().id == 2, "active device")
assert(out:find("%(active%)") and out:find("%(combined%)"), "pad report flags")
print = nil
io.write("smoke test passed\n")
