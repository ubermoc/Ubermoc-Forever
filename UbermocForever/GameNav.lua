----------------------------------------------------------------------
-- Ubermoc Forever: moving around the game's own windows (bags, character, map, game menu, question windows ...)
--
-- While one of the game's windows is open (and it is not combat), the controller buttons are taken (through Nav) and
-- used like this:
--   D-pad          move a drawn highlight from button to button (the mouse never moves)
--   A / X          left / right click on the highlighted button, from a real secure button, so protected things
--                  (using an item, picking it up) work the way a mouse click would
--   B              closes the window the highlight is in (its own close button, or for a question window its second
--                  button); the highlight then jumps to another open window, so B three times closes three windows
--   bumpers        the previous / next tab or page of the group of tabs nearest the highlight, wrapping round
--   triggers       scroll the list the highlight is in up / down; the list also scrolls by itself to show the highlight
--
-- How it was designed (docs/RESEARCH-NAVIGATION.md, sections 2, 5 and 7): the highlight and the secure click on the
-- highlighted button are what ConsolePort does; the bumpers for tabs, a modal question window and the closing steps are
-- what Ubermoc UI does. The code here is written fresh; nothing is copied from either.
-- Nothing happens in combat: the game gives every button back to the player's own binds (see Nav.lua).
----------------------------------------------------------------------
local _, UF = ...

local G = {}
UF.GameNav = G

----------------------------------------------------------------------
-- Pure helpers (tested offline)
----------------------------------------------------------------------
-- Nodes are { cx, cy, l, r, t, b } in screen units, y up. Pick the best node from `cur` in direction UP/DOWN/LEFT/RIGHT:
-- it must lie ahead (at least 6 units along the direction) and within about 80 degrees of it; the score is the
-- distance times (1 + the angle off the direction / 45), so straight ahead beats a closer node off to the side.
function G.pick(nodes, cur, dir)
    local best, bestScore
    for _, n in ipairs(nodes) do
        if n ~= cur then
            local dx, dy = n.cx - cur.cx, n.cy - cur.cy
            local along, across
            if dir == "UP" then along, across = dy, dx
            elseif dir == "DOWN" then along, across = -dy, dx
            elseif dir == "LEFT" then along, across = -dx, dy
            else along, across = dx, dy end
            if along >= 6 then
                local angle = math.deg(math.atan(math.abs(across) / along))
                if angle < 80 then
                    local score = math.sqrt(dx * dx + dy * dy) * (1 + angle / 45)
                    if not bestScore or score < bestScore then best, bestScore = n, score end
                end
            end
        end
    end
    return best
end

function G.nearest(nodes, x, y)
    local best, bestD
    for _, n in ipairs(nodes) do
        local d = (n.cx - x) ^ 2 + (n.cy - y) ^ 2
        if not bestD or d < bestD then best, bestD = n, d end
    end
    return best
end

function G.inside(f, ancestor)
    local depth = 0
    while f and depth < 30 do
        if f == ancestor then return true end
        f, depth = f.GetParent and f:GetParent(), depth + 1
    end
    return false
end

-- Next tab, wrapping round: step is +1 or -1.
function G.stepTab(count, current, step)
    if count < 1 then return nil end
    return ((current - 1 + step) % count) + 1
end

----------------------------------------------------------------------
-- Finding the windows
----------------------------------------------------------------------
local POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
local FIXED = { "WorldMapFrame", "SettingsPanel", "ContainerFrameCombinedBags" }

local function shown(f) return type(f) == "table" and f.IsShown and f:IsShown() and true or false end

local function isOurs(f)
    if f.ubfNavOk then return false end   -- our own menu (ItemMenu) is moved through like a game window
    local n = f.GetName and f:GetName()
    return n and n:find("^UbermocForever") and true or false
end

local function addWindow(list, seen, f)
    if shown(f) and not seen[f] and not isOurs(f) then
        seen[f] = true
        list[#list + 1] = f
    end
end

-- Returns the open windows, and the question window when one is up (it is modal: only its buttons count).
local BAR_BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
                      "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

-- While a spell is on the cursor waiting for a slot, only the action bars count.
local function barFrames()
    local list, seen = {}, {}
    for _, base in ipairs(BAR_BUTTONS) do
        for i = 1, 12 do
            local b = _G[base .. i]
            local par = b and b.GetParent and b:GetParent()
            if par and not seen[par] and shown(par) then seen[par] = true; list[#list + 1] = par end
        end
    end
    return list
end

function G.windows()
    if G.placing then return barFrames(), nil end
    for _, n in ipairs(POPUPS) do
        local p = _G[n]
        if shown(p) then return { p }, p end
    end
    local menu = _G.UbermocForeverItemMenu
    if shown(menu) then return { menu }, nil end   -- the item menu is on top of everything
    local list, seen = {}, {}
    if GetUIPanel then
        for _, side in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
            local ok, f = pcall(GetUIPanel, side)
            if ok then addWindow(list, seen, f) end
        end
    end
    for _, n in ipairs(FIXED) do addWindow(list, seen, _G[n]) end
    for i = 1, 13 do addWindow(list, seen, _G["ContainerFrame" .. i]) end
    addWindow(list, seen, _G.GameMenuFrame)
    for _, n in ipairs(UISpecialFrames or {}) do addWindow(list, seen, _G[n]) end
    return list, nil
end

----------------------------------------------------------------------
-- Finding the buttons inside them
----------------------------------------------------------------------
local MAX_DEPTH, MAX_NODES = 14, 900

local function isButton(f)
    return f.IsObjectType and (f:IsObjectType("Button") or f:IsObjectType("CheckButton"))
end

local function rectOf(f)
    local cx, cy = f:GetCenter()
    local w, h = f:GetWidth(), f:GetHeight()
    if not (cx and cy and w and h) or w <= 0 or h <= 0 then return nil end
    local s = f:GetEffectiveScale() or 1
    cx, cy, w, h = cx * s, cy * s, w * s, h * s
    return { cx = cx, cy = cy, l = cx - w / 2, r = cx + w / 2, t = cy + h / 2, b = cy - h / 2 }
end

local function isScroller(f)
    return f.GetScrollTarget or f.ScrollTarget or (f.IsObjectType and f:IsObjectType("ScrollFrame"))
end

local function visit(f, out, depth, clip)
    if #out >= MAX_NODES or depth > MAX_DEPTH then return end
    if f.IsForbidden and f:IsForbidden() then return end
    if not f.IsShown or not f:IsShown() then return end
    if isOurs(f) then return end
    if isScroller(f) then
        local r = rectOf(f)
        if r then
            if clip then
                clip = { l = math.max(clip.l, r.l), r = math.min(clip.r, r.r), t = math.min(clip.t, r.t), b = math.max(clip.b, r.b) }
            else
                clip = r
            end
        end
    end
    if depth > 0 and isButton(f) and f.IsMouseEnabled and f:IsMouseEnabled() then
        local r = rectOf(f)
        if r and (not clip or (r.cx >= clip.l and r.cx <= clip.r and r.cy >= clip.b and r.cy <= clip.t)) then
            r.frame = f
            out[#out + 1] = r
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do visit(c, out, depth + 1, clip) end
    end
end

function G.scan(windows)
    local out = {}
    for _, w in ipairs(windows) do visit(w, out, 0, nil) end
    return out
end

----------------------------------------------------------------------
-- The drawn highlight (plain gold edges: the game's own buttons keep their own art underneath)
----------------------------------------------------------------------
local cursor
local function getCursor()
    if cursor then return cursor end
    cursor = CreateFrame("Frame", "UbermocForeverGameCursor", UIParent)
    cursor:SetFrameStrata("TOOLTIP")
    cursor:EnableMouse(false)
    local function edge(p1, p2, w, h)
        local t = cursor:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.82, 0, 1)
        t:SetPoint(p1, cursor, p1)
        t:SetPoint(p2, cursor, p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 2)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    cursor:Hide()
    return cursor
end

local function drawAt(frame)
    local c = getCursor()
    if not frame then c:Hide(); return end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    c:Show()
end

----------------------------------------------------------------------
-- The secure buttons: A and X click the highlighted button, B clicks the close button. Their targets are set when the
-- highlight moves (never in combat, where the buttons are not ours anyway).
----------------------------------------------------------------------
local function secureButton(name)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "click")
    return b
end

local clicker, backer
local function buttons()
    if not clicker then
        clicker = secureButton("UbermocForeverGameClick")
        clicker:HookScript("PostClick", function() if G.placing then pcall(G.placeHere) end end)
    end
    if not backer then
        backer = secureButton("UbermocForeverGameBack")
        -- when the window has no close button of its own, the game's closing steps run before the click
        backer:SetScript("PreClick", function() if not G.closer and G.fallbackClose then pcall(G.fallbackClose) end end)
    end
    return clicker, backer
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local focus          -- the highlighted node's frame
local entry          -- our place on Nav's stack while active
local wins, popup = {}, nil
G.closer = nil

local function secureCall(fn, ...)
    if securecallfunction then return pcall(securecallfunction, fn, ...) end
    return pcall(fn, ...)
end

-- The close button of a window: its own, in the places the game puts it.
local function closeButtonOf(w)
    local n = w.GetName and w:GetName()
    local c = w.CloseButton or w.ClosePanelButton or (n and (_G[n .. "CloseButton"] or _G[n .. "ClosePanelButton"]))
    if c and c.Click and c.IsShown and c:IsShown() then return c end
end

-- The open window the highlight is in (the innermost one listed), else nil.
function G.windowOfFocus()
    if not focus then return nil end
    for i = #wins, 1, -1 do
        if G.inside(focus, wins[i]) then return wins[i] end
    end
end

local function setTargets()
    if InCombatLockdown() then return end
    local c, b = buttons()
    c:SetAttribute("clickbutton", (not G.placing) and focus or nil)
    local closer
    if G.placing then
        closer = nil   -- B cancels the placing (fallbackClose)
    elseif popup then
        closer = popup.GetButton2 and popup:GetButton2()
        if not (closer and closer:IsShown()) then closer = nil end
    else
        closer = closeButtonOf(G.windowOfFocus() or wins[#wins] or menu)
    end
    G.closer = closer
    b:SetAttribute("clickbutton", closer)
end

function G.fallbackClose()
    if G.placing then G.endPlace(true); return end
    local w = G.windowOfFocus() or wins[#wins]
    if w then secureCall(HideUIPanel, w) end
end

----------------------------------------------------------------------
-- Placing a spell on an action bar: the spell is on the cursor (ItemMenu picked it up); the highlight moves over the
-- action bars; A drops it on the highlighted slot with C_ActionBar.PutActionInSlot (the call the game itself makes when a
-- slot is picked in quick keybind mode, Blizzard_ActionBar ActionButton.lua); B puts it back.
----------------------------------------------------------------------
function G.beginPlace(from)
    G.placing = { from = from }
    focus = nil
    G.scrolled = nil
end

function G.endPlace(cancel)
    local p = G.placing
    G.placing = nil
    if cancel and ClearCursor then pcall(ClearCursor) end
    focus = nil
    if p and p.from then G.restore = p.from end
end

local function placeHere()
    if not (G.placing and focus) then return end
    local slot = (focus.CalculateAction and select(2, pcall(focus.CalculateAction, focus))) or focus.action
    if type(slot) == "number" and C_ActionBar and C_ActionBar.PutActionInSlot then
        pcall(C_ActionBar.PutActionInSlot, slot)
        if ClearCursor then pcall(ClearCursor) end   -- whatever was in that slot lands on the cursor: let it go
        UF.say("Spell placed on the action bar.")
    end
    G.endPlace(false)
end
G.placeHere = placeHere

----------------------------------------------------------------------
-- Scrolling
----------------------------------------------------------------------
local function scrollerOf(node)
    local f, depth = node, 0
    while f and depth < 14 do
        if f.ScrollToElementDataIndex and f.GetScrollTarget then return f, "box" end
        if f.IsObjectType and f:IsObjectType("ScrollFrame") and f.GetVerticalScrollRange then return f, "frame" end
        f, depth = f.GetParent and f:GetParent(), depth + 1
    end
end

-- Bring the highlighted button into view.
local function reveal(node)
    local sc, kind = scrollerOf(node)
    if not sc then return end
    if kind == "box" then
        local target = sc:GetScrollTarget()
        local row = node
        while row and row:GetParent() ~= target do row = row:GetParent() end
        local getter = row and row.GetElementDataIndex
        if getter then
            local ok, index = pcall(getter, row)
            if ok and index then pcall(sc.ScrollToElementDataIndex, sc, index) end
        end
    else
        local top, bottom, sTop, sBottom = node:GetTop(), node:GetBottom(), sc:GetTop(), sc:GetBottom()
        if not (top and bottom and sTop and sBottom) then return end
        local cur, range, new = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0, nil
        if top > sTop - 8 then new = cur - (top - (sTop - 8))
        elseif bottom < sBottom + 8 then new = cur + ((sBottom + 8) - bottom) end
        if new then sc:SetVerticalScroll(math.max(0, math.min(range, new))) end
    end
end

local function scrollBy(step)
    if not focus then return end
    local sc, kind = scrollerOf(focus)
    if not sc then return end
    if kind == "box" then
        local fn = sc:GetScript("OnMouseWheel")
        if fn then pcall(fn, sc, step > 0 and -1 or 1) end    -- the game's wheel: negative scrolls down
    else
        local cur, range = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0
        sc:SetVerticalScroll(math.max(0, math.min(range, cur + step * 60)))
    end
    G.scrolled = true   -- the next tick re-picks the highlight if it was scrolled out of view
end

----------------------------------------------------------------------
-- Tabs and pages
-- A window can hold several groups of tabs (the character window has its mode tabs and the side tabs; the professions
-- window has its profession tabs down the right; the spellbook has its category tabs). The bumpers move through the group
-- nearest the highlight. The shapes looked for are the ones found in the Blizzard Forever source:
--   TabSystemMixin (`frame.tabs` + `SetTab`, selected = `selectedTabID`)        Blizzard_SharedXML TabSystemTemplates.lua
--   a `Tabs` array of check buttons (CharacterFrame.ModeTabs, PaperDollSidebarTabs)   Camelot CharacterFrame / PaperDollFrame
--   `rightProfessionTabs` (+ `ProfessionsOverviewTab`)                            Blizzard_Professions Camelot ProfessionsFrame.lua
--   the older PanelTemplates (`numTabs`, `selectedTab`, buttons named <frame>Tab<n>)
----------------------------------------------------------------------
local function usable(b)
    return type(b) == "table" and b.Click and b.IsShown and b:IsShown() and true or false
end

local function checkedIndex(list)
    for i, b in ipairs(list) do
        if b.GetChecked and b:GetChecked() then return i end
    end
end

local function collectGroups(f, depth, out, seen)
    if depth > 7 or not (f.IsShown and f:IsShown()) then return end
    local function add(list, cur)
        if #list < 2 or seen[list[1]] then return end
        for _, b in ipairs(list) do seen[b] = true end
        out[#out + 1] = { buttons = list, cur = cur or checkedIndex(list) or 1 }
    end
    if type(f.tabs) == "table" and f.SetTab then
        local list, cur = {}, nil
        for id, b in ipairs(f.tabs) do
            if usable(b) then
                list[#list + 1] = b
                if id == f.selectedTabID then cur = #list end
            end
        end
        add(list, cur)
    end
    if type(f.Tabs) == "table" then
        local list = {}
        for _, b in ipairs(f.Tabs) do if usable(b) then list[#list + 1] = b end end
        add(list)
    end
    if type(f.rightProfessionTabs) == "table" then
        local list = {}
        if usable(f.ProfessionsOverviewTab) then list[1] = f.ProfessionsOverviewTab end
        for _, b in ipairs(f.rightProfessionTabs) do if usable(b) then list[#list + 1] = b end end
        add(list)
    end
    if type(f.numTabs) == "number" and f.numTabs > 1 then
        local n = f.GetName and f:GetName()
        local list = {}
        for i = 1, f.numTabs do
            local b = n and _G[n .. "Tab" .. i]
            if usable(b) then list[#list + 1] = b end
        end
        add(list, tonumber(f.selectedTab))
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do collectGroups(c, depth + 1, out, seen) end
    end
end

-- The group of tabs nearest the highlight (the first one when nothing is highlighted).
local function pickGroup()
    local groups, seen = {}, {}
    for i = #wins, 1, -1 do collectGroups(wins[i], 0, groups, seen) end
    if #groups == 0 then return nil end
    local fr = focus and rectOf(focus)
    if not fr then return groups[1] end
    local best, bestD
    for _, g in ipairs(groups) do
        local sx, sy, n = 0, 0, 0
        for _, b in ipairs(g.buttons) do
            local r = rectOf(b)
            if r then sx, sy, n = sx + r.cx, sy + r.cy, n + 1 end
        end
        if n > 0 then
            local d = (sx / n - fr.cx) ^ 2 + (sy / n - fr.cy) ^ 2
            if not bestD or d < bestD then best, bestD = g, d end
        end
    end
    return best or groups[1]
end

local function stepTab(step)
    local g = pickGroup()
    if not g then return end
    local nxt = G.stepTab(#g.buttons, g.cur, step)
    local b = nxt and g.buttons[nxt]
    if b then pcall(b.Click, b) end
    G.scrolled = true
end

----------------------------------------------------------------------
-- The highlight
----------------------------------------------------------------------
local nodes = {}

local function setFocus(f)
    focus = f
    drawAt(f)
    setTargets()
    if f then pcall(reveal, f) end
end

local function rescan()
    nodes = G.scan(wins)
end

local function startNode()
    if G.placing then
        local b = _G.ActionButton1
        if b and b:IsShown() then return b end
    end
    if popup then
        local b1 = popup.GetButton1 and popup:GetButton1()
        if b1 and b1:IsShown() then return b1 end
    end
    -- the top left button of the topmost window
    local best
    for _, n in ipairs(nodes) do
        if not best or n.cy > best.cy + 4 or (math.abs(n.cy - best.cy) <= 4 and n.cx < best.cx) then best = n end
    end
    return best and best.frame
end

local function nodeOf(f)
    for _, n in ipairs(nodes) do if n.frame == f then return n end end
end

local function move(dir)
    rescan()
    local cur = focus and nodeOf(focus)
    if not cur then setFocus(startNode()); return end
    local nxt = G.pick(nodes, cur, dir)
    if nxt then setFocus(nxt.frame) end
end

----------------------------------------------------------------------
-- The legend bar: what each button does right now, shown at the bottom of the screen while this is active. A button is
-- listed only when it is bound to something where the highlight is (Y only on a bag item, tabs only on a window with tabs).
----------------------------------------------------------------------
local bar, barLegend, barSig
local function getBar()
    if bar then return bar end
    bar = CreateFrame("Frame", "UbermocForeverGameLegend", UIParent)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetSize(10, 30)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 28)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.6)
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -10, 4)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 10, -4)
    barLegend = UF.CreateLegend(bar)
    barLegend:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar:Hide()
    return bar
end

local function legendTexts()
    local t = { PADDUP = "Move" }
    local inMenu = wins[1] and wins[1] == _G.UbermocForeverItemMenu
    if G.placing then
        t.PAD1, t.PAD2 = "Place here", "Cancel"
        return t
    end
    if popup then
        t.PAD1, t.PAD2 = "Accept", "Decline"
        return t
    end
    if inMenu then
        t.PAD1, t.PAD2 = "Choose", "Close"
        return t
    end
    t.PAD1, t.PAD2 = "Select", "Close"
    if focus then
        t.PAD3 = "Right-click"
        local kind = UF.ItemMenu and UF.ItemMenu.kind(focus)
        if kind then t.PAD4 = (kind == "spell") and "Bind" or "Options" end
        if scrollerOf(focus) then t.PADLTRIGGER, t.PADRTRIGGER = "Scroll up", "Scroll down" end
    end
    if pickGroup() then t.PADLSHOULDER, t.PADRSHOULDER = "Prev tab", "Next tab" end
    return t
end

-- The legend sits just under the window the highlight is in (inside its bottom edge when the window reaches the bottom of
-- the screen, and above the action bars while a spell is being placed).
local anchoredTo
local function anchorBar(b)
    local w = (not G.placing) and (G.windowOfFocus() or wins[#wins]) or nil
    local key = w or "screen"
    if key == anchoredTo then return end
    anchoredTo = key
    b:ClearAllPoints()
    local bottom = w and w.GetBottom and w:GetBottom()
    if w and bottom and bottom > 50 then
        b:SetPoint("TOP", w, "BOTTOM", 0, -12)
    elseif w then
        b:SetPoint("BOTTOM", w, "BOTTOM", 0, 14)
    else
        b:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150)
    end
end

local lastCalc, lastFocus = 0, nil
local function updateBar()
    local b = getBar()
    local now = GetTime and GetTime() or 0
    if focus ~= lastFocus or now - lastCalc > 0.5 or not barSig then
        lastFocus, lastCalc = focus, now
        local t = legendTexts()
        local sig = {}
        for k, v in pairs(t) do sig[#sig + 1] = k .. "=" .. v end
        table.sort(sig)
        sig = table.concat(sig, ";")
        if sig ~= barSig then
            barSig = sig
            barLegend:Set(t)
            b:SetWidth(barLegend:GetWidth())
        end
    end
    anchorBar(b)
    if not b:IsShown() then b:Show() end
end

----------------------------------------------------------------------
-- Active or not
----------------------------------------------------------------------
local function release()
    if entry then UF.Nav.Pop(entry); entry = nil end
    focus = nil
    drawAt(nil)
    if G.placing then G.endPlace(true) end
    if bar then bar:Hide() end
    barSig, anchoredTo = nil, nil
end

local function engage()
    local c, b = buttons()
    entry = UF.Nav.Push({
        PADDUP = function() move("UP") end,
        PADDDOWN = function() move("DOWN") end,
        PADDLEFT = function() move("LEFT") end,
        PADDRIGHT = function() move("RIGHT") end,
        PAD4 = function() if focus and UF.ItemMenu and not (wins[1] and wins[1] == _G.UbermocForeverItemMenu) then UF.ItemMenu.open(focus) end end,
        PADLSHOULDER = function() stepTab(-1) end,
        PADRSHOULDER = function() stepTab(1) end,
        PADLTRIGGER = function() scrollBy(-1) end,
        PADRTRIGGER = function() scrollBy(1) end,
    }, {
        PAD1 = { c:GetName(), "LeftButton" },
        PAD3 = { c:GetName(), "RightButton" },
        PAD2 = { b:GetName(), "LeftButton" },
    })
end

function G.enabled() return UF.DB().gameNav ~= false end
function G.active() return entry ~= nil end

function G.update()
    local want = false
    if G.enabled() and not InCombatLockdown() then
        wins, popup = G.windows()
        local others = UF.Nav.Count() - (entry and 1 or 0)
        want = #wins > 0 and others == 0
    end
    if want and not entry then
        engage()
        rescan()
        setFocus(startNode())
        pcall(updateBar)
    elseif not want and entry then
        release()
    elseif want then
        -- keep the highlight honest: a popup appearing takes it, a vanished button is replaced, a scroll re-picks it
        if G.placing and GetCursorInfo and not GetCursorInfo() then G.endPlace(false) end
        if G.restore then
            local back = G.restore
            G.restore = nil
            if back.IsVisible and back:IsVisible() then rescan(); setFocus(back) end
        end
        local needNew = popup and focus and not G.inside(focus, popup)
        if needNew or not focus or not focus:IsVisible() then
            rescan(); setFocus(startNode())
        elseif G.scrolled then
            G.scrolled = nil
            rescan()
            if not nodeOf(focus) then
                local r = rectOf(focus)
                local n = r and G.nearest(nodes, r.cx, r.cy)
                setFocus(n and n.frame or startNode())
            end
        else
            drawAt(focus)
        end
        pcall(updateBar)
    end
end

local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.15 then return end
    acc = 0
    pcall(G.update)
end)
ticker:RegisterEvent("PLAYER_REGEN_DISABLED")
ticker:SetScript("OnEvent", function() release() end)
