----------------------------------------------------------------------
-- Ubermoc Forever: the Y menu on a bag item
-- With the highlight (GameNav) on an item in your bags or bank, Y opens a short list next to it:
--   Use / equip (Sell while a vendor is open), Pick up / move, Delete, Sort bags.
-- The list is a window of its own that GameNav moves through like any other: D-pad to choose, A to do it, B to close.
-- Researched in docs/RESEARCH-NAVIGATION.md (sections 1 and 2): Ubermoc UI's menu (Extras.lua openItemMenu) and ConsolePort's
-- (ConsolePort_Menu ItemMenu.lua) both offer these for bag items.
-- Using an item has to come from a real secure button press, so "Use / equip" is a secure button of type "item" (the game
-- uses the same click at a vendor to sell, which is why one entry covers both). "Pick up" is a secure click on the item's
-- own button. Delete asks "Really delete?" first.
-- On an equipped item (character window): Use, Pick up / move. On a spell in the spellbook: "Bind to action bar", which
-- picks the spell up (the same C_SpellBook.PickupSpellBookItem call the game's own drag makes, SpellBookItem.lua) and hands
-- over to GameNav's "place" mode, where the highlight moves over the action bars and A drops the spell on a slot.
----------------------------------------------------------------------
local _, UF = ...

local M = {}
UF.ItemMenu = M

local menu, entries, title
local MAX = 4

-- Which side of the highlighted item the menu opens on: "right" (default) or "left". Set with the button on the options
-- window, or /ubf menu left|right.
function UF.menuSide() return UF.DB().menuSide == "left" and "left" or "right" end

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
        if UF.GameNav and not UF.GameNav.placing then UF.GameNav.restore = back end
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

local function spellOf(btn)
    local p = btn and btn.GetParent and btn:GetParent()
    if type(p) == "table" and p.slotIndex and p.spellBank and p.spellBookItemInfo then return p end
end

local EQUIP_NAME = "^Character%u%a+Slot$"
local function equipSlot(btn)
    local n = btn and btn.GetName and btn:GetName()
    if not (n and n:find(EQUIP_NAME) and btn.GetID) then return end
    local id = btn:GetID()
    if type(id) == "number" and id > 0 and GetInventoryItemLink and GetInventoryItemLink("player", id) then return id end
end

-- What the highlighted button is: "bag", "equip", "spell" or nil.
function M.kind(btn)
    if not btn then return nil end
    local bag = bagSlot(btn)
    if bag then
        local info = C_Container and C_Container.GetContainerItemInfo and select(2, pcall(C_Container.GetContainerItemInfo, bagSlot(btn)))
        if info then return "bag" end
        return nil
    end
    if equipSlot(btn) then return "equip" end
    if spellOf(btn) then return "spell" end
end

local function layout(count)
    for i, e in ipairs(entries) do
        if i > count then e:Hide() end
    end
    menu:SetHeight(46 + count * 28)
end

local function openBag(btn)
    local bag, slot = bagSlot(btn)
    local info = bag and C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if not info then return false end
    title:SetText(info.hyperlink and info.hyperlink:match("%[(.-)%]") or "Item")
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
    local count = 3
    if C_Container.SortBags then
        count = 4
        setEntry(4, "Sort bags", nil, function() pcall(C_Container.SortBags) end)
    end
    layout(count)
    return true
end

local function openEquip(btn)
    local id = equipSlot(btn)
    if not id then return false end
    local link = GetInventoryItemLink("player", id)
    title:SetText(link and link:match("%[(.-)%]") or "Item")
    setEntry(1, "Use", { type = "macro", macrotext = "/use " .. id })
    setEntry(2, "Pick up / move", { type = "click", clickbutton = btn })
    layout(2)
    return true
end

local function openSpell(btn)
    local p = spellOf(btn)
    if not p then return false end
    title:SetText(p.spellBookItemInfo.name or "Spell")
    setEntry(1, "Bind to action bar", nil, function()
        if not (C_SpellBook and C_SpellBook.PickupSpellBookItem) then return end
        pcall(C_SpellBook.PickupSpellBookItem, p.slotIndex, p.spellBank)
        if GetCursorInfo and GetCursorInfo() then
            if UF.GameNav and UF.GameNav.beginPlace then UF.GameNav.beginPlace(btn) end
        else
            say("That spell cannot go on an action bar.")
        end
    end, true)
    layout(1)
    return true
end

-- Put the menu beside the highlighted button: on the side chosen in the options when it fits on the screen, otherwise on
-- the other side, and when neither side has room, over the button's edge, always kept on the screen.
function M.place(btn)
    menu:ClearAllPoints()
    if menu.SetClampedToScreen then menu:SetClampedToScreen(true) end
    local side = UF.menuSide()
    local ok, chosen = pcall(function()
        local ui = UIParent:GetEffectiveScale() or 1
        local sc = (btn:GetEffectiveScale() or 1) / ui
        local left, right = btn:GetLeft(), btn:GetRight()
        local screenW = UIParent:GetWidth() or 0
        local w = (menu:GetWidth() or 210) + 12
        if left and right and screenW > 0 then
            local roomLeft, roomRight = left * sc, screenW - right * sc
            local fits = { left = roomLeft >= w, right = roomRight >= w }
            if not fits[side] then
                local other = (side == "left") and "right" or "left"
                if fits[other] then return other end
                return (roomRight >= roomLeft) and "right" or "left"
            end
        end
        return side
    end)
    if ok and chosen then side = chosen end
    if side == "left" then
        menu:SetPoint("RIGHT", btn, "LEFT", -12, 0)
    else
        menu:SetPoint("LEFT", btn, "RIGHT", 12, 0)
    end
end

-- Open the list for the highlighted button `btn`. Returns true when it opened.
function M.open(btn)
    if InCombatLockdown() then return false end
    local kind = M.kind(btn)
    if not kind then
        say("The options menu works on items in your bags, items you are wearing, and spells in the spellbook.")
        return false
    end
    build()
    M.from = btn
    for _, e in ipairs(entries) do e:Hide() end
    local ok = (kind == "bag" and openBag(btn)) or (kind == "equip" and openEquip(btn)) or (kind == "spell" and openSpell(btn))
    if not ok then M.from = nil; return false end
    M.place(btn)
    menu:Show()
    return true
end

function M.isOpen() return menu and menu:IsShown() or false end
