----------------------------------------------------------------------
-- Ubermoc Forever: controller options
-- One window, opened from the game menu (see Menu.lua). Pick a layer (nothing held, Shift button held, Ctrl
-- button held, both), click a row to choose what that button does, X clears the row the cursor is on, Y resets
-- everything to the default. The window uses the game's own frame, button and list templates; if the game's
-- window template is missing the game's dialog textures are used instead.
----------------------------------------------------------------------
local _, UF = ...

local ROW_H = 30
local win, content, picker, legend, info, layerButtons, rows, hovered
local layer = 1

StaticPopupDialogs["UBERMOCFOREVER_RESET"] = {
    text = "Reset every controller bind to the default for %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if UF.applyDefaults(UF.activeSet()) then UF.say("Controller binds reset to the default.") end
        if UF.RefreshOptions then UF.RefreshOptions() end
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

local function actionText(combo)
    local a = UF.actionOf(combo)
    return a and UF.actionName(a) or "|cff888888Not bound|r"
end

local function rowVisible(pad)
    if UF.isModifierButton(pad) then return false end
    if pad:find("^PADPADDLE") and not (UF.activeSet() == "steam" or UF.hasPaddles) then return false end
    if pad == "PADLTRIGGER" or pad == "PADRTRIGGER" then return true end
    return true
end

function UF.RefreshOptions()
    if not win then return end
    local setId = UF.activeSet()
    local d = UF.DB()
    local set = UF.SETS[setId]
    local found = UF.detected and UF.SETS[UF.detected] and UF.SETS[UF.detected].name or "none found"
    -- The game's own name for the device is shown too: on a Steam Deck, Steam Input can hand the game a pad it calls
    -- "Xbox", in which case pick Steam Deck / Steam Controller with the button on the right.
    info:SetText((set and set.name or "?") .. (d.layout == "auto" and "  (detected)" or "  (chosen)"))
    win.controllerBtn:SetText(d.layout == "auto" and "Auto" or (set and set.name or "?"))

    -- layer buttons: what to hold
    local okS, sp = pcall(GetCVar, "GamePadEmulateShift")
    local okC, cp = pcall(GetCVar, "GamePadEmulateCtrl")
    local sg = (okS and sp and sp ~= "NONE") and UF.glyph(sp) or "Shift"
    local cg = (okC and cp and cp ~= "NONE") and UF.glyph(cp) or "Ctrl"
    layerButtons[1]:SetText("Base")
    layerButtons[2]:SetText("Hold " .. sg)
    layerButtons[3]:SetText("Hold " .. cg)
    layerButtons[4]:SetText("Hold " .. sg .. cg)
    for i, b in ipairs(layerButtons) do
        if i == layer then b:LockHighlight() else b:UnlockHighlight() end
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
    picker = CreateFrame("Frame", nil, win)
    picker:SetFrameLevel(win:GetFrameLevel() + 50)
    picker:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -56)
    picker:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 48)
    -- A solid background (the game's own dialog art over black) so nothing behind the list shows through. A backdrop
    -- was tried first and left the rows underneath visible.
    local black = picker:CreateTexture(nil, "BACKGROUND", nil, -2)
    black:SetAllPoints()
    black:SetColorTexture(0, 0, 0, 1)
    local art = picker:CreateTexture(nil, "BACKGROUND", nil, -1)
    art:SetAllPoints()
    art:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    picker:EnableMouse(true)
    picker:Hide()
    picker.head = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    picker.head:SetPoint("TOPLEFT", 14, -12)
    local sf = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -40)
    sf:SetPoint("BOTTOMRIGHT", -30, 10)
    local list = CreateFrame("Frame", nil, sf)
    list:SetSize(460, 10)
    sf:SetScrollChild(list)
    picker.list, picker.buttons, picker.scroll = list, {}, sf

    function picker:Open(pad)
        self.pad = pad
        self.head:SetText("Choose what " .. UF.glyph(pad) .. " does")
        if not self.built then
            self.built = true
            local y = 0
            for _, e in ipairs(collectActions()) do
                if e.header then
                    local fs = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    fs:SetPoint("TOPLEFT", 4, -y - 6)
                    fs:SetText(e.header)
                    y = y + 28
                else
                    local b = CreateFrame("Button", nil, list)
                    b:SetSize(440, 24)
                    b:SetPoint("TOPLEFT", 14, -y)
                    local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    t:SetPoint("LEFT", 4, 0)
                    t:SetText(UF.actionName(e.cmd))
                    b:SetFontString(t)
                    local hl = b:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.12)
                    b:SetScript("OnClick", function()
                        if UF.setBind(UF.combo(layer, picker.pad), e.cmd) then picker:Hide(); UF.RefreshOptions() end
                    end)
                    picker.buttons[#picker.buttons + 1] = b
                    y = y + 24
                end
            end
            list:SetHeight(y + 10)
        end
        self:Show()
        sf:SetVerticalScroll(0)
        legend:Set({ PAD1 = "Select", PAD2 = "Cancel" })
    end
    picker:SetScript("OnHide", function()
        if win and win:IsShown() then
            legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset to default" })
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
    f:SetSize(520, 560)
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

local function build()
    win = makeWindow()
    table.insert(UISpecialFrames, "UbermocForeverOptions")

    win.controllerBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.controllerBtn:SetSize(130, 22)
    win.controllerBtn:SetPoint("TOPRIGHT", -18, -32)

    -- The header stops before the button, so a long controller name can never run into it.
    info = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 18, -36)
    info:SetPoint("RIGHT", win.controllerBtn, "LEFT", -8, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(false)

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

    layerButtons = {}
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(112, 24)
        b:SetPoint("TOPLEFT", 18 + (i - 1) * 118, -62)
        b:SetScript("OnClick", function() layer = i; UF.RefreshOptions() end)
        layerButtons[i] = b
    end

    local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -96)
    sf:SetPoint("BOTTOMRIGHT", -34, 92)
    win.scroll = sf
    content = CreateFrame("Frame", nil, sf)
    content:SetSize(460, 10)
    sf:SetScrollChild(content)

    rows = {}
    for _, pad in ipairs(UF.PAD_ORDER) do
        local r = CreateFrame("Button", nil, content)
        r:SetSize(460, ROW_H)
        r.pad = pad
        r.glyph = r:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        r.glyph:SetPoint("LEFT", 6, 0)
        r.glyph:SetWidth(60)
        r.glyph:SetJustifyH("LEFT")
        r.action = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.action:SetPoint("LEFT", 72, 0)
        r.action:SetPoint("RIGHT", -96, 0)
        r.action:SetJustifyH("LEFT")
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        r.btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.btn:SetSize(86, 22)
        r.btn:SetPoint("RIGHT", -2, 0)
        r.btn:SetText("Change")
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

    legend = UF.CreateLegend(win)
    legend:SetPoint("BOTTOMLEFT", 20, 24)
    legend:Set({ PAD1 = "Select", PAD2 = "Back", PAD3 = "Clear", PAD4 = "Reset to default" })

    local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("BOTTOMRIGHT", -18, 52)
    reset:SetText("Reset to default")
    reset:SetScript("OnClick", function()
        StaticPopup_Show("UBERMOCFOREVER_RESET", (UF.SETS[UF.activeSet()] or {}).name or "this controller")
    end)
    local checks = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    checks:SetSize(90, 24)
    checks:SetPoint("BOTTOMLEFT", 18, 52)
    checks:SetText("Checks")
    checks:SetScript("OnClick", function() UF.reportChecks() end)

    buildPicker()

    -- Moving around: the D-pad jumps the game's own cursor from button to button (Nav.lua), A clicks it for real,
    -- the bumpers change layer, B goes back, X clears the row the cursor is on, Y resets. These buttons are taken
    -- only while this window is open.
    local function pickerOpen() return picker and picker:IsShown() end
    local function focusable()
        local list = {}
        if pickerOpen() then
            for _, b in ipairs(picker.buttons) do list[#list + 1] = b end
            return list
        end
        list[#list + 1] = win.controllerBtn
        for _, b in ipairs(layerButtons) do list[#list + 1] = b end
        for _, r in ipairs(rows) do if r:IsShown() then list[#list + 1] = r.btn end end
        list[#list + 1] = reset
        list[#list + 1] = checks
        if win.CloseButton then list[#list + 1] = win.CloseButton end
        return list
    end
    local function step(direction)
        local scroller = pickerOpen() and picker.scroll or win.scroll
        return UF.Nav.Step(direction, focusable, scroller)
    end
    local function cursorRow()
        local x, y = GetCursorPosition()
        for _, r in ipairs(rows) do
            if r:IsShown() and r:IsVisible() then
                local l, bt, w, h = r:GetRect()
                if l then
                    local s = r:GetEffectiveScale()
                    if x >= l * s and x <= (l + w) * s and y >= bt * s and y <= (bt + h) * s then return r end
                end
            end
        end
    end
    local navMap = {
        PADDUP = function() step("UP") end,
        PADDDOWN = function() step("DOWN") end,
        PADDLEFT = function() step("LEFT") end,
        PADDRIGHT = function() step("RIGHT") end,
        PADLSHOULDER = function() if not pickerOpen() and layer > 1 then layer = layer - 1; UF.RefreshOptions() end end,
        PADRSHOULDER = function() if not pickerOpen() and layer < 4 then layer = layer + 1; UF.RefreshOptions() end end,
        PAD2 = function() if pickerOpen() then picker:Hide() else win:Hide() end end,
        PAD3 = function()
            if pickerOpen() then return end
            local r = cursorRow() or hovered
            if r then UF.setBind(UF.combo(layer, r.pad), nil); UF.RefreshOptions() end
        end,
        PAD4 = function()
            if pickerOpen() then return end
            StaticPopup_Show("UBERMOCFOREVER_RESET", (UF.SETS[UF.activeSet()] or {}).name or "this controller")
        end,
    }
    win:SetScript("OnShow", function()
        pcall(UF.detect)
        if CanAutoSetGamePadCursorControl and CanAutoSetGamePadCursorControl(true) then SetGamePadCursorControl(true) end
        UF.Nav.Enable(navMap)
        UF.RefreshOptions()
    end)
    win:SetScript("OnHide", function()
        picker:Hide()
        UF.Nav.Disable()
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
