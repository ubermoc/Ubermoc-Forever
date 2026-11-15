----------------------------------------------------------------------
-- Ubermoc Forever: the game menu entry
-- A "Controller" button directly above the game's Options button. The game builds its menu in
-- GameMenuFrame:InitButtons() (Blizzard_GameMenu/Shared/GameMenuFrame.lua) from a button pool, giving each button
-- a layoutIndex. After it has run, the entry is added and given the index just before Options, so it sits in the
-- same list with the same button art and spacing.
----------------------------------------------------------------------
local _, UF = ...

local function open()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    if GameMenuFrame then HideUIPanel(GameMenuFrame) end
    UF.ToggleOptions(true)
end

local function addEntry(menu)
    if not (menu.buttonPool and menu.buttonPool.EnumerateActive and menu.AddButton) then return end
    local optionsButton
    for button in menu.buttonPool:EnumerateActive() do
        if button.GetText and button:GetText() == GAMEMENU_OPTIONS then optionsButton = button; break end
    end
    if not (optionsButton and optionsButton.layoutIndex) then return end
    local entry = menu:AddButton("Controller", open)
    entry.layoutIndex = optionsButton.layoutIndex - 0.5
    entry.topPadding = optionsButton.topPadding
    optionsButton.topPadding = nil
    menu:MarkDirty()
end

UF.OnLogin(function()
    if GameMenuFrame and GameMenuFrame.InitButtons then
        hooksecurefunc(GameMenuFrame, "InitButtons", function(self)
            local ok, err = pcall(addEntry, self)
            if not ok then UF.check("Game menu entry", false, tostring(err)) end
        end)
    end
end)
