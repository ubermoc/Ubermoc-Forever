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
    if ns.settingsCategory and Settings then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    else
        ns:Print("Settings not ready yet. Use /reload after login.")
    end
end

EventRegistry:RegisterCallback("UIPanel.FrameHidden", function(self, contextKey)
    if contextKey ~= GAME_MENU_CONTEXT_KEY then return end
    local action = pendingAction
    pendingAction = nil
    if action == "settings" then
        OpenUbermocSettings()
    elseif action == "keybinds" then
        ns:OpenKeybinds()
    end
end)

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

    -- Keybinds entry, so controller bindings are reachable straight from the
    -- pause menu (Blizzard's Options panel is mouse/keyboard first).
    self:AddButton("Ubermoc Keybinds", function()
        pendingAction = "keybinds"
    end)
end)
