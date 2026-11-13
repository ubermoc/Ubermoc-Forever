-- EscMenu.lua: our entry in the game's Esc (pause) menu -> opens our settings page (REQUIREMENTS.md R-2.1:
-- the options must be reachable from the Esc menu, not only through Esc -> Options -> AddOns).
--
-- HOW (the verified recipe, references/modules/wow-addon.md + Blizzard_GameMenu/Shared/GameMenuFrame.lua):
-- GameMenuFrameMixin:OnShow calls InitButtons EVERY time the menu opens (:61-72); InitButtons wipes the
-- list and re-adds every button through self:AddButton(text, callback, ...) (:147, called for Options at
-- :189). So we hook AddButton and add our button right after Blizzard adds its own Options button - the
-- text check (GAMEMENU_OPTIONS) stops the hook from calling itself. NO run-once flag: the list is rebuilt
-- on every show, a flag would hide the button from the second Esc press on.
--
-- The callback must NOT open the Settings window inline: Blizzard wraps every menu callback so it runs
-- AFTER HideUIPanel(self) (GameMenuFrame.lua:166-171), and the settings-open path runs CloseWindows()
-- which hides the pause menu again and re-enters the same UIPanel.FrameHidden dispatch (references/
-- lessons/wow-api-notes.md, Esc menu / panel lifecycle). That re-entry produced ADDON_ACTION_FORBIDDEN
-- taint in an earlier project. So the open is deferred with C_Timer.After(0, ...) - it runs after the
-- dispatch flushes. Same reason PLAYER_QUITING/PLAYER_LOGOUT cancel a pending open.
local addonName, ns = ...

local HideUIPanel = HideUIPanel   -- real Blizzard Lua (UIParentPanelManager.lua), not in the C-API index

local pendingOpen = false

local function openSettingsDeferred()
    if not ns.settingsCategory then
        ns:Print("options not ready yet.")
        return
    end
    pendingOpen = true
    C_Timer.After(0, function()
        pendingOpen = false
        -- If the player pressed Esc again in this instant, leave their menu alone.
        if _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then return end
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end)
end

ns:RegisterEvent("PLAYER_LOGIN", function()
    local gmf = _G.GameMenuFrame
    if not gmf or type(gmf.AddButton) ~= "function" then return end   -- defensive: never error on a menu we don't see
    hooksecurefunc(gmf, "AddButton", function(self, text)
        if text ~= GAMEMENU_OPTIONS then return end   -- our own button's text differs: no recursion
        self:AddButton(addonName, openSettingsDeferred)
    end)
end)

-- A pending deferred open must not survive a quit/logout (references/lessons/wow-api-notes.md).
for _, event in ipairs({ "PLAYER_QUITING", "PLAYER_LOGOUT" }) do
    ns:RegisterEvent(event, function() pendingOpen = false end)
end
