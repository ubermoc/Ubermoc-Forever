-- Offline smoke test: loads the addon files against stubbed WoW APIs.
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
local handlers = {}
local function proxy()
    return setmetatable({}, { __index = function(t) return t end, __call = function(t) return t end })
end
UIParent = { GetEffectiveScale = function() return 0.75 end }
UISpecialFrames = {}
function CreateFrame(_, name)
    local f = setmetatable({ events = {}, scripts = {}, name = name, shown = false },
        { __index = function() return proxy() end })
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(kind, fn)
        self.scripts[kind] = fn
        if kind == "OnEvent" then self.fn = fn elseif kind == "OnUpdate" then self.onUpdate = fn end
    end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f.CreateFontString()
        local fs = setmetatable({}, { __index = function() return proxy() end })
        fs.GetStringWidth = function() return 100 end
        fs.GetStringHeight = function() return 18 end
        fs.SetText = function(this, text) this.value = text end
        return fs
    end
    function f:SetHeight(h) self.height = h end
    function f:GetHeight() return rawget(self, "height") or 0 end
    function f:SetParent(p) self.parentFrame = p end
    function f:GetParent() return rawget(self, "parentFrame") end
    function f:GetFrameLevel() return 1 end
    function f:CreateTexture() return setmetatable({}, { __index = function() return proxy() end }) end
    function f:SetAttribute(k, v) if not rawget(self, "attrs") then self.attrs = {} end self.attrs[k] = v end
    handlers[#handlers + 1] = f
    return f
end
function GetBuildInfo() return "1.60.1", "70707", "x", 16001 end
function GetTime() return 1 end
function date() return "2026-01-01 00:00:00" end
C_Texture = { GetAtlasInfo = function(a) if a:find("xbox") then return {} end end }
function geterrorhandler() return function() end end
function seterrorhandler() end
local nativeLoaded = false
C_AddOns = { GetAddOnMetadata = function() return "test" end, IsAddOnLoaded = function(name) return name == "Blizzard_Gamepad" and nativeLoaded end }
SlashCmdList = {}
local configs = {
    ["all"] = { name = "All Devices", labelStyle = "Generic" },
    ["10462/4607"] = { vendorID = 10462, productID = 4607, labelStyle = "Generic", rawButtonMappings = { 1, 2, 3 } },
}
local applied = 0
local function configKey(id) return id.vendorID and (id.vendorID .. "/" .. id.productID) or "all" end
local cursorPos = { x = 100, y = 100 }
local setCalls = 0
function GetCursorPosition() return cursorPos.x, cursorPos.y end
function SetCursorPosition(x, y) setCalls = setCalls + 1 cursorPos = { x = x, y = y } end
local cursorOn = false
local mouseFoci = {}
function GetMouseFoci() return mouseFoci end
WorldFrame = {}
local windowsClosed = 0
function CloseAllWindows() windowsClosed = windowsClosed + 1 return windowsClosed % 2 == 1 end
function GetUIPanel() return nil end
local hooked = {}
function hooksecurefunc(t, name, fn) if type(t) == "table" then hooked[name] = fn end end
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
function PlaySound() end
local menuHidden = 0
function HideUIPanel() menuHidden = menuHidden + 1 end
local saved = {}
function SetBinding(key, action) saved[key] = action end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function IsGamePadCursorControlEnabled() return cursorOn end
function SetGamePadCursorControl(on) cursorOn = on end
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADLSHOULDER",
    GamePadCursorLeftClick = "PADRTRIGGER", GamePadCursorRightClick = "PADRSHOULDER", GamePadCursorCentering = "0" }
C_CVar = {
    GetCVar = function(n) return cvars[n] end,
    SetCVar = function(n, v) assert(cvars[n] ~= nil, "unknown cvar") cvars[n] = v end,
}
local inCombat = false
function InCombatLockdown() return inCombat end
local bindings = {}
function SetOverrideBinding(_, _, key, command) bindings[key] = command end
function ClearOverrideBindings() bindings = {} end
function GetBindingAction(key, checkOverride)
    if checkOverride then return bindings[key] or saved[key] or "" end
    return saved[key] or ""
end
C_GamePad = {
    IsEnabled = function() return true end,
    GetActiveDeviceID = function() return 2 end,
    GetCombinedDeviceID = function() return 99 end,
    GetAllDeviceIDs = function() return { 2, 99 } end,
    GetDeviceMappedState = function(id)
        return { name = "Pad" .. (id or "active"), labelStyle = "Generic", buttonCount = 32, axisCount = 2, stickCount = 1,
            buttons = { false, true, false }, axes = { 0, 0.5 }, sticks = { { x = 0.5, y = 0, len = 0.5 } } }
    end,
    ButtonIndexToBinding = function(i)
        local names = { [0] = "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
            "PADLSTICK", "PADRSTICK", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
            "PADLSTICKUP", "PADLSTICKRIGHT", "PADLSTICKDOWN", "PADLSTICKLEFT",
            "PADRSTICKUP", "PADRSTICKRIGHT", "PADRSTICKDOWN", "PADRSTICKLEFT",
            "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PADFORWARD", "PADBACK", "PADSYSTEM", "PADSOCIAL" }
        return names[i] or ("PADX" .. i)
    end,
    AxisIndexToConfigName = function(i) return "Axis" .. i end,
    StickIndexToConfigName = function(i) return "Stick" .. i end,
    GetDeviceRawState = function(id)
        if id == 2 then return { name = "Steam Virtual Gamepad", vendorID = 10462, productID = 4607 } end
        return { name = "Combined", vendorID = 0, productID = 0 }
    end,
    GetConfig = function(id)
        local c = configs[configKey(id)]
        if not c then return nil end
        local copy = {}
        for k, v in pairs(c) do copy[k] = v end
        return copy
    end,
    SetConfig = function(c) configs[configKey(c)] = c end,
    ApplyConfigs = function() applied = applied + 1 end,
}

local ns = {}
for _, f in ipairs({ "Locales/enUS.lua", "Core/Init.lua", "Core/Compat.lua", "Core/Debug.lua", "Core/SelfTest.lua", "Input/GamePad.lua", "Input/Labels.lua", "Input/PadTest.lua", "Input/Layout.lua", "Input/Cursor.lua", "Input/Binds.lua", "Core/Report.lua", "Input/Tabs.lua", "UI/Legend.lua", "UI/Options.lua", "UI/GameMenu.lua" }) do
    assert(loadfile(f))("UbermocForever", ns)
end
local function fire(event, arg)
    for _, h in ipairs(handlers) do
        if h.events[event] and h.fn then h.fn(h, event, arg) end
    end
end
fire("ADDON_LOADED", "UbermocForever")
fire("PLAYER_LOGIN")
fire("GAME_PAD_CONNECTED")
assert(configs["10462/4607"].labelStyle == "Letters", "Valve's pad is switched to Letters by default")
assert(#configs["10462/4607"].rawButtonMappings == 3, "the rest of the pad config is kept")
assert(applied == 1, "configs applied once")
assert(configs["all"].labelStyle == "Letters", "auto sets the all-devices config too while a Valve pad is connected")
fire("GAME_PAD_CONFIGS_CHANGED")
assert(applied == 1, "nothing is rewritten when the style already matches")
ns.Labels.Command("shapes")
assert(configs["10462/4607"].labelStyle == "Shapes" and configs["all"].labelStyle == "Shapes", "an explicit style applies everywhere")
assert(ns.Labels.Describe({ changed = 1, same = 0, missing = 0, failed = 0 }):find("reports"), "result line names the active style")
ns.Labels.Command("default")
ns.Labels.Command("generic")
assert(configs["all"].labelStyle == "Generic", "explicit style can change back")
ns.Labels.Command("default")
configs["10462/4607"].labelStyle = "Shapes"
ns.Labels.Command("default")
assert(configs["10462/4607"].labelStyle == "Shapes", "game default leaves configs alone")
ns.Labels.Command("auto")
assert(configs["10462/4607"].labelStyle == "Letters", "auto returns to Letters for Valve")
SlashCmdList["UBERMOCFOREVER"]("pad")
SlashCmdList["UBERMOCFOREVER"]("debug")
SlashCmdList["UBERMOCFOREVER"]("log")
SlashCmdList["UBERMOCFOREVER"]("padtest")
SlashCmdList["UBERMOCFOREVER"]("padmap")
for _, h in ipairs(handlers) do
    if h.onUpdate then h.onUpdate(h, 1) end
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local layout = ns.Layout

-- layout is off until enabled
assert(count(bindings) == 0, "layout starts off")
layout.Command("on")
assert(count(bindings) == 68, "68 bindings, got " .. count(bindings))
assert(bindings["PAD3"] == "ACTIONBUTTON1", "X is slot 1")
assert(bindings["PAD1"] == "ACTIONBUTTON2", "A is slot 2")
assert(bindings["PADLTRIGGER"] == "ACTIONBUTTON12", "L2 is slot 12")
assert(bindings["SHIFT-PAD3"] == "MULTIACTIONBAR1BUTTON1", "shift set is bar 2")
assert(bindings["CTRL-PAD3"] == "MULTIACTIONBAR2BUTTON1", "ctrl set is bar 3")
assert(bindings["CTRL-SHIFT-PADDUP"] == "MULTIACTIONBAR3BUTTON8", "both set is bar 4")
assert(cvars.GamePadEmulateShift == "PADPADDLE1" and cvars.GamePadEmulateCtrl == "PADPADDLE3", "paddles emulate modifiers")

assert(bindings["PADFORWARD"] == "CLICK UbermocForeverMenu:LeftButton", "Start opens the game menu directly")
assert(bindings["CTRL-PADFORWARD"] == "CLICK UbermocForeverMenu:LeftButton", "Start works with a paddle held too")
assert(bindings["PADBACK"] == "TOGGLEWORLDMAP", "Select opens the map")
assert(bindings["PADLSTICK"] == "TOGGLEAUTORUN", "L3 auto-runs")
assert(bindings["PADPADDLE2"] == "INTERACTTARGET", "L4 interacts")
assert(bindings["PADPADDLE4"] == "JUMP", "L5 jumps")
assert(bindings["CTRL-SHIFT-PADPADDLE4"] == "JUMP", "L5 jumps with both modifiers held")
layout.Command("extra PADPADDLE4 NONE")
assert(bindings["PADPADDLE4"] == nil and count(bindings) == 64, "extra can be unbound")
layout.Command("extra PADPADDLE4 JUMP")
layout.Command("extra PAD1 JUMP")
layout.Command("bind 2 PADFORWARD")
assert(bindings["PAD1"] == "ACTIONBUTTON2", "extra keys are protected from slot binds")
layout.Command("status")
layout.Command("off")
cvars.GamePadEmulateShift = nil
cvars.GamePadEmulateCtrl = nil
local mark = #printed
layout.Command("on")
assert(table.concat(printed, "\n", mark + 1):find("did not accept"), "missing cvars reported")
assert(count(bindings) == 68, "bindings still applied without cvars")
layout.Command("off")
cvars.GamePadEmulateShift = "PADLTRIGGER"
cvars.GamePadEmulateCtrl = "PADLSHOULDER"
layout.Command("on")
layout.Command("bind 1 PAD5")
assert(bindings["PAD5"] == "ACTIONBUTTON1", "free key can be bound")
assert(bindings["PAD3"] == nil, "old key released")
layout.Command("bind 1 PAD4")  -- used by slot 4, so the two swap
assert(bindings["PAD4"] == "ACTIONBUTTON1" and bindings["PAD5"] == "ACTIONBUTTON4", "duplicate swaps slots")
layout.Command("bind 1 PAD5")
assert(bindings["PAD5"] == "ACTIONBUTTON1" and bindings["PAD4"] == "ACTIONBUTTON4", "swap back")
layout.Command("bind 1 NOPE")  -- unknown
layout.Command("bar 2 5")
assert(bindings["SHIFT-PAD5"] == "MULTIACTIONBAR4BUTTON1", "custom slot and bar")

inCombat = true
layout.Command("reset")
assert(bindings["SHIFT-PAD5"] == "MULTIACTIONBAR4BUTTON1", "no change while in combat")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(bindings["SHIFT-PAD3"] == "MULTIACTIONBAR1BUTTON1", "pending reset applies after combat")
assert(bindings["SHIFT-PAD5"] == nil, "custom binding gone after reset")

layout.Command("off")
assert(count(bindings) == 0, "off clears bindings")
assert(cvars.GamePadEmulateShift == "PADLTRIGGER" and cvars.GamePadEmulateCtrl == "PADLSHOULDER", "off restores cvars")

-- options window
inCombat = true
ns.Options.Toggle()
local win
for _, h in ipairs(handlers) do if h.name == "UbermocForeverOptions" then win = h end end
assert(win == nil, "options window does not open in combat")
inCombat = false
ns.Options.Toggle()
for _, h in ipairs(handlers) do if h.name == "UbermocForeverOptions" then win = h end end
assert(win and win.shown, "options window opens")
local press = win.scripts.OnGamePadButtonDown
local cfg = ns.Layout.Config()
press(win, "PADDDOWN")            -- slot 1 row
press(win, "PAD1")                -- start capture
press(win, "PADPADDLE1")          -- a modifier paddle is refused
assert(cfg.slots[1] ~= "PADPADDLE1", "modifier paddle refused")
press(win, "PADLSTICKUP")         -- stick direction is a valid slot button
assert(cfg.slots[1] == "PADLSTICKUP", "capture assigns slot 1")
press(win, "PADRSHOULDER")        -- page 2
press(win, "PADDRIGHT")
assert(cfg.shiftButton == "PADPADDLE2", "shift paddle cycles")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cfg.ctrlButton == "PADPADDLE4", "ctrl paddle cycles")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cfg.bars[1] == 2, "bar cycles")
press(win, "PADRSHOULDER")        -- page 3
press(win, "PADDRIGHT")
assert(cfg.extras.PADFORWARD == "TOGGLEGAMEMENU", "extra command cycles")
-- A opens a drop-down list on a row with choices; the D-pad moves, A picks, B cancels
press(win, "PAD1")
assert(ns.Options.DropdownOpen(), "A opens the list")
press(win, "PADDDOWN")
press(win, "PAD1")
assert(not ns.Options.DropdownOpen() and cfg.extras.PADFORWARD == "TOGGLEWORLDMAP", "the highlighted choice is picked")
press(win, "PAD1")
press(win, "PADDUP")
press(win, "PAD2")
assert(not ns.Options.DropdownOpen() and cfg.extras.PADFORWARD == "TOGGLEWORLDMAP", "B closes the list and changes nothing")
press(win, "PAD1")
for _ = 1, 20 do press(win, "PADDDOWN") end
press(win, "PAD1")
assert(cfg.extras.PADFORWARD ~= nil and not ns.Options.DropdownOpen(), "the list wraps and still picks")
cfg.extras.PADFORWARD = "TOGGLEGAMEMENU"
for _ = 1, 5 do press(win, "PADDDOWN") end   -- window background tint row
press(win, "PADDRIGHT")
assert(ns.db.optionsTint == 50, "tint steps by 5 from 45")
press(win, "PADRTRIGGER")
assert(ns.db.optionsTint == 51, "trigger steps tint by 1")
for _ = 1, 30 do press(win, "PADDLEFT") end
assert(ns.db.optionsTint == 0, "tint stops at 0")
press(win, "PADDDOWN")                       -- window background opacity row
press(win, "PADDLEFT")
assert(ns.db.optionsOpacity == 95, "opacity starts at 100 and steps by 5")
press(win, "PADRTRIGGER")
assert(ns.db.optionsOpacity == 96, "trigger steps opacity by 1")
for _ = 1, 30 do press(win, "PADDRIGHT") end
assert(ns.db.optionsOpacity == 100, "opacity stops at 100")
for _ = 1, 30 do press(win, "PADDLEFT") end
assert(ns.db.optionsOpacity == 0, "opacity stops at 0")
-- a 0.4.2 save stored the tint as optionsOpacity
ns.db.optionsTint, ns.db.optionsOpacity = nil, 80
press(win, "PADDLEFT")
assert(ns.db.optionsTint == 80 and ns.db.optionsOpacity == 95, "0.4.2 tint carried over, opacity restarts at 100 then steps")
ns.db.optionsTint, ns.db.optionsOpacity, ns.db.optionsShade = nil, nil, 1
press(win, "PADDLEFT")
assert(ns.db.optionsTint == 100 and ns.db.optionsShade == nil and ns.db.optionsOpacity == 95, "0.4.1 dark step carried over")
saved["PAD4"] = "ACTIONBUTTON4"
press(win, "PADDDOWN")                       -- button labels row
press(win, "PADDRIGHT")
assert(ns.db.labelStyle == "DEFAULT", "button labels row cycles")
press(win, "PADDLEFT")
assert(ns.db.labelStyle == nil, "button labels row returns to auto")
press(win, "PADDDOWN")                       -- button picture style row
press(win, "PADDRIGHT")
assert(ns.db.legendStyle == "Midnight", "interface style row cycles from auto to Midnight")
assert(rawget(_G, "UbermocForeverOptions").uiStyle == "Midnight", "the open window is redrawn in the plain panel")
press(win, "PADDRIGHT")
assert(ns.db.legendStyle == "Forever", "then to Forever")
assert(rawget(_G, "UbermocForeverOptions").uiStyle == "Forever", "and in Blizzard's portrait panel")
press(win, "PADDRIGHT")
assert(ns.db.legendStyle == nil, "and back to auto")
assert(rawget(_G, "UbermocForeverOptions").uiStyle == "Forever", "auto is the game's own style (Forever here)")
press(win, "PADDDOWN")                       -- clear old saved binds row
press(win, "PAD1")
assert(saved["PAD4"] == "ACTIONBUTTON4", "clearing needs a second press")
press(win, "PAD1")
assert(saved["PAD4"] == nil and ns.db.bindBackup, "second press backs up and clears")
press(win, "PADDDOWN")                       -- restore row
press(win, "PAD1")
assert(saved["PAD4"] == "ACTIONBUTTON4" and ns.db.bindBackup == nil, "restore puts the bind back")
saved["PAD4"] = nil
press(win, "PADRSHOULDER")                   -- cursor page
press(win, "PADDRIGHT")                      -- cursor opens with windows
assert(ns.db.cursorAuto == false, "cursor auto toggles off (on by default on Midnight)")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(ns.db.cursorActions == false, "cursor actions toggle off")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(ns.db.closeOnCombat == false, "close in combat toggles off")
press(win, "PADDDOWN")                       -- left click row
press(win, "PADDRIGHT")
assert(cvars.GamePadCursorLeftClick == "PADRSHOULDER", "left click button cycles")
press(win, "PADDLEFT")
press(win, "PADDLEFT")
assert(cvars.GamePadCursorLeftClick == "NONE", "left click button can be switched off")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cvars.GamePadCursorRightClick == "PADLTRIGGER", "right click button cycles")
press(win, "PADDDOWN")
press(win, "PADDRIGHT")
assert(cvars.GamePadCursorCentering == "1", "centering toggles on")
press(win, "PADDDOWN")
press(win, "PAD1")
assert(cursorOn == true, "cursor can be turned on from the window")
press(win, "PADDDOWN")
press(win, "PAD1")
assert(cvars.GamePadCursorLeftClick == "PADRTRIGGER" and cvars.GamePadCursorRightClick == "PADRSHOULDER"
    and cvars.GamePadCursorCentering == "0", "cursor settings reset")
press(win, "PADRSHOULDER")                   -- back around to the first page
press(win, "PAD2")
assert(not win.shown, "B closes the window")
ns.Layout.ResetDefaults()
ns.db.cursorAuto, ns.db.cursorActions, ns.db.closeOnCombat = nil, nil, nil

-- game cursor manager
local menu = { shown = false }
GameMenuFrame = { IsShown = function() return menu.shown end }
cursorOn, inCombat = false, false
menu.shown = true
ns.Cursor.Update(0.3)
assert(cursorOn, "cursor opens with a window")
menu.shown = false
ns.Cursor.Update(0.1)
assert(cursorOn, "cursor waits a moment before closing")
ns.Cursor.Update(0.3)
assert(not cursorOn, "cursor closes once the windows are gone")
cursorOn = true
ns.Cursor.Update(0.6)
assert(cursorOn, "a cursor the player started is left alone")
cursorOn, inCombat, menu.shown = false, true, true
ns.Cursor.Update(0.3)
assert(not cursorOn, "no cursor changes in combat")
inCombat = false

-- the cursor's buttons
local clicked
mouseFoci[1] = { Click = function(_, b) clicked = b end, IsEnabled = function() return true end,
    GetName = function() return "TestButton" end, GetParent = function() return nil end }
local pad
for _, h in ipairs(handlers) do if h.name == "UbermocForeverCursorInput" then pad = h end end
cursorOn, menu.shown = true, true
ns.Cursor.Update(0.1)
local onButton = pad.scripts.OnGamePadButtonDown
assert(onButton, "buttons are taken while the cursor is on")
onButton(pad, "PAD1")
assert(clicked == "LeftButton", "A left-clicks")
onButton(pad, "PAD3")
assert(clicked == "RightButton", "X right-clicks")

-- the D-pad moves the cursor between buttons
local function node(x, y)
    local f = {}
    function f:IsForbidden() return false end
    function f:IsShown() return true end
    function f:IsVisible() return true end
    function f:IsMouseEnabled() return true end
    function f:GetObjectType() return "Button" end
    function f:GetCenter() return x, y end
    function f:GetRect() return x - 20, y - 10, 40, 20 end
    function f:GetEffectiveScale() return 1 end
    function f:GetChildren() end
    return f
end
local rightNode, upNode, downNode = node(300, 100), node(100, 300), node(100, 40)
local pickable = { { x = 10, y = 100 }, { x = 100, y = 15 }, { x = 90, y = 200 } }
assert(ns.Cursor.Pick(pickable, 0, 0, "UP") == pickable[1], "nearly straight ahead beats far off to the side")
assert(ns.Cursor.Pick(pickable, 0, 0, "RIGHT") == pickable[2], "the one level with the origin wins going right")
assert(ns.Cursor.Pick(pickable, 0, 0, "DOWN") == nil, "nothing below the origin")
assert(ns.Cursor.Pick({ { x = 3, y = 0 } }, 0, 0, "RIGHT") == nil, "a button under the cursor is skipped")
local realMenu = GameMenuFrame
GameMenuFrame = { IsShown = function() return true end, GetChildren = function() return rightNode, upNode, downNode end }
cursorPos, setCalls = { x = 100, y = 100 }, 0
onButton(pad, "PADDRIGHT")
assert(setCalls == 1, "one cursor move per press")
assert(cursorPos.y ~= 100, "off every button, the first press goes to the nearest one")
ns.Cursor.CheckLanding()                      -- the guess (UI units) was wrong, the stub takes screen units
cursorPos = { x = 100, y = 40 }               -- where the first, miscalibrated, move really landed
onButton(pad, "PADDUP")
assert(cursorPos.x == 100 and cursorPos.y == 300, "calibrated moves land on the button")
onButton(pad, "PADDDOWN")
assert(cursorPos.x == 100 and cursorPos.y == 40, "down snaps to the lower button")
local before = setCalls
onButton(pad, "PADDDOWN")
assert(setCalls == before, "no move when nothing is that way")
local grid = { { x = 100, y = 40, l = 80, r = 120, b = 30, t = 50 }, { x = 100, y = 40, l = 0, r = 500, b = 0, t = 500 } }
assert(ns.Cursor.Containing(grid, 100, 40) == grid[1], "the smallest button under the cursor wins")
assert(ns.Cursor.Containing(grid, 900, 900) == nil, "nothing under the cursor")
assert(ns.Cursor.Nearest({ { x = 0, y = 0 }, { x = 5, y = 5 } }, 6, 6).x == 5, "nearest button in any direction")
GameMenuFrame = realMenu

-- real mouse clicks and the wheel
local sim, wheel, simulateFails = {}, nil, false
function SimulateMouseClick(b) if simulateFails then error("focus not valid") end sim[#sim + 1] = b end
function SimulateMouseWheel(d) wheel = d end
onButton(pad, "PAD1")
onButton(pad, "PAD3")
assert(sim[1] == "LeftButton" and sim[2] == "RightButton", "A and X send real mouse clicks")
clicked = nil
simulateFails = true
onButton(pad, "PAD1")
assert(clicked == "LeftButton", "a refused click falls back to clicking the button")
simulateFails = false
onButton(pad, "PADRTRIGGER")
assert(wheel == -1, "R2 scrolls down")
onButton(pad, "PADLTRIGGER")
assert(wheel == 1, "L2 scrolls up")
windowsClosed = 0
onButton(pad, "PAD2")
assert(cursorOn, "B closes a window first")
onButton(pad, "PAD2")
assert(not cursorOn, "B with no window open gives the stick back")
-- Back closes a dialog first, then everything else, and never runs the Esc action
local popupUp, escTouched = true, false
function StaticPopup_EscapePressed() if popupUp then popupUp = false return 1 end end
function ToggleGameMenu() escTouched = true end
windowsClosed = 0
onButton(pad, "PAD2")
assert(not popupUp and windowsClosed == 0, "B closes a dialog before anything else")
onButton(pad, "PAD2")
assert(windowsClosed == 1, "B then closes the windows")
assert(not escTouched, "the Esc action (target clear, stop casting) is not used")
-- the settings panel is closed without the game's step back to the menu, which would run Esc
local closeArg, panelOpen
SettingsPanel = { IsShown = function() return panelOpen end, Close = function(_, skip) closeArg = skip panelOpen = false end }
panelOpen = true
windowsClosed = 0
onButton(pad, "PAD2")
assert(closeArg == true and windowsClosed == 0, "B closes the settings panel and skips the step back to the menu")
SettingsPanel = nil
StaticPopup_EscapePressed, ToggleGameMenu = nil, nil
cursorOn = true
menu.shown = false
cursorOn = true
ns.Cursor.Update(0.05)
assert(pad.scripts.OnGamePadButtonDown == nil, "buttons are not taken when no window is open")
menu.shown = true
ns.Cursor.Update(0.05)
assert(pad.scripts.OnGamePadButtonDown, "buttons are taken again when a window opens")
cursorOn = false
ns.Cursor.Update(0.05)
assert(pad.scripts.OnGamePadButtonDown, "buttons stay taken while a window is open even if the game switches the cursor off")
ns.Cursor.OnCombatStart()
assert(not cursorOn and pad.scripts.OnGamePadButtonDown == nil, "combat start closes windows and frees the buttons")
nativeLoaded = true
assert(not ns.Cursor.Auto() and not ns.Cursor.ActionsOn(), "cursor takeovers start off where the game has its own gamepad menus")
nativeLoaded = false

-- saved binds left by another addon
saved["PAD1"], saved["SHIFT-PADDUP"] = "ACTIONBUTTON2", "MULTIACTIONBAR1BUTTON1"
local found = 0
for _ in pairs(ns.Binds.Scan()) do found = found + 1 end
assert(found == 2, "scan finds saved controller binds")
inCombat = true
ns.Binds.Command("clear")
assert(saved["PAD1"] == "ACTIONBUTTON2", "no clearing in combat")
inCombat = false
ns.Binds.Command("clear")
assert(saved["PAD1"] == nil and saved["SHIFT-PADDUP"] == nil, "saved binds cleared")
ns.Binds.Command("restore")
assert(saved["PAD1"] == "ACTIONBUTTON2" and saved["SHIFT-PADDUP"] == "MULTIACTIONBAR1BUTTON1", "saved binds restored")
saved["PAD1"], saved["SHIFT-PADDUP"] = nil, nil

ns.RunSelfTest()
local report = ns.db.selftest
assert(report and #report.results >= 10, "self test stored results")
assert(report.failed >= 1, "missing atlas reported as failure")
assert(#ns.db.log > 0, "log persisted to saved variables")

-- /ubf test: press analysis tells taken, leaked and ignored presses apart.
local summary, rows = ns.Report.Analyze({
    { time = 10, button = "PADDUP", x = 100, y = 100, x2 = 160, y2 = 100 },
    { time = 12, button = "PAD1", x = 0, y = 0, x2 = 0, y2 = 0 },
    { time = 14, button = "PAD2", x = 0, y = 0, x2 = 0, y2 = 0 },
}, { { time = 10.05, key = "PADDUP" }, { time = 14.05, key = "PAD2" } }, { { time = 14.1, event = "UNIT_SPELLCAST_SENT" } }, 9)
assert(summary.taken == 1 and summary.leaked == 1 and summary.ignored == 1, "press analysis counts")
assert(rows[1]:find("taken by addon") and rows[1]:find("cursor moved 60"), "press row text")
assert(rows[3]:find("ability fired"), "leak detected")
ns.Report.Run()
assert(ns.db.report and ns.db.report.environment and ns.db.report.time, "report written")
assert(ns.Cursor.trace, "trace hook installed while recording")
ns.Report.Stop()
assert(ns.Cursor.trace == nil and ns.db.report.summary, "report finished")

-- Game menu: our button goes first, and the old first button gets a section gap.
local menuButtons = {}
GameMenuFrame = {
    InitButtons = function() end,
    buttons = {},
    buttonPool = { EnumerateActive = function() local i = 0 return function() i = i + 1 return menuButtons[i] end end },
    MarkDirty = function(self) self.dirty = true end,
    AddButton = function(self, text, callback)
        local b = { text = text, callback = callback, layoutIndex = #menuButtons + 1 }
        menuButtons[#menuButtons + 1] = b
        self.buttons[#self.buttons + 1] = b
        return b
    end,
}
menuButtons[1] = { text = "Options", layoutIndex = 1 }
GameMenuFrame.buttons[1] = menuButtons[1]
menuButtons[2] = { text = "Support", layoutIndex = 2 }
GameMenuFrame.buttons[2] = menuButtons[2]
ns.GameMenu.Hook()
assert(hooked.InitButtons, "game menu rebuild hooked")
hooked.InitButtons(GameMenuFrame)
local added = menuButtons[3]
assert(added.text == "Ubermoc Forever" and added.layoutIndex == 0, "menu button is first in layout")
assert(menuButtons[1].topPadding == 20, "old first button gets a gap")
assert(GameMenuFrame.buttons[1] == added and GameMenuFrame.dirty, "list order and relayout")
-- Start works in steps: clear and close first, the menu once there is nothing left, then hide it
local shownNow = false
GameMenuFrame.IsShown = function() return shownNow end
function ShowUIPanel(f) if f == GameMenuFrame then shownNow = true end end
function HideUIPanel(f) menuHidden = menuHidden + 1 if f == GameMenuFrame then shownNow = false end end
function CloseMenus() end
local hasTarget, anyWindow = true, false
function UnitExists() return hasTarget end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
local realWindowOpen = ns.Cursor.WindowOpen
ns.Cursor.WindowOpen = function() return anyWindow end
local starter
for _, f in ipairs(handlers) do if f.name == "UbermocForeverMenu" then starter = f end end
assert(starter and starter.attrs.type == "macro" and starter.attrs.macrotext:find("/cleartarget"), "start button clears with a macro")
windowsClosed = 0
assert(ns.StartPressed() == "clear" and not shownNow and windowsClosed == 0, "with a target, Start only clears it")
starter.scripts.PreClick()
assert(starter.attrs.type == "macro", "a clearing press keeps the macro")
starter.scripts.PostClick()
hasTarget, anyWindow = false, true
assert(ns.StartPressed() == "clear" and not shownNow and windowsClosed == 1, "with a window open, Start closes it")
anyWindow = false
starter.scripts.PreClick()
assert(shownNow and starter.attrs.type == nil, "nothing left: Start opens the menu and does not clear")
starter.scripts.PostClick()
assert(starter.attrs.type == "macro", "the macro is back for the next press")
assert(ns.StartPressed() == "hide" and not shownNow, "Start again puts the menu away")
inCombat = true
local menuBefore = shownNow
assert(ns.StartPressed() == "combat" and shownNow == menuBefore, "in combat Start leaves the panels alone")
inCombat = false
ns.Cursor.WindowOpen = realWindowOpen
local hiddenBefore = menuHidden
added.callback()
assert(menuHidden == hiddenBefore + 1, "menu closes when the button is used")

-- Tabs: both kinds of tab are found, and the shoulders step through them
local function tabButton(id, enabled)
    local b = { clicks = 0, id = id }
    function b:IsShown() return true end
    function b:IsEnabled() return enabled ~= false end
    function b:Click() self.clicks = self.clicks + 1 end
    function b:GetTabID() return self.id end
    return b
end
local t1, t2, t3 = tabButton(1), tabButton(2), tabButton(3)
local tabbed = { numTabs = 3, selectedTab = 1, Tabs = { t1, t2, t3 }, GetName = function() return "Tabbed" end,
    IsShown = function() return true end, GetChildren = function() end }
local realOpen = ns.Cursor.OpenWindows
ns.Cursor.OpenWindows = function() return { tabbed } end
assert(ns.Tabs.Available(), "panel tabs are found")
assert(ns.Tabs.Target(1) == t2 and t2.clicks == 0, "next tab is the target and is not clicked from addon code")
tabbed.selectedTab = 3
assert(ns.Tabs.Target(1) == t1, "tabs wrap round at the end")
tabbed.selectedTab = 1
assert(ns.Tabs.Target(-1) == t3, "previous wraps to the last tab")
tabbed.selectedTab = 2
assert(ns.Tabs.Target(1) == t3 and ns.Tabs.Target(-1) == t1, "every tab can be reached in both directions")
-- the game disables the tab you are on; it must still count as the current position
local d1, d2, d3 = tabButton(1, false), tabButton(2), tabButton(3)
tabbed = { numTabs = 3, selectedTab = 1, Tabs = { d1, d2, d3 }, GetName = function() return "Tabbed" end,
    IsShown = function() return true end, GetChildren = function() end }
assert(ns.Tabs.Target(1) == d2 and ns.Tabs.Target(-1) == d3, "the disabled selected tab is the starting point")
tabbed.selectedTab = 2
d1.IsEnabled = function() return true end
d2.IsEnabled = function() return false end
assert(ns.Tabs.Target(1) == d3 and ns.Tabs.Target(-1) == d1, "stepping continues from the middle")
local two = { numTabs = 2, selectedTab = 1, Tabs = { tabButton(1, false), tabButton(2) }, GetName = function() return "Two" end,
    IsShown = function() return true end, GetChildren = function() end }
tabbed = two
assert(ns.Tabs.Available() and ns.Tabs.Target(1) == two.Tabs[2], "a two-tab window counts as having tabs")
tabbed = { numTabs = 3, selectedTab = 1, Tabs = { t1, t2, t3 }, GetName = function() return "Tabbed" end,
    IsShown = function() return true end, GetChildren = function() end }
local s1, s2 = tabButton(1), tabButton(2, false)
local s3 = tabButton(3)
local system = { tabs = { s1, s2, s3 }, selectedTabID = 1 }
tabbed = { IsShown = function() return true end, GetChildren = function() return system end }
system.GetChildren = function() end
system.IsShown = function() return true end
assert(ns.Tabs.Target(1) == s3, "tab systems skip disabled tabs")
tabbed = { IsShown = function() return true end, GetChildren = function() end }
assert(not ns.Tabs.Available() and ns.Tabs.Target(1) == nil, "no tabs, nothing happens")
-- the cursor goes to the tab on press and a real click is sent on release
local tabNode = tabButton(2)
tabNode.GetCenter = function() return 300, 200 end
tabNode.GetEffectiveScale = function() return 1 end
local realTarget = ns.Tabs.Target
ns.Tabs.Target = function() return tabNode end
ns.Options.Hide()
ns.Cursor.OpenWindows = function() return { tabbed } end
tabbed = { IsShown = function() return true end, GetChildren = function() end }
ns.Cursor.Update(0.05)
local clicksBefore = #sim
cursorPos, setCalls = { x = 0, y = 0 }, 0
assert(ns.Cursor.TabStep(1, "PADRSHOULDER") and setCalls == 1, "shoulder press moves the cursor onto the tab")
assert(#sim == clicksBefore, "no click yet on press")
assert(pad.scripts.OnGamePadButtonUp, "release is watched while the buttons are taken")
pad.scripts.OnGamePadButtonUp(pad, "PADRSHOULDER")
assert(#sim == clicksBefore + 1 and sim[#sim] == "LeftButton", "release sends a real click")
pad.scripts.OnGamePadButtonUp(pad, "PADRSHOULDER")
assert(#sim == clicksBefore + 1, "only one click per press")
ns.Tabs.Target = realTarget
ns.Cursor.OpenWindows = realOpen

-- The game's own cursor click buttons (R2, R1) are switched off while the buttons are taken here
cvars.GamePadCursorLeftClick, cvars.GamePadCursorRightClick = "PADRTRIGGER", "PADRSHOULDER"
ns.db.cursorActions, ns.db.clickBackup = true, nil
ns.Cursor.ManageClickCVars()
assert(cvars.GamePadCursorLeftClick == "NONE" and cvars.GamePadCursorRightClick == "NONE", "engine clicks are switched off")
ns.Cursor.SetActions(false)
assert(cvars.GamePadCursorLeftClick == "PADRTRIGGER" and cvars.GamePadCursorRightClick == "PADRSHOULDER", "and put back")
cvars.GamePadCursorLeftClick = "PADBACK"
ns.Cursor.SetActions(true)
assert(cvars.GamePadCursorLeftClick == "PADBACK", "a button you chose yourself is left alone")
cvars.GamePadCursorLeftClick = "PADRTRIGGER"
ns.db.cursorActions, ns.db.clickBackup = nil, nil

-- Legend: each game defaults to its own style, and the choice can be changed
ns.isForever = false
assert(ns.Legend.Style() == "Midnight", "Midnight defaults to its own style")
ns.isForever = true
assert(ns.Legend.Style() == "Forever", "Forever defaults to its own style")
ns.Legend.SetChoice("Midnight")
assert(ns.Legend.Style() == "Midnight" and ns.db.legendStyle == "Midnight", "the style can be switched")
ns.Legend.SetChoice("Auto")
assert(ns.db.legendStyle == nil and ns.Legend.Style() == "Forever", "auto returns to the game's own style")
-- the legend is a footer that belongs to the window: below its tabs, wrapping at its width
local fakeRoot = { GetEffectiveScale = function() return 1 end, GetBottom = function() return 300 end,
    GetWidth = function() return 500 end, GetFrameLevel = function() return 5 end }
local hang = { GetBottom = function() return 270 end, GetEffectiveScale = function() return 1 end }
ns.Legend.Show(true, fakeRoot, { hang })
assert(ns.Legend.Available("Midnight") and ns.Legend.Available("Forever"), "styles are available when their art exists")
assert(ns.Legend.Status():find("legend: shown"), "legend status reports it")
assert(ns.Legend.Status():find("height 34"), "the height follows the wrapped text (18 + 2 x 8)")
ns.Legend.Show(false, nil)
assert(ns.Legend.Status():find("legend: hidden"), "no window, no legend")
local where, gap = ns.Legend.ComputePlacement(270, 34, 30)
assert(where == "below" and gap == 32, "below the tabs, clear of how far they hang")
where, gap = ns.Legend.ComputePlacement(270, 34, 0)
assert(where == "below" and gap == 2, "no tabs: just under the window")
where, gap = ns.Legend.ComputePlacement(20, 34, 30)
assert(where == "above" and gap == 2, "no room below: above the window")
ns.Legend.Hide()

local out = table.concat(printed, "\n")
assert(ns.isForever and ns.gameType == "Forever", "game type")
assert(ns.Pad.GetActive().id == 2, "active device")
assert(out:find("0=PADDUP"), "padmap lists buttons")
assert(out:find("%(active%)") and out:find("%(combined%)"), "pad report flags")
print = nil
io.write("smoke test passed\n")
