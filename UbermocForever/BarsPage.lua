----------------------------------------------------------------------
-- Ubermoc Forever: the Bars page of the options window (fourth page): everything the gamepad layout (GamepadBar.lua) changes, in one place.
-- The layout's own settings, a button that opens the game's Edit Mode (the experience bar, micro menu and bags are the game's own parts and
-- are moved there), and the fading of the four parts that stay adjustable while the layout is on: the gamepad bar, the experience bar, the micro
-- menu and the bags, with the same three situations as the Fading page (they are the same settings: Fading page elements "xpall", "micro",
-- "bags"; the gamepad bar's "gbar" only lives here). Everything else the layout hides is hidden for good and has no setting.
-- Plain buttons, as on the other pages, so the D-pad and A work on all of them.
----------------------------------------------------------------------
local ADDON, UF = ...
local BP = {}
UF.BarsPage = BP

local page, rows, pickBtns, stateRows, titleFS, hideBtn, resetBtn, note
local sel
local PARTS = {
    { key = "gbar", short = "Gamepad bar" },
    { key = "xpall", short = "XP bar", layoutHidden = true },
    { key = "micro", short = "Micro menu", layoutHidden = true },
    { key = "bags", short = "Bags", layoutHidden = true },
}
BP.PARTS = PARTS

local function button(parent, w, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 24)
    b:SetText(text or "")
    return b
end

-- What a situation's value reads as: a part the layout hides to start with says Hidden until it has a setting of its own.
function BP.valueText(part, v)
    local F = UF.Fade
    if v == nil then
        if part.layoutHidden and UF.GamepadBar.cfg().on then return "Hidden" end
        return "Normal"
    end
    return F.percentText(v)
end

function BP.refresh()
    if not page then return end
    local B, F = UF.GamepadBar, UF.Fade
    local c = B.cfg()
    rows.on:SetText("Gamepad layout: " .. (c.on and "On" or "Off"))
    rows.empty:SetText("Hide empty buttons: " .. (c.hideEmpty and "On" or "Off"))
    rows.size:SetText("Button size: " .. c.size)
    rows.gap:SetText("Gap: " .. c.gap)
    rows.raise:SetText("Height: " .. c.raise)
    for _, b in ipairs(pickBtns) do
        local fs = b:GetFontString()
        local set = F.get(b.part.key) ~= nil
        if fs then
            if set then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(1, 1, 1) end
        end
        b:SetText((sel == b.part and "> " or "") .. b.part.short)
    end
    local hid = F.hidden(sel.key)
    titleFS:SetText(sel.short)
    for _, r in ipairs(stateRows) do
        r.value:SetText(BP.valueText(sel, F.value(sel.key, r.state)))
        r.normal:SetText((sel.layoutHidden and c.on) and "Default" or "Normal")
        r.frame:SetAlpha(hid and 0.5 or 1)
    end
    hideBtn:SetText("Hide for good: " .. (hid and "On" or "Off"))
end

function BP.build(parent, inset)
    if page then return page end
    local B, F = UF.GamepadBar, UF.Fade
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    page:Hide()

    local function tip(b, title, text)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    head:SetText("Gamepad layout")
    rows = {}
    rows.on = button(page, 190); rows.on:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
    rows.empty = button(page, 220); rows.empty:SetPoint("LEFT", rows.on, "RIGHT", 6, 0)
    rows.edit = button(page, 200, "Move bars (Edit Mode)"); rows.edit:SetPoint("LEFT", rows.empty, "RIGHT", 6, 0)
    rows.size = button(page, 190); rows.size:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -56)
    rows.gap = button(page, 140); rows.gap:SetPoint("LEFT", rows.size, "RIGHT", 6, 0)
    rows.raise = button(page, 140); rows.raise:SetPoint("LEFT", rows.gap, "RIGHT", 6, 0)
    rows.on:SetScript("OnClick", function() B.toggle(); BP.refresh() end)
    rows.empty:SetScript("OnClick", function() B.toggleEmpty(); BP.refresh() end)
    rows.edit:SetScript("OnClick", function() B.openEditMode() end)
    rows.size:SetScript("OnClick", function() B.nextSize(); BP.refresh() end)
    rows.gap:SetScript("OnClick", function() B.nextGap(); BP.refresh() end)
    rows.raise:SetScript("OnClick", function() B.nextRaise(); BP.refresh() end)
    tip(rows.on, "Gamepad layout", "One row of action buttons at the bottom of the screen: nothing held shows action bar 1, the first modifier bar 2, the second bar 3, both bar 4 (the layers the default binds fill). Each button shows the controller button it is bound to. The game's bottom art is hidden for good while this is on. Off puts everything back.")
    tip(rows.empty, "Hide empty buttons", "Buttons with nothing on them are removed from the row and the rest are centred and spaced evenly. Changes wait until a fight is over.")
    tip(rows.edit, "Move bars (Edit Mode)", "Opens the game's Edit Mode, where the experience bar, the micro menu and the bags can be moved. They show while Edit Mode is open. This window closes.")
    tip(rows.size, "Button size", "How big each button is. Press to step through the choices.")
    tip(rows.gap, "Gap", "The space between buttons, the same everywhere in the row.")
    tip(rows.raise, "Height", "How far the row sits above the bottom edge of the screen.")

    local head2 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head2:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -96)
    head2:SetText("Fading of the parts the layout leaves adjustable")
    pickBtns = {}
    local prev
    for _, part in ipairs(PARTS) do
        local b = button(page, 150, part.short)
        b.part = part
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -118) end
        b:SetScript("OnClick", function() sel = part; BP.refresh() end)
        pickBtns[#pickBtns + 1] = b
        prev = b
    end
    sel = PARTS[1]

    titleFS = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -152)
    stateRows = {}
    for i, st in ipairs(F.STATES) do
        local fr = CreateFrame("Frame", nil, page)
        fr:SetSize(520, 26)
        fr:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -184 - (i - 1) * 34)
        local lab = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lab:SetPoint("LEFT", 0, 0); lab:SetWidth(120); lab:SetJustifyH("LEFT"); lab:SetText(st.label)
        local normal = button(fr, 70, "Normal"); normal:SetPoint("LEFT", 124, 0)
        local zero = button(fr, 30, "0"); zero:SetPoint("LEFT", normal, "RIGHT", 2, 0)
        local minus = button(fr, 30, "-"); minus:SetPoint("LEFT", zero, "RIGHT", 8, 0)
        local value = fr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("LEFT", minus, "RIGHT", 2, 0); value:SetWidth(64)
        local plus = button(fr, 30, "+"); plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
        normal:SetScript("OnClick", function() F.set(sel.key, st.key, nil); BP.refresh() end)
        zero:SetScript("OnClick", function() F.set(sel.key, st.key, 0); BP.refresh() end)
        minus:SetScript("OnClick", function() F.step(sel.key, st.key, -1); BP.refresh() end)
        plus:SetScript("OnClick", function() F.step(sel.key, st.key, 1); BP.refresh() end)
        stateRows[i] = { frame = fr, state = st.key, value = value, normal = normal, zero = zero, minus = minus, plus = plus }
    end
    local y = -184 - #F.STATES * 34
    hideBtn = button(page, 200); hideBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 6)
    hideBtn:SetScript("OnClick", function() F.toggleHide(sel.key); BP.refresh() end)
    resetBtn = button(page, 200, "Reset this part"); resetBtn:SetPoint("LEFT", hideBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function() F.reset(sel.key); BP.refresh() end)
    note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", hideBtn, "BOTTOMLEFT", 0, -12)
    note:SetWidth(640); note:SetJustifyH("LEFT")
    note:SetText("The XP bar, micro menu and bags start hidden while the layout is on (Default); set a value to bring them back, and the mouse-over opacity of the Fading page works on them. They are the same settings as on the Fading page. Everything else the layout hides cannot be shown while it is on, not even with the mouse. Moving needs Edit Mode. Type /ubf bars to see what the layout found.")
    BP.refresh()
    return page
end

function BP.frame() return page end

function BP.navRows()
    local out = {}
    if not page then return out end
    out[1] = { rows.on, rows.empty, rows.edit }
    out[2] = { rows.size, rows.gap, rows.raise }
    local picks = {}
    for _, b in ipairs(pickBtns) do picks[#picks + 1] = b end
    out[3] = picks
    for _, r in ipairs(stateRows) do out[#out + 1] = { r.normal, r.zero, r.minus, r.plus } end
    out[#out + 1] = { hideBtn, resetBtn }
    return out
end
