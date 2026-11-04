local _, ns = ...

-- The game has its own gamepad cursor: the right stick moves it and two buttons
-- click. Blizzard turns it on for some windows but not all (opening a bag from
-- the backpack key does not), so this turns it on while any window is open and
-- gives the stick back afterwards. It only turns off what it turned on, so a
-- cursor you started yourself stays. Nothing here runs in combat.
local Cursor = {}
ns.Cursor = Cursor

local POLL = 0.1
local CLOSE_DELAY = 0.3
local OWN_WINDOW = "UbermocForeverOptions"
local FIXED_FRAMES = { "GameMenuFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
    "ContainerFrameCombinedBags" }
local PANELS = { "left", "center", "right", "doublewide", "fullscreen" }

local weEnabledIt = false
local closedFor = 0
local lastState
local sinceLastPoll = 0
local syncInput
local inputActive = false
local tabCheck, legendUp = 0, false
local TAB_CHECK = 0.5

local function shown(frame)
    return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

-- The windows that are open, as a list of their top frames.
function Cursor.OpenWindows()
    local list, seen = {}, {}
    local function add(frame)
        if shown(frame) and not seen[frame] then
            seen[frame] = true
            list[#list + 1] = frame
        end
    end
    for _, name in ipairs(UISpecialFrames) do
        if name ~= OWN_WINDOW then
            add(_G[name])
        end
    end
    for _, side in ipairs(PANELS) do
        add(GetUIPanel(side))
    end
    for _, name in ipairs(FIXED_FRAMES) do
        add(_G[name])
    end
    for i = 1, 13 do
        add(_G["ContainerFrame" .. i])
    end
    return list
end

function Cursor.WindowOpen()
    return #Cursor.OpenWindows() > 0
end

local function enabled()
    return IsGamePadCursorControlEnabled() and true or false
end

-- One look at the situation; step is the time since the last look.
function Cursor.Update(step)
    local now = enabled()
    if now ~= lastState then
        ns.Log("cursor control " .. tostring(now))
        lastState = now
    end
    local ownWindow = _G[OWN_WINDOW]
    -- The game switches its cursor off and on again by itself, so the buttons stay taken for as
    -- long as a window is open; letting go for even a moment would fire abilities.
    syncInput(not InCombatLockdown() and Cursor.ActionsOn() and not shown(ownWindow) and Cursor.WindowOpen())
    if inputActive then
        tabCheck = tabCheck + step
        if tabCheck >= TAB_CHECK or not legendUp then
            tabCheck = 0
            legendUp = true
            ns.Legend.Show(ns.Tabs.Available())
        end
    else
        legendUp = false
    end
    if InCombatLockdown() or not Cursor.Auto() then
        closedFor = 0
        return
    end
    if not now then
        weEnabledIt = false
    end
    if Cursor.WindowOpen() then
        closedFor = 0
        if not now then
            SetGamePadCursorControl(true)
            weEnabledIt = true
        end
    elseif now and weEnabledIt then
        closedFor = closedFor + step
        if closedFor >= CLOSE_DELAY then
            closedFor = 0
            SetGamePadCursorControl(false)
            weEnabledIt = false
        end
    end
end

-- While a window is open and you are not in combat, this takes the face buttons
-- the way a console menu does: A clicks what the cursor points at, X right-clicks it,
-- B or Start goes back, and Y is held back for later. A frame that listens for
-- controller buttons keeps them from firing abilities underneath.
local input = CreateFrame("Frame", "UbermocForeverCursorInput", UIParent)
input:SetSize(1, 1)
input:SetPoint("TOPLEFT", UIParent, "TOPLEFT")

local function clickable(frame)
    for _ = 1, 5 do
        if not frame or frame == WorldFrame then
            return nil
        end
        if type(frame.Click) == "function" and frame.IsEnabled and frame:IsEnabled() then
            return frame
        end
        frame = frame.GetParent and frame:GetParent() or nil
    end
end

-- Returns the frame that was clicked, or nil.
function Cursor.ClickUnderCursor(mouseButton)
    for _, frame in ipairs(GetMouseFoci()) do
        local target = clickable(frame)
        if target then
            local ok = pcall(target.Click, target, mouseButton)
            ns.Log(("cursor %s click on %s: %s"):format(mouseButton, tostring(target.GetName and target:GetName() or "unnamed"), tostring(ok)))
            return ok and target or nil
        end
    end
    ns.Log("cursor " .. mouseButton .. " click: nothing clickable under the cursor")
end

-- The D-pad moves the game's cursor from button to button. Positions are in screen
-- units (a frame's centre times its effective scale, like GetCursorPosition).
local NODE_TYPES = { Button = true, CheckButton = true }
local MAX_DEPTH, MAX_NODES = 14, 900
local MIN_MOVE = 6
local DIRECTIONS = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT" }

local function visit(child, out, depth)
    if child:IsForbidden() or not child:IsShown() then
        return
    end
    if NODE_TYPES[child:GetObjectType()] and child:IsMouseEnabled() and child:IsVisible() then
        local cx, cy = child:GetCenter()
        local left, bottom, width, height = child:GetRect()
        if cx and cy and left then
            local scale = child:GetEffectiveScale()
            out[#out + 1] = { frame = child, x = cx * scale, y = cy * scale,
                l = left * scale, b = bottom * scale, r = (left + width) * scale, t = (bottom + height) * scale }
        end
    end
    if depth < MAX_DEPTH then
        for _, grandchild in ipairs({ child:GetChildren() }) do
            if #out < MAX_NODES then
                pcall(visit, grandchild, out, depth + 1)
            end
        end
    end
end

function Cursor.Nodes()
    local out = {}
    for _, root in ipairs(Cursor.OpenWindows()) do
        for _, child in ipairs({ root:GetChildren() }) do
            if #out < MAX_NODES then
                pcall(visit, child, out, 1)
            end
        end
    end
    return out
end

-- The nearest candidate in a direction. Straight ahead wins over off to the side.
function Cursor.Pick(candidates, ox, oy, direction)
    local best, bestScore
    for _, c in ipairs(candidates) do
        local dx, dy = c.x - ox, c.y - oy
        local along, across
        if direction == "UP" then
            along, across = dy, dx
        elseif direction == "DOWN" then
            along, across = -dy, dx
        elseif direction == "RIGHT" then
            along, across = dx, dy
        else
            along, across = -dx, dy
        end
        if along > MIN_MOVE then
            local score = along + 2 * math.abs(across)
            if not bestScore or score < bestScore then
                best, bestScore = c, score
            end
        end
    end
    return best
end

-- The node the cursor is on (the smallest one when they overlap), or nil.
function Cursor.Containing(candidates, ox, oy)
    local best, bestArea
    for _, c in ipairs(candidates) do
        if c.l and ox >= c.l and ox <= c.r and oy >= c.b and oy <= c.t then
            local area = (c.r - c.l) * (c.t - c.b)
            if not bestArea or area < bestArea then
                best, bestArea = c, area
            end
        end
    end
    return best
end

-- The closest node in any direction, for when the cursor is not on anything yet.
function Cursor.Nearest(candidates, ox, oy)
    local best, bestDistance
    for _, c in ipairs(candidates) do
        local distance = (c.x - ox) ^ 2 + (c.y - oy) ^ 2
        if not bestDistance or distance < bestDistance then
            best, bestDistance = c, distance
        end
    end
    return best
end

-- SetCursorPosition's units are not written down: a first guess is checked on the
-- next frame against where the cursor really landed, and corrected from then on.
local calibration = { factor = nil }
local pendingCheck

function Cursor.MoveTo(px, py)
    local factor = calibration.factor or (1 / UIParent:GetEffectiveScale())
    local ax, ay = px * factor, py * factor
    local bx, by = GetCursorPosition()
    SetCursorPosition(ax, ay)
    if not calibration.factor then
        pendingCheck = { ax = ax, ay = ay, bx = bx, by = by, tries = 0 }
    end
end

function Cursor.CheckLanding()
    local check = pendingCheck
    if not check then
        return
    end
    local rx, ry = GetCursorPosition()
    if math.abs(rx - check.bx) < 2 and math.abs(ry - check.by) < 2 then
        check.tries = check.tries + 1
        if check.tries > 10 then
            pendingCheck = nil
        end
        return
    end
    pendingCheck = nil
    local factor = check.ax / rx
    if rx > 50 and factor > 0.2 and factor < 5 then
        calibration.factor = factor
        ns.Log(("cursor units: sent %.0f,%.0f and it landed at %.0f,%.0f, factor %.4f"):format(check.ax, check.ay, rx, ry, factor))
    else
        ns.Log(("cursor units: could not tell (sent %.0f,%.0f, landed %.0f,%.0f)"):format(check.ax, check.ay, rx, ry))
    end
end

function Cursor.Snap(direction)
    local ox, oy = GetCursorPosition()
    local nodes = Cursor.Nodes()
    local target
    if Cursor.Containing(nodes, ox, oy) then
        target = Cursor.Pick(nodes, ox, oy, direction)
    else
        -- Not on a button yet (a menu just opened): the first press goes to the nearest one.
        target = Cursor.Nearest(nodes, ox, oy)
        ns.Log("snap " .. direction .. ": cursor was not on a button, going to the nearest")
    end
    if not target then
        ns.Log("snap " .. direction .. ": nothing that way")
        return false
    end
    Cursor.MoveTo(target.x, target.y)
    return true
end

-- A real mouse click at the cursor; falls back to clicking the button under it.
function Cursor.Click(mouseButton)
    local ok, err = pcall(SimulateMouseClick, mouseButton)
    ns.Log(("simulated %s click: %s"):format(mouseButton, ok and "ok" or tostring(err)))
    if not ok then
        Cursor.ClickUnderCursor(mouseButton)
    end
end

function Cursor.Scroll(delta)
    local ok, err = pcall(SimulateMouseWheel, delta)
    if not ok then
        ns.Log("simulated wheel failed: " .. tostring(err))
    end
end

-- Back closes the top thing: a dialog first, then the settings panel, menus, windows and bags.
-- The game's whole Esc action also stops casting and clears the target, and can use up
-- the press before anything closes, so only the closing steps are used.
function Cursor.Back()
    local closed
    if type(StaticPopup_EscapePressed) == "function" then
        local ok, result = pcall(StaticPopup_EscapePressed)
        closed = ok and result
    end
    if not closed then
        local settings = _G.SettingsPanel
        if shown(settings) then
            closed = pcall(settings.Close, settings)
        end
    end
    if not closed then
        if type(CloseMenus) == "function" then
            pcall(CloseMenus)
        end
        closed = CloseAllWindows()
    end
    if not closed and enabled() then
        SetGamePadCursorControl(false)
    end
    weEnabledIt = false
end

local function onButton(_, key)
    key = key:match("([^-]+)$") or key
    if Cursor.trace then
        Cursor.trace(key)
    end
    if DIRECTIONS[key] then
        Cursor.Snap(DIRECTIONS[key])
    elseif key == "PAD1" then
        Cursor.Click("LeftButton")
    elseif key == "PAD3" then
        Cursor.Click("RightButton")
    elseif key == "PADLSHOULDER" then
        ns.Tabs.Step(-1)
    elseif key == "PADRSHOULDER" then
        ns.Tabs.Step(1)
    elseif key == "PADLTRIGGER" then
        Cursor.Scroll(1)
    elseif key == "PADRTRIGGER" then
        Cursor.Scroll(-1)
    elseif key == "PAD2" or key == "PADFORWARD" or key == "PADBACK" then
        Cursor.Back()
    end
end

function Cursor.ActionsOn()
    local value = ns.db.cursorActions
    if value == nil then
        return not ns.HasNativeGamepad()
    end
    return value
end

function Cursor.SetActions(on)
    ns.db.cursorActions = on and true or false
end

function Cursor.CloseOnCombat()
    return ns.db.closeOnCombat ~= false
end

function Cursor.SetCloseOnCombat(on)
    ns.db.closeOnCombat = on and true or false
end

function syncInput(want)
    if want == inputActive then
        return
    end
    inputActive = want
    input:EnableGamePadButton(want)
    if want then
        input:SetScript("OnGamePadButtonDown", onButton)
        input:Show()
    else
        input:SetScript("OnGamePadButtonDown", nil)
        input:Hide()
    end
    ns.Log("cursor buttons " .. (want and "taken" or "released"))
    if not want then
        ns.Legend.Hide()
    end
end

-- Combat starts: windows close, the cursor goes, and the buttons are the abilities again.
function Cursor.OnCombatStart()
    syncInput(false)
    if not Cursor.CloseOnCombat() then
        return
    end
    ns.Options.Hide()
    pcall(CloseAllWindows)
    if enabled() then
        pcall(SetGamePadCursorControl, false)
    end
    weEnabledIt = false
    closedFor = 0
end

function Cursor.SetAuto(on)
    ns.db.cursorAuto = on and true or false
end

function Cursor.Auto()
    local value = ns.db.cursorAuto
    if value == nil then
        return not ns.HasNativeGamepad()
    end
    return value
end

function Cursor.PrintStatus()
    print(ns.L.CURSOR_STATE:format(enabled() and ns.L.YES or ns.L.NO, Cursor.Auto() and ns.L.YES or ns.L.NO,
        Cursor.WindowOpen() and ns.L.YES or ns.L.NO))
    print(ns.L.CURSOR_ACTIONS:format(Cursor.ActionsOn() and ns.L.YES or ns.L.NO, Cursor.CloseOnCombat() and ns.L.YES or ns.L.NO))
    print(ns.L.CURSOR_CLICKS:format(tostring(C_CVar.GetCVar("GamePadCursorLeftClick")),
        tostring(C_CVar.GetCVar("GamePadCursorRightClick")), tostring(C_CVar.GetCVar("GamePadCursorCentering"))))
end

-- /ubf cursor <args>
function Cursor.Command(args)
    local word, rest = args:match("^(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "auto" then
        local value = rest:lower()
        if value == "on" or value == "off" then
            Cursor.SetAuto(value == "on")
            print(ns.L.CURSOR_AUTO_SET:format(value == "on" and ns.L.YES or ns.L.NO))
            return
        end
        print(ns.L.CURSOR_HELP)
    elseif word == "actions" then
        local value = rest:lower()
        if value == "on" or value == "off" then
            Cursor.SetActions(value == "on")
            print(ns.L.CURSOR_ACTIONS_SET:format(value == "on" and ns.L.YES or ns.L.NO))
            return
        end
        print(ns.L.CURSOR_HELP)
    elseif word == "on" or word == "off" then
        SetGamePadCursorControl(word == "on")
    elseif word == "" or word == "status" then
        Cursor.PrintStatus()
    else
        print(ns.L.CURSOR_HELP)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function()
    Cursor.OnCombatStart()
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    Cursor.CheckLanding()
    sinceLastPoll = sinceLastPoll + elapsed
    if sinceLastPoll >= POLL then
        local step = sinceLastPoll
        sinceLastPoll = 0
        Cursor.Update(step)
    end
end)

pcall(hooksecurefunc, "SetGamePadCursorControl", function(on)
    ns.Log("SetGamePadCursorControl(" .. tostring(on) .. ")")
end)
