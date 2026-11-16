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
--   triggers       the previous / next side page (the tabs stacked down the right of the professions window, the spellbook
--                  and others); in a window without them, scroll the list the highlight is in (it also scrolls by itself
--                  to show the highlight)
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

-- While a spell is waiting for a slot, only the action bars count: every bar the game or another addon shows, found by
-- looking for the buttons that stand for an action slot (so a bar whose buttons are bound to the back buttons through Steam
-- Input, or any custom bar, is included). The list is made once when placing starts.
local function findBarParents()
    local list, seen = {}, {}
    local function add(b)
        local par = b and b.GetParent and b:GetParent()
        if par and not seen[par] and shown(par) then seen[par] = true; list[#list + 1] = par end
    end
    for _, base in ipairs(BAR_BUTTONS) do
        for i = 1, 12 do add(_G[base .. i]) end
    end
    if EnumerateFrames then
        local f = EnumerateFrames()
        while f do
            if (f.CalculateAction or type(f.action) == "number") and f.IsShown and f:IsShown() and f.IsObjectType
                and (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) and not isOurs(f) then
                add(f)
            end
            f = EnumerateFrames(f)
        end
    end
    return list
end

local function barFrames()
    if G.placing then
        G.placing.bars = G.placing.bars or findBarParents()
        local out = {}
        for _, p in ipairs(G.placing.bars) do if shown(p) then out[#out + 1] = p end end
        return out
    end
    return {}
end

-- Drop-down menus that are open: the game's newer menu (Blizzard_Menu: Menu.GetManager) and the older lists
-- (DropDownList1..3). While one is open it is modal: only its entries count.
local function openMenus()
    local list = {}
    if Menu and Menu.GetManager then
        local ok, m = pcall(Menu.GetManager)
        if ok and m then
            local ok2, any = pcall(m.IsAnyMenuOpen, m)
            if ok2 and any then
                local ok3, menu = pcall(m.GetOpenMenu, m)
                if ok3 and shown(menu) then list[#list + 1] = menu end
            end
        end
    end
    for i = 1, 3 do
        local d = _G["DropDownList" .. i]
        if shown(d) then list[#list + 1] = d end
    end
    return list
end
G.openMenus = openMenus

local function closeMenus()
    local did = false
    if Menu and Menu.GetManager then
        local ok, m = pcall(Menu.GetManager)
        if ok and m then
            local ok2, any = pcall(m.IsAnyMenuOpen, m)
            if ok2 and any then pcall(m.CloseMenus, m); did = true end
        end
    end
    if shown(_G.DropDownList1) and CloseDropDownMenus then pcall(CloseDropDownMenus); did = true end
    return did
end

function G.windows()
    for _, n in ipairs(POPUPS) do
        local p = _G[n]
        if shown(p) then return { p }, p end
    end
    local drop = openMenus()
    if #drop > 0 then return drop, nil end
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
    -- every window the game registered as a panel, and the windows that hang off another one (the open letter in the mail,
    -- the guild pop-ups ...: UIChildWindows, Blizzard_UIParentPanelManager); children go last so they count as on top
    if type(UIPanelWindows) == "table" then
        for n in pairs(UIPanelWindows) do addWindow(list, seen, _G[n]) end
    end
    if type(UIChildWindows) == "table" then
        for _, n in ipairs(UIChildWindows) do
            local f = _G[n]
            if shown(f) and not seen[f] then seen[f] = true; list[#list + 1] = f end
        end
    end
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
-- The action bars are the game's protected, edit-mode managed frames. Running one of their scripts from here (the tooltip's
-- OnEnter / OnLeave) leaves values tainted that the bars use later, which showed as blocked-action and "secret value"
-- errors in ActionButton.lua and EditMode. So no tooltip is ever raised on them, and nothing of ours is anchored to them
-- (the highlight is placed by screen position instead).
local BAR_NAMES = { "^ActionButton%d", "^MultiBar", "^MainActionBar", "^MainMenuBar", "^StanceButton", "^PetActionButton",
                    "^OverrideActionBar", "^ExtraActionButton", "^PossessButton", "ActionBar" }
local function onActionBar(f)
    local g, depth = f, 0
    while g and depth < 5 do
        local n = g.GetName and g:GetName()
        if n then
            for _, pat in ipairs(BAR_NAMES) do if n:find(pat) then return true end end
        end
        g, depth = g.GetParent and g:GetParent(), depth + 1
    end
    return false
end
G.onActionBar = onActionBar

local function getCursor()
    if cursor then return cursor end
    cursor = CreateFrame("Frame", "UbermocForeverGameCursor", UIParent)
    cursor:SetFrameStrata("TOOLTIP")
    cursor:EnableMouse(false)
    -- A glow over the button, like the game's own button highlight (its ButtonHilight-Square art, added to what is
    -- underneath) plus a faint warm wash so it shows on any button. No outline.
    local glow = cursor:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(cursor)
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.9, 0.55, 1)
    local wash = cursor:CreateTexture(nil, "ARTWORK")
    wash:SetAllPoints(cursor)
    wash:SetColorTexture(1, 0.85, 0.4, 0.22)
    wash:SetBlendMode("ADD")
    cursor:Hide()
    return cursor
end

local function drawAt(frame)
    local c = getCursor()
    if not frame then c:Hide(); return end
    c:ClearAllPoints()
    local r = onActionBar(frame) and rectOf(frame)
    if r then
        -- by position, never anchored to an action bar button (see above)
        local ui = UIParent:GetEffectiveScale() or 1
        c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r.l / ui - 2, r.t / ui + 2)
        c:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r.r / ui + 2, r.b / ui - 2)
    else
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    end
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

local focus          -- the highlighted node's frame (declared here so the click handlers below can see it)
local clicker, backer, rclicker

-- Mail: the inbox row (or the open letter) the highlight is on, as an inbox index, or nil.
local function mailIndex(f)
    local g, depth = f, 0
    while g and depth < 6 do
        if g == _G.OpenMailFrame then return _G.InboxFrame and _G.InboxFrame.openMailID or _G.OpenMailFrame.openMailID or nil end
        local n = g.GetName and g:GetName()
        if n and n:match("^MailItem%d+") then
            if g.index then return g.index end
            local row = tonumber(n:match("^MailItem(%d+)"))
            local page = (_G.InboxFrame and _G.InboxFrame.pageNum) or 1
            return row and ((page - 1) * (_G.INBOXITEMS_TO_DISPLAY or 7) + row) or nil
        end
        g, depth = g.GetParent and g:GetParent(), depth + 1
    end
end
G.mailIndex = mailIndex

-- True when that mail has something to take (an item or money) and is not cash on delivery.
local function mailTakeable(index)
    if not (index and GetInboxHeaderInfo) then return false end
    local ok, _, _, _, _, money, cod, _, hasItem = pcall(GetInboxHeaderInfo, index)
    if not ok then return false end
    if cod and cod > 0 then return false, true end
    return (hasItem and true or false) or ((money or 0) > 0)
end
G.mailTakeable = mailTakeable

local function takeMail(index)
    local ok, cod = mailTakeable(index)
    if cod then UF.say("That mail is cash on delivery: open it to pay for it.") return end
    if not ok then return end
    if AutoLootMailItem then
        local good, err = pcall(AutoLootMailItem, index)
        if not good then UF.check("Take mail", false, tostring(err)) end
    end
end

local function buttons()
    if not clicker then
        clicker = secureButton("UbermocForeverGameClick")
        clicker:HookScript("PostClick", function()
            if G.placing then pcall(G.placeHere); return end
            -- Some of the game's buttons act on the mouse going down or up and have no OnClick at all (the newer drop-down
            -- buttons open on mouse DOWN: DropdownButtonMixin:OnMouseDown_Intrinsic). A click from here sends neither, so
            -- for those the button's own mouse scripts are run, as a real click would (what ConsolePort does for such
            -- buttons too: ConsolePort_Cursor Cursor.lua GetEmuClick). A drop-down that still did not open is toggled
            -- with its own SetMenuOpen call.
            local f = focus
            if not f or InCombatLockdown() or not f.GetScript then return end
            local isDrop = f.SetMenuOpen and f.IsMenuOpen
            if f:GetScript("OnClick") and not isDrop then return end
            local down, up = f:GetScript("OnMouseDown"), f:GetScript("OnMouseUp")
            local wasOpen = isDrop and select(2, pcall(f.IsMenuOpen, f)) or false
            if down then
                local ok, err = pcall(down, f, "LeftButton")
                if not ok then UF.check("Mouse-down on " .. (f:GetName() or "a button"), false, tostring(err)) end
            end
            if up then pcall(up, f, "LeftButton", true) end
            if isDrop then
                local nowOpen = select(2, pcall(f.IsMenuOpen, f))
                if nowOpen == wasOpen then pcall(f.SetMenuOpen, f, not wasOpen) end
                G.menuFrom = f
            end
        end)
    end
    if not backer then
        backer = secureButton("UbermocForeverGameBack")
        -- when the window has no close button of its own, the game's closing steps run before the click
        backer:SetScript("PreClick", function() if not G.closer and G.fallbackClose then pcall(G.fallbackClose) end end)
    end
    -- X: the right click, a button of its own so it can be left without a target where a right click means nothing or is
    -- refused (the game's question windows assert when their buttons get a right click)
    if not rclicker then
        rclicker = secureButton("UbermocForeverGameRClick")
        -- X on a mail with an item or money takes everything in it (the game's own call, run by this press)
        rclicker:HookScript("PostClick", function()
            if InCombatLockdown() or not focus then return end
            local idx = mailIndex(focus)
            if idx then pcall(takeMail, idx) end
        end)
    end
    return clicker, backer, rclicker
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
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

-- Conversations: quest and gossip windows start on their first option (or the Accept/Continue/Complete button), B is the
-- window's Decline, and in a trainer X trains the selected skill.
local function visibleButton(name)
    local b = _G[name]
    if b and b.IsVisible and b:IsVisible() then return b end
end

local function dialogCloser(w)
    if w and w == _G.QuestFrame then
        return visibleButton("QuestFrameDeclineButton") or visibleButton("QuestFrameGoodbyeButton")
    end
end

local function trainButton(f)
    local t = _G.ClassTrainerFrame
    if f and shown(t) and G.inside(f, t) then
        local b = t.TrainButton or _G.ClassTrainerTrainButton
        if b and b.IsVisible and b:IsVisible() then return b end
    end
end
G.trainButton = trainButton

local function setTargets()
    if InCombatLockdown() then return end
    local c, b, rc = buttons()
    c:SetAttribute("clickbutton", (not G.placing) and focus or nil)
    local menuUp = wins[1] and wins[1] == _G.UbermocForeverItemMenu
    local train = trainButton(focus)
    rc:SetAttribute("clickbutton", (not (G.placing or popup or menuUp or #openMenus() > 0)) and (train or (not mailIndex(focus) and focus or nil)) or nil)
    local closer
    if G.placing then
        closer = nil   -- B cancels the placing (fallbackClose)
    elseif popup then
        closer = popup.GetButton2 and popup:GetButton2()
        if not (closer and closer:IsShown()) then closer = nil end
    else
        local w = G.windowOfFocus() or wins[#wins]
        closer = dialogCloser(w) or closeButtonOf(w or menu)
    end
    G.closer = closer
    b:SetAttribute("clickbutton", closer)
end

function G.fallbackClose()
    if G.placing then G.endPlace(true); return end
    if closeMenus() then return end
    local w = G.windowOfFocus() or wins[#wins]
    if w then secureCall(HideUIPanel, w) end
end

----------------------------------------------------------------------
-- Placing a spell on an action bar: the spell is on the cursor (ItemMenu picked it up); the highlight moves over the
-- action bars; A drops it on the highlighted slot with C_ActionBar.PutActionInSlot (the call the game itself makes when a
-- slot is picked in quick keybind mode, Blizzard_ActionBar ActionButton.lua); B puts it back.
----------------------------------------------------------------------
-- The spell is not picked up here: the highlight goes over the action bars, and picking the slot places it in one step
-- (so it never sits on the mouse cursor), the way the game's own "change what a slot uses" works.
function G.beginPlace(from, spell)
    G.placing = { from = from, spell = spell }
    focus = nil
    G.scrolled = nil
    if G.applyMap then G.applyMap() end
    if G.setCapture then G.setCapture(true) end
    UF.say("Hold your buttons and press the one to put this spell on (a back button that Steam Input turns into a key works too). B cancels.")
end

function G.endPlace(cancel)
    local p = G.placing
    G.placing = nil
    if cancel and ClearCursor then pcall(ClearCursor) end
    focus = nil
    if p and p.from then G.restore = p.from end
    if G.applyMap then G.applyMap() end
    if G.setCapture then G.setCapture(false) end
end

-- The action slot (1 to 180) a bar button stands for. The game's own methods first, then the number it keeps, then the
-- slot worked out from the button's name (ActionButtonN is the page you are on, the other bars have fixed ranges).
local BAR_FIRST = { MultiBarBottomLeftButton = 60, MultiBarBottomRightButton = 48, MultiBarRightButton = 24,
                    MultiBarLeftButton = 36, MultiBar5Button = 144, MultiBar6Button = 156, MultiBar7Button = 168 }
local function slotOf(f)
    local function num(v) return (type(v) == "number" and v > 0) and v or nil end
    if f.CalculateAction then
        local ok, v = pcall(f.CalculateAction, f)
        if ok and num(v) then return v end
    end
    if num(f.action) then return f.action end
    if f.GetAttribute then
        local ok, v = pcall(f.GetAttribute, f, "action")
        if ok and num(v) then return v end
    end
    local n = f.GetName and f:GetName()
    if n then
        local base, i = n:match("^(.-)(%d+)$")
        i = tonumber(i)
        if base and i then
            if BAR_FIRST[base] then return BAR_FIRST[base] + i end
            if base == "ActionButton" then
                local page = (GetActionBarPage and GetActionBarPage()) or 1
                return (page - 1) * 12 + i
            end
        end
    end
end
G.slotOf = slotOf

-- Put the spell being placed into an action slot. Returns true when the slot now holds it.
local function placeSpell(slot, spell)
    local sp = spell or (G.placing and G.placing.spell)
    if not (sp and C_SpellBook and C_SpellBook.PickupSpellBookItem and C_ActionBar and C_ActionBar.PutActionInSlot) then
        UF.say("This game version cannot place a spell from here.")
        return false
    end
    local ok, err = pcall(C_SpellBook.PickupSpellBookItem, sp.slotIndex, sp.spellBank)
    if not ok then UF.check("Pick up the spell to place it", false, tostring(err)) end
    if not (GetCursorInfo and GetCursorInfo()) then
        UF.say("That spell cannot go on an action bar.")
        return false
    end
    local ok2, err2 = pcall(C_ActionBar.PutActionInSlot, slot)
    if not ok2 then UF.check("Place the spell in slot " .. slot, false, tostring(err2)) end
    if ClearCursor then pcall(ClearCursor) end   -- whatever was in that slot lands on the cursor: let it go
    return (ok2 and GetActionInfo and GetActionInfo(slot)) and true or false
end

-- The first empty slot on a bar that is showing: the side bars first (bars 4 and 5), then the others. Returns the slot and the
-- name of the key bind that triggers it.
local FREE_ORDER = { { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" }, { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" },
                     { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" }, { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
                     { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" }, { "MultiBar6Button", "MULTIACTIONBAR6BUTTON" },
                     { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" } }
function G.freeSlot()
    for _, bar in ipairs(FREE_ORDER) do
        for i = 1, 12 do
            local f = _G[bar[1] .. i]
            if f and f.IsShown and f:IsShown() then
                local slot = slotOf(f)
                if slot and GetActionInfo and not GetActionInfo(slot) then return slot, bar[2] .. i, bar[1] .. i end
            end
        end
    end
end

-- A button combination was pressed while placing a spell. A combination that already triggers an action slot gets the spell
-- in that slot. A combination with no bind at all (a back button pair, say) is given one: the spell goes into the first
-- empty slot and the combination is bound to it. A combination that does something else is left alone.
function G.placeKey(key)
    if not G.placing or InCombatLockdown() then return end
    local slot, action = G.slotForKey(key)
    if slot then
        if placeSpell(slot) then UF.say(("Spell placed on the slot that %s triggers (slot %d)."):format(key, slot))
        else UF.say(("The spell was not placed in slot %d. /ubf check shows why."):format(slot)) end
        G.endPlace(false)
        return
    end
    if action and action ~= "" then
        -- ask: the game's own question window (A is Replace, B keeps what is there). Placing stops while it is up.
        local sp = G.placing.spell
        G.endPlace(false)
        G.pendingBind = { key = key, spell = sp }
        local name = UF.actionName and UF.actionName(action) or action
        if StaticPopup_Show then
            StaticPopup_Show("UBERMOCFOREVER_REPLACEBIND", key, name)
        else
            G.pendingBind = nil
            UF.say(("%s is already used for %s. Nothing was changed."):format(key, name))
        end
        return
    end
    G.bindToFree(key, G.placing.spell)
end

-- A combination with nothing on it: put the spell in the first empty slot and bind the combination to it. Also used after
-- the player agreed to replace what was there.
function G.bindToFree(key, spell)
    local free, bind, frameName = G.freeSlot()
    if not free then
        UF.say("There is no empty slot on a visible action bar to put it in.")
        if G.placing then G.endPlace(false) end
        return
    end
    if placeSpell(free, spell) then
        if UF.setBind and UF.setBind(key, bind) then
            UF.say(("Spell placed on %s (slot %d) and %s is now bound to it."):format(frameName, free, key))
        else
            UF.say(("Spell placed on %s (slot %d), but %s could not be bound to it."):format(frameName, free, key))
        end
    else
        UF.say(("The spell was not placed in slot %d. /ubf check shows why."):format(free))
    end
    if G.placing then G.endPlace(false) end
end

StaticPopupDialogs["UBERMOCFOREVER_REPLACEBIND"] = {
    text = "%s is already used for %s.\n\nReplace it with this spell?",
    button1 = "Replace",
    button2 = "Keep it",
    OnAccept = function()
        local p = G.pendingBind
        G.pendingBind = nil
        if p then G.bindToFree(p.key, p.spell) end
    end,
    OnCancel = function()
        G.pendingBind = nil
        UF.say("Nothing was changed.")
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- (a click while placing, kept for the old route: nothing to do now)
local function placeHere() end
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

-- Scroll a scroll box by a number of screen pixels (positive = down) using its percentage, which works whatever the
-- row layout. Returns the box's percentage before the move, or nil when it cannot be done.
local function scrollPixels(sc, px)
    if not (sc.GetScrollPercentage and sc.SetScrollPercentage and sc.GetVisibleExtentPercentage) then return nil end
    local okc, cur = pcall(sc.GetScrollPercentage, sc)
    local okv, vis = pcall(sc.GetVisibleExtentPercentage, sc)
    local r = rectOf(sc)
    if not (okc and okv and cur and vis and r and vis > 0 and vis < 1) then return nil end
    local H = r.t - r.b
    local range = H / vis - H
    if range <= 0 then return nil end
    pcall(sc.SetScrollPercentage, sc, math.max(0, math.min(1, cur + px / range)))
    return cur
end

-- Bring the highlighted button into view, moving the list only as far as needed (never to one of its ends).
local function reveal(node)
    local sc, kind = scrollerOf(node)
    if not sc then return end
    if kind == "box" then
        local rn, rs = rectOf(node), rectOf(sc)
        if rn and rs and sc.GetScrollPercentage then
            local margin, px = 8, nil
            if rn.t > rs.t - margin then px = -(rn.t - (rs.t - margin))
            elseif rn.b < rs.b + margin then px = (rs.b + margin) - rn.b end
            if px == nil then return end
            if scrollPixels(sc, px) ~= nil then return end
        end
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
        -- a page at a time, by percentage, so it can reach both ends of the list (the game's wheel step is small)
        local done = false
        if sc.GetScrollPercentage and sc.SetScrollPercentage then
            local ok, cur = pcall(sc.GetScrollPercentage, sc)
            local okv, vis = pcall(function() return sc.GetVisibleExtentPercentage and sc:GetVisibleExtentPercentage() end)
            if ok and cur then
                local page = (okv and vis and vis > 0 and vis <= 1) and vis * 0.7 or 0.2
                local new = math.max(0, math.min(1, cur + (step > 0 and page or -page)))
                done = pcall(sc.SetScrollPercentage, sc, new)
            end
        end
        if not done then
            local fn = sc:GetScript("OnMouseWheel")
            if fn then pcall(fn, sc, step > 0 and -1 or 1) end    -- the game's wheel: negative scrolls down
        end
    else
        local cur, range = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0
        local page = math.max(60, (sc:GetHeight() or 100) * 0.7)
        sc:SetVerticalScroll(math.max(0, math.min(range, cur + step * page)))
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
-- The big tabs down the side of a window (professions, character, group finder, guild and communities, collections ...)
-- are plain Frames from LargeSideTabButtonTemplate (Blizzard_SharedXML SharedUIPanelTemplates.xml), not Buttons: they have
-- no Click(), they act on OnMouseUp, and they show SelectedTexture when chosen. The template is recognised by those parts.
local function isSideTab(b)
    return type(b) == "table" and b.SelectedTexture and b.TabGlow and b.GetScript and b:GetScript("OnMouseUp") and true or false
end

local function usable(b)
    if type(b) ~= "table" or not (b.IsShown and b:IsShown()) then return false end
    return (b.Click or isSideTab(b)) and true or false
end

local function isSelected(b)
    if b.GetChecked then
        local ok, v = pcall(b.GetChecked, b)
        if ok and v then return true end
    end
    return isSideTab(b) and b.SelectedTexture.IsShown and b.SelectedTexture:IsShown() or false
end

local function checkedIndex(list)
    for i, b in ipairs(list) do
        if isSelected(b) then return i end
    end
end

-- Press a tab the way the mouse does.
local function pressTab(b)
    if b.Click and not isSideTab(b) then pcall(b.Click, b); return end
    local down, up = b:GetScript("OnMouseDown"), b:GetScript("OnMouseUp")
    if down then pcall(down, b, "LeftButton") end
    if up then pcall(up, b, "LeftButton", true) end
end

local function collectGroups(f, depth, out, seen)
    if depth > 7 or not (f.IsShown and f:IsShown()) then return end
    local function add(list, cur)
        if #list < 2 then return end
        for _, b in ipairs(list) do if seen[b] then return end end
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
    -- side tabs that sit together under one frame, whatever the window calls them, top to bottom
    if f.GetChildren then
        local kids, side = { f:GetChildren() }, {}
        for _, c in ipairs(kids) do if usable(c) and isSideTab(c) then side[#side + 1] = c end end
        table.sort(side, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
        add(side)
        for _, c in ipairs(kids) do collectGroups(c, depth + 1, out, seen) end
    end
end

function G.groupsFor(w)   -- for the offline test
    local out = {}
    collectGroups(w, 0, out, {})
    return out
end

-- A group is "vertical" when its tabs are stacked more than they are side by side (the profession tabs and the
-- spellbook's category tabs down the right edge of a window).
local function isVertical(g)
    local minX, maxX, minY, maxY
    for _, b in ipairs(g.buttons) do
        local r = rectOf(b)
        if r then
            minX, maxX = math.min(minX or r.cx, r.cx), math.max(maxX or r.cx, r.cx)
            minY, maxY = math.min(minY or r.cy, r.cy), math.max(maxY or r.cy, r.cy)
        end
    end
    return minX ~= nil and (maxY - minY) > (maxX - minX)
end

-- The group of tabs nearest the highlight (the first one when nothing is highlighted). `vertical` true asks for the
-- stacked side tabs (the triggers step those); false asks for the bumpers' group: the across-the-top kind, or any
-- group when the window has no other.
local function pickGroup(vertical)
    local all, seen = {}, {}
    for i = #wins, 1, -1 do collectGroups(wins[i], 0, all, seen) end
    local groups = {}
    for _, g in ipairs(all) do
        if isVertical(g) == (vertical and true or false) then groups[#groups + 1] = g end
    end
    if #groups == 0 and not vertical then groups = all end
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

local function stepTab(step, vertical)
    local g = pickGroup(vertical)
    if not g then return false end
    local nxt = G.stepTab(#g.buttons, g.cur, step)
    local b = nxt and g.buttons[nxt]
    if b then pressTab(b) end
    G.scrolled = true
    return true
end

----------------------------------------------------------------------
-- The highlight
----------------------------------------------------------------------
local nodes = {}

----------------------------------------------------------------------
-- The tooltip beside the highlight: the highlighted button's own OnEnter runs (as if the mouse were on it, so every
-- window shows its own tooltip), then the tooltip is moved next to the button on the side with room: the right when it
-- fits on the screen, otherwise the left (and the other way round when the right has no room).
----------------------------------------------------------------------
local tipFor
local function tooltipHide()
    if tipFor then
        local f = tipFor
        tipFor = nil
        local leave = f.GetScript and f:GetScript("OnLeave")
        if leave then pcall(leave, f) end
    end
    if GameTooltip and GameTooltip:IsShown() then GameTooltip:Hide() end
end
G.tooltipHide = tooltipHide

local function tooltipPlace(f)
    if not (GameTooltip and GameTooltip:IsShown()) then return end
    local ui = UIParent:GetEffectiveScale() or 1
    local sc = (f:GetEffectiveScale() or 1) / ui
    local left, right = f:GetLeft(), f:GetRight()
    local screenW = UIParent:GetWidth() or 0
    local tipScale = (GameTooltip:GetEffectiveScale() or 1) / ui
    local w = (GameTooltip:GetWidth() or 300) * tipScale + 12
    local side = "right"
    if left and right and screenW > 0 then
        local roomLeft, roomRight = left * sc, screenW - right * sc
        if roomRight >= w then side = "right"
        elseif roomLeft >= w then side = "left"
        else side = (roomRight >= roomLeft) and "right" or "left" end
    end
    GameTooltip:ClearAllPoints()
    if GameTooltip.SetClampedToScreen then GameTooltip:SetClampedToScreen(true) end
    if side == "left" then
        GameTooltip:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)
    end
end


local function tooltipShow(f)
    tooltipHide()
    if not f or InCombatLockdown() or G.placing or onActionBar(f) then return end
    local enter = f.GetScript and f:GetScript("OnEnter")
    if not enter then return end
    tipFor = f
    pcall(enter, f)
    pcall(tooltipPlace, f)
end

local function setFocus(f, noReveal)
    focus = f
    if f then G.lastRect = rectOf(f) end
    drawAt(f)
    setTargets()
    if f and not noReveal then pcall(reveal, f) end
    pcall(tooltipShow, f)
end

local function rescan()
    nodes = G.scan(wins)
end

function G.dialogStart()
    local q = _G.QuestFrame
    if shown(q) then
        for _, n in ipairs({ "QuestFrameAcceptButton", "QuestFrameCompleteQuestButton", "QuestFrameCompleteButton" }) do
            local b = visibleButton(n)
            if b and (not b.IsEnabled or b:IsEnabled()) then return b end
        end
    end
    for _, w in ipairs({ _G.QuestFrame, _G.GossipFrame }) do
        if shown(w) then
            local skip = {}
            skip[closeButtonOf(w) or 0] = true
            skip[_G.QuestFrameGoodbyeButton or 0] = true
            skip[_G.QuestFrameDeclineButton or 0] = true
            skip[_G.GossipFrameGreetingGoodbyeButton or 0] = true
            skip[(w.GreetingPanel and w.GreetingPanel.GoodbyeButton) or 0] = true
            local best
            for _, n in ipairs(nodes) do
                if G.inside(n.frame, w) and not skip[n.frame]
                    and (not best or n.cy > best.cy + 4 or (math.abs(n.cy - best.cy) <= 4 and n.cx < best.cx)) then
                    best = n
                end
            end
            if best then return best.frame end
        end
    end
end

local function startNode()
    local menu = _G.UbermocForeverItemMenu
    if wins[1] and wins[1] == menu then
        local e = _G.UbermocForeverItemMenuEntry1
        if e and e:IsShown() then return e end
    end
    if G.placing then
        local b = _G.ActionButton1
        if b and b:IsShown() then return b end
    end
    if popup then
        local b1 = popup.GetButton1 and popup:GetButton1()
        if b1 and b1:IsShown() then return b1 end
    end
    local d = G.dialogStart and G.dialogStart()
    if d then return d end
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

-- True unless the highlighted button has been scrolled out of the list or text it sits in.
function G.inView(f)
    if not f then return false end
    local sc = scrollerOf(f)
    if not sc then return true end
    local a, b = rectOf(f), rectOf(sc)
    if not (a and b) then return true end
    return a.cy <= b.t and a.cy >= b.b
end

local function move(dir)
    rescan()
    local cur = focus and nodeOf(focus)
    if not cur and focus then
        -- the highlight was scrolled out of view: start from the button nearest where it was
        local r = G.lastRect or rectOf(focus)
        local n = r and G.nearest(nodes, r.cx, r.cy)
        if n then setFocus(n.frame); return end
    end
    if not cur then setFocus(startNode()); return end
    local nxt = G.pick(nodes, cur, dir)
    if nxt then setFocus(nxt.frame); return end
    -- nothing further in view: a list that can still scroll that way scrolls half a page, then the move is tried again
    if (dir == "UP" or dir == "DOWN") and focus then
        local sc, kind = scrollerOf(focus)
        local r = sc and rectOf(sc)
        if sc and kind == "box" and r then
            local half = (r.t - r.b) * 0.5
            if scrollPixels(sc, dir == "DOWN" and half or -half) ~= nil then G.retry = { dir = dir, tries = 5 } end
        elseif sc and kind == "frame" then
            local cur, range = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0
            local nv = math.max(0, math.min(range, cur + (dir == "DOWN" and 1 or -1) * (sc:GetHeight() or 200) * 0.5))
            if nv ~= cur then sc:SetVerticalScroll(nv); G.retry = { dir = dir, tries = 5 } end
        end
    end
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
    barLegend:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bar:Hide()
    return bar
end

local function legendTexts()
    local t = { PADDUP = "Move" }
    local inMenu = wins[1] and wins[1] == _G.UbermocForeverItemMenu
    if G.placing then
        t.PAD2 = "Cancel"
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
        t.PAD3 = trainButton(focus) and "Train" or "Right-click"
        local mi = mailIndex(focus)
        if mi and mailTakeable(mi) then t.PAD3 = "Take all" end
        local w = G.windowOfFocus()
        local dc = dialogCloser(w)
        if dc then t.PAD2 = "Decline" end
        local kind = UF.ItemMenu and UF.ItemMenu.kind(focus)
        if kind then t.PAD4 = (kind == "spell") and "Bind" or "Options" end
        if scrollerOf(focus) then t.PADLTRIGGER, t.PADRTRIGGER = "Scroll up", "Scroll down" end
    end
    if pickGroup(true) then t.PADLTRIGGER, t.PADRTRIGGER = "Prev page", "Next page" end
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
        end
    end
    anchorBar(b)
    -- never wider than the window it sits under: the items wrap onto more rows
    local w = (not G.placing) and (G.windowOfFocus() or wins[#wins]) or nil
    local maxW = 600
    if w and w.GetWidth and w.GetEffectiveScale and UIParent.GetEffectiveScale then
        local ww = (w:GetWidth() or 0) * ((w:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
        if ww > 0 then maxW = math.max(220, ww - 20) end
    end
    barLegend:SetMaxWidth(maxW)
    b:SetSize(barLegend:GetWidth(), barLegend:GetHeight())
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
    pcall(tooltipHide)
    if bar then bar:Hide() end
    barSig, anchoredTo = nil, nil
end

-- Placing a spell: no highlight. The next button you press, with whatever paddles you hold (the game turns a held paddle
-- into Shift or Ctrl), says which action slot it goes in: the slot that exact combination triggers, found from the player's
-- own key binds. A plain B cancels.
local PAD_KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
                   "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PADLSTICK", "PADRSTICK" }
local MODS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }
local BIND_FRAMES = { ACTIONBUTTON = "ActionButton", MULTIACTIONBAR1BUTTON = "MultiBarBottomLeftButton",
                      MULTIACTIONBAR2BUTTON = "MultiBarBottomRightButton", MULTIACTIONBAR3BUTTON = "MultiBarRightButton",
                      MULTIACTIONBAR4BUTTON = "MultiBarLeftButton", MULTIACTIONBAR5BUTTON = "MultiBar5Button",
                      MULTIACTIONBAR6BUTTON = "MultiBar6Button", MULTIACTIONBAR7BUTTON = "MultiBar7Button" }

-- The action slot a key combination triggers, and the bind it found: slot, action, or nil, action.
function G.slotForKey(key)
    local action = GetBindingAction and GetBindingAction(key)
    if not action or action == "" then return nil, nil end
    local base, n = action:match("^(.-BUTTON)(%d+)$")
    local frameName = base and BIND_FRAMES[base]
    local f = frameName and _G[frameName .. n]
    local slot = f and G.slotOf(f)
    return slot, action
end

-- Keys that do not come as pad buttons: a back button that Steam Input turns into a keyboard key (SPACE, F6 ...), and
-- any pad button the game also reports as a key. A frame takes the keyboard while a spell is being placed; the modifiers
-- held (a paddle the game uses as Ctrl or Shift counts too) make the combination, written the way the game stores binds.
local capFrame
local MODIFIER_KEYS = { LCTRL = 1, RCTRL = 1, LSHIFT = 1, RSHIFT = 1, LALT = 1, RALT = 1 }
local function comboFor(key)
    local m = ""
    if IsAltKeyDown and IsAltKeyDown() then m = "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then m = m .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then m = m .. "SHIFT-" end
    return m .. key
end
local function onCapKey(_, key)
    if not G.placing or not key then return end
    if MODIFIER_KEYS[key] or (UF.isModifierButton and UF.isModifierButton(key)) then
        UF.say("Binding: modifier " .. key .. " held.")   -- the paddle that stands in for Ctrl / Shift
        return
    end
    local combo = comboFor(key)
    local now = GetTime and GetTime() or 0
    if G.capLast == combo and now - (G.capLastT or 0) < 0.25 then return end   -- the same press arriving twice
    G.capLast, G.capLastT = combo, now
    UF.say("Binding: the game sent " .. combo .. " (key " .. tostring(key) .. ").")
    if key == "ESCAPE" or combo == "PAD2" then G.endPlace(true); UF.say("Binding cancelled."); return end
    if G.placeKey then G.placeKey(combo) end
end
function G.setCapture(on)
    if not capFrame then
        if not on then return end
        capFrame = CreateFrame("Frame", "UbermocForeverKeyCapture", UIParent)
        capFrame:SetScript("OnKeyDown", onCapKey)
        capFrame:SetScript("OnGamePadButtonDown", onCapKey)
    end
    -- turning it off must work in combat too, so nothing here checks for combat; each call is protected
    if on then
        pcall(capFrame.SetPropagateKeyboardInput, capFrame, false)
        pcall(capFrame.EnableKeyboard, capFrame, true)
        pcall(capFrame.EnableGamePadButton, capFrame, true)
    else
        pcall(capFrame.SetPropagateKeyboardInput, capFrame, true)
        pcall(capFrame.EnableKeyboard, capFrame, false)
        pcall(capFrame.EnableGamePadButton, capFrame, false)
    end
end

local function captureMap()
    local map = {}
    for _, mod in ipairs(MODS) do
        for _, k in ipairs(PAD_KEYS) do
            local key = mod .. k
            map[key] = function()
                if key == "PAD2" then G.endPlace(true); UF.say("Binding cancelled."); return end
                local now = GetTime and GetTime() or 0
                if G.capLast == key and now - (G.capLastT or 0) < 0.25 then return end
                G.capLast, G.capLastT = key, now
                UF.say("Binding: the controller sent " .. key .. ".")
                if G.placeKey then G.placeKey(key) end
            end
        end
    end
    return map
end

local function entryMaps()
    if G.placing then return captureMap(), nil end
    local c, b, rc = buttons()
    return {
        PADDUP = function() move("UP") end,
        PADDDOWN = function() move("DOWN") end,
        PADDLEFT = function() move("LEFT") end,
        PADDRIGHT = function() move("RIGHT") end,
        PAD4 = function()
            if focus and UF.ItemMenu and not (wins[1] and wins[1] == _G.UbermocForeverItemMenu) then
                if UF.ItemMenu.open(focus) then pcall(tooltipHide) end
            end
        end,
        PADLSHOULDER = function() stepTab(-1) end,
        PADRSHOULDER = function() stepTab(1) end,
        -- the side tabs when the window has them, else scroll the list
        PADLTRIGGER = function() if not stepTab(-1, true) then scrollBy(-1) end end,
        PADRTRIGGER = function() if not stepTab(1, true) then scrollBy(1) end end,
    }, {
        PAD1 = { c:GetName(), "LeftButton" },
        PAD3 = { rc:GetName(), "RightButton" },
        PAD2 = { b:GetName(), "LeftButton" },
    }
end

local function engage()
    local m, s = entryMaps()
    entry = UF.Nav.Push(m, s)
end

function G.applyMap()
    if not entry or InCombatLockdown() then return end
    local m, s = entryMaps()
    UF.Nav.Update(entry, m, s)
end

----------------------------------------------------------------------
-- The right stick scrolls the list or text under the highlight (a quest's text, a long list), smoothly: the further you push,
-- the faster. The sticks are only taken from the game while the highlight is in something that scrolls and we are not in
-- combat. The stick API is the one Ubermoc UI uses: C_GamePad.StickIndexToConfigName, GetDeviceMappedState().sticks[i] with
-- x, y and len, and EnableGamePadStick on a frame that has an OnGamePadStick script.
----------------------------------------------------------------------
local stickFrame, rightStick
local function findRightStick()
    rightStick = nil
    if not (C_GamePad and C_GamePad.StickIndexToConfigName) then return end
    for i = 0, 16 do
        local ok, name = pcall(C_GamePad.StickIndexToConfigName, i)
        if not ok or not name then break end
        if name == "Right" then rightStick = i + 1; return end
    end
end

local function stickScroll(dt)
    local sc, kind = scrollerOf(focus)
    if not sc then return end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    local pos = ok and state and state.sticks and rightStick and state.sticks[rightStick]
    if not pos or not pos.len or pos.len < 0.3 then return end
    local y = pos.y or 0
    if UF.DB().stickFlip then y = -y end
    local dir = (y > 0) and -1 or 1          -- stick up: back toward the top of the list
    local amount = math.min(1, math.abs(y)) * dt
    if kind == "box" and sc.GetScrollPercentage and sc.SetScrollPercentage then
        local okc, cur = pcall(sc.GetScrollPercentage, sc)
        local okv, vis = pcall(function() return sc.GetVisibleExtentPercentage and sc:GetVisibleExtentPercentage() end)
        if okc and cur then
            local per = (okv and vis and vis > 0 and vis <= 1) and vis * 1.2 or 0.25
            pcall(sc.SetScrollPercentage, sc, math.max(0, math.min(1, cur + dir * per * amount)))
        end
    elseif kind == "frame" then
        local cur, range = sc:GetVerticalScroll() or 0, sc:GetVerticalScrollRange() or 0
        sc:SetVerticalScroll(math.max(0, math.min(range, cur + dir * (sc:GetHeight() or 200) * 1.2 * amount)))
    end
    G.stickScrolled = true   -- only the view moves; the highlight stays on its button
    G.stickUntil = (GetTime and GetTime() or 0) + 1.0
end

local stickTicker = CreateFrame("Frame")
stickTicker:SetScript("OnUpdate", function(_, dt)
    local want = entry ~= nil and focus ~= nil and not InCombatLockdown() and scrollerOf(focus) ~= nil
    if want and not stickFrame then
        stickFrame = CreateFrame("Frame", "UbermocForeverStickBlocker", UIParent)
        stickFrame:SetScript("OnGamePadStick", function() end)
        findRightStick()
    end
    if stickFrame and stickFrame.stickOn ~= want then
        stickFrame.stickOn = want
        pcall(stickFrame.EnableGamePadStick, stickFrame, want)
    end
    if want then pcall(stickScroll, dt) end
end)

G.known = {}
function G.focusFrame() return focus end
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
        G.known = {}
        for _, w in ipairs(wins) do G.known[w] = true end
        rescan()
        setFocus(startNode())
        pcall(updateBar)
    elseif not want and entry then
        release()
    elseif want then
        -- keep the highlight honest: a popup appearing takes it, a vanished button is replaced, a scroll re-picks it
        if G.menuFrom and #openMenus() == 0 and not G.menuWait then
            G.menuWait = (G.menuWait or 0) + 1
        elseif G.menuFrom and #openMenus() == 0 then
            G.restore, G.menuFrom, G.menuWait = G.menuFrom, nil, nil
        elseif #openMenus() > 0 then
            G.menuWait = nil
        end
        -- a window that has just opened (the letter you opened in the mail) takes the highlight
        local now, fresh = {}, nil
        for _, w in ipairs(wins) do
            now[w] = true
            if not G.known[w] then fresh = w end
        end
        G.known = now
        if fresh and not G.placing and not popup and not (wins[1] == _G.UbermocForeverItemMenu) then
            rescan()
            local best
            for _, n in ipairs(nodes) do
                if G.inside(n.frame, fresh) and (not best or n.cy > best.cy + 4 or (math.abs(n.cy - best.cy) <= 4 and n.cx < best.cx)) then
                    best = n
                end
            end
            local d = G.dialogStart()
            if d and G.inside(d, fresh) then setFocus(d)
            elseif best then setFocus(best.frame) end
        end
        if G.placing then
            -- placing a spell: no highlight, the next button press picks the slot
            drawAt(nil)
            pcall(updateBar)
            return
        end
        if G.restore then
            local back = G.restore
            G.restore = nil
            if back.IsVisible and back:IsVisible() then rescan(); setFocus(back) end
        end
        local menu = _G.UbermocForeverItemMenu
        local needNew = (popup and focus and not G.inside(focus, popup))
            or (wins[1] and wins[1] == menu and focus and not G.inside(focus, menu))
            or (#wins == 1 and focus and wins[1].ubfMenuLike == nil and #openMenus() > 0 and not G.inside(focus, wins[1]))
        if G.retry then
            -- a move that scrolled the list first: the new buttons are there a moment later
            rescan()
            local cur = focus and nodeOf(focus)
            if not cur and G.lastRect then cur = G.nearest(nodes, G.lastRect.cx, G.lastRect.cy) end
            local nxt = cur and G.pick(nodes, cur, G.retry.dir)
            if nxt then setFocus(nxt.frame); G.retry = nil
            else
                G.retry.tries = G.retry.tries - 1
                if G.retry.tries <= 0 then G.retry = nil end
            end
        end
        if needNew or not focus then
            rescan(); setFocus(startNode())
        elseif not focus:IsVisible() then
            -- the button's row was recycled by a scroll. While the stick is scrolling, hold the highlight where it was;
            -- otherwise take the button nearest to where it was (never the window's first button, which is its exit).
            if (GetTime and GetTime() or 0) < (G.stickUntil or 0) then
                drawAt(nil)
            else
                rescan()
                local r = G.lastRect
                local n = r and G.nearest(nodes, r.cx, r.cy)
                setFocus(n and n.frame or startNode(), true)
            end
        elseif G.stickScrolled then
            G.stickScrolled = nil
            if G.inView(focus) then drawAt(focus) else drawAt(nil) end
        elseif G.scrolled then
            G.scrolled = nil
            rescan()
            if not nodeOf(focus) then
                local r = rectOf(focus)
                local n = r and G.nearest(nodes, r.cx, r.cy)
                -- the view was scrolled on purpose: keep it where it is
                setFocus(n and n.frame or startNode(), true)
            end
        else
            if G.inView(focus) then drawAt(focus) else drawAt(nil) end
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

-- /ubf tabs: what is open and which tab groups were found in it (for when a window's tabs do not answer).
function G.report()
    local w = G.windows()
    if #w == 0 then UF.say("No game window is open."); return end
    for _, f in ipairs(w) do
        local groups = G.groupsFor(f)
        local parts = {}
        for _, g in ipairs(groups) do parts[#parts + 1] = #g.buttons .. (isVertical(g) and " side" or " across") end
        UF.say((f.GetName and f:GetName() or "unnamed window") .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "no tabs found"))
    end
end
