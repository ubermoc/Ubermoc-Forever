local _, ns = ...

local Pad = {}
ns.Pad = Pad

local listeners = {}

local EVENTS = {
    "GAME_PAD_ACTIVE_CHANGED",
    "GAME_PAD_CONNECTED",
    "GAME_PAD_DISCONNECTED",
    "GAME_PAD_CONFIGS_CHANGED",
}

function Pad.IsEnabled()
    return C_GamePad.IsEnabled() and true or false
end

local function describe(id, activeID, combinedID)
    local mapped = C_GamePad.GetDeviceMappedState(id)
    local raw = C_GamePad.GetDeviceRawState(id)
    return {
        id = id,
        active = id == activeID,
        combined = id == combinedID,
        name = mapped and mapped.name or (raw and raw.name) or "?",
        labelStyle = mapped and mapped.labelStyle or "?",
        vendorID = raw and raw.vendorID,
        productID = raw and raw.productID,
        buttons = mapped and mapped.buttonCount or 0,
        axes = mapped and mapped.axisCount or 0,
        sticks = mapped and mapped.stickCount or 0,
    }
end

-- Every device the game sees, with the active one flagged.
function Pad.GetDevices()
    local list = {}
    local activeID = C_GamePad.GetActiveDeviceID()
    local combinedID = C_GamePad.GetCombinedDeviceID()
    for _, id in ipairs(C_GamePad.GetAllDeviceIDs()) do
        list[#list + 1] = describe(id, activeID, combinedID)
    end
    return list
end

function Pad.GetActive()
    for _, device in ipairs(Pad.GetDevices()) do
        if device.active then
            return device
        end
    end
end

-- fn(event) runs after the controller list changes.
function Pad.Subscribe(fn)
    listeners[#listeners + 1] = fn
end

function Pad.PrintReport()
    print(ns.L.PAD_ENABLED:format(Pad.IsEnabled() and ns.L.YES or ns.L.NO))
    local devices = Pad.GetDevices()
    if #devices == 0 then
        print(ns.L.PAD_NONE)
        return
    end
    for _, d in ipairs(devices) do
        print(ns.L.PAD_LINE:format(
            d.id, d.name, d.labelStyle,
            d.vendorID or 0, d.productID or 0,
            d.buttons, d.axes, d.sticks,
            d.active and ns.L.PAD_ACTIVE or "",
            d.combined and ns.L.PAD_COMBINED or ""))
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
    ns.Log("pad event " .. event)
    for _, fn in ipairs(listeners) do
        fn(event)
    end
end)
for _, event in ipairs(EVENTS) do
    frame:RegisterEvent(event)
end
