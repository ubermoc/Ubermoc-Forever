-- EscMenu.lua: our entry in the game's Esc (pause) menu -> opens our settings page (REQUIREMENTS.md R-2.1:
-- the options must be reachable from the Esc menu, not only through Esc -> Options -> AddOns).
--
-- HOW (the verified recipe, Blizzard_GameMenu/Shared/GameMenuFrame.lua): GameMenuFrameMixin:OnShow calls
-- InitButtons EVERY time the menu opens (:61-72); InitButtons wipes the list and re-adds every button
-- through self:AddButton(text, callback, ...) (:160, called for Options at :189). So we hook AddButton
-- and add our button right after Blizzard adds its own Options button - the text check (GAMEMENU_OPTIONS)
-- stops the hook from calling itself. NO run-once flag: the list is rebuilt on every show.
--
-- WHAT THE USER'S IN-GAME TEST 2026-11-13 round 4 PROVED AND WHAT CHANGED BECAUSE OF IT:
-- a) our button existed (probe esc.buttonTexts = {"Options","UbermocForever"}) but clicking it did
--    NOTHING, and b) pressing Exit Game right after produced a Lua error. The exact stack was never
--    captured (BugGrabber held only the old round-3 error), so this is an EDUCATED fix, on the user's
--    test list: our old callback opened the Settings window from C_Timer.After(0,...) while Blizzard had
--    ALREADY hidden the menu itself (GenerateMenuCallback runs HideUIPanel(self) before any callback,
--    :166-171). The open then raced Blizzard's own panel lifecycle. It also bypassed Blizzard's own
--    pattern entirely: every working menu button hands its target straight to GenerateMenuCallback -
--    the Options button is literally GenerateMenuCallback(GenerateFlatClosure(SettingsPanel.Open,
--    SettingsPanel)) (:189). So we now do EXACTLY what that line does: pass SettingsPanel.Open through
--    Blizzard's own wrapper inline. No timer of ours, no guards of ours in the click path - one code
--    path with Blizzard's Options button.
-- c) the pendingOpen flag and its PLAYER_QUITING/PLAYER_LOGOUT resets are gone (nothing is pending any
--    more); the ns.settingsCategory check stays ONLY as a chat message for the rare "page not ready"
--    case, because OpenToCategory takes a category ID we must have.
local addonName, ns = ...

local function openSettings()
    if not ns.settingsCategory then
        ns:Print("options not ready yet.")
        return
    end
    -- Settings.OpenToCategory is Blizzard's own wrapper (Blizzard_Settings_Shared/Blizzard_Settings.lua:144
    -- "function Settings.OpenToCategory(categoryID, scrollToElementName) C_SettingsUtil.OpenSettingsPanel(...)").
    -- Our button was added INSIDE Blizzard's InitButtons, so this runs when the player CLICKS our
    -- button, inside GenerateMenuCallback (GameMenuFrame.lua:166-171), at the same moment Blizzard's
    -- own Options button opens Settings. That is the proven-working path; anything of ours racing it
    -- was the suspect for both symptoms (dead click + the Exit Game error).
    Settings.OpenToCategory(ns.settingsCategory:GetID())
end

ns:RegisterEvent("PLAYER_LOGIN", function()
    local gmf = _G.GameMenuFrame
    if not gmf or type(gmf.AddButton) ~= "function" then return end   -- defensive: never error on a menu we don't see
    hooksecurefunc(gmf, "AddButton", function(self, text)
        if text ~= GAMEMENU_OPTIONS then return end   -- our own button's text differs: no recursion
        -- Inline, exactly like Blizzard's own Options button (:189). Verified chain: AddButton sets the
        -- callback as the button's OnClick (Blizzard_SharedXML/Shared/Frame/MainMenuFrameTemplates.lua:34
        -- "newButton:SetScript(\"OnClick\", callback);"), and Blizzard wraps its callbacks in
        -- GenerateMenuCallback BEFORE passing them, so on click ours runs right after HideUIPanel(self).
        -- NO C_Timer of ours around it (round-4 change).
        self:AddButton(addonName, openSettings)
    end)
end)
