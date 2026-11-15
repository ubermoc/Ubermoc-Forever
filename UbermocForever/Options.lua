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

local WIN_W, WIN_H = 580, 560
local ROW_H = 30
local LIST_W = 520            -- width of the rows inside the inset (the inset is WIN_W - 10 wide, minus margins and the scroll bar)
local win, inset, content, picker, legend, info, layerButtons, rows, hovered
local layer = 1

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

local function actionText(combo)
    local a = UF.actionOf(combo)
    return a and UF.actionName(a) or "|cff888888Not bound|r"
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
    info:SetText((set and set.name or "?") .. (d.layout == "auto" and "  (detected)" or "  (chosen)"))
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
            row.action:SetText(actionText(UF.combo(layer, row.pad)))
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
local function collectActions()
    local list, lastCat = {}, nil
    for i = 1, (GetNumBindings() or 0) do
        local cmd, cat = GetBinding(i)
        if cmd and not cmd:find("^HEADER") then
            if cat ~= lastCat then
                -- GetBinding hands back the name of the game's header text ("BINDING_HEADER_MOVEMENT"), not the text
                local text = _G[tostring(cat)]
                if type(text) ~= "string" then text = _G["BINDING_HEADER_" .. tostring(cat)] end
                list[#list + 1] = { header = type(text) == "string" and text or tostring(cat) }
                lastCat = cat
            end
            list[#list + 1] = { cmd = cmd }
        end
    end
    return list
end

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
    picker.list, picker.buttons, picker.scroll = list, { cancel }, sf

    function picker:Open(pad)
        self.pad = pad
        self.head:SetText("Choose what " .. UF.glyph(pad) .. " does")
        if not self.built then
            self.built = true
            local y = 0
            for _, e in ipairs(collectActions()) do
                if e.header then
                    local fs = oneLine(list:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
                    fs:SetPoint("TOPLEFT", 8, -y - 8)
                    fs:SetText(e.header)
                    y = y + 30
                else
                    local b = CreateFrame("Button", nil, list)
                    b:SetSize(LIST_W - 8, 26)
                    b:SetPoint("TOPLEFT", 8, -y)
                    local t = oneLine(b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
                    t:SetPoint("LEFT", 14, 0)
                    t:SetPoint("RIGHT", -8, 0)
                    t:SetText(UF.actionName(e.cmd))
                    b:SetFontString(t)
                    b.navScroll = sf
                    local hl = b:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.12)
                    b:SetScript("OnClick", function()
                        if UF.setBind(UF.combo(layer, picker.pad), e.cmd) then picker:Hide(); UF.RefreshOptions() end
                    end)
                    picker.buttons[#picker.buttons + 1] = b
                    y = y + 26
                end
            end
            list:SetHeight(y + 10)
        end
        -- The list underneath is hidden while the picker is open, so nothing can show through or draw over it.
        win.scroll:Hide()
        for _, b in ipairs(layerButtons) do b:Hide() end
        self:Show()
        sf:SetVerticalScroll(0)
        legend:Set({ PAD1 = "Select", PAD2 = "Cancel" })
        UF.Nav.ClearFocus()
        UF.Nav.SetFocus(self.buttons[2] or self.cancel)
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
            legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset" })
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
    info:SetPoint("RIGHT", win.controllerBtn, "LEFT", -8, 0)

    -- What the game itself calls the device: on a Steam Deck, Steam Input can hand the game a pad it calls "Xbox", in
    -- which case this button switches to Steam Deck / Steam Controller and Reset to default applies that layout.
    win.controllerBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Controller")
        GameTooltip:AddLine("The game reports: " .. (UF.deviceName or "no controller"), 1, 1, 1)
        GameTooltip:AddLine("Click to choose the controller by hand.", 0.8, 0.8, 0.8)
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
        if i == 1 then b:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
        else b:SetPoint("LEFT", layerButtons[i - 1], "RIGHT", 6, 0) end
        b:SetScript("OnClick", function() layer = i; UF.RefreshOptions() end)
        layerButtons[i] = b
    end

    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -40)
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
    legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset" })

    local reset = bottomButton("Reset to default", 140)
    reset:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 4)
    reset:SetScript("OnClick", function()
        StaticPopup_Show("UBERMOCFOREVER_RESET", (UF.SETS[UF.activeSet()] or {}).name or "this controller")
    end)
    local checks = bottomButton("Checks", 70)
    checks:SetPoint("RIGHT", reset, "LEFT", -1, 0)
    checks:SetScript("OnClick", function() UF.reportChecks() end)

    buildPicker()

    -- Moving around (Nav.lua): the D-pad moves a highlight from button to button, A presses the highlighted button,
    -- the bumpers change layer, B goes back, X clears the highlighted row, Y resets. While this window is open these
    -- buttons are taken from the action bars; they are given back when it closes (and by the game when combat starts).
    local Nav = UF.Nav
    local function pickerOpen() return picker and picker:IsShown() end
    local function navRows()
        local out = {}
        if pickerOpen() then
            out[1] = { picker.cancel }
            for i = 2, #picker.buttons do out[#out + 1] = { picker.buttons[i] } end
            return out
        end
        local header = { win.controllerBtn }
        if win.CloseButton and win.CloseButton:IsVisible() then header[2] = win.CloseButton end
        out[1] = header
        out[2] = layerButtons
        for _, r in ipairs(rows) do
            if r:IsShown() then out[#out + 1] = { r.btn } end
        end
        out[#out + 1] = { checks, reset }
        return out
    end
    local function startRow() return pickerOpen() and 2 or 3 end
    local navMap = {
        PADDUP = function() Nav.Move("UP", navRows, startRow()) end,
        PADDDOWN = function() Nav.Move("DOWN", navRows, startRow()) end,
        PADDLEFT = function() Nav.Move("LEFT", navRows, startRow()) end,
        PADDRIGHT = function() Nav.Move("RIGHT", navRows, startRow()) end,
        PAD1 = function()
            if not Nav.Click() then Nav.Move("DOWN", navRows, startRow()) end
        end,
        PADLSHOULDER = function() if not pickerOpen() and layer > 1 then layer = layer - 1; UF.RefreshOptions() end end,
        PADRSHOULDER = function() if not pickerOpen() and layer < 4 then layer = layer + 1; UF.RefreshOptions() end end,
        PAD2 = function() if pickerOpen() then picker:Hide() else win:Hide() end end,
        PAD3 = function()
            if pickerOpen() then return end
            local f = Nav.focus
            local r = (f and f.navRow) or hovered
            if r then UF.setBind(UF.combo(layer, r.pad), nil); UF.RefreshOptions() end
        end,
        PAD4 = function()
            if pickerOpen() then return end
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
        Nav.Move("DOWN", navRows, 3)   -- highlight the first row
    end)
    win:SetScript("OnHide", function()
        picker:Hide()
        if navToken then Nav.Pop(navToken); navToken = nil end
        Nav.ClearFocus()
        if CanAutoSetGamePadCursorControl and CanAutoSetGamePadCursorControl(false) then SetGamePadCursorControl(false) end
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() if win:IsShown() then win:Hide() end end)
    UF.OnDetect(function() if win:IsShown() then UF.RefreshOptions() end end)
end

function UF.ToggleOptions(forceShow)
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
