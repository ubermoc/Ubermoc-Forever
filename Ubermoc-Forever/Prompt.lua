----------------------------------------------------------------------
-- Ubermoc Forever: first-run prompt
-- When a controller is found, once for each character, the game's own question window asks whether to set the
-- default controller binds. Answering No is remembered; the same choice stays in the game menu under Ubermoc Forever.
----------------------------------------------------------------------
local _, UF = ...

StaticPopupDialogs["UBERMOCFOREVER_DEFAULTS"] = {
    text = "Controller detected: %s.\n\nSet the default controller key binds? This replaces your current controller binds. You can change them any time in the game menu under Ubermoc Forever.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if UF.applyDefaults(UF.activeSet()) then
            UF.say("Default controller binds set. Change them in the game menu under Ubermoc Forever.")
        end
    end,
    OnCancel = function()
        local g = UF.guid()
        if g then UF.DB().declined[g] = true end
    end,
    OnShow = function(self) UF.Nav.TakePopup(self) end,
    OnHide = function(self) UF.Nav.ReleasePopup(self) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

local shown = false
local function tryPrompt()
    if shown then return end
    local g = UF.guid()
    if not g or not UF.detected then return end
    local d = UF.DB()
    if d.applied[g] or d.declined[g] then return end
    if InCombatLockdown() then return end
    shown = true
    local set = UF.SETS[UF.activeSet()]
    StaticPopup_Show("UBERMOCFOREVER_DEFAULTS", set and set.name or "A")
end
UF.tryPrompt = tryPrompt

UF.OnDetect(function() C_Timer.After(1, tryPrompt) end)
UF.OnLogin(function()
    -- The game can take a moment to list its controllers after login.
    C_Timer.After(3, function() pcall(UF.detect); tryPrompt() end)
    C_Timer.After(10, function() pcall(UF.detect); tryPrompt() end)
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function() tryPrompt() end)

----------------------------------------------------------------------
-- Gamepad layout: once for each character, when the layout is on, ask whether to move the micro menu, bags and XP bar now (they are
-- not moved by the layout itself; the game's Edit Mode does it).
----------------------------------------------------------------------
StaticPopupDialogs["UBERMOCFOREVER_MOVEPARTS"] = {
    text = "Gamepad layout is on. The micro menu, bags and experience bar stay where the game puts them.\n\nOpen the game's Edit Mode now to move them? You can do it any time with Move bars on the Bars page.",
    button1 = YES,
    button2 = NO,
    OnAccept = function() if UF.GamepadBar and UF.GamepadBar.openEditMode then UF.GamepadBar.openEditMode() end end,
    OnShow = function(self) UF.Nav.TakePopup(self) end,
    OnHide = function(self) UF.Nav.ReleasePopup(self) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}
local function tryPartsPrompt()
    local g = UF.guid()
    if not g or InCombatLockdown() then return end
    local B = UF.GamepadBar
    if not (B and B.cfg and B.cfg().on) then return end
    local d = UF.DB()
    d.partsAsked = d.partsAsked or {}
    if d.partsAsked[g] then return end
    if StaticPopup_Visible and StaticPopup_Visible("UBERMOCFOREVER_DEFAULTS") then return end
    d.partsAsked[g] = true
    StaticPopup_Show("UBERMOCFOREVER_MOVEPARTS")
end
UF.tryPartsPrompt = tryPartsPrompt
UF.OnLogin(function() C_Timer.After(15, tryPartsPrompt) end)

----------------------------------------------------------------------
-- Gamepad layout: a layer's action bar is switched off in the game's Gameplay > Action Bars settings, so nothing shows when its modifiers are held.
-- The game's own question window offers to open that settings page (Settings.OpenToCategory(Settings.ACTION_BAR_CATEGORY_ID), the call the game's
-- Edit Mode makes itself, EditModeSystemTemplates.lua:1211), asks again next time on "Not now", never again on "Don't ask again". Nothing is changed by us.
----------------------------------------------------------------------
StaticPopupDialogs["UBERMOCFOREVER_BARSOFF"] = {
    text = "Gamepad layout: %s switched off in the game's settings, so nothing shows while you hold its modifiers.\n\nOpen Gameplay > Action Bars now to switch it on?",
    button1 = "Open settings",
    button2 = "Not now",
    button3 = "Don't ask again",
    OnAccept = function()
        local id = _G.Settings and _G.Settings.ACTION_BAR_CATEGORY_ID
        if id and _G.Settings.OpenToCategory then
            if securecallfunction then securecallfunction(_G.Settings.OpenToCategory, id) else _G.Settings.OpenToCategory(id) end
        else
            UF.say("Open the game menu, Options, Gameplay, Action Bars.")
        end
    end,
    OnAlt = function()
        local g = UF.guid()
        if g then UF.DB().barsNever = UF.DB().barsNever or {}; UF.DB().barsNever[g] = true end
    end,
    OnShow = function(self) UF.Nav.TakePopup(self) end,
    OnHide = function(self) UF.Nav.ReleasePopup(self) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}
local barsAsked = false
local function tryBarsPrompt()
    if barsAsked or InCombatLockdown() then return end
    local g = UF.guid()
    local B = UF.GamepadBar
    if not g or not (B and B.cfg and B.cfg().on and B.hiddenBars) then return end
    local d = UF.DB()
    if d.barsNever and d.barsNever[g] then return end
    local hidden = B.hiddenBars()
    if #hidden == 0 then return end
    local names = {}
    for _, i in ipairs(hidden) do names[#names + 1] = "action bar " .. i end
    barsAsked = true
    StaticPopup_Show("UBERMOCFOREVER_BARSOFF", table.concat(names, " and ") .. (#names > 1 and " are" or " is"))
end
UF.tryBarsPrompt = tryBarsPrompt
UF.OnLogin(function() C_Timer.After(20, tryBarsPrompt) end)
