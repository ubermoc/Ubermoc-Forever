----------------------------------------------------------------------
-- Ubermoc Forever: controller detection
-- Looks at every controller the game can see (at login none is "active" until a button is pressed, and Steam can
-- show its own controller beside the virtual one it hands to games), and names the kind from the device's own
-- name and vendor. Ported from Ubermoc UI, which has been running this on real controllers.
-- Events and fields used here are from Blizzard's GamePadDocumentation: GAME_PAD_CONNECTED, GAME_PAD_DISCONNECTED,
-- GAME_PAD_ACTIVE_CHANGED, C_GamePad.GetAllDeviceIDs / GetActiveDeviceID / GetDeviceRawState (name, vendorID, productID).
----------------------------------------------------------------------
local _, UF = ...

UF.detected = nil        -- controller id from Layouts.lua, nil when no controller is seen
UF.deviceName = nil
UF.hasPaddles = false
UF.devices = {}

local function classify(name, vendor, product)
    local n = (name or ""):lower()
    if n:find("steam") or n:find("valve") then return "steam" end
    if type(vendor) == "number" and vendor == 10462 then return "steam" end               -- Valve
    if n:find("dualsense") or n:find("ps5") or n:find("dualshock 4") or n:find("ps4") or n:find("wireless controller") then return "ps5" end
    if n:find("dualshock 3") or n:find("ps3") or n:find("playstation%(r%)3") or n:find("playstation 3") then return "ps3" end
    if n:find("switch") or n:find("pro controller") or n:find("joy%-con") or n:find("nintendo") then return "switch" end
    if type(vendor) == "number" then
        if vendor == 1356 then return (product == 616) and "ps3" or "ps5" end              -- Sony
        if vendor == 1406 then return "switch" end                                         -- Nintendo
        if vendor == 1118 then return "xbox" end                                           -- Microsoft
    end
    if n:find("xbox") or n:find("x%-box") or n:find("xinput") then return "xbox" end
    return nil
end
UF.classify = classify

local callbacks = {}
function UF.OnDetect(fn) callbacks[#callbacks + 1] = fn end

function UF.detect()
    local before = UF.detected
    UF.detected, UF.deviceName = nil, nil
    wipe(UF.devices)
    if not C_GamePad then return end
    local ids, seen = {}, {}
    local okA, active = pcall(function() return C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID() end)
    if okA and active ~= nil then ids[#ids + 1] = active; seen[active] = true end
    local okL, all = pcall(function() return C_GamePad.GetAllDeviceIDs and C_GamePad.GetAllDeviceIDs() end)
    if okL and type(all) == "table" then
        for _, id in ipairs(all) do if not seen[id] then ids[#ids + 1] = id; seen[id] = true end end
    end
    local best, bestId
    for _, id in ipairs(ids) do
        local okR, raw = pcall(C_GamePad.GetDeviceRawState, id)
        if okR and type(raw) == "table" then
            local name = type(raw.name) == "string" and raw.name or nil
            local set = classify(name, raw.vendorID, raw.productID)
            UF.devices[#UF.devices + 1] = { id = id, name = name, vendor = raw.vendorID, product = raw.productID, set = set }
            -- A Valve device anywhere wins: with Steam's input the game may also see a plain "Xbox" pad.
            if set == "steam" or not best then
                if set or not best then best, bestId, UF.deviceName = set, id, name end
            end
        end
    end
    UF.detected = best
    -- Does the device hand the game its back buttons?
    UF.hasPaddles = false
    if bestId ~= nil and C_GamePad.GetDeviceMappedState and C_GamePad.ButtonIndexToBinding then
        local okM, st = pcall(C_GamePad.GetDeviceMappedState, bestId)
        if okM and type(st) == "table" and type(st.buttons) == "table" then
            for i = 0, #st.buttons - 1 do
                local okB, b = pcall(C_GamePad.ButtonIndexToBinding, i)
                if okB and type(b) == "string" and b:find("PADPADDLE") then UF.hasPaddles = true; break end
            end
        end
    end
    if UF.detected ~= before then
        for _, fn in ipairs(callbacks) do pcall(fn, UF.detected) end
    end
end

-- The controller to use: the one the player chose in the options, else the one detected, else Xbox letters.
function UF.activeSet()
    local d = UF.DB()
    if d.layout ~= "auto" and UF.SETS[d.layout] then return d.layout end
    return UF.detected or "xbox"
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GAME_PAD_CONNECTED")
ev:RegisterEvent("GAME_PAD_DISCONNECTED")
ev:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
ev:SetScript("OnEvent", function() pcall(UF.detect) end)

UF.OnLogin(function() UF.detect() end)
