local _, ns = ...

-- Controller-driven options window. The d-pad (or the left stick's direction
-- buttons) moves, A selects, B or Select closes, L1 and R1 change page.
local Options = {}
ns.Options = Options

local L = ns.L
local WIDTH, HEIGHT = 560, 470
local ROW_HEIGHT = 24
local ROW_COUNT = 14
local FIRST_ROW_Y = -64

-- How opaque the dark marble behind the rows is: 1 dark, 2 medium, 3 light.
local SHADE_ALPHA = { 1, 0.45, 0 }
local DEFAULT_SHADE = 2

local frame
local rowFrames = {}
local header, hint, status
local page, index = 1, 1
local captureSlot
local message = ""

local function cycle(list, current, step)
    local position = 1
    for i, value in ipairs(list) do
        if value == current then
            position = i
        end
    end
    return list[(position - 1 + step) % #list + 1]
end

local function shade()
    return ns.db.optionsShade or DEFAULT_SHADE
end

local function applyShade()
    if frame then
        frame.InsetBg:SetAlpha(SHADE_ALPHA[shade()])
    end
end

local function buildRows()
    local Layout = ns.Layout
    local c = Layout.Config()
    local rows = {}

    if page == 1 then
        local function toggle()
            Layout.SetEnabled(not c.enabled)
        end
        rows[#rows + 1] = { label = L.OPT_LAYOUT_ON, value = c.enabled and L.YES or L.NO,
            onLeft = toggle, onRight = toggle, onActivate = toggle }
        for slot = 1, Layout.SLOT_COUNT do
            rows[#rows + 1] = { label = L.OPT_SLOT:format(slot), value = Layout.Friendly(c.slots[slot]),
                onActivate = function() captureSlot = slot end }
        end
        rows[#rows + 1] = { label = L.OPT_RESET, value = "", onActivate = Layout.ResetDefaults }

    elseif page == 2 then
        local function modifierRow(which, field, step)
            return function()
                local other = which == "shift" and c.ctrlButton or c.shiftButton
                local key = cycle(Layout.PADDLES, c[field], step)
                if key == other then
                    key = cycle(Layout.PADDLES, key, step)
                end
                Layout.SetModifier(which, key)
            end
        end
        rows[#rows + 1] = { label = L.OPT_SHIFT_PADDLE, value = Layout.Friendly(c.shiftButton),
            onLeft = modifierRow("shift", "shiftButton", -1), onRight = modifierRow("shift", "shiftButton", 1) }
        rows[#rows + 1] = { label = L.OPT_CTRL_PADDLE, value = Layout.Friendly(c.ctrlButton),
            onLeft = modifierRow("ctrl", "ctrlButton", -1), onRight = modifierRow("ctrl", "ctrlButton", 1) }
        for set, def in ipairs(Layout.SETS) do
            local function step(delta)
                return function()
                    Layout.SetBar(set, (c.bars[set] - 1 + delta) % Layout.MAX_BAR + 1)
                end
            end
            rows[#rows + 1] = { label = L.OPT_SET:format(def.label), value = L.OPT_BAR:format(c.bars[set]),
                onLeft = step(-1), onRight = step(1) }
        end

    else
        for _, key in ipairs(Layout.EXTRA_ORDER) do
            local function step(delta)
                return function()
                    Layout.SetExtra(key, cycle(Layout.EXTRA_COMMAND_LIST, c.extras[key], delta))
                end
            end
            rows[#rows + 1] = { label = Layout.Friendly(key), value = c.extras[key],
                onLeft = step(-1), onRight = step(1) }
        end
        local function stepShade(delta)
            return function()
                ns.db.optionsShade = (shade() - 1 + delta) % #SHADE_ALPHA + 1
                applyShade()
            end
        end
        rows[#rows + 1] = { label = L.OPT_SHADE, value = L.OPT_SHADES[shade()],
            onLeft = stepShade(-1), onRight = stepShade(1) }
        rows[#rows + 1] = { label = L.OPT_SELFTEST, value = "", onActivate = ns.RunSelfTest }
        rows[#rows + 1] = { label = L.OPT_CLOSE, value = "", onActivate = function() Options.Hide() end }
    end
    return rows
end

local function render()
    if not frame then
        return
    end
    local rows = buildRows()
    if index > #rows then
        index = #rows
    end
    for i = 1, ROW_COUNT do
        local row, data = rowFrames[i], rows[i]
        if data then
            row.label:SetText(data.label)
            row.value:SetText(data.value)
            row.highlight:SetShown(i == index)
            row:Show()
        else
            row:Hide()
        end
    end
    local names = { L.OPT_PAGE_BUTTONS, L.OPT_PAGE_MODIFIERS, L.OPT_PAGE_OTHER }
    names[page] = "[" .. names[page] .. "]"
    header:SetText("L1  " .. table.concat(names, "   ") .. "  R1")
    hint:SetText(captureSlot and L.OPT_CAPTURE:format(captureSlot) or L.OPT_HINT)
    status:SetText(message)
end

local function handleKey(key)
    key = key:match("([^-]+)$") or key
    ns.Log("options key " .. key)
    message = L.OPT_LAST_KEY:format(key)

    if captureSlot then
        if key == "PADBACK" then
            captureSlot = nil
        else
            local ok, reason = ns.Layout.SetSlot(captureSlot, key)
            if ok then
                captureSlot = nil
            elseif reason == "extra" then
                message = L.OPT_KEY_EXTRA
            elseif reason == "modifier" then
                message = L.OPT_KEY_MODIFIER
            else
                message = L.OPT_KEY_INVALID
            end
        end
        render()
        return
    end

    local rows = buildRows()
    local row = rows[index]
    if key == "PADDUP" or key == "PADLSTICKUP" then
        index = (index - 2) % #rows + 1
    elseif key == "PADDDOWN" or key == "PADLSTICKDOWN" then
        index = index % #rows + 1
    elseif key == "PADDLEFT" or key == "PADLSTICKLEFT" then
        if row.onLeft then row.onLeft() end
    elseif key == "PADDRIGHT" or key == "PADLSTICKRIGHT" then
        if row.onRight then row.onRight() end
    elseif key == "PAD1" then
        local action = row.onActivate or row.onRight
        if action then action() end
    elseif key == "PADLSHOULDER" then
        page = (page - 2) % 3 + 1
        index = 1
    elseif key == "PADRSHOULDER" then
        page = page % 3 + 1
        index = 1
    elseif key == "PAD2" or key == "PADBACK" or key == "PADFORWARD" then
        Options.Hide()
        return
    end
    render()
end
Options.HandleKey = handleKey

local function create()
    frame = CreateFrame("Frame", "UbermocForeverOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame.TitleText:SetText(L.OPT_TITLE)
    applyShade()
    table.insert(UISpecialFrames, "UbermocForeverOptions")

    header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", frame, "TOP", 0, -34)

    for i = 1, ROW_COUNT do
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, FIRST_ROW_Y - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, FIRST_ROW_Y - (i - 1) * ROW_HEIGHT)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 0.82, 0, 0.25)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        rowFrames[i] = row
    end

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    status:SetPoint("BOTTOM", frame, "BOTTOM", 0, 34)
    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)

    frame:EnableGamePadButton(true)
    frame:SetScript("OnGamePadButtonDown", function(_, key)
        handleKey(key)
    end)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    watcher:SetScript("OnEvent", function()
        Options.Hide()
    end)
end

function Options.Hide()
    captureSlot = nil
    if frame then
        frame:Hide()
    end
end

function Options.Toggle()
    if frame and frame:IsShown() then
        Options.Hide()
        return
    end
    if InCombatLockdown() then
        print(L.OPT_COMBAT)
        return
    end
    if not frame then
        create()
    end
    page, index, message = 1, 1, ""
    frame:Show()
    render()
end
