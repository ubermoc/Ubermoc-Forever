----------------------------------------------------------------------
-- Ubermoc Forever: the Start button
-- Start works in steps, like Esc on a keyboard (ported from Ubermoc UI): the first press closes what is open, clears
-- the target and stops a cast; once there is nothing left to clear, the next press opens the game menu; if the game
-- menu is up, it closes it. The game's own Escape action does this too, but on a controller its first steps can use
-- up every press so the menu never opens (and on the plain layer it did nothing at all in the game).
-- Clearing the target and stopping a cast are protected, so they run from a secure macro on the button. Closing
-- windows and showing the menu are done just before, through securecallfunction so this addon's taint stays out of
-- the game's panels.
----------------------------------------------------------------------
local _, UF = ...

UF.START_BIND = "CLICK UbermocForeverStart:LeftButton"

local function secureCall(fn, ...)
    if securecallfunction then return pcall(securecallfunction, fn, ...) end
    return pcall(fn, ...)
end

local function shownFrame(f) return type(f) == "table" and f.IsShown and f:IsShown() and true or false end

local PANELS = { "UbermocForeverOptions", "SettingsPanel", "DropDownList1", "DropDownList2", "WorldMapFrame",
                 "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

local function panelsOpen()
    for _, n in ipairs(PANELS) do if shownFrame(_G[n]) then return true end end
    if GetUIPanel then
        if shownFrame(GetUIPanel("left")) or shownFrame(GetUIPanel("center")) or shownFrame(GetUIPanel("right")) then return true end
    end
    for _, n in ipairs(UISpecialFrames or {}) do
        if n ~= "GameMenuFrame" and shownFrame(_G[n]) then return true end
    end
    for i = 1, 13 do if shownFrame(_G["ContainerFrame" .. i]) then return true end end
    return false
end

local function closePanels()
    if StaticPopup_EscapePressed then secureCall(StaticPopup_EscapePressed) end
    if shownFrame(_G.SettingsPanel) and _G.SettingsPanel.Close then secureCall(_G.SettingsPanel.Close, _G.SettingsPanel, true) end
    local w = _G.UbermocForeverOptions
    if shownFrame(w) then pcall(w.Hide, w) end
    if CloseMenus then secureCall(CloseMenus) end
    if CloseAllWindows then secureCall(CloseAllWindows) end
end

-- "combat" (only the macro runs), "hide" the game menu, "clear" (close windows, then the macro clears the target and
-- stops a cast), or "menu" (nothing was left to clear, so the game menu opens).
local function startPressed()
    if InCombatLockdown() then return "combat" end
    local gm = _G.GameMenuFrame
    if shownFrame(gm) then
        secureCall(HideUIPanel, gm)
        return "hide"
    end
    local panels = panelsOpen()
    local casting = (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))
    if panels or UnitExists("target") or casting then
        if panels then closePanels() end
        return "clear"
    end
    if gm and not (AreAllPanelsDisallowed and AreAllPanelsDisallowed()) then secureCall(ShowUIPanel, gm) end
    return "menu"
end
UF.startPressed = startPressed

-- A secure button so the macro can clear the target. The type is switched off for presses that must not clear
-- anything (it cannot be changed in combat, where a press always runs the macro).
local starter = CreateFrame("Button", "UbermocForeverStart", UIParent, "SecureActionButtonTemplate")
starter:RegisterForClicks("AnyUp")
starter:SetAttribute("useOnKeyDown", false)
starter:SetAttribute("type", "macro")
starter:SetAttribute("macrotext", "/stopcasting\n/cleartarget")
starter:SetScript("PreClick", function()
    local ok, action = pcall(startPressed)
    if ok and not InCombatLockdown() then starter:SetAttribute("type", action == "clear" and "macro" or nil) end
end)
starter:SetScript("PostClick", function()
    if not InCombatLockdown() then starter:SetAttribute("type", "macro") end
end)

-- Start on every layer does the stepped press, and the game's own Escape button is turned off so it cannot take the press.
function UF.bindStart()
    for _, layer in ipairs(UF.LAYERS) do SetBinding(layer .. "PADFORWARD", UF.START_BIND) end
    pcall(SetCVar, "GamePadEmulateEsc", "NONE")
end

-- Characters whose binds were set by an older version (Start was the game's own Escape) are moved over once, when
-- Start is still on that old setup (no bind of its own on the plain layer).
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if InCombatLockdown() then return end
    local db = UF.DB()
    local g = UF.guid and UF.guid()
    if not g or not db.applied[g] or db.startMigrated then return end
    db.startMigrated = true
    local a = GetBindingAction("PADFORWARD")
    if a == nil or a == "" or a == "TOGGLEGAMEMENU" then
        UF.bindStart()
        UF.saveBinds()
    end
end)
