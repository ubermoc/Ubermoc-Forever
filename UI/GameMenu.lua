local _, ns = ...

-- Adds an "Ubermoc Forever" button at the top of the game menu, in the menu's own button style.
-- The menu rebuilds its buttons whenever it opens, so the button is added after every rebuild.
-- Menu buttons are laid out by layoutIndex, and the menu hands out 1, 2, 3 ..., so 0 is first.
local FIRST = 0
local SECTION_GAP = 20

local hooked

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
