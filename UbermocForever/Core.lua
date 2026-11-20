----------------------------------------------------------------------
-- Ubermoc Forever: core
-- Shared table, saved settings, and a self-check. The game's script commands (/run, /dump) can be switched
-- off in Forever, so this addon tests what it depends on by itself after login and reports the result.
----------------------------------------------------------------------
local ADDON, UF = ...
_G.UbermocForever = UF
UF.title = "Ubermoc Forever"

function UF.say(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. UF.title .. ":|r " .. tostring(msg))
    end
end

-- The settings a new install starts with: the author's own (2026-11-19), copied once into a brand-new saved-variables table (an install that
-- already has settings is not touched).
UF.SEED = {
    menuSide = "left",
    fadeMouse = 1,
    gbar = { extras = false, faceColor = false, gap = 0, hideEmpty = true, on = true, raise = 0, size = 40 },
    aim = { dist = 3, on = true, size = 1, v2 = true },
    cinemaEdges = 3,
    cinemaBars = 3,
    chat = { auto = { chat = true, chatbtns = true, chatedit = true, chattabs = true, quickjoin = true }, fade = 3, on = true, reveal = true, visible = 5, editTop = false },
    plates = { enemy = true, friendly = true, health = true, percent = true, quest = true, questText = true, friendlyLevel = true },
    vendor = { repair = true, sell = true, guild = true },
    platerange = { on = true, backup = {} },
    fade = {
    arena = { flight = 0, idle = 0.4 },
    bags = { combat = 0, flight = 0, idle = 0 },
    bar2 = { flight = 0, idle = 0.4 },
    bar3 = { flight = 0, idle = 0.4 },
    bar4 = { flight = 0, idle = 0.4 },
    bar5 = { flight = 0, idle = 0.4 },
    bar6 = { flight = 0 },
    bar7 = { flight = 0 },
    bar8 = { flight = 0 },
    boss = { flight = 0, idle = 0.4 },
    buffs = { flight = 0, idle = 0.4 },
    castbar = { flight = 0, idle = 0.4 },
    cd_bars = { flight = 0 },
    cd_buffs = { flight = 0 },
    classres = { combat = 0.7, flight = 0, idle = 0.3 },
    deadly = { flight = 0, idle = 0.4 },
    debuffs = { flight = 0, idle = 0.4 },
    defensives = { flight = 0, idle = 0.4 },
    extrabtn = { flight = 0, idle = 0.4 },
    focus = { flight = 0, idle = 0.4 },
    focus_art = { flight = 0, idle = 0.4 },
    focus_health = { flight = 0, idle = 0.4 },
    focus_icons = { flight = 0, idle = 0.4 },
    focus_name = { flight = 0, idle = 0.4 },
    focus_portrait = { flight = 0, idle = 0.4 },
    focus_power = { flight = 0, idle = 0.4 },
    fot = { flight = 0, idle = 0.4 },
    gbar = { flight = 0, idle = 0.2 },
    mainbar = { flight = 0, idle = 0.4 },
    mb_border = { flight = 0, idle = 0.4 },
    mb_leftcap = { flight = 0, idle = 0.4 },
    mb_page = { flight = 0, idle = 0.4 },
    mb_rightcap = { flight = 0, idle = 0.4 },
    micro = { combat = 0, flight = 0, idle = 0 },
    minimap = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_addons = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_back = { flight = 0, idle = 0.4 },
    mm_cal = { flight = 0, idle = 0.4 },
    mm_clock = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_coords = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_diff = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_exp = { combat = 0.7, flight = 0, idle = 0.3 },
    mm_mail = { flight = 0, idle = 0.4 },
    mm_map = { flight = 0, idle = 0.4 },
    mm_track = { flight = 0, idle = 0.4 },
    mm_zone = { flight = 0, idle = 0.4 },
    mm_zoom = { combat = 0.7, flight = 0, idle = 0.3 },
    party = { flight = 0, idle = 0.4 },
    pet = { flight = 0, idle = 0.4 },
    pet_portrait = { flight = 0, idle = 0.4 },
    petbar = { flight = 0, idle = 0.4 },
    petcast = { flight = 0, idle = 0.4 },
    player = { flight = 0, idle = 0.4 },
    player_art = { flight = 0, idle = 0.4 },
    player_health = { flight = 0, idle = 0.4 },
    player_icons = { flight = 0, idle = 0.4 },
    player_name = { flight = 0, idle = 0.4 },
    player_portrait = { flight = 0, idle = 0.4 },
    possess = { flight = 0, idle = 0.4 },
    queue = { combat = 0.7, flight = 0, idle = 0.3 },
    raid = { flight = 0, idle = 0.4 },
    raidmgr = { flight = 0, idle = 0.4 },
    stance = { flight = 0, idle = 0.4 },
    target = { flight = 0, idle = 0.4 },
    target_art = { flight = 0, idle = 0.4 },
    target_health = { flight = 0, idle = 0.4 },
    target_icons = { flight = 0, idle = 0.4 },
    target_name = { flight = 0, idle = 0.4 },
    target_portrait = { flight = 0, idle = 0.4 },
    target_power = { flight = 0, idle = 0.4 },
    tot = { flight = 0, idle = 0.4 },
    totembar = { flight = 0, idle = 0.4 },
    tr_ach = { hide = true, idle = 0.4 },
    tr_bonus = { hide = true, idle = 0.4 },
    tr_campaign = { hide = true, idle = 0.4 },
    tr_month = { hide = true, idle = 0.4 },
    tr_prof = { hide = true, idle = 0.4 },
    tr_quest = { hide = true, idle = 0.4 },
    tr_scen = { hide = true, idle = 0.4 },
    tr_tasks = { hide = true, idle = 0.4 },
    tr_widget = { hide = true, idle = 0.4 },
    tr_world = { hide = true, idle = 0.4 },
    tracker = { hide = true, idle = 0.4 },
    vehicleexit = { flight = 0, idle = 0.4 },
    xpall = { combat = 0, flight = 0, idle = 0 },
    zoneabil = { flight = 0, idle = 0.4 },
    },
}
local function copyDeep(v)
    if type(v) ~= "table" then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = copyDeep(x) end
    return o
end

function UF.DB()
    UbermocForeverDB = UbermocForeverDB or {}
    local d = UbermocForeverDB
    if d.seedChecked == nil then
        d.seedChecked = true
        if next(d) == nil or (next(d) == "seedChecked" and next(d, "seedChecked") == nil) then
            for k, v in pairs(UF.SEED) do d[k] = copyDeep(v) end
        end
    end
    if d.layout == nil then d.layout = "auto" end   -- "auto" or a controller id from Layouts.lua
    d.applied = d.applied or {}                      -- character GUID -> "steam" / "standard"
    d.partsAsked = d.partsAsked or {}                -- character GUID -> true (the move-the-bars question was shown)
    d.declined = d.declined or {}                    -- character GUID -> true
    return d
end

-- The version in the TOC, so what is installed can be told at a glance.
function UF.getVersion()
    local ok, v = pcall(function() return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("UbermocForever", "Version") end)
    return (ok and v) or "?"
end

function UF.guid()
    return UnitGUID and UnitGUID("player") or nil
end

-- Things other files want to run once the game has loaded everything.
local loginJobs = {}
function UF.OnLogin(fn) loginJobs[#loginJobs + 1] = fn end

----------------------------------------------------------------------
-- Self-check
----------------------------------------------------------------------
UF.checks = {}
local function check(name, ok, detail)
    UF.checks[#UF.checks + 1] = { name = name, ok = ok and true or false, detail = detail }
end
UF.check = check

local function atlasExists(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    if not ok then return nil end
    return info ~= nil
end

function UF.runChecks()
    wipe(UF.checks)
    check("Gamepad API (C_GamePad)", C_GamePad ~= nil)
    check("Gamepad device list", C_GamePad ~= nil and C_GamePad.GetAllDeviceIDs ~= nil)
    for _, a in ipairs({ "Gamepad_Ltr_A_64", "Gamepad_Shp_Cross_64", "Gamepad_Rev_B_64", "Gamepad_Gen_Paddle1_64" }) do
        local e = atlasExists(a)
        check("Game art: " .. a, e == true, e == nil and "atlas lookup not available" or nil)
    end
    check("Game button text (KEY_PAD1_LTR)", type(_G.KEY_PAD1_LTR) == "string")
    check("Game menu (GameMenuFrame)", GameMenuFrame ~= nil and GameMenuFrame.InitButtons ~= nil)
    check("Game menu buttons (buttonPool)", GameMenuFrame ~= nil and GameMenuFrame.buttonPool ~= nil)
    check("Key binding list", GetNumBindings ~= nil and (GetNumBindings() or 0) > 0)
    check("Popup dialogs (StaticPopupDialogs)", StaticPopupDialogs ~= nil)
    check("Gamepad cursor helper", CanAutoSetGamePadCursorControl ~= nil and SetGamePadCursorControl ~= nil)
    local okC, v = pcall(GetCVar, "GamePadEnable")
    check("Setting GamePadEnable", okC and v ~= nil)
    check("Setting GamePadEmulateShift", (pcall(GetCVar, "GamePadEmulateShift")) and GetCVar("GamePadEmulateShift") ~= nil)
    local bad = 0
    for _, c in ipairs(UF.checks) do if not c.ok then bad = bad + 1 end end
    UF.checksFailed = bad
    return bad
end

function UF.reportChecks()
    UF.runChecks()
    UF.say("Version " .. UF.getVersion())
    UF.say("Controller the game reports: " .. tostring(UF.deviceName or "none") .. " (read as " .. tostring(UF.detected or "none") .. ")")
    -- the game's own controller settings and what Start does on each layer, as the game has them right now
    local function cv(n) local ok, v = pcall(GetCVar, n); return ok and tostring(v) or "?" end
    UF.say("Shift = " .. cv("GamePadEmulateShift") .. ", Ctrl = " .. cv("GamePadEmulateCtrl") .. ", Alt = " .. cv("GamePadEmulateAlt") .. ", Escape = " .. cv("GamePadEmulateEsc") .. ", cursor clicks = " .. cv("GamePadCursorLeftClick") .. " / " .. cv("GamePadCursorRightClick"))
    if GetBindingAction then
        local parts = {}
        for _, layerPrefix in ipairs({ "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }) do
            local a = GetBindingAction(layerPrefix .. "PADFORWARD")
            parts[#parts + 1] = (layerPrefix == "" and "Start" or (layerPrefix .. "Start")) .. " = " .. ((a and a ~= "") and a or "(nothing)")
        end
        UF.say(table.concat(parts, ", "))
    end
    for _, c in ipairs(UF.checks) do
        UF.say((c.ok and "|cff44ff44ok|r  " or "|cffff4444MISSING|r  ") .. c.name .. (c.detail and (" (" .. c.detail .. ")") or ""))
    end
    UF.say(UF.checksFailed == 0 and "Every check passed." or (UF.checksFailed .. " check(s) failed."))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    UF.DB()
    for _, fn in ipairs(loginJobs) do
        local ok, err = pcall(fn)
        if not ok then check("Error while starting", false, tostring(err)) end
    end
    C_Timer.After(2, function()
        local bad = UF.runChecks()
        if bad > 0 then
            UF.say(bad .. " game feature(s) it needs were not found. Open the game menu > Ubermoc Forever and press Checks.")
        end
    end)
end)

SLASH_UBERMOCFOREVER1 = "/ubf"
SlashCmdList["UBERMOCFOREVER"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "check" or msg == "checks" then
        UF.reportChecks()
    elseif msg == "nav off" or msg == "nav on" then
        UF.DB().gameNav = (msg == "nav on")
        UF.say("Moving around the game's windows with the controller is " .. (msg == "nav on" and "on." or "off."))
    elseif msg == "scan" or msg:match("^scan ") then
        if UF.scan then UF.scan(msg:match("^scan%s+(.*)$")) end
    elseif msg == "stick flip" then
        UF.DB().stickFlip = not UF.DB().stickFlip
        UF.say("Right stick scrolling is now " .. (UF.DB().stickFlip and "reversed." or "the normal way (up scrolls up)."))
    elseif msg == "cinema on" or msg == "cinema off" then
        UF.DB().cinema = (msg == "cinema on")
        if msg == "cinema off" and UF.Cinematic then UF.Cinematic.stopNow() end
        if UF.DialogButtons then UF.DialogButtons.refresh() end
        UF.say("The cinematic camera while talking to an NPC is " .. (msg == "cinema on" and "on." or "off."))
    elseif msg == "targetmenu on" or msg == "targetmenu off" then
        if UF.TargetMenu then UF.TargetMenu.set(msg == "targetmenu on") end
        UF.say("Interact on a target you cannot interact with opens its menu: " .. (msg == "targetmenu on" and "on." or "off."))
    elseif msg == "targetmenu" then
        if UF.TargetMenu then UF.TargetMenu.report() end
    elseif msg == "bars" then
        if UF.GamepadBar then UF.GamepadBar.report() end
    elseif msg == "bars hold" then
        -- the report in 6 seconds: time to hold both modifier buttons on the controller
        UF.say("Hold the modifiers now: the bars report comes in 6 seconds.")
        C_Timer.After(6, function() if UF.GamepadBar then UF.GamepadBar.report() end end)
    elseif msg == "fade" then
        if UF.Fade then UF.Fade.report() end
    elseif msg == "dialog" then
        if UF.GameNav and UF.GameNav.dialogReport then UF.GameNav.dialogReport() end
    elseif msg == "item" then
        if UF.ItemMenu and UF.GameNav then UF.ItemMenu.report(UF.GameNav.focusFrame()) end
    elseif msg == "tabs" then
        if UF.GameNav then UF.GameNav.report() end
    elseif UF.ToggleOptions then
        UF.ToggleOptions()
    end
end

-- Settings that step through values: A (or a left click) goes forward, X (or a right click) goes back; both wrap around.
function UF.stepRange(v, lo, hi, dir)
    v = (tonumber(v) or lo) + (dir or 1)
    if v > hi then return lo elseif v < lo then return hi end
    return v
end
function UF.stepIndex(i, n, dir) return (((i or 1) - 1 + (dir or 1)) % n) + 1 end
-- A button that steps a setting: step(dir) is called with 1 or -1, then after(). Nav (Options.lua) presses b.ufBack on X.
function UF.cycleButton(b, step, after)
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b.ufBack = function() step(-1); if after then after() end end
    b:SetScript("OnClick", function(_, button) step(button == "RightButton" and -1 or 1); if after then after() end end)
end

-- The highlight colour shared by the game-window highlight (GameNav.lua) and our own windows (Nav.lua): a yellow tint over
-- the game's own button highlight art (ButtonHilight-Square, added to what is underneath) and a light yellow wash.
UF.HIGHLIGHT = { glow = { 1, 0.82, 0.12, 1 }, wash = { 1, 0.8, 0.05, 0.3 } }
function UF.tintHighlight(frame)
    local h = UF.HIGHLIGHT
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(frame)
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(h.glow[1], h.glow[2], h.glow[3], h.glow[4])
    local wash = frame:CreateTexture(nil, "ARTWORK")
    wash:SetAllPoints(frame)
    wash:SetColorTexture(h.wash[1], h.wash[2], h.wash[3], h.wash[4])
    wash:SetBlendMode("ADD")
    return glow, wash
end
