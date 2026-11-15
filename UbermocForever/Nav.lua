----------------------------------------------------------------------
-- Ubermoc Forever: moving around our windows
-- With the game's controller interface off (the way the game is played here) its own way of moving around a window
-- is the virtual cursor: the right stick moves it and A clicks. This adds the D-pad on top, like Ubermoc UI does:
-- a press jumps the game's real cursor to the next button in that direction, and A then clicks it for real, so
-- the window behaves like a native one. While one of our windows is open the buttons it uses are taken with
-- override bindings (out of combat only); they are given back when it closes.
-- The cursor jump is ported from Ubermoc UI's PadCursor.lua: SetCursorPosition's units are not written down, so the
-- first jump is checked on the next frame against where the cursor really landed and corrected from then on.
----------------------------------------------------------------------
local _, UF = ...

local Nav = {}
UF.Nav = Nav

local calibration = { factor = nil }
local pendingCheck

local function MoveTo(px, py)
    local factor = calibration.factor or (1 / UIParent:GetEffectiveScale())
    local ax, ay = px * factor, py * factor
    local bx, by = GetCursorPosition()
    SetCursorPosition(ax, ay)
    if not calibration.factor then
        pendingCheck = { ax = ax, ay = ay, bx = bx, by = by, tries = 0 }
    end
end

local function checkLanding()
    local check = pendingCheck
    if not check then return end
    local rx, ry = GetCursorPosition()
    if math.abs(rx - check.bx) < 2 and math.abs(ry - check.by) < 2 then
        check.tries = check.tries + 1
        if check.tries > 10 then pendingCheck = nil end
        return
    end
    pendingCheck = nil
    local factor = check.ax / rx
    if rx > 50 and factor > 0.2 and factor < 5 then calibration.factor = factor end
end

-- A button's rectangle in the same units GetCursorPosition uses.
local function rectPx(b)
    local l, bt, w, h = b:GetRect()
    if not l then return nil end
    local s = b:GetEffectiveScale()
    return l * s, bt * s, (l + w) * s, (bt + h) * s
end

local function nodesOf(buttons, scrollFrame)
    local nodes = {}
    for _, b in ipairs(buttons) do
        if b:IsVisible() and (not b.IsEnabled or b:IsEnabled()) then
            local inView = true
            if scrollFrame and b:GetTop() and scrollFrame:GetTop() then
                inView = b:GetTop() <= scrollFrame:GetTop() + 1 and b:GetBottom() >= scrollFrame:GetBottom() - 1
            end
            local l, bt, r, t = rectPx(b)
            if inView and l then
                nodes[#nodes + 1] = { b = b, l = l, bt = bt, r = r, t = t, x = (l + r) / 2, y = (bt + t) / 2 }
            end
        end
    end
    return nodes
end

local function containing(nodes, x, y)
    for _, n in ipairs(nodes) do
        if x >= n.l and x <= n.r and y >= n.bt and y <= n.t then return n end
    end
end

local function nearest(nodes, x, y)
    local best, bestD
    for _, n in ipairs(nodes) do
        local d = (n.x - x) ^ 2 + (n.y - y) ^ 2
        if not bestD or d < bestD then best, bestD = n, d end
    end
    return best
end

-- The best button from (x, y) in a direction: it has to lie that way, and straight ahead beats off to the side.
local function pick(nodes, from, direction)
    local best, bestScore
    for _, n in ipairs(nodes) do
        if n ~= from then
            local dx, dy = n.x - from.x, n.y - from.y
            local along, across
            if direction == "UP" then along, across = dy, dx
            elseif direction == "DOWN" then along, across = -dy, dx
            elseif direction == "LEFT" then along, across = -dx, dy
            else along, across = dx, dy end
            if along > 2 then
                local score = along + 2.5 * math.abs(across)
                if not bestScore or score < bestScore then best, bestScore = n, score end
            end
        end
    end
    return best
end

-- getButtons() -> list of buttons that may take the cursor right now; scrollFrame (optional) is scrolled when
-- there is nothing further that way inside it.
function Nav.Step(direction, getButtons, scrollFrame)
    local buttons = getButtons()
    local nodes = nodesOf(buttons, scrollFrame)
    if #nodes == 0 then return false end
    local ox, oy = GetCursorPosition()
    local from = containing(nodes, ox, oy)
    local target
    if from then
        target = pick(nodes, from, direction)
        if not target and scrollFrame and (direction == "UP" or direction == "DOWN") then
            local range = scrollFrame:GetVerticalScrollRange() or 0
            local cur = scrollFrame:GetVerticalScroll() or 0
            local nextScroll = math.max(0, math.min(range, cur + (direction == "DOWN" and 90 or -90)))
            if nextScroll ~= cur then
                scrollFrame:SetVerticalScroll(nextScroll)
                -- the buttons have moved: look again on the next frame
                C_Timer.After(0, function()
                    local again = nodesOf(getButtons(), scrollFrame)
                    local f = containing(again, GetCursorPosition()) or nearest(again, GetCursorPosition())
                    local t = f and pick(again, f, direction)
                    if t then MoveTo(t.x, t.y) end
                end)
                return true
            end
        end
    else
        target = nearest(nodes, ox, oy)   -- not on a button yet: the first press goes to the nearest one
    end
    if not target then return false end
    MoveTo(target.x, target.y)
    return true
end

----------------------------------------------------------------------
-- Taking the buttons while a window is open
-- The buttons are taken with override bindings on one owner frame. That frame is a secure one with a state driver
-- on [combat]: the game itself drops its bindings the moment combat starts (code like this addon's cannot change
-- bindings in combat), so the D-pad, bumpers and face buttons are never left taken during a fight. This is the same
-- way Ubermoc UI does it. Blizzard's own controller code uses the same SetOverrideBindingClick for the same job.
----------------------------------------------------------------------
local carriers, handlers = {}, {}
local owner

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
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnClick", function()
        local fn = handlers[key]
        if fn then pcall(fn) end
    end)
    carriers[key] = b
    return b
end

-- map: { PADDUP = function() ... end, ... } for the buttons the window wants. Out of combat only.
function Nav.Enable(map)
    if InCombatLockdown() then return false end
    local o = getOwner()
    handlers = map
    for key in pairs(map) do
        local b = carrier(key)
        pcall(SetOverrideBindingClick, o, true, key, b:GetName(), "LeftButton")
    end
    return true
end

-- Gives the buttons back. In combat the secure driver has already done it.
function Nav.Disable()
    handlers = {}
    if InCombatLockdown() or not owner then return end
    pcall(ClearOverrideBindings, owner)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function() if pendingCheck then checkLanding() end end)
