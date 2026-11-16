----------------------------------------------------------------------
-- Ubermoc Forever: the Y menu on an item or a spell
-- With the highlight (GameNav) on an item (in your bags or bank, or on your character) or a spell, Y opens a short list
-- beside it, which GameNav moves through like any other window: D-pad to choose, A to do it, B to close.
--
--   An item in a bag:  Use / equip (Sell at a vendor), "Use on <weapon>" for items that are used on another item (sharpening
--                      stones, poisons, oils ...), Disenchant / Prospect / Mill when your professions allow it, Pick up /
--                      move, Delete, Sort bags.
--   A worn item:       Use, "Use <item from your bags> on this" for each such item you carry (weapons only), Pick up / move.
--   A spell:           Bind to action bar (picks the spell up; GameNav's place mode drops it on a slot).
--
-- Sources (docs/RESEARCH-NAVIGATION.md sections 1 and 2): Ubermoc UI's menu (Extras.lua openItemMenu) and ConsolePort's
-- (ConsolePort_Menu ItemMenu.lua, which also adds Disenchant with the macro "/cast Disenchant" then "/use <bag> <slot>").
-- Using an item has to come from a real secure button press, so those entries are secure buttons: type "item" for a plain
-- use, and a macro for "use this, then use it on that slot" ("/use <bag> <slot>" then "/use <inventory slot>", the same
-- two lines players have long used for sharpening stones; the slot numbers are the game's: 16 main hand, 17 off hand).
--
-- Which items are used on another item is decided from the game's own item data (see usedOnItems below). That rule has not
-- been confirmed in the game for every item: /ubf item prints what the game says about the highlighted item.
----------------------------------------------------------------------
local _, UF = ...

local M = {}
UF.ItemMenu = M

local menu, entries, title
local MAX = 8

local function say(m) if UF.say then UF.say(m) end end

----------------------------------------------------------------------
-- What the highlighted button is
----------------------------------------------------------------------
local function locationOf(btn)
    if not (btn and btn.GetItemLocation) then return nil end
    local ok, loc = pcall(btn.GetItemLocation, btn)
    if ok and type(loc) == "table" and loc.IsValid and loc:IsValid() then return loc end
end

-- Returns bag, slot for a bag or bank item button.
local function bagSlot(btn)
    if btn and btn.GetBagID and btn.GetID then
        local ok, bag = pcall(btn.GetBagID, btn)
        local slot = btn:GetID()
        if ok and type(bag) == "number" and type(slot) == "number" and slot > 0 then return bag, slot end
    end
    local loc = locationOf(btn)
    if loc and loc.IsBagAndSlot and loc:IsBagAndSlot() then
        local ok, bag, slot = pcall(loc.GetBagAndSlot, loc)
        if ok and bag and slot then return bag, slot end
    end
end

local EQUIP_NAME = "^Character%u%a+Slot$"
-- Returns the inventory slot number for a worn-item button.
local function equipSlot(btn)
    local loc = locationOf(btn)
    if loc and loc.IsEquipmentSlot and loc:IsEquipmentSlot() then
        local ok, id = pcall(loc.GetEquipmentSlot, loc)
        if ok and id then return id end
    end
    local n = btn and btn.GetName and btn:GetName()
    if n and n:find(EQUIP_NAME) and btn.GetID then
        local id = btn:GetID()
        if type(id) == "number" and id > 0 and GetInventoryItemLink and GetInventoryItemLink("player", id) then return id end
    end
end

local function spellOf(btn)
    local p = btn and btn.GetParent and btn:GetParent()
    if type(p) == "table" and p.slotIndex and p.spellBank and p.spellBookItemInfo then return p end
end

-- What the highlighted button is: "bag", "equip", "spell" or nil.
function M.kind(btn)
    if not btn then return nil end
    local bag, slot = bagSlot(btn)
    if bag then
        if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        return (ok and info) and "bag" or nil
    end
    if equipSlot(btn) then return "equip" end
    if spellOf(btn) then return "spell" end
end

----------------------------------------------------------------------
-- Item facts from the game's own data
----------------------------------------------------------------------
local function instant(itemID)
    if not (itemID and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local ok, _, _, _, equipLoc, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
    if ok then return classID, subClassID, equipLoc end
end

local function quality(itemID)
    if not (itemID and C_Item and C_Item.GetItemInfo) then return nil end
    local ok, _, _, q = pcall(C_Item.GetItemInfo, itemID)
    return ok and q or nil
end

local function hasUse(itemID)
    if not (itemID and C_Item and C_Item.GetItemSpell) then return false end
    local ok, name = pcall(C_Item.GetItemSpell, itemID)
    return ok and name ~= nil
end

-- Item classes (Enum.ItemClass in Blizzard_APIDocumentationGenerated ItemConstantsDocumentation.lua).
local CLASS = { consumable = 0, weapon = 2, armor = 4, tradegoods = 7, itemEnhancement = 8 }
-- Consumables that are plainly not used on another item: potions 1, elixirs 2, flasks 3, scrolls 4, food and drink 5,
-- bandages 7 (Enum.ItemConsumableSubclass, same file).
local NOT_ON_ITEMS = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true }

-- Items that are used on another item (sharpening stones, weightstones, poisons, oils, enchant scrolls ...): the game
-- groups them as the "Item Enhancement" class, or as consumables of the Item Enhancement subclasses (6 and 15), and a
-- consumable with a use that is not a potion, elixir, flask, scroll, food or bandage is treated the same way.
function M.usedOnItems(itemID)
    if not hasUse(itemID) then return false end
    local classID, subClassID = instant(itemID)
    if classID == CLASS.itemEnhancement then return true end
    if classID == CLASS.consumable then return not NOT_ON_ITEMS[subClassID or -1] end
    return false
end

-- Slots a use-on-item can go to: the weapons you wear. (16 main hand, 17 off hand, 18 ranged, in the game's numbering.)
local WEAPON_SLOTS = { 16, 17, 18 }
local SLOT_NAMES = { [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

local function equippedWeapons()
    local list = {}
    for _, slot in ipairs(WEAPON_SLOTS) do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if id and instant(id) == CLASS.weapon then list[#list + 1] = { slot = slot, id = id, name = SLOT_NAMES[slot] } end
    end
    return list
end

local function isWeaponSlot(slot)
    for _, s in ipairs(WEAPON_SLOTS) do if s == slot then return true end end
    return false
end

----------------------------------------------------------------------
-- Profession actions on a bag item
----------------------------------------------------------------------
-- Spell ids as used by Ubermoc UI's menu (Extras.lua), checked against the player's own spells at run time.
local PROFESSION = {
    { id = 13262, label = "Disenchant" },
    { id = 31252, label = "Prospect" },
    { id = 51005, label = "Mill" },
}

local function knownSpell(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n then return n end
    end
end

function M.professionFor(spellId, itemID, count)
    local classID, subClassID = instant(itemID)
    if spellId == 13262 then   -- Disenchant: green to epic weapons and armour
        local q = quality(itemID)
        return (classID == CLASS.weapon or classID == CLASS.armor) and q ~= nil and q >= 2 and q <= 4
    elseif spellId == 31252 then   -- Prospecting: five or more ore (trade goods, metal and stone)
        return classID == CLASS.tradegoods and subClassID == 7 and (count or 1) >= 5
    elseif spellId == 51005 then   -- Milling: five or more herbs (trade goods, herb)
        return classID == CLASS.tradegoods and subClassID == 9 and (count or 1) >= 5
    end
    return false
end

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
local function build()
    if menu then return end
    menu = CreateFrame("Frame", "UbermocForeverItemMenu", UIParent, "BackdropTemplate")
    menu.ubfNavOk = true
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(260)
    if menu.SetBackdrop then
        menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                           edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
                           insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    end
    title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", menu, "TOP", 0, -14)
    title:SetWidth(200)
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
        b:SetSize(230, 24)
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

local count = 0
local function reset()
    count = 0
    for _, e in ipairs(entries) do e:Hide() end
end

local function add(label, attrs, pre, keepOpen)
    if count >= MAX then return end
    count = count + 1
    local b = entries[count]
    for _, k in ipairs({ "type", "item", "clickbutton", "macrotext" }) do b:SetAttribute(k, nil) end
    for k, v in pairs(attrs or {}) do b:SetAttribute(k, v) end
    b:SetText(label)
    b.keepOpen = keepOpen
    b:SetScript("PreClick", pre)
    b:Show()
    return b
end

local function itemName(link, fallback)
    return link and link:match("%[(.-)%]") or fallback
end

-- Put the menu beside the highlighted button: on the right when it fits on the screen, otherwise on the left, and when
-- neither side has room, on the side with more room; always kept on the screen.
function M.place(btn)
    menu:ClearAllPoints()
    if menu.SetClampedToScreen then menu:SetClampedToScreen(true) end
    local side = "right"
    local ok, chosen = pcall(function()
        local ui = UIParent:GetEffectiveScale() or 1
        local sc = (btn:GetEffectiveScale() or 1) / ui
        local left, right = btn:GetLeft(), btn:GetRight()
        local screenW = UIParent:GetWidth() or 0
        local w = (menu:GetWidth() or 260) + 12
        if left and right and screenW > 0 then
            local roomLeft, roomRight = left * sc, screenW - right * sc
            if roomRight >= w then return "right" end
            if roomLeft >= w then return "left" end
            return (roomRight >= roomLeft) and "right" or "left"
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

----------------------------------------------------------------------
-- The three kinds of menu
----------------------------------------------------------------------
local function openBag(btn)
    local bag, slot = bagSlot(btn)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not (ok and info) then return false end
    local itemID = info.itemID
    title:SetText(itemName(info.hyperlink, "Item"))
    reset()
    local vendor = MerchantFrame and MerchantFrame:IsShown()
    add(vendor and "Sell" or "Use / equip", { type = "item", item = bag .. " " .. slot })

    -- used on another item: one entry for each weapon you wear
    if not vendor and M.usedOnItems(itemID) then
        for _, w in ipairs(equippedWeapons()) do
            local link = GetInventoryItemLink and GetInventoryItemLink("player", w.slot)
            add("Use on " .. w.name .. ": " .. itemName(link, "weapon"),
                { type = "macro", macrotext = "/use " .. bag .. " " .. slot .. "\n/use " .. w.slot })
        end
    end

    -- profession actions the character can do
    for _, p in ipairs(PROFESSION) do
        if knownSpell(p.id) and M.professionFor(p.id, itemID, info.stackCount) then
            local n = spellName(p.id)
            if n then add(p.label, { type = "macro", macrotext = "/cast " .. n .. "\n/use " .. bag .. " " .. slot }) end
        end
    end

    add("Pick up / move", { type = "click", clickbutton = btn })
    local armed = false
    add("Delete", nil, function(self)
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
        add("Sort bags", nil, function() pcall(C_Container.SortBags) end)
    end
    return true
end

-- Items in the bags that are used on another item, one per kind, with where they are.
local function carriedEnhancers()
    local out, seen = {}, {}
    local lastBag = NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not seen[info.itemID] and M.usedOnItems(info.itemID) then
                seen[info.itemID] = true
                out[#out + 1] = { bag = bag, slot = slot, link = info.hyperlink, count = info.stackCount }
            end
        end
    end
    return out
end

local function openEquip(btn)
    local id = equipSlot(btn)
    if not id then return false end
    local link = GetInventoryItemLink("player", id)
    title:SetText(itemName(link, "Item"))
    reset()
    local itemID = GetInventoryItemID and GetInventoryItemID("player", id)
    if hasUse(itemID) then add("Use", { type = "macro", macrotext = "/use " .. id }) end
    -- a weapon: everything in the bags that can be used on it
    if instant(itemID) == CLASS.weapon and isWeaponSlot(id) then
        local ok, list = pcall(carriedEnhancers)
        if ok then
            for _, e in ipairs(list) do
                add("Use " .. itemName(e.link, "item") .. ((e.count and e.count > 1) and (" (" .. e.count .. ")") or ""),
                    { type = "macro", macrotext = "/use " .. e.bag .. " " .. e.slot .. "\n/use " .. id })
            end
        end
    end
    add("Pick up / move", { type = "click", clickbutton = btn })
    return true
end

local function openSpell(btn)
    local p = spellOf(btn)
    if not p then return false end
    title:SetText(p.spellBookItemInfo.name or "Spell")
    reset()
    add("Bind to action bar", nil, function()
        if not (C_SpellBook and C_SpellBook.PickupSpellBookItem) then return end
        pcall(C_SpellBook.PickupSpellBookItem, p.slotIndex, p.spellBank)
        if GetCursorInfo and GetCursorInfo() then
            if UF.GameNav and UF.GameNav.beginPlace then UF.GameNav.beginPlace(btn) end
        else
            say("That spell cannot go on an action bar.")
        end
    end, true)
    return true
end

-- Open the list for the highlighted button. Returns true when it opened.
function M.open(btn)
    if InCombatLockdown() then return false end
    local kind = M.kind(btn)
    if not kind then
        say("The options menu works on items in your bags, items you are wearing, and spells in the spellbook.")
        return false
    end
    build()
    M.from = btn
    local ok, opened = pcall(function()
        if kind == "bag" then return openBag(btn) end
        if kind == "equip" then return openEquip(btn) end
        return openSpell(btn)
    end)
    if not (ok and opened) then
        M.from = nil
        if not ok and UF.check then UF.check("Item menu", false, tostring(opened)) end
        return false
    end
    menu:SetHeight(46 + count * 28)
    M.place(btn)
    menu:Show()
    return true
end

function M.isOpen() return menu and menu:IsShown() or false end

-- /ubf item: what the game says about the highlighted item, to check the rules above against real items.
function M.report(btn)
    local bag, slot = bagSlot(btn)
    local itemID
    if bag then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        itemID = info and info.itemID
    else
        local id = equipSlot(btn)
        itemID = id and GetInventoryItemID and GetInventoryItemID("player", id)
    end
    if not itemID then say("Highlight an item first."); return end
    local classID, subClassID, equipLoc = instant(itemID)
    say(string.format("Item %d: class %s, subclass %s, equip %s, has a use: %s, used on another item: %s.",
        itemID, tostring(classID), tostring(subClassID), tostring(equipLoc), tostring(hasUse(itemID)),
        tostring(M.usedOnItems(itemID))))
end
