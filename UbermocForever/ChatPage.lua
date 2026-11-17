----------------------------------------------------------------------
-- Ubermoc Forever: the Chat page of the options window (third page). Everything to do with chat is here and nowhere else:
-- lines fading by themselves, the chat window appearing on a new message, and the opacity of each chat part (window, tabs, edit
-- box, buttons, quick join) in the same three situations as the Fading page. Modelled on Ubermoc UI's Chat page (Fade / Tabs / Messages).
-- The tabs are only ever changed by their own setting here: a new message or typing does not open them.
----------------------------------------------------------------------
local ADDON, UF = ...
local CP = {}
UF.ChatPage = CP

local page, topRow, pickBtns, stateRows, titleFS, hideBtn, resetBtn, noteFS
local sel
local SHORT = { chat = "Window", chattabs = "Tabs", chatedit = "Edit box", chatbtns = "Buttons", quickjoin = "Quick join" }
local WIDTHS = { chat = 110, chattabs = 90, chatedit = 110, chatbtns = 110, quickjoin = 120 }

local function button(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text or "")
    return b
end

function CP.refresh()
    if not page then return end
    local F, Ch = UF.Fade, UF.Chat
    topRow.fade:SetText("Chat fade: " .. (Ch.cfg().on and "On" or "Off"))
    topRow.vis:SetText("Visible: " .. Ch.visibleName())
    topRow.out:SetText("Fade-out: " .. Ch.fadeName())
    topRow.reveal:SetText("Reveal on message: " .. (Ch.cfg().reveal and "On" or "Off"))
    for _, b in ipairs(pickBtns) do
        local fs = b:GetFontString()
        local set = F.get(b.element.key) ~= nil
        if fs then
            if F.found(b.element) == 0 then fs:SetTextColor(0.5, 0.5, 0.5)
            elseif set then fs:SetTextColor(1, 0.82, 0)
            else fs:SetTextColor(1, 1, 1) end
        end
        b:SetText((sel == b.element and "> " or "") .. SHORT[b.element.key])
    end
    local hid = F.hidden(sel.key)
    titleFS:SetText(sel.label)
    for _, r in ipairs(stateRows) do
        r.value:SetText(F.percentText(F.value(sel.key, r.state)))
        r.frame:SetAlpha(hid and 0.5 or 1)
    end
    hideBtn:SetText("Hide for good: " .. (hid and "On" or "Off"))
end

function CP.build(parent, inset)
    if page then return page end
    local F, Ch = UF.Fade, UF.Chat
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

    -- Lines and the new-message reveal (Chat.lua)
    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    head:SetText("Messages")
    topRow = {}
    topRow.fade = button(page, 150, 24); topRow.fade:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
    topRow.vis = button(page, 130, 24); topRow.vis:SetPoint("LEFT", topRow.fade, "RIGHT", 6, 0)
    topRow.out = button(page, 140, 24); topRow.out:SetPoint("LEFT", topRow.vis, "RIGHT", 6, 0)
    topRow.reveal = button(page, 210, 24); topRow.reveal:SetPoint("LEFT", topRow.out, "RIGHT", 6, 0)
    topRow.fade:SetScript("OnClick", function() Ch.toggle(); CP.refresh() end)
    topRow.vis:SetScript("OnClick", function() Ch.nextVisible(); CP.refresh() end)
    topRow.out:SetScript("OnClick", function() Ch.nextFade(); CP.refresh() end)
    topRow.reveal:SetScript("OnClick", function() Ch.toggleReveal(); CP.refresh() end)
    tip(topRow.fade, "Chat fade", "Every chat line fades out by itself a few seconds after it appears, in every chat window. Off puts your old chat settings back.")
    tip(topRow.vis, "Visible", "How long a line stays (and a faded chat window stays shown after a message) before it fades. Press to step through the choices.")
    tip(topRow.out, "Fade-out", "How long the fade-out takes. Press to step through the choices.")
    tip(topRow.reveal, "Reveal on message", "A chat window you have faded below appears fully when a message arrives, then fades back. Tabs are not opened by this. While you type, the chat window and edit box stay shown until the message is sent.")

    -- One part of the chat at a time, with the same situations as the Fading page
    local head2 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head2:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -62)
    head2:SetText("Opacity of each part of the chat")
    pickBtns = {}
    local prev
    for _, e in ipairs(F.CHAT) do
        local b = button(page, WIDTHS[e.key] or 110, 24, SHORT[e.key])
        b.element = e
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -84) end
        b:SetScript("OnClick", function() sel = e; CP.refresh() end)
        pickBtns[#pickBtns + 1] = b
        prev = b
    end
    sel = F.CHAT[1]

    titleFS = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -124)
    stateRows = {}
    for i, st in ipairs(F.STATES) do
        local fr = CreateFrame("Frame", nil, page)
        fr:SetSize(440, 26)
        fr:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -156 - (i - 1) * 34)
        local lab = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lab:SetPoint("LEFT", 0, 0); lab:SetWidth(120); lab:SetJustifyH("LEFT"); lab:SetText(st.label)
        local normal = button(fr, 62, 24, "Normal"); normal:SetPoint("LEFT", 124, 0)
        local zero = button(fr, 30, 24, "0"); zero:SetPoint("LEFT", normal, "RIGHT", 2, 0)
        local minus = button(fr, 30, 24, "-"); minus:SetPoint("LEFT", zero, "RIGHT", 8, 0)
        local value = fr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("LEFT", minus, "RIGHT", 2, 0); value:SetWidth(56)
        local plus = button(fr, 30, 24, "+"); plus:SetPoint("LEFT", value, "RIGHT", 2, 0)
        normal:SetScript("OnClick", function() F.set(sel.key, st.key, nil); CP.refresh() end)
        zero:SetScript("OnClick", function() F.set(sel.key, st.key, 0); CP.refresh() end)
        minus:SetScript("OnClick", function() F.step(sel.key, st.key, -1); CP.refresh() end)
        plus:SetScript("OnClick", function() F.step(sel.key, st.key, 1); CP.refresh() end)
        stateRows[i] = { frame = fr, state = st.key, value = value, normal = normal, zero = zero, minus = minus, plus = plus }
    end
    local y = -156 - #F.STATES * 34
    hideBtn = button(page, 200, 24); hideBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 6)
    hideBtn:SetScript("OnClick", function() F.toggleHide(sel.key); CP.refresh() end)
    resetBtn = button(page, 200, 24, "Reset this part"); resetBtn:SetPoint("LEFT", hideBtn, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function() F.reset(sel.key); CP.refresh() end)
    noteFS = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteFS:SetPoint("TOPLEFT", hideBtn, "BOTTOMLEFT", 0, -12)
    noteFS:SetWidth(640); noteFS:SetJustifyH("LEFT")
    noteFS:SetText("Normal leaves the game's own opacity; the first situation that is on and has a value wins, in the order above. The tabs follow only their own setting here: a new message or typing does not open them.")
    CP.refresh()
    return page
end

function CP.frame() return page end

-- The rows the D-pad moves over.
function CP.navRows()
    local out = {}
    if not page then return out end
    out[1] = { topRow.fade, topRow.vis, topRow.out, topRow.reveal }
    local picks = {}
    for _, b in ipairs(pickBtns) do picks[#picks + 1] = b end
    out[2] = picks
    for _, r in ipairs(stateRows) do out[#out + 1] = { r.normal, r.zero, r.minus, r.plus } end
    out[#out + 1] = { hideBtn, resetBtn }
    return out
end
