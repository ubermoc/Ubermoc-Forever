local _, ns = ...

-- Adds an "Ubermoc Forever" button at the top of the game menu, in the menu's own button style.
-- The menu rebuilds its buttons whenever it opens, so the button is added after every rebuild.
-- Menu buttons are laid out by layoutIndex, and the menu hands out 1, 2, 3 ..., so 0 is first.
local FIRST = 0
local SECTION_GAP = 20

local hooked

-- Start works in steps, like Esc on a keyboard: the first press closes what is open, clears the
-- target and stops a cast, and once there is nothing left to clear the next press opens the menu.
-- (The game's own Esc action does this too, but on a controller its first steps can use up every
-- press so the menu never opens.) Clearing the target and stopping a cast are protected, so they
-- run from a secure macro on the button; the closing and the menu are done just before it.
local CLEAR_MACRO = "/stopcasting\n/cleartarget"

local function isShown(frame)
    return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

local function casting()
    local ok, busy = pcall(function()
        return UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
    end)
    return ok and busy
end

local function panelsOpen()
    if ns.Cursor.WindowOpen() or isShown(_G.SettingsPanel) or isShown(_G.UbermocForeverOptions)
        or isShown(_G.DropDownList1) or isShown(_G.DropDownList2) then
        return true
    end
    for i = 1, 4 do
        if isShown(_G["StaticPopup" .. i]) then
            return true
        end
    end
    return false
end

local function closePanels()
    if type(StaticPopup_EscapePressed) == "function" then
        pcall(StaticPopup_EscapePressed)
    end
    if isShown(_G.SettingsPanel) then
        pcall(_G.SettingsPanel.Close, _G.SettingsPanel, true)
    end
    ns.Options.Hide()
    if type(CloseMenus) == "function" then
        pcall(CloseMenus)
    end
    CloseAllWindows()
end

function ns.OpenGameMenu()
    local menu = _G.GameMenuFrame
    if not menu or (AreAllPanelsDisallowed and AreAllPanelsDisallowed()) then
        return
    end
    closePanels()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    ShowUIPanel(menu)
end

-- What a press of Start does: "hide" the menu if it is up, "clear" (close panels, then the macro
-- clears the target and stops a cast), or "menu" when there was nothing to clear.
function ns.StartPressed()
    local menu = _G.GameMenuFrame
    if isShown(menu) then
        PlaySound(SOUNDKIT.IG_MAINMENU_QUIT)
        HideUIPanel(menu)
        return "hide"
    end
    local panels = panelsOpen()
    if panels or UnitExists("target") or casting() then
        if panels then
            closePanels()
        end
        return "clear"
    end
    ns.OpenGameMenu()
    return "menu"
end

-- Bindings reach this through a click on the button. It is a secure button so that the macro can
-- clear the target; the attribute is switched off for presses that should not clear anything
-- (it cannot be changed in combat, where the press always runs the macro).
local starter = CreateFrame("Button", "UbermocForeverMenu", UIParent, "SecureActionButtonTemplate")
starter:RegisterForClicks("AnyUp")
starter:SetAttribute("useOnKeyDown", false)
starter:SetAttribute("type", "macro")
starter:SetAttribute("macrotext", CLEAR_MACRO)
starter:SetScript("PreClick", function()
    local ok, action = pcall(ns.StartPressed)
    if not ok then
        ns.Log("start key failed: " .. tostring(action))
        return
    end
    if not InCombatLockdown() then
        starter:SetAttribute("type", action == "clear" and "macro" or nil)
    end
end)
starter:SetScript("PostClick", function()
    if not InCombatLockdown() then
        starter:SetAttribute("type", "macro")
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
