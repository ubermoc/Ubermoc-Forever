local _, ns = ...

-- Live readout of the active controller, for learning what a given pad and
-- Steam Input layout really reports. Button and axis names are shown for both
-- index bases because the docs do not say which one the lookup functions use.
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
            pressed[#pressed + 1] = ("b%d (%s / %s)"):format(
                index,
                name(C_GamePad.ButtonIndexToBinding, index - 1),
                name(C_GamePad.ButtonIndexToBinding, index))
        end
    end
    lines[#lines + 1] = ns.L.PADTEST_BUTTONS .. (#pressed > 0 and table.concat(pressed, ", ") or "-")

    local moved = {}
    for index, value in ipairs(state.axes) do
        if math.abs(value) > 0.05 then
            moved[#moved + 1] = ("a%d=%.2f (%s / %s)"):format(
                index, value,
                name(C_GamePad.AxisIndexToConfigName, index - 1),
                name(C_GamePad.AxisIndexToConfigName, index))
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
