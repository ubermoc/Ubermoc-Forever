----------------------------------------------------------------------
-- Ubermoc Forever: the Y menu on a bag item
-- With the highlight (GameNav) on an item in your bags or bank, Y opens a short list next to it:
--   Use / equip (Sell while a vendor is open), Pick up / move, Delete, Sort bags.
-- The list is a window of its own that GameNav moves through like any other: D-pad to choose, A to do it, B to close.
-- Researched in docs/RESEARCH-NAVIGATION.md (sections 1 and 2): Ubermoc UI's menu (Extras.lua openItemMenu) and ConsolePort's
-- (ConsolePort_Menu ItemMenu.lua) both offer these for bag items.
-- Using an item has to come from a real secure button press, so "Use / equip" is a secure button of type "item" (the game
-- uses the same click at a vendor to sell, which is why one entry covers both). "Pick up" is a secure click on the item's
-- own button. Delete asks "Really delete?" first. Spells in the spellbook are not covered yet.
----------------------------------------------------------------------
local _, UF = ...

local M = {}
UF.ItemMenu = M

local menu, entries, title
local MAX = 4

local function say(m) if UF.say then UF.say(m) end end

local function bagSlot(btn)
    if not (btn and btn.GetBagID and btn.GetID) then return end
    local ok, bag = pcall(btn.GetBagID, btn)
    local slot = btn:GetID()
    if ok and type(bag) == "number" and type(slot) == "number" and slot > 0 then return bag, slot end
end

local function build()
    if menu then return end
    menu = CreateFrame("Frame", "UbermocForeverItemMenu", UIParent, "BackdropTemplate")
    menu.ubfNavOk = true
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(210)
    if menu.SetBackdrop then
        menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                           edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                           insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    end
    title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", menu, "TOP", 0, -14)
    title:SetWidth(180)
    local close = CreateFrame("Button", "UbermocForeverItemMenuClose", menu, "UIPanelCloseButton")
    close.ubfNavOk = true
    close:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 2, 2)
    menu.CloseButton = close
    entries = {}
    for i = 1, MAX do
        local b = CreateFrame("Button", "UbermocForeverItemMenuEntry" .. i, menu, "SecureActionButtonTemplate,UIPanelButtonTemplate")
        b.ubfNavOk = true
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("useOnKeyDown", false)
        b:SetSize(180, 24)
        b:SetPoint("TOP", menu, "TOP", 0, -34 - (i - 1) * 28)
        b:HookScript("PostClick", function(self)
            if self.keepOpen then return end
            C_Timer.After(0.1, function() if menu:IsShown() then menu:Hide() end end)
        end)
        entries[i] = b
    end
    menu:SetScript("OnHide", function()
        local back = M.from
        M.from = nil
        if UF.GameNav then UF.GameNav.restore = back end
    end)
    menu:Hide()
end

local function setEntry(i, label, attrs, pre, keepOpen)
    local b = entries[i]
    for _, k in ipairs({ "type", "item", "clickbutton", "macrotext" }) do b:SetAttribute(k, nil) end
    for k, v in pairs(attrs or {}) do b:SetAttribute(k, v) end
    b:SetText(label)
    b.keepOpen = keepOpen
    b:SetScript("PreClick", pre)
    b:Show()
end

-- Open the list for the highlighted button `btn`. Returns true when it opened.
function M.open(btn)
    if InCombatLockdown() then return false end
    local bag, slot = bagSlot(btn)
    local info = bag and C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if not info then
        say("The options menu works on items in your bags and bank.")
        return false
    end
    build()
    M.from = btn
    local name = info.hyperlink and info.hyperlink:match("%[(.-)%]") or "Item"
    title:SetText(name)
    for _, e in ipairs(entries) do e:Hide() end
    local vendor = MerchantFrame and MerchantFrame:IsShown()
    setEntry(1, vendor and "Sell" or "Use / equip", { type = "item", item = bag .. " " .. slot })
    setEntry(2, "Pick up / move", { type = "click", clickbutton = btn })
    local armed = false
    setEntry(3, "Delete", nil, function(self)
        if not armed then
            armed = true
            self:SetText("Really delete?")
            self.keepOpen = true
            return
        end
        self.keepOpen = false
        pcall(C_Container.PickupContainerItem, bag, slot)
        if CursorHasItem and CursorHasItem() then
            pcall(DeleteCursorItem)
            if CursorHasItem() then ClearCursor(); say("The game would not delete that item from here.") end
        end
    end, true)
    if C_Container.SortBags then
        setEntry(4, "Sort bags", nil, function() pcall(C_Container.SortBags) end)
    end
    menu:SetHeight(46 + MAX * 28)
    menu:ClearAllPoints()
    menu:SetPoint("LEFT", btn, "RIGHT", 12, 0)
    menu:Show()
    return true
end

function M.isOpen() return menu and menu:IsShown() or false end
