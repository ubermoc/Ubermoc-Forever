----------------------------------------------------------------------
-- Ubermoc Forever: the Fading page of the options window.
-- Left: the elements in drop-down lists (only one open at a time), in a scrolling column. Right: the chosen element's opacity for each
-- situation (Normal, or 0 to 100 % stepped with - and +), Hide, Copy / Paste, and Apply to the whole list. Everything is a plain button so the
-- D-pad and A work on it.
----------------------------------------------------------------------
local ADDON, UF = ...
local P = {}
UF.FadePage = P

local ROW = 24
local COLW = 262
local page, scroll, listChild, headers, items, openCat, sel
local mouseRow, stateRows, titleFS, hideBtn, copyBtn, pasteBtn, applyBtn, resetBtn, resetAllBtn, hintFS, foundFS, clipFS

local function button(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text or "")
    return b
end

-- An element the gamepad layout hides for good (the game's bottom art while the layout is on) has no setting to offer: it is not listed.
local function offered(e)
    local fc = UF.Fade.forced and UF.Fade.forced[e.key]
    return not (fc and fc())
end
local function categoryOffered(c)
    for _, e in ipairs(c.elements) do if offered(e) then return true end end
    return false
end

local function layout()
    local y = 0
    for ci, c in ipairs(UF.Fade.CATEGORIES) do
        local h = headers[ci]
        local catOn = categoryOffered(c)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
        h.fadeY = y
        h:SetText((openCat == ci and "[-] " or "[+] ") .. c.name)
        h:SetShown(catOn)
        if catOn then y = y + ROW + 2 end
        for ei, e in ipairs(c.elements) do
            local b = items[ci][ei]
            if openCat == ci and catOn and offered(e) then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", listChild, "TOPLEFT", 18, -y)
                b.fadeY = y
                b:Show()
                y = y + ROW
            else
                b:Hide()
            end
        end
        if openCat == ci and catOn then y = y + 4 end
    end
    listChild:SetHeight(math.max(y, 10))
end

-- Scrolls the left column so a button of the list is in view.
function P.reveal(b)
    if not (scroll and b and b.fadeY) then return end
    local viewH = scroll:GetHeight() or 0
    local range = math.max(0, (listChild:GetHeight() or 0) - viewH)
    local cur = scroll:GetVerticalScroll() or 0
    local top, bottom = b.fadeY, b.fadeY + ROW
    if top < cur then cur = top elseif bottom > cur + viewH then cur = bottom - viewH end
    scroll:SetVerticalScroll(math.max(0, math.min(range, cur)))
end

function P.refresh()
    if not page then return end
    if sel and not offered(sel) then
        sel = nil
        for _, c in ipairs(UF.Fade.CATEGORIES) do
            for _, e in ipairs(c.elements) do if not sel and offered(e) then sel = e end end
        end
    end
    layout()
    local F = UF.Fade
    for ci, c in ipairs(F.CATEGORIES) do
        for ei, e in ipairs(c.elements) do
            local b = items[ci][ei]
            local fs = b:GetFontString()
            local set = F.get(e.key) ~= nil
            local found = F.found(e)
            if fs then
                if found == 0 then fs:SetTextColor(0.5, 0.5, 0.5)
                elseif set then fs:SetTextColor(1, 0.82, 0)
                else fs:SetTextColor(1, 1, 1) end
            end
            b:SetText((sel and sel.key == e.key and "> " or "") .. e.label)
        end
    end
    mouseRow.value:SetText(F.mouse() == nil and "Off" or F.percentText(F.mouse()))
    local e = sel
    titleFS:SetText(e and e.label or "Pick an element on the left")
    hintFS:SetShown(e ~= nil)
    local hid = e and F.hidden(e.key)
    for _, r in ipairs(stateRows) do
        r.frame:SetShown(e ~= nil)
        if e then
            r.value:SetText(F.percentText(F.value(e.key, r.state)))
            r.frame:SetAlpha(hid and 0.5 or 1)
        end
    end
    for _, b in ipairs({ hideBtn, copyBtn, pasteBtn, applyBtn, resetBtn }) do b:SetShown(e ~= nil) end
    foundFS:SetShown(e ~= nil)
    clipFS:SetShown(e ~= nil)
    if e then
        hideBtn:SetText("Hide for good: " .. (hid and "On" or "Off"))
        local found, total = F.found(e)
        foundFS:SetText(found == 0 and "|cff999999Not available in this game|r" or (found == total and "" or ("Found " .. found .. " of " .. total .. " parts")))
        clipFS:SetText(F.hasClipboard() and ("Copied: " .. tostring(F.clipboardFrom())) or "Nothing copied yet")
        pasteBtn:SetEnabled(F.hasClipboard())
    end
end

function P.build(parent, inset)
    if page then return page end
    local F = UF.Fade
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    page:Hide()

    -- Left: the scrolling list
    scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    scroll:SetWidth(COLW)
    listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(COLW - 4, 10)
    scroll:SetScrollChild(listChild)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, (listChild:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 3 * ROW)))
    end)
    headers, items = {}, {}
    openCat = 1
    for ci, c in ipairs(F.CATEGORIES) do
        local h = button(listChild, 250, ROW, c.name)
        h:SetScript("OnClick", function() openCat = (openCat ~= ci) and ci or nil; P.refresh(); P.reveal(h) end)
        headers[ci] = h
        items[ci] = {}
        for ei, e in ipairs(c.elements) do
            local b = button(listChild, 232, ROW - 2, e.label)
            b:Hide()
            b:SetScript("OnClick", function() sel = e; P.refresh() end)
            items[ci][ei] = b
        end
    end
    sel = F.CATEGORIES[1].elements[1]

    -- Right pane
    local RX = COLW + 24
    titleFS = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", page, "TOPLEFT", RX, 0)
    hideBtn = button(page, 200, 24, "")
    hideBtn:SetPoint("TOPLEFT", page, "TOPLEFT", RX, -30)
    hideBtn:SetScript("OnClick", function() if sel then F.toggleHide(sel.key); P.refresh() end end)
    foundFS = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    foundFS:SetPoint("LEFT", hideBtn, "RIGHT", 10, 0)

    stateRows = {}
    for i, st in ipairs(F.STATES) do
        local fr = CreateFrame("Frame", nil, page)
        fr:SetSize(400, 26)
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
    hintFS:SetWidth(400)
    hintFS:SetJustifyH("LEFT")
    hintFS:SetText("Normal leaves the game's own opacity. The first situation that is on and has a value wins, in the order above. A part with a setting stops following the frame it sits in. Hidden frames can still take clicks.")
    copyBtn = button(page, 96, 24, "Copy")
    copyBtn:SetPoint("TOPLEFT", hintFS, "BOTTOMLEFT", 0, -12)
    copyBtn:SetScript("OnClick", function() if sel then F.copy(sel.key); P.refresh() end end)
    pasteBtn = button(page, 96, 24, "Paste")
    pasteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    pasteBtn:SetScript("OnClick", function() if sel and F.paste(sel.key) then P.refresh() end end)
    clipFS = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clipFS:SetPoint("LEFT", pasteBtn, "RIGHT", 10, 0)
    applyBtn = button(page, 200, 24, "Apply to the whole list")
    applyBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -6)
    applyBtn:SetScript("OnClick", function()
        if sel then
            local n = F.applyToList(sel.key)
            UF.say("Fading: " .. sel.label .. "'s settings were put on the other " .. n .. " elements of this list.")
            P.refresh()
        end
    end)
    resetBtn = button(page, 200, 24, "Reset this element")
    resetBtn:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 0, -6)
    resetBtn:SetScript("OnClick", function() if sel then F.reset(sel.key); P.refresh() end end)
    resetAllBtn = button(page, 200, 24, "Reset all fading")
    resetAllBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
    resetAllBtn:SetScript("OnClick", function() F.resetAll(); P.refresh() end)

    -- The one universal setting: the opacity any faded element goes to while the mouse is over it.
    local mf = CreateFrame("Frame", nil, page)
    mf:SetSize(400, 26)
    mf:SetPoint("TOPLEFT", resetAllBtn, "BOTTOMLEFT", 0, -18)
    local mlab = mf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mlab:SetPoint("LEFT", 0, 0)
    mlab:SetWidth(120)
    mlab:SetJustifyH("LEFT")
    mlab:SetText("Mouse over (all)")
    local moff = button(mf, 62, 24, "Off")
    moff:SetPoint("LEFT", 124, 0)
    local mminus = button(mf, 30, 24, "-")
    mminus:SetPoint("LEFT", moff, "RIGHT", 40, 0)
    local mvalue = mf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mvalue:SetPoint("LEFT", mminus, "RIGHT", 2, 0)
    mvalue:SetWidth(56)
    local mplus = button(mf, 30, 24, "+")
    mplus:SetPoint("LEFT", mvalue, "RIGHT", 2, 0)
    moff:SetScript("OnClick", function() F.setMouse(nil); P.refresh() end)
    mminus:SetScript("OnClick", function() F.stepMouse(-1); P.refresh() end)
    mplus:SetScript("OnClick", function() F.stepMouse(1); P.refresh() end)
    mouseRow = { frame = mf, value = mvalue, off = moff, minus = mminus, plus = mplus }
    mouseRow.tip = mf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mouseRow.tip:SetPoint("TOPLEFT", mf, "BOTTOMLEFT", 0, -4)
    mouseRow.tip:SetWidth(400)
    mouseRow.tip:SetJustifyH("LEFT")
    mouseRow.tip:SetText("Any element that has a setting goes to this opacity while the mouse is over it, never lower than its own. Hidden for good stays hidden.")
    P.refresh()
    return page
end

function P.frame() return page end

-- The rows of buttons the D-pad moves over (left list first, then the right pane).
function P.navRows()
    local out = {}
    if not page then return out end
    for ci, c in ipairs(UF.Fade.CATEGORIES) do
        if categoryOffered(c) then
            out[#out + 1] = { headers[ci] }
            if openCat == ci then
                for ei, e in ipairs(c.elements) do if offered(e) then out[#out + 1] = { items[ci][ei] } end end
            end
        end
    end
    if sel then
        out[#out + 1] = { hideBtn }
        for _, r in ipairs(stateRows) do out[#out + 1] = { r.normal, r.zero, r.minus, r.plus } end
        out[#out + 1] = { copyBtn, pasteBtn }
        out[#out + 1] = { applyBtn }
        out[#out + 1] = { resetBtn }
    end
    out[#out + 1] = { resetAllBtn }
    out[#out + 1] = { mouseRow.off, mouseRow.minus, mouseRow.plus }
    return out
end

-- Moving by position: the nearest button in the direction pressed, across the left list and the right pane.
-- cands: { { b = button, cx = x, cy = y } ... } (y grows upward, as on screen). Pure, so it can be tested.
function P.pick(cands, fx, fy, dir)
    local best, bestScore
    for _, c in ipairs(cands) do
        local dx, dy = c.cx - fx, c.cy - fy
        local along, across
        if dir == "RIGHT" then along, across = dx, dy
        elseif dir == "LEFT" then along, across = -dx, dy
        elseif dir == "UP" then along, across = dy, dx
        else along, across = -dy, dx end
        if along > 4 then
            local score = along + 3 * math.abs(across)
            if not bestScore or score < bestScore then best, bestScore = c.b, score end
        end
    end
    return best
end

-- All the buttons the D-pad can reach on this page (plus any the caller adds, such as the window's header buttons).
function P.buttons(extra)
    local out = {}
    for _, row in ipairs(P.navRows()) do for _, b in ipairs(row) do out[#out + 1] = b end end
    for _, b in ipairs(extra or {}) do if b and b.IsVisible and b:IsVisible() then out[#out + 1] = b end end
    return out
end

function P.move(dir, extra)
    local Nav = UF.Nav
    local all = P.buttons(extra)
    if #all == 0 then return false end
    local focus = Nav.focus
    local known = false
    for _, b in ipairs(all) do if b == focus then known = true end end
    if not (focus and known and focus:IsVisible()) then
        local first = all[1] == focus and all[2] or P.firstElement() or all[1]
        Nav.SetFocus(first)
        P.reveal(first)
        return true
    end
    local fx, fy = focus:GetCenter()
    if not fx then return false end
    local cands = {}
    for _, b in ipairs(all) do
        if b ~= focus then
            local cx, cy = b:GetCenter()
            if cx then cands[#cands + 1] = { b = b, cx = cx, cy = cy } end
        end
    end
    local nxt = P.pick(cands, fx, fy, dir)
    if nxt then Nav.SetFocus(nxt); P.reveal(nxt) end
    return true
end

-- Where the highlight starts: the chosen element's button, else the first list header.
function P.firstElement()
    if sel then
        for ci, c in ipairs(UF.Fade.CATEGORIES) do
            for ei, e in ipairs(c.elements) do
                if e == sel and items[ci][ei]:IsShown() then return items[ci][ei] end
            end
        end
    end
    return headers and headers[1]
end
