----------------------------------------------------------------------
-- Ubermoc Forever: first-run prompt
-- When a controller is found, once for each character, the game's own question window asks whether to set the
-- default controller binds. Answering No is remembered; the same choice stays in the game menu under Controller.
----------------------------------------------------------------------
local _, UF = ...

StaticPopupDialogs["UBERMOCFOREVER_DEFAULTS"] = {
    text = "Controller detected: %s.\n\nSet the default controller key binds? This replaces your current controller binds. You can change them any time in the game menu under Controller.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if UF.applyDefaults(UF.activeSet()) then
            UF.say("Default controller binds set. Change them in the game menu under Controller.")
        end
    end,
    OnCancel = function()
        local g = UF.guid()
        if g then UF.DB().declined[g] = true end
    end,
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
