local _, ns = ...

-- Adds an "Ubermoc Forever" button at the top of the game menu, in the menu's own button style.
-- The menu rebuilds its buttons whenever it opens, so the button is added after every rebuild.
-- Menu buttons are laid out by layoutIndex, and the menu hands out 1, 2, 3 ..., so 0 is first.
local FIRST = 0
local SECTION_GAP = 20

local hooked

-- The same steps as the menu button on the micro bar: close what is open, then show the menu,
-- or put it away if it is already up. Nothing here stops casting or clears the target.
function ns.ToggleGameMenu()
    local menu = _G.GameMenuFrame
    if not menu then
        return
    end
    if menu:IsShown() then
        PlaySound(SOUNDKIT.IG_MAINMENU_QUIT)
        HideUIPanel(menu)
        return
    end
    if AreAllPanelsDisallowed and AreAllPanelsDisallowed() then
        return
    end
    if _G.SettingsPanel and _G.SettingsPanel:IsShown() then
        _G.SettingsPanel:Close()
    end
    ns.Options.Hide()
    CloseMenus()
    CloseAllWindows()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    ShowUIPanel(menu)
end

-- Bindings reach a function through a click on a button; this one is bound to Start.
local starter = CreateFrame("Button", "UbermocForeverMenu", UIParent)
starter:RegisterForClicks("AnyUp")
starter:SetScript("OnClick", function()
    local ok, err = pcall(ns.ToggleGameMenu)
    if not ok then
        ns.Log("game menu key failed: " .. tostring(err))
    end
end)

local function openOptions()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    HideUIPanel(GameMenuFrame)
    ns.Options.Toggle()
end

local function addButton(menu)
    local button = menu:AddButton(ns.L.OPT_TITLE, openOptions)
    local pool = menu.buttonPool
    if pool and pool.EnumerateActive then
        for other in pool:EnumerateActive() do
            if other ~= button and other.layoutIndex == 1 then
                other.topPadding = SECTION_GAP
            end
        end
    end
    button.layoutIndex = FIRST
    -- Forever's menu also keeps its buttons in a list that controller navigation wraps around.
    local list = menu.buttons
    if list and list[#list] == button then
        table.remove(list)
        table.insert(list, 1, button)
        if menu.ResetGamepadButtons and menu.SetupGamepadButtons then
            menu:ResetGamepadButtons()
            menu:SetupGamepadButtons()
        end
    end
    menu:MarkDirty()
end

local function hook()
    local menu = _G.GameMenuFrame
    if hooked or not menu or not menu.InitButtons then
        return
    end
    hooked = true
    hooksecurefunc(menu, "InitButtons", function(self)
        local ok, err = pcall(addButton, self)
        if not ok then
            ns.Log("game menu button failed: " .. tostring(err))
        end
    end)
    ns.Log("game menu button hooked")
end

ns.GameMenu = { Hook = hook, AddButton = addButton }

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "Blizzard_GameMenu" then
        hook()
    end
end)
