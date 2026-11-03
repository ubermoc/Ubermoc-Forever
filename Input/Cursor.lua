local _, ns = ...

-- The game has its own gamepad cursor: the right stick moves it and two buttons
-- click. Blizzard turns it on for some windows but not all (opening a bag from
-- the backpack key does not), so this turns it on while any window is open and
-- gives the stick back afterwards. It only turns off what it turned on, so a
-- cursor you started yourself stays. Nothing here runs in combat.
local Cursor = {}
ns.Cursor = Cursor

local POLL = 0.25
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

local function shown(frame)
    return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

function Cursor.WindowOpen()
    for _, name in ipairs(UISpecialFrames) do
        if name ~= OWN_WINDOW and shown(_G[name]) then
            return true
        end
    end
    for _, side in ipairs(PANELS) do
        if shown(GetUIPanel(side)) then
            return true
        end
    end
    for _, name in ipairs(FIXED_FRAMES) do
        if shown(_G[name]) then
            return true
        end
    end
    for i = 1, 13 do
        if shown(_G["ContainerFrame" .. i]) then
            return true
        end
    end
    return false
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
    syncInput(now and not InCombatLockdown() and Cursor.ActionsOn() and not shown(ownWindow) and Cursor.WindowOpen())
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

-- While the game's cursor is on, a window is open and you are not in combat, this takes
-- the face buttons the way a console menu does: A clicks what the cursor points at, X right-clicks it,
-- B or Start goes back, and Y is held back for later. A frame that listens for
-- controller buttons keeps them from firing abilities underneath.
local input = CreateFrame("Frame", "UbermocForeverCursorInput", UIParent)
input:SetSize(1, 1)
input:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
local inputActive = false

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

-- Back: close windows, and if none were open give the stick back to the camera.
function Cursor.Back()
    local closed = CloseAllWindows()
    if not closed and enabled() then
        SetGamePadCursorControl(false)
    end
    weEnabledIt = false
end

local function onButton(_, key)
    key = key:match("([^-]+)$") or key
    if key == "PAD1" then
        Cursor.ClickUnderCursor("LeftButton")
    elseif key == "PAD3" then
        Cursor.ClickUnderCursor("RightButton")
    elseif key == "PAD2" or key == "PADFORWARD" or key == "PADBACK" then
        Cursor.Back()
    end
end

-- Unless chosen, these start on where the game has no gamepad menus of its own
-- (Midnight) and off where it does (Forever).
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
