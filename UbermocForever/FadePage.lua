----------------------------------------------------------------------
-- Ubermoc Forever: the Fading page of the options window.
-- Left: the elements in four drop-down lists (only one open at a time). Right: the chosen element's opacity for each situation
-- (Normal, or 0 to 100 %, stepped with - and +), and Hide. Everything is a plain button so the D-pad and A work on it.
----------------------------------------------------------------------
local ADDON, UF = ...
local P = {}
UF.FadePage = P

local ROW = 24
local page, headers, items, openCat, sel
local stateRows, titleFS, hideBtn, resetBtn, resetAllBtn, hintFS

local function button(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text or "")
    return b
end

local function layout()
    local y = 0
    for ci, c in ipairs(UF.Fade.CATEGORIES) do
        local h = headers[ci]
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        h:SetText((openCat == ci and "[-] " or "[+] ") .. c.name)
        y = y + ROW + 2
        for ei, e in ipairs(c.elements) do
            local b = items[ci][ei]
            if openCat == ci then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", page, "TOPLEFT", 18, -y)
                b:Show()
                y = y + ROW
            else
                b:Hide()
            end
        end
        if openCat == ci then y = y + 4 end
    end
end

function P.refresh()
    if not page then return end
    layout()
    local F = UF.Fade
    for ci, c in ipairs(F.CATEGORIES) do
        for ei, e in ipairs(c.elements) do
            local b = items[ci][ei]
            local fs = b:GetFontString()
            local set = F.get(e.key) ~= nil
            local chosen = sel and sel.key == e.key
            if fs then fs:SetTextColor(set and 1 or 1, set and 0.82 or 1, set and 0 or 1) end
            b:SetText((chosen and "> " or "") .. e.label)
        end
    end
    local e = sel
    titleFS:SetText(e and e.label or "Pick an element on the left")
    hintFS:SetShown(e ~= nil)
    local hid = e and F.hidden(e.key)
    for _, r in ipairs(stateRows) do
        r.frame:SetShown(e ~= nil)
        if e then
            local v = F.value(e.key, r.state)
            r.value:SetText(F.percentText(v))
            r.frame:SetAlpha(hid and 0.5 or 1)
        end
    end
    hideBtn:SetShown(e ~= nil)
    resetBtn:SetShown(e ~= nil)
    if e then hideBtn:SetText("Hide for good: " .. (hid and "On" or "Off")) end
end

function P.build(parent, inset)
    if page then return page end
    local F = UF.Fade
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    page:Hide()
    headers, items = {}, {}
    openCat = 1
    for ci, c in ipairs(F.CATEGORIES) do
        local h = button(page, 250, ROW, c.name)
        h:SetScript("OnClick", function() openCat = (openCat ~= ci) and ci or nil; P.refresh() end)
        headers[ci] = h
        items[ci] = {}
        for ei, e in ipairs(c.elements) do
            local b = button(page, 232, ROW - 2, e.label)
            b:Hide()
            b:SetScript("OnClick", function() sel = e; P.refresh() end)
            items[ci][ei] = b
        end
    end
    sel = F.CATEGORIES[1].elements[1]

    -- Right pane
    local RX = 275
    titleFS = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", page, "TOPLEFT", RX, 0)
    hideBtn = button(page, 200, 24, "")
    hideBtn:SetPoint("TOPLEFT", page, "TOPLEFT", RX, -30)
    hideBtn:SetScript("OnClick", function() if sel then F.toggleHide(sel.key); P.refresh() end end)

    stateRows = {}
    for i, st in ipairs(F.STATES) do
        local fr = CreateFrame("Frame", nil, page)
        fr:SetSize(380, 26)
        fr:SetPoint("TOPLEFT", page, "TOPLEFT", RX, -68 - (i - 1) * 34)
        local lab = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lab:SetPoint("LEFT", 0, 0)
        lab:SetWidth(120)
        lab:SetJustifyH("LEFT")
        lab:SetText(st.label)
        local normal = button(fr, 62, 24, "Normal")
        normal:SetPoint("LEFT", 124, 0)
        local zero = button(fr, 30, 24, "0")
        zero:SetPoint("LEFT", normal, "RIGHT", 2, 0)
        local minus = button(fr, 30, 24, "-")
        minus:SetPoint("LEFT", zero, "RIGHT", 8, 0)
        local value = fr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("LEFT", minus, "RIGHT", 2, 0)
        value:SetWidth(56)
        local plus = button(fr, 30, 24, "+")
        plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
        normal:SetScript("OnClick", function() if sel then F.set(sel.key, st.key, nil); P.refresh() end end)
        zero:SetScript("OnClick", function() if sel then F.set(sel.key, st.key, 0); P.refresh() end end)
        minus:SetScript("OnClick", function() if sel then F.step(sel.key, st.key, -1); P.refresh() end end)
        plus:SetScript("OnClick", function() if sel then F.step(sel.key, st.key, 1); P.refresh() end end)
        stateRows[i] = { frame = fr, state = st.key, value = value, normal = normal, zero = zero, minus = minus, plus = plus }
    end
    hintFS = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintFS:SetPoint("TOPLEFT", page, "TOPLEFT", RX, -68 - #F.STATES * 34)
    hintFS:SetWidth(380)
    hintFS:SetJustifyH("LEFT")
    hintFS:SetText("Normal leaves the game's own opacity. The first situation that is on and has a value wins, in the order above. Hidden frames can still take clicks.")
    resetBtn = button(page, 200, 24, "Reset this element")
    resetBtn:SetPoint("TOPLEFT", hintFS, "BOTTOMLEFT", 0, -14)
    resetBtn:SetScript("OnClick", function() if sel then F.reset(sel.key); P.refresh() end end)
    resetAllBtn = button(page, 200, 24, "Reset all fading")
    resetAllBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
    resetAllBtn:SetScript("OnClick", function() F.resetAll(); P.refresh() end)
    P.refresh()
    return page
end

function P.frame() return page end

-- The rows of buttons the D-pad moves over (left list first, then the right pane).
function P.navRows()
    local out = {}
    if not page then return out end
    for ci, c in ipairs(UF.Fade.CATEGORIES) do
        out[#out + 1] = { headers[ci] }
        if openCat == ci then
            for ei = 1, #c.elements do out[#out + 1] = { items[ci][ei] } end
        end
    end
    if sel then
        out[#out + 1] = { hideBtn }
        for _, r in ipairs(stateRows) do out[#out + 1] = { r.normal, r.zero, r.minus, r.plus } end
        out[#out + 1] = { resetBtn }
    end
    out[#out + 1] = { resetAllBtn }
    return out
end
