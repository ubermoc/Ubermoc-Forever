----------------------------------------------------------------------
-- Ubermoc Forever: options window
-- One window, opened from the game menu (see Menu.lua). Pick a layer (nothing held, Shift button held, Ctrl
-- button held, both), click a row to choose what that button does, X clears the row the cursor is on, Y resets
-- everything to the default.
--
-- It is laid out the way the game lays out its own windows (Blizzard_SharedXML ButtonFrameTemplate): a header
-- band under the title, the content inside the frame's marble inset, and the action buttons in the bottom bar as
-- "magic" buttons. Every piece of text is one line, so nothing can wrap into the row below it.
----------------------------------------------------------------------
local _, UF = ...

local WIN_W, WIN_H = 680, 560
local ROW_H = 30
local LIST_W = 620            -- width of the rows inside the inset (the inset is WIN_W - 10 wide, minus margins and the scroll bar)
local win, inset, content, picker, legend, info, layerButtons, rows, hovered
local layer = 1
local pageBtn, pageNo = nil, 1   -- the page switch (1 = settings and binds, 2 = fading)
local cineBtn, barsBtn, edgesBtn, aimBtn, distBtn, sizeBtn   -- declared here, above every function that uses it
function UF.optionsLayer() return layer end
function UF.optionsPage() return pageNo end   -- for the offline test   -- for the offline test

StaticPopupDialogs["UBERMOCFOREVER_RESET"] = {
    text = "Reset every controller bind to the default for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if UF.applyDefaults(UF.activeSet()) then UF.say("Controller binds reset to the default.") end
        if UF.RefreshOptions then UF.RefreshOptions() end
    end,
    OnShow = function(self) UF.Nav.TakePopup(self) end,
    OnHide = function(self) UF.Nav.ReleasePopup(self) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

local function oneLine(fs)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function actionText(combo, pad)
    local a = UF.actionOf(combo)
    if a then return UF.actionName(a) end
    -- the game's Escape button, with nothing bound on this layer, shows as Exit
    if UF.isExitRow(combo, pad) then return "Exit (Escape)" end
    return "|cffa0a0a0Not bound|r"
end

local function rowVisible(pad)
    if UF.isModifierButton(pad) then return false end
    if pad:find("^PADPADDLE") and not (UF.activeSet() == "steam" or UF.hasPaddles) then return false end
    return true
end

function UF.RefreshOptions()
    if not win then return end
    local setId = UF.activeSet()
    local d = UF.DB()
    local set = UF.SETS[setId]
    if aimBtn and UF.Aim then
        aimBtn:SetText("Aim dot: " .. (UF.Aim.cfg().on and "On" or "Off"))
        distBtn:SetText("Aim distance: " .. UF.Aim.distanceName())
        sizeBtn:SetText("Dot: " .. UF.Aim.sizeName())
    end
    if barsBtn and UF.Cinematic then
        barsBtn:SetText("Bars: " .. UF.Cinematic.barsName())
        edgesBtn:SetText("Edges: " .. UF.Cinematic.edgesName())
    end
    if pageBtn then pageBtn:SetText(pageNo == 2 and "Page: Fading" or "Page: Settings") end
    if pageNo == 2 and UF.FadePage then UF.FadePage.refresh() end
    if cineBtn then cineBtn:SetText("Cinematic mode: " .. (d.cinema == false and "Off" or "On")) end
    info:SetText((set and set.name or "?") .. (d.layout == "auto" and "  (detected)" or "  (chosen)") .. "  |cff808080v" .. UF.getVersion() .. "|r")
    -- A short name on the button, sized to fit: the full name is in the line to its left.
    win.controllerBtn:SetText(d.layout == "auto" and "Auto" or (set and set.short or "?"))
    win.controllerBtn:SetWidth(math.max(110, math.min(190, (win.controllerBtn:GetTextWidth() or 0) + 28)))

    -- layer buttons: what to hold
    local okS, sp = pcall(GetCVar, "GamePadEmulateShift")
    local okC, cp = pcall(GetCVar, "GamePadEmulateCtrl")
    local sg = (okS and sp and sp ~= "NONE") and UF.glyph(sp) or "Shift"
    local cg = (okC and cp and cp ~= "NONE") and UF.glyph(cp) or "Ctrl"
    layerButtons[1]:SetText("Base")
    layerButtons[2]:SetText("Hold " .. sg)
    layerButtons[3]:SetText("Hold " .. cg)
    layerButtons[4]:SetText("Hold " .. sg .. cg)
    -- the chosen layer shows as a pressed button; the highlight is kept for the button the D-pad is on
    for i, b in ipairs(layerButtons) do
        if i == layer then b:SetButtonState("PUSHED", true) else b:SetButtonState("NORMAL", false) end
    end

    local y = 0
    for _, row in ipairs(rows) do
        if rowVisible(row.pad) then
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            y = y + ROW_H
            row.glyph:SetText(UF.glyph(row.pad, setId))
            row.action:SetText(actionText(UF.combo(layer, row.pad), row.pad))
        else
            row:Hide()
        end
    end
    content:SetHeight(math.max(y, 1))
    legend:Refresh()
end

----------------------------------------------------------------------
-- Choosing an action
----------------------------------------------------------------------
-- The game's own binding categories, the way its Key Bindings page reads them (Blizzard_SettingsDefinitions_Frame):
-- GetBinding gives the name of the header text ("BINDING_HEADER_MOVEMENT"), which is looked up to get the words; a
-- binding with no category at all belongs to "Other"; entries whose action starts with HEADER or PREFACE are spacers
-- and notes, not actions. (A binding with no category used to break this list: a nil can't be a table key.)
local function collectGroups()
    local groups, byTitle = {}, {}
    local other = _G.BINDING_HEADER_OTHER or "Other"
    for i = 1, (GetNumBindings() or 0) do
        local cmd, cat = GetBinding(i)
        if cmd and not cmd:find("^HEADER") and not cmd:find("^PREFACE") then
            local title = other
            if cat then
                local text = _G[tostring(cat)]
                if type(text) ~= "string" then text = _G["BINDING_HEADER_" .. tostring(cat)] end
                title = type(text) == "string" and text or tostring(cat)
            end
            local g = byTitle[title]
            if not g then
                g = { title = title, cmds = {} }
                byTitle[title] = g
                groups[#groups + 1] = g
            end
            g.cmds[#g.cmds + 1] = cmd
        end
    end
    return groups
end

local HEAD_H, ITEM_H = 28, 26
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"   -- the game's own expand / collapse art

local function buildPicker()
    -- The game's own inset (marble background and border) laid exactly over the window's inset, so it covers the list
    -- underneath completely. Falls back to plain black if the template is missing.
    local ok, f = pcall(CreateFrame, "Frame", nil, win, "InsetFrameTemplate")
    picker = ok and f or CreateFrame("Frame", nil, win)
    -- Drawn in a higher layer than the window, not just a higher level: in the game a raised level alone left the rows and
    -- layer buttons drawing on top of the picker. Its children are created after this, so they follow it.
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(100)
    picker:SetAllPoints(inset)
    local black = picker:CreateTexture(nil, "BACKGROUND", nil, -8)
    black:SetAllPoints()
    black:SetColorTexture(0, 0, 0, 1)
    picker:EnableMouse(true)
    picker:Hide()

    picker.head = oneLine(picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
    picker.head:SetPoint("TOPLEFT", 14, -14)

    local cancel = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancel:SetSize(90, 22)
    cancel:SetPoint("TOPRIGHT", -10, -8)
    cancel:SetText(CANCEL or "Cancel")
    cancel:SetScript("OnClick", function() picker:Hide() end)
    picker.cancel = cancel

    local sf = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -42)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local list = CreateFrame("Frame", nil, sf)
    list:SetSize(LIST_W, 10)
    sf:SetScrollChild(list)
    picker.list, picker.scroll = list, sf

    -- One line of the list: highlight on hover, text on one line.
    local function newLine(parent, height, font, indent)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(LIST_W - 8, height)
        local t = oneLine(b:CreateFontString(nil, "OVERLAY", font))
        t:SetPoint("LEFT", indent, 0)
        t:SetPoint("RIGHT", -8, 0)
        b:SetFontString(t)
        b.label = t
        b.navScroll = sf
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.12)
        return b
    end

    -- Lay the list out: the Exit line, then every category; only the open category shows its actions.
    local function relayout()
        local y = 0
        picker.groups = picker.groups or {}
        if picker.exit then
            picker.exit:Show()
            picker.exit:ClearAllPoints()
            picker.exit:SetPoint("TOPLEFT", 8, -y)
            y = y + ITEM_H + 6
        end
        for _, g in ipairs(picker.groups) do
            g.header:ClearAllPoints()
            g.header:SetPoint("TOPLEFT", 8, -y)
            g.header.icon:SetTexture(g.open and MINUS or PLUS)
            y = y + HEAD_H
            for _, b in ipairs(g.items) do
                if g.open then
                    b:Show()
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 8, -y)
                    y = y + ITEM_H
                else
                    b:Hide()
                end
            end
        end
        list:SetHeight(y + 10)
    end

    -- Opening a category closes the one that was open: one at a time.
    local function toggle(g)
        local was = g.open
        for _, other in ipairs(picker.groups) do other.open = false end
        g.open = not was
        relayout()
        -- keep the highlight on the header and in view once the layout has settled
        C_Timer.After(0, function()
            if picker:IsShown() then UF.Nav.SetFocus(g.header) end
        end)
    end

    local function build()
        picker.groups = {}

        -- Exit first, so it is there even if the categories cannot be built
        local exit = newLine(list, ITEM_H, "GameFontHighlight", 28)
        exit.label:SetText("Exit / game menu (Start)")
        exit:SetScript("OnClick", function()
            if UF.setBind(UF.combo(layer, picker.pad), UF.START_BIND) then picker:Hide(); UF.RefreshOptions() end
        end)
        picker.exit = exit

        local okGroups, groups = pcall(collectGroups)
        if not okGroups then
            UF.say("The list of actions could not be read: " .. tostring(groups))
            UF.check("Action list", false, tostring(groups))
            picker.built = true
            return
        end
        picker.groups = groups
        picker.built = true

        for _, g in ipairs(picker.groups) do
            local h = newLine(list, HEAD_H, "GameFontNormal", 28)
            h.icon = h:CreateTexture(nil, "ARTWORK")
            h.icon:SetSize(16, 16)
            h.icon:SetPoint("LEFT", 6, 0)
            h.label:SetText(g.title)
            h:SetScript("OnClick", function() toggle(g) end)
            g.header, g.items, g.open = h, {}, false
            for _, cmd in ipairs(g.cmds) do
                local b = newLine(list, ITEM_H, "GameFontHighlight", 40)
                b.label:SetText(UF.actionName(cmd))
                b:SetScript("OnClick", function()
                    if UF.setBind(UF.combo(layer, picker.pad), cmd) then picker:Hide(); UF.RefreshOptions() end
                end)
                g.items[#g.items + 1] = b
            end
        end
    end

    -- The rows the D-pad walks, top to bottom: Cancel, Exit, then each category and, under the open one, its actions.
    function picker.navRows()
        local out = { { cancel } }
        if picker.exit and picker.exit:IsShown() then out[#out + 1] = { picker.exit } end
        for _, g in ipairs(picker.groups or {}) do
            out[#out + 1] = { g.header }
            if g.open then
                for _, b in ipairs(g.items) do out[#out + 1] = { b } end
            end
        end
        return out
    end

    function picker:Open(pad)
        self.pad = pad
        self.head:SetText("Choose what " .. UF.glyph(pad) .. " does")
        if not self.built then
            local ok, err = pcall(build)
            if not ok then
                self.built = false   -- try again next time
                UF.say("The list of actions could not be built: " .. tostring(err))
                UF.check("Action list", false, tostring(err))
            end
        end
        for _, g in ipairs(self.groups or {}) do g.open = false end   -- every category starts closed
        relayout()
        -- The list underneath is hidden while the picker is open, so nothing can show through or draw over it.
        win.scroll:Hide()
        for _, b in ipairs(layerButtons) do b:Hide() end
        self:Show()
        sf:SetVerticalScroll(0)
        legend:Set({ PAD1 = "Select", PAD2 = "Cancel" })
        UF.Nav.ClearFocus()
        UF.Nav.SetFocus(self.exit or ((self.groups or {})[1] and self.groups[1].header) or cancel)
    end
    picker:SetScript("OnHide", function()
        win.scroll:Show()
        for _, b in ipairs(layerButtons) do b:Show() end
        -- back on the row that was being changed
        UF.Nav.ClearFocus()
        for _, r in ipairs(rows) do
            if r.pad == picker.pad and r:IsShown() then UF.Nav.SetFocus(r.btn); break end
        end
        if win and win:IsShown() then
            legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset", PADLSHOULDER = "Prev", PADRSHOULDER = "Next", PADRTRIGGER = "Page" })
        end
    end)
end

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
local function makeWindow()
    local f
    local ok = pcall(function() f = CreateFrame("Frame", "UbermocForeverOptions", UIParent, "ButtonFrameTemplate") end)
    if ok and f then
        if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
        if f.SetTitle then pcall(f.SetTitle, f, UF.title) end
    else
        f = CreateFrame("Frame", "UbermocForeverOptions", UIParent, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", 0, -16)
        t:SetText(UF.title)
        local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        x:SetPoint("TOPRIGHT", -4, -4)
    end
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    return f
end

-- The frame's own inset, or one made the same way (ButtonFrameTemplate: top left 4,-60, bottom right -6,26).
local function makeInset()
    if win.Inset then return win.Inset end
    local ok, f = pcall(CreateFrame, "Frame", nil, win, "InsetFrameTemplate")
    local i = ok and f or CreateFrame("Frame", nil, win)
    i:SetPoint("TOPLEFT", 4, -60)
    i:SetPoint("BOTTOMRIGHT", -6, 26)
    return i
end

-- A button for the bottom bar: the game's magic button, else a plain panel button.
local function bottomButton(text, width)
    local ok, b = pcall(CreateFrame, "Button", nil, win, "MagicButtonTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate") end
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

local function build()
    win = makeWindow()
    inset = makeInset()
    table.insert(UISpecialFrames, "UbermocForeverOptions")

    -- Header band, between the title and the inset: what controller this is, and the button to choose it by hand.
    win.controllerBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.controllerBtn:SetSize(140, 22)
    win.controllerBtn:SetPoint("TOPRIGHT", -12, -32)
    info = oneLine(win:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    info:SetPoint("LEFT", win, "TOPLEFT", 16, -43)
    -- The page switch: the binds and settings, or the fading of the game's interface (FadePage.lua).
    pageBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    pageBtn:SetSize(130, 22)
    pageBtn:SetPoint("RIGHT", win.controllerBtn, "LEFT", -6, 0)
    -- Cinematic camera while talking to an NPC (Cinematic.lua): one button, On or Off.
    cineBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    cineBtn:SetSize(160, 22)
    cineBtn:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    cineBtn:SetScript("OnClick", function()
        local d = UF.DB()
        d.cinema = (d.cinema == false)
        if d.cinema == false and UF.Cinematic then UF.Cinematic.stopNow() end
        if UF.DialogButtons then UF.DialogButtons.refresh() end
        UF.RefreshOptions()
    end)
    cineBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Cinematic mode")
        GameTooltip:AddLine("While you talk to a quest giver or other NPC, the camera moves in and the screen gets black bars. The game's own quest window is not changed, and the A and B pictures are added to its buttons.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cineBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function cineButton(width, prev, click, tip)
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        b:SetScript("OnClick", function() click(); UF.RefreshOptions() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip[1])
            GameTooltip:AddLine(tip[2], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    barsBtn = cineButton(140, cineBtn, function() UF.Cinematic.nextBars() end, { "Black bars", "How thick the black bars at the top and bottom are during a talk. Press to step through the choices; a short preview shows it." })
    edgesBtn = cineButton(150, barsBtn, function() UF.Cinematic.nextEdges() end, { "Dark edges", "How far the dark, cloudy edges come in during a talk. Press to step through the choices; a short preview shows it." })

    -- Second row: the aim dot for ground spells (Aim.lua).
    local function aimButton(width, prev, click, tip)
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -36) end
        b:SetScript("OnClick", function() click(); UF.RefreshOptions() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip[1])
            GameTooltip:AddLine(tip[2], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    aimBtn = aimButton(120, nil, function() UF.Aim.toggle() end, { "Aim dot", "A white dot shows where a ground spell (Heroic Leap, Blizzard, Rain of Fire) will land, only while you are aiming it." })
    distBtn = aimButton(180, aimBtn, function() UF.Aim.nextDistance() end, { "Aim distance", "How far from your character the aim point rests (higher on the screen is further). Exact yards cannot be set. Press to step through the choices." })
    sizeBtn = aimButton(100, distBtn, function() UF.Aim.nextSize() end, { "Dot size", "Small, medium or large." })
    info:SetPoint("RIGHT", pageBtn, "LEFT", -8, 0)

    -- What the game itself calls the device: on a Steam Deck, Steam Input can hand the game a pad it calls "Xbox", in
    -- which case this button switches to Steam Deck / Steam Controller and Reset to default applies that layout.
    win.controllerBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Controller")
        GameTooltip:AddLine("The game reports: " .. (UF.deviceName or "no controller"), 1, 1, 1)
        GameTooltip:AddLine("Click to choose the controller by hand.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Ubermoc Forever " .. UF.getVersion(), 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    win.controllerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.controllerBtn:SetScript("OnClick", function()
        -- Auto, then each controller in turn
        local d = UF.DB()
        local order = { "auto" }
        for _, id in ipairs(UF.SET_ORDER) do order[#order + 1] = id end
        local idx = 1
        for i, id in ipairs(order) do if id == d.layout then idx = i end end
        d.layout = order[idx % #order + 1]
        UF.RefreshOptions()
    end)

    -- Inside the inset: the four layers across the top, then the list.
    layerButtons = {}
    local widths = { 94, 134, 134, 160 }
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(widths[i], 24)
        if i == 1 then b:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -64)
        else b:SetPoint("LEFT", layerButtons[i - 1], "RIGHT", 6, 0) end
        b:SetScript("OnClick", function() layer = i; UF.RefreshOptions() end)
        layerButtons[i] = b
    end

    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -96)
    sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -28, 8)
    win.scroll = sf
    content = CreateFrame("Frame", nil, sf)
    content:SetSize(LIST_W, 10)
    sf:SetScrollChild(content)

    rows = {}
    for _, pad in ipairs(UF.PAD_ORDER) do
        local r = CreateFrame("Button", nil, content)
        r:SetSize(LIST_W, ROW_H)
        r.pad = pad
        r.glyph = oneLine(r:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
        r.glyph:SetPoint("LEFT", 8, 0)
        r.glyph:SetWidth(64)
        r.action = oneLine(r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        r.action:SetPoint("LEFT", 80, 0)
        r.action:SetPoint("RIGHT", -104, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        local sep = r:CreateTexture(nil, "BACKGROUND")
        sep:SetColorTexture(1, 1, 1, 0.06)
        sep:SetPoint("BOTTOMLEFT", 4, 0)
        sep:SetPoint("BOTTOMRIGHT", -4, 0)
        sep:SetHeight(1)
        r.btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.btn:SetSize(92, 22)
        r.btn:SetPoint("RIGHT", -4, 0)
        r.btn:SetText("Change")
        r.btn.navRow = r
        r.btn.navScroll = sf
        local function choose()
            if InCombatLockdown() then UF.say("Binds can't be changed in combat."); return end
            picker:Open(pad)
        end
        r:SetScript("OnClick", choose)
        r.btn:SetScript("OnClick", choose)
        r:SetScript("OnEnter", function() hovered = r end)
        r:SetScript("OnLeave", function() if hovered == r then hovered = nil end end)
        r.btn:HookScript("OnEnter", function() hovered = r end)
        r.btn:HookScript("OnLeave", function() if hovered == r then hovered = nil end end)
        rows[#rows + 1] = r
    end

    -- The bottom bar: the legend on the left, the action buttons on the right (the game's magic buttons).
    legend = UF.CreateLegend(win)
    legend:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 3)
    legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset", PADLSHOULDER = "Prev", PADRSHOULDER = "Next" })

    local reset = bottomButton("Reset to default", 120)
    reset:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 4)
    reset:SetScript("OnClick", function()
        StaticPopup_Show("UBERMOCFOREVER_RESET", (UF.SETS[UF.activeSet()] or {}).name or "this controller")
    end)
    local checks = bottomButton("Checks", 60)
    checks:SetPoint("RIGHT", reset, "LEFT", -1, 0)
    checks:SetScript("OnClick", function() UF.reportChecks() end)

    buildPicker()

    -- Moving around (Nav.lua): the D-pad moves a highlight from button to button, A presses the highlighted button,
    -- the bumpers change layer, B goes back, X clears the highlighted row, Y resets. While this window is open these
    -- buttons are taken from the action bars; they are given back when it closes (and by the game when combat starts).
    local Nav = UF.Nav
    -- Switching page: the settings page's pieces hide, the fading page shows (built the first time).
    local function showPage(n)
        pageNo = n
        local fadeFrame = UF.FadePage.build(win, inset)
        local one = { cineBtn, barsBtn, edgesBtn, aimBtn, distBtn, sizeBtn, win.scroll }
        for _, b in ipairs(layerButtons) do one[#one + 1] = b end
        for _, f in ipairs(one) do if f then f:SetShown(n == 1) end end
        fadeFrame:SetShown(n == 2)
        if n == 2 then
            legend:Set({ PAD1 = "Press", PAD2 = "Back", PADRTRIGGER = "Page" })
        else
            legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset", PADLSHOULDER = "Prev", PADRSHOULDER = "Next", PADRTRIGGER = "Page" })
        end
        UF.RefreshOptions()
    end
    pageBtn:SetScript("OnClick", function() showPage(pageNo == 1 and 2 or 1) end)
    local function pickerOpen() return picker and picker:IsShown() end
    local function navRows()
        local out = {}
        if pickerOpen() then return picker.navRows() end
        local header = { pageBtn, win.controllerBtn }   -- left to right as drawn: Page, the controller button, then the X
        if win.CloseButton and win.CloseButton:IsVisible() then header[3] = win.CloseButton end
        out[1] = header
        if pageNo == 2 then
            for _, r in ipairs(UF.FadePage.navRows()) do out[#out + 1] = r end
            return out
        end
        out[2] = { cineBtn, barsBtn, edgesBtn }
        out[3] = { aimBtn, distBtn, sizeBtn }
        out[4] = layerButtons
        for _, r in ipairs(rows) do
            if r:IsShown() then out[#out + 1] = { r.btn } end
        end
        out[#out + 1] = { checks, reset }
        return out
    end
    local function startRow() return (pickerOpen() or pageNo == 2) and 2 or 5 end
    local navMap = {
        PADDUP = function()
            -- the header's Page and controller buttons sit below the X: up goes to it
            local f = Nav.focus
            local x = win.CloseButton
            if not pickerOpen() and x and x:IsVisible() and (f == pageBtn or f == win.controllerBtn) then
                Nav.SetFocus(x)
                return
            end
            if pageNo == 2 and not pickerOpen() then UF.FadePage.move("UP", { win.controllerBtn, pageBtn, win.CloseButton }) else Nav.Move("UP", navRows, startRow()) end
        end,
        PADDDOWN = function() if pageNo == 2 and not pickerOpen() then UF.FadePage.move("DOWN", { win.controllerBtn, pageBtn, win.CloseButton }) else Nav.Move("DOWN", navRows, startRow()) end end,
        PADDLEFT = function() if pageNo == 2 and not pickerOpen() then UF.FadePage.move("LEFT", { win.controllerBtn, pageBtn, win.CloseButton }) else Nav.Move("LEFT", navRows, startRow()) end end,
        PADDRIGHT = function() if pageNo == 2 and not pickerOpen() then UF.FadePage.move("RIGHT", { win.controllerBtn, pageBtn, win.CloseButton }) else Nav.Move("RIGHT", navRows, startRow()) end end,
        PAD1 = function()
            if not Nav.Click() then
                if pageNo == 2 and not pickerOpen() then UF.FadePage.move("DOWN", { win.controllerBtn, pageBtn, win.CloseButton })
                else Nav.Move("DOWN", navRows, startRow()) end
            end
        end,
        -- the triggers go through the pages: settings, fading
        PADLTRIGGER = function() if not pickerOpen() then showPage(pageNo == 1 and 2 or 1) end end,
        PADRTRIGGER = function() if not pickerOpen() then showPage(pageNo == 1 and 2 or 1) end end,
        PADLSHOULDER = function() if not pickerOpen() and pageNo == 1 then layer = layer == 1 and 4 or layer - 1; UF.RefreshOptions() end end,
        PADRSHOULDER = function() if not pickerOpen() and pageNo == 1 then layer = layer == 4 and 1 or layer + 1; UF.RefreshOptions() end end,
        PAD2 = function() if pickerOpen() then picker:Hide() else win:Hide() end end,
        PAD3 = function()
            if pickerOpen() or pageNo == 2 then return end
            local f = Nav.focus
            local r = (f and f.navRow) or hovered
            if r then
                local combo = UF.combo(layer, r.pad)
                -- an Exit row has no bind to clear: clearing it turns the Escape button off
                if UF.isExitRow(combo, r.pad) then UF.clearExit() else UF.setBind(combo, nil) end
                UF.RefreshOptions()
            end
        end,
        PAD4 = function()
            if pickerOpen() or pageNo == 2 then return end
            StaticPopup_Show("UBERMOCFOREVER_RESET", (UF.SETS[UF.activeSet()] or {}).name or "this controller")
        end,
    }
    local navToken
    win:SetScript("OnShow", function()
        pcall(UF.detect)
        if CanAutoSetGamePadCursorControl and CanAutoSetGamePadCursorControl(true) then SetGamePadCursorControl(true) end
        UF.RefreshOptions()
        navToken = Nav.Push(navMap)
        Nav.ClearFocus()
        Nav.Move("DOWN", navRows, 5)   -- highlight the first row
    end)
    win:SetScript("OnHide", function()
        picker:Hide()
        if navToken then Nav.Pop(navToken); navToken = nil end
        Nav.ClearFocus()
        if CanAutoSetGamePadCursorControl and CanAutoSetGamePadCursorControl(false) then SetGamePadCursorControl(false) end
    end)
    UF.OnDetect(function() if win:IsShown() then UF.RefreshOptions() end end)
end

function UF.ToggleOptions(forceShow)
    if UF.Nav.InCombat() and (forceShow == true or not (win and win:IsShown())) then
        UF.say("Can't open this in combat.")
        return
    end
    if not win then
        local ok, err = pcall(build)
        if not ok then
            win = nil
            UF.check("Options window", false, tostring(err))
            UF.say("The options window could not be built: " .. tostring(err))
            return
        end
    end
    if forceShow == true or not win:IsShown() then win:Show() else win:Hide() end
end
