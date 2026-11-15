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

function UF.DB()
    UbermocForeverDB = UbermocForeverDB or {}
    local d = UbermocForeverDB
    if d.layout == nil then d.layout = "auto" end   -- "auto" or a controller id from Layouts.lua
    d.applied = d.applied or {}                      -- character GUID -> "steam" / "standard"
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
    UF.say("Shift = " .. cv("GamePadEmulateShift") .. ", Ctrl = " .. cv("GamePadEmulateCtrl") .. ", Alt = " .. cv("GamePadEmulateAlt") .. ", Escape = " .. cv("GamePadEmulateEsc"))
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
    elseif UF.ToggleOptions then
        UF.ToggleOptions()
    end
end
