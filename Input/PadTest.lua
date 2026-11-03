local _, ns = ...

-- Live readout of the active controller, for learning what a given pad and
-- Steam Input layout really reports. The name lookups are 0-based while the
-- state tables are 1-based (confirmed on a Steam Input pad for buttons, axes
-- and sticks).
local UPDATE_INTERVAL = 0.05

local frame
local text
local elapsedSum = 0

local function name(lookup, index)
    return lookup(index) or "-"
end

local function build()
    local state = C_GamePad.GetDeviceMappedState()
    if not state then
        return ns.L.PADTEST_NONE
    end
    local lines = { state.name .. " | " .. state.labelStyle }

    local pressed = {}
    for index, down in ipairs(state.buttons) do
        if down then
            pressed[#pressed + 1] = ("b%d (%s)"):format(
                index, name(C_GamePad.ButtonIndexToBinding, index - 1))
        end
    end
    lines[#lines + 1] = ns.L.PADTEST_BUTTONS .. (#pressed > 0 and table.concat(pressed, ", ") or "-")

    local moved = {}
    for index, value in ipairs(state.axes) do
        if math.abs(value) > 0.05 then
            moved[#moved + 1] = ("a%d=%.2f (%s)"):format(
                index, value, name(C_GamePad.AxisIndexToConfigName, index - 1))
        end
    end
    lines[#lines + 1] = ns.L.PADTEST_AXES .. (#moved > 0 and table.concat(moved, ", ") or "-")

    for index, stick in ipairs(state.sticks) do
        if stick.len > 0 then
            lines[#lines + 1] = ("s%d %s x=%.2f y=%.2f"):format(
                index, name(C_GamePad.StickIndexToConfigName, index - 1), stick.x, stick.y)
        end
    end
    return table.concat(lines, "\n")
end

local function create()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(640, 140)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    frame:SetFrameStrata("DIALOG")
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 8, -8)
    text:SetPoint("BOTTOMRIGHT", -8, 8)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    frame:SetScript("OnUpdate", function(_, elapsed)
        elapsedSum = elapsedSum + elapsed
        if elapsedSum >= UPDATE_INTERVAL then
            elapsedSum = 0
            text:SetText(build())
        end
    end)
end

function ns.TogglePadTest()
    if not frame then
        create()
        return
    end
    frame:SetShown(not frame:IsShown())
end

-- Prints every button, axis and stick name the game defines for the active pad.
function ns.PrintPadMap()
    local state = C_GamePad.GetDeviceMappedState()
    if not state then
        print(ns.L.PADTEST_NONE)
        return
    end
    local function dump(label, count, lookup)
        local parts = {}
        for index = 0, count - 1 do
            parts[#parts + 1] = ("%d=%s"):format(index, name(lookup, index))
        end
        print(label .. table.concat(parts, ", "))
    end
    dump(ns.L.PADMAP_BUTTONS, state.buttonCount, C_GamePad.ButtonIndexToBinding)
    dump(ns.L.PADMAP_AXES, state.axisCount, C_GamePad.AxisIndexToConfigName)
    dump(ns.L.PADMAP_STICKS, state.stickCount, C_GamePad.StickIndexToConfigName)
end
