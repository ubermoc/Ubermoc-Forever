----------------------------------------------------------------------
-- Ubermoc Forever: moving around our windows with the controller
--
-- While one of our windows (or one of our question windows) is open, the controller buttons it uses are taken from
-- the action bars with override bindings and handed to the window: the D-pad moves a highlight from button to
-- button, A presses the highlighted button, B goes back, X clears, Y resets, the bumpers change page. Nothing is
-- taken at any other time.
--
-- Why a highlight and not the game's pointer: the game's own virtual cursor does not click with A (its click is
-- R2), so A would fire whatever is on the action bars; and moving the pointer by code needs units the game does not
-- document (an earlier version did that and jumped to the wrong place). The highlight is the button's own highlight
-- art, and a button is pressed with its own Click(), so what you see is what is pressed.
--
-- The buttons are taken with override bindings on one secure owner frame with a [combat] state driver: code like
-- this addon's cannot change bindings in combat, so the game itself drops them the moment combat starts. This is the
-- same way Ubermoc UI does it; Blizzard's own controller code uses the same SetOverrideBindingClick.
----------------------------------------------------------------------
local _, UF = ...

local Nav = {}
UF.Nav = Nav
Nav.focus = nil

----------------------------------------------------------------------
-- Which window has which button: a stack, the newest on top
----------------------------------------------------------------------
local stack, carriers = {}, {}
local owner
local held, heldT

local REPEAT_KEYS = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }

local function handlerFor(key)
    for i = #stack, 1, -1 do
        local fn = stack[i].map[key]
        if fn then return fn end
    end
end

local function getOwner()
    if owner then return owner end
    owner = CreateFrame("Frame", "UbermocForeverNavOwner", UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-combat", [[ if newstate == "1" then self:ClearBindings() end ]])
    pcall(RegisterStateDriver, owner, "combat", "[combat] 1; 0")
    return owner
end

local function carrier(key)
    if carriers[key] then return carriers[key] end
    local b = CreateFrame("Button", "UbermocForeverNav_" .. key, UIParent)
    b:RegisterForClicks("AnyDown", "AnyUp")
    local pressed = false
    b:SetScript("OnClick", function(_, _, down)
        if down then
            pressed = true
            local fn = handlerFor(key)
            if fn then pcall(fn) end
            if REPEAT_KEYS[key] then held, heldT = key, -0.35 end
        else
            if not pressed then   -- only the release arrived: act on it
                local fn = handlerFor(key)
                if fn then pcall(fn) end
            end
            pressed = false
            if held == key then held = nil end
        end
    end)
    carriers[key] = b
    return b
end

-- Take every button any window on the stack wants. Out of combat only (the game blocks it in combat).
local function rebind()
    if InCombatLockdown() then return end
    local o = getOwner()
    pcall(ClearOverrideBindings, o)
    -- key -> { button name, mouse button }; an entry's `secure` keys (a real secure button, for clicking the game's own
    -- protected buttons) win over the plain carrier for the same key
    local keys = {}
    for _, e in ipairs(stack) do
        for key in pairs(e.map) do keys[key] = { carrier(key):GetName(), "LeftButton" } end
        for key, spec in pairs(e.secure or {}) do keys[key] = spec end
    end
    for key, spec in pairs(keys) do
        pcall(SetOverrideBindingClick, o, true, key, spec[1], spec[2])
    end
end

-- map: { PADDUP = function() ... end, PAD1 = function() ... end, ... }. Returns a token for Pop.
function Nav.Push(map, secure)
    local entry = { map = map, secure = secure }
    stack[#stack + 1] = entry
    rebind()
    return entry
end

function Nav.Count() return #stack end

function Nav.Pop(entry)
    for i = #stack, 1, -1 do
        if stack[i] == entry then table.remove(stack, i); break end
    end
    held = nil
    rebind()
end

-- Combat rule: nothing is taken in combat (the game blocks it), so a window opened then would show but not answer, and
-- the buttons would still fire abilities. Windows refuse to open in combat (see Nav.InCombat), and when combat ends the
-- buttons are taken again for any window still on the stack.
function Nav.InCombat() return InCombatLockdown() and true or false end
local after = CreateFrame("Frame")
after:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Windows stay open when combat starts: the game's secure driver gives every button back to the player's own binds, so
-- the buttons fire abilities, and it is up to the player to close the window. Any button held at that moment is let go.
after:RegisterEvent("PLAYER_REGEN_DISABLED")
after:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then held = nil else rebind() end
end)

-- Hold the D-pad to keep moving.
local repeater = CreateFrame("Frame")
repeater:SetScript("OnUpdate", function(_, dt)
    if not held then return end
    if #stack == 0 then held = nil; return end
    heldT = heldT + dt
    if heldT >= 0.1 then
        heldT = 0
        local fn = handlerFor(held)
        if fn then pcall(fn) end
    end
end)

----------------------------------------------------------------------
-- Our question windows: A is the first button (Yes), B the second (No)
----------------------------------------------------------------------
function Nav.TakePopup(dialog)
    local b1 = dialog.GetButton1 and dialog:GetButton1()
    local b2 = dialog.GetButton2 and dialog:GetButton2()
    dialog.ubfNav = Nav.Push({
        PAD1 = function() if b1 and b1:IsEnabled() then b1:Click() end end,
        PAD2 = function() if b2 and b2:IsShown() then b2:Click() end end,
    })
end

function Nav.ReleasePopup(dialog)
    if dialog.ubfNav then Nav.Pop(dialog.ubfNav); dialog.ubfNav = nil end
end

----------------------------------------------------------------------
-- The highlight
-- Buttons are given in rows: { { button, button }, { button }, ... }. Up and down move between rows (landing on the
-- button in that row closest across), left and right move within a row. A button may carry .navRow (a row frame to
-- highlight with it) and .navScroll (a scroll frame to keep it in view).
----------------------------------------------------------------------
local function lock(b, on)
    if not b then return end
    if on then
        if b.LockHighlight then b:LockHighlight() end
    else
        if b.UnlockHighlight then b:UnlockHighlight() end
    end
    local row = b.navRow
    if row then
        if on then row:LockHighlight() else row:UnlockHighlight() end
    end
end

function Nav.ClearFocus()
    lock(Nav.focus, false)
    Nav.focus = nil
end

-- Scroll just enough to bring the button fully into view.
local function reveal(b)
    local sf = b.navScroll
    if not sf or not sf:IsVisible() then return end
    local top, bottom = b:GetTop(), b:GetBottom()
    local sTop, sBottom = sf:GetTop(), sf:GetBottom()
    if not (top and bottom and sTop and sBottom) then return end
    local cur = sf:GetVerticalScroll() or 0
    local range = sf:GetVerticalScrollRange() or 0
    local margin = 8
    local new = cur
    if top > sTop - margin then
        new = cur - (top - (sTop - margin))
    elseif bottom < sBottom + margin then
        new = cur + ((sBottom + margin) - bottom)
    end
    new = math.max(0, math.min(range, new))
    if new ~= cur then sf:SetVerticalScroll(new) end
end

function Nav.SetFocus(b)
    if not b then return end
    if Nav.focus and Nav.focus ~= b then lock(Nav.focus, false) end
    Nav.focus = b
    lock(b, true)
    reveal(b)
end

function Nav.Move(direction, getRows, startRow)
    local rows = getRows()
    if #rows == 0 then return false end
    local r, c
    for i, row in ipairs(rows) do
        for j, b in ipairs(row) do
            if b == Nav.focus then r, c = i, j end
        end
    end
    if not r or not Nav.focus:IsVisible() then
        -- nothing highlighted yet (or it has gone): start here, without moving
        local row = rows[startRow or 1] or rows[1]
        Nav.SetFocus(row[1])
        return true
    end
    local row = rows[r]
    if direction == "LEFT" then
        if c > 1 then Nav.SetFocus(row[c - 1]) end
        return true
    elseif direction == "RIGHT" then
        if c < #row then Nav.SetFocus(row[c + 1]) end
        return true
    end
    local r2 = r + (direction == "DOWN" and 1 or -1)
    if r2 < 1 or r2 > #rows then return false end   -- the end of the list: stay, never wrap round
    local fx = Nav.focus:GetCenter() or 0
    local best, bestD
    for _, b in ipairs(rows[r2]) do
        local x = b:GetCenter() or fx
        local d = math.abs(x - fx)
        if not bestD or d < bestD then best, bestD = b, d end
    end
    Nav.SetFocus(best)
    return true
end

-- Press the highlighted button the way a mouse click would.
function Nav.Click()
    local b = Nav.focus
    if b and b:IsVisible() and (not b.IsEnabled or b:IsEnabled()) and b.Click then
        b:Click()
        return true
    end
    return false
end
