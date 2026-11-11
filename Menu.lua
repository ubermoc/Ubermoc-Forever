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

local function OpenUbermocSettings()
    if ns.settingsCategory and Settings then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    else
        ns:Print("Settings not ready yet. Use /reload after login.")
    end
end

-- Blizzard's own menu buttons close the pause menu with HideUIPanel(GameMenuFrame)
-- (GameMenuFrameMixin:InitButtons -> GenerateMenuCallback); CloseMenu is a thin
-- wrapper that also plays the "continue" sound. Prefer the exact native call;
-- fall back to the wrapper only if the global is somehow unavailable.
-- (HideUIPanel ships in Blizzard_UIParentPanelManager, which loads before any
-- addon runs, but it is not in the generated API index, so declare it here.)
local HideUIPanel = HideUIPanel -- luacheck: ignore 431

local function CloseGameMenu()
    if HideUIPanel and GameMenuFrame then
        HideUIPanel(GameMenuFrame)
    elseif GameMenuFrame.CloseMenu then
        GameMenuFrame:CloseMenu()
    end
end

hooksecurefunc(GameMenuFrame, "AddButton", function(self, text)
    -- Add ours right after the Options button, before any section break, so
    -- it participates in layout and gamepad navigation like a native entry.
    -- No "added once" flag here: Blizzard wipes and rebuilds this list every time the menu opens,
    -- so the button has to be added on every rebuild. The text checks below also stop this hook
    -- from reacting to the buttons it adds itself.
    if text ~= GAMEMENU_OPTIONS then return end

    self:AddButton("Ubermoc", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        CloseGameMenu()
        OpenUbermocSettings()
    end)

    -- Keybinds entry, so controller bindings are reachable straight from the
    -- pause menu (Blizzard's Options panel is mouse/keyboard first).
    self:AddButton("Ubermoc Keybinds", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        CloseGameMenu()
        ns:OpenKeybinds()
    end)
end)
