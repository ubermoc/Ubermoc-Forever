-- UbermocForever/Menu.lua
-- Adds a button to the in-game pause (Esc) menu that opens the Ubermoc settings.
-- Forever's GameMenuFrame rebuilds its whole button list every time it is
-- shown (GameMenuFrameMixin:InitButtons uses a frame pool with layout
-- indices), so a hand-placed frame at a fixed offset would overlap Blizzard's
-- buttons and be skipped by gamepad focus navigation. Instead we hook the
-- real menu builder and add our button through GameMenuFrame:AddButton,
-- which is how Blizzard adds its own entries.
local addonName, ns = ...

if not GameMenuFrame or not GameMenuFrame.AddButton then return end

-- The click callback must stay inert. Blizzard's menu builder wraps every
-- button callback in GenerateMenuCallback (GameMenuFrame.lua:166-172), whose
-- HideUIPanel(self) is a protected call; anything our callback does inside
-- that flow gets blamed on the addon ("ADDON_ACTION_FORBIDDEN ... callback()",
-- GameMenuFrame.lua:170). So the callback only records which entry was
-- chosen, and a frame we own performs the actual open after the menu has
-- closed. That deferred handler runs in our own untainted code, where
-- Settings.OpenToCategory is allowed (it is what /ubermoc config uses).
local pendingAction = nil

-- Blizzard fires UIPanel.FrameHidden (an EventRegistry callback, not a frame
-- event) from HideUIPanel for any panel with a uiPanelContextKey; GameMenuFrame
-- carries G_GameMenuFrameContextKey = "GameMenuFrame" and listens the same way
-- (GameMenuFrame.lua:53). Our handler runs as a plain callback after the menu
-- has closed, outside Blizzard's protected click flow.
local GAME_MENU_CONTEXT_KEY = "GameMenuFrame"

local function OpenUbermocSettings()
    -- Same deferral as everywhere else: Settings.OpenToCategory is protected,
    -- so the open happens one frame later in our own untainted code (the
    -- shared helper from Core.lua).
    if ns.OpenSettingsDeferred then
        ns.OpenSettingsDeferred()
    end
end

-- Why this defers by one frame (the 0.1.9 -> 0.2.0 Exit Game fix).
-- Blizzard's own UIPanel.FrameHidden listener re-shows the game menu when a
-- context panel closes: if our handler calls Settings.OpenToCategory() inline,
-- that opens the full-screen SettingsPanel INSIDE Blizzard's own dispatch of
-- UIPanel.FrameHidden. The settings open path runs CloseWindows(), which hides
-- GameMenuFrame again -> HideUIPanel -> TriggerEvent("UIPanel.FrameHidden")
-- re-enters the same dispatch (CallbackRegistry.lua:191 "reentrant calls"),
-- and Blizzard's listener then calls ShowUIPanel(GameMenuFrame) while the menu
-- is being hidden by Logout()/Quit(). The result is an error when Exit Game /
-- Quit to Desktop is clicked, even though pendingAction was never set for it.
-- Deferring with C_Timer.After(0) runs our open AFTER Blizzard's dispatch has
-- finished and its executingEvents bookkeeping is flushed, so the re-entrant
-- hide/re-show loop no longer happens.
local function RunDeferred()
    C_Timer.After(0, function()
        if pendingAction == "settings" then
            OpenUbermocSettings()
        end
    end)
end

EventRegistry:RegisterCallback("UIPanel.FrameHidden", function(self, contextKey)
    if contextKey ~= GAME_MENU_CONTEXT_KEY then return end
    local action = pendingAction
    pendingAction = nil
    -- A quit/logout hides the menu with no pending choice of ours; never try
    -- to open settings while the client is tearing down.
    if not action then return end
    RunDeferred(action)
end)

-- Safety net: a quit or logout in progress cancels any recorded choice, so we
-- never schedule an open during teardown. PLAYER_QUITING reaches plain frames
-- through the frame-event routing table (Blizzard_Game/Shared/EventRouting.lua)
-- when the Quit button runs Logout()/Quit(), and PLAYER_LOGOUT fires as the
-- client leaves the world. Uses the addon's shared event bus from Core.lua.
local function CancelPendingAction()
    pendingAction = nil
end

ns:RegisterEvent("PLAYER_QUITING", CancelPendingAction)
ns:RegisterEvent("PLAYER_LOGOUT", CancelPendingAction)

hooksecurefunc(GameMenuFrame, "AddButton", function(self, text)
    -- Add ours right after the Options button, before any section break, so
    -- it participates in layout and gamepad navigation like a native entry.
    -- No "added once" flag here: Blizzard wipes and rebuilds this list every time the menu opens,
    -- so the button has to be added on every rebuild. The text checks below also stop this hook
    -- from reacting to the buttons it adds itself.
    if text ~= GAMEMENU_OPTIONS then return end

    self:AddButton("Ubermoc", function()
        pendingAction = "settings"
    end)
end)
