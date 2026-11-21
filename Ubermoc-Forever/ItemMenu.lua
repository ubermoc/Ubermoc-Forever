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

-- what X's rule sees on this button (for /ubf x): which bag and slot it is, and what X resolves to there
function M.xInfo(btn, out)
    out = out or UF.say
    local bag, slot = bagSlot(btn)
    if not bag then return end
    local act = M.rightClickAction(btn)
    local what = "nothing"
    if act then what = tostring(act.macrotext or act.item or act.type) end
    out("X sees bag " .. bag .. " slot " .. slot .. ": " .. what)
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

-- A bag slot on the bag bar beside the micro menu (Blizzard_MainMenuBarBagButtons: CharacterBag0Slot to CharacterBag3Slot,
-- CharacterReagentBag0Slot; the backpack itself cannot be swapped). Returns its bag ID, inventory slot and whether it is the
-- reagent slot.
function M.bagBarSlot(btn)
    if type(btn) ~= "table" then return nil end
    local reagent
    local n = btn.GetName and btn:GetName()
    if type(n) == "string" and n ~= "" then
        reagent = n:find("^CharacterReagentBag%dSlot$") ~= nil
        if not (reagent or n:find("^CharacterBag%dSlot$")) then n = nil end
    else
        n = nil
    end
    if not n then
        -- the gamepad bag bar inside the combined bags window (Blizzard_MainMenuBarBagButtons GamepadBagBar): its slot
        -- buttons have no global name, only a slotName key ("BAG0SLOT" ... "BAG3SLOT", "REAGENTBAG0SLOT"; the backpack and
        -- the key ring have other names and are left out)
        local sn = btn.slotName
        if type(sn) ~= "string" then return nil end
        reagent = sn:find("^REAGENTBAG%dSLOT$") ~= nil
        if not (reagent or sn:find("^BAG%dSLOT$")) then return nil end
    end
    if not btn.GetBagID or not btn.GetID then return nil end
    local okB, bagID = pcall(btn.GetBagID, btn)
    local okI, inv = pcall(btn.GetID, btn)
    if not (okB and okI and type(bagID) == "number" and type(inv) == "number") then return nil end
    if bagID < 1 then return nil end
    return bagID, inv, reagent
end

-- What the highlighted button is: "bag", "equip", "spell", "bagslot" or nil.
function M.kind(btn)
    if not btn then return nil end
    if M.bagBarSlot(btn) then return "bagslot" end
    local bag, slot = bagSlot(btn)
    if bag then
        if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        return (ok and info) and "bag" or nil
    end
    if equipSlot(btn) then return "equip" end
    if spellOf(btn) then return "spell" end
end

-- What X (the right click) should do on the highlighted button, as attributes for the secure right-click
-- button, or nil when X has nothing to do there. Second return: true when the button is a bag slot, so the
-- caller knows X has no action for it and must not fall back to a plain click.
-- Our code cannot run the game's own right click on a bag slot: the secure click only reaches a button when
-- the frame was not stored by our code (`SECURE_ACTIONS.click` refuses a delegate with access constraints,
-- SecureTemplates.lua:557-564), and the game's right click on a bag item is a protected action (the item's
-- own use, ContainerFrame.lua:1604-1612) - which is why X did nothing in the bags (the user's report). What
-- does work is the pattern the Y menu already uses: attributes that are strings, the secure "item" action
-- (SecureTemplates.lua:418-438) or a macro.
-- 1.3.152: X now does that use for EVERY item in a bag slot. The user's rule: X is a right click, and the game's
-- right click on a bag slot is the item's own use. So the item types the Y menu also handles (poisons, armour kits,
-- oils, stones, enchants) and bags are no longer left out; the Y menu keeps its entries, it is just not the only way.
-- The secure "item" action is the same call the game's right click ends with (C140, C141), so a poison, a kit or a
-- bag goes through it like anything else.
-- 1.3.154: X runs the use as the game's own /use command, through the macro action, because that is the route the user
-- confirmed working in the game (the Y menu's "Use on <weapon>" entries). The secure "item" action route is not
-- confirmed working in the game - the user reports X still does nothing there - so X does not rely on it.
-- C157: `macrotext` is run by `C_Macro.RunMacroText(text, button)`; C158: Blizzard reads `SecureCmdItemParse` as
-- `name, bag, slot` and calls `SecureCmdUseItem(name, bag, slot, target)`, which ends with
-- `C_Container.UseContainerItem(bag, slot, target)` (C153) - the same call as the game's right click (C138).
function M.rightClickAction(btn)
    if type(btn) ~= "table" then return nil end
    local bag, slot = bagSlot(btn)
    if not bag then return nil end
    local no = function() return nil, true end
    local name = btn.GetName and btn.GetName()
    -- At a vendor the game's own right click sells (ContainerFrame.lua:1543-1549, and nothing on the buyback
    -- tab). That click is the game's action on the button itself, so we can only reach it through a macro,
    -- which needs the button's name; a slot inside the gamepad bag window has no name (see bagBarSlot above),
    -- so X has nothing to do there at a vendor. Everywhere else the right click is the item's own use.
    if MerchantFrame and MerchantFrame:IsShown() then
        if MerchantFrame.selectedTab == 2 then return no() end   -- the game sells nothing on the buyback tab
        if name and name ~= "" then return { type = "macro", macrotext = "/click " .. name .. " RightButton" } end
        return no()
    end
    if not (C_Container and C_Container.GetContainerItemInfo) then return no() end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not (ok and info) then return no() end
    -- with no vendor open the game's right click is the item's own use: learning a recipe, using a hearthstone,
    -- applying a poison or a kit, equipping a bag - the same secure action as the Y menu's "Use / equip" entry
    -- (C140: it equips when the item is equippable and not equipped, else uses it; C141: the game's right click
    -- ends with the same call). 1.3.152: no item type is left out any more.
    -- 1.3.154: the game's /use command, as a macro attribute (C157, C158, C153): a string, not a stored frame, and
    -- the route confirmed working in the game. For a bag slot reference the macro name is nothing, so the use - and
    -- the equip of an equippable item - goes through the same call the game's own right click ends with (C138).
    return { type = "macro", macrotext = "/use " .. bag .. " " .. slot }
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

-- Item classes (Enum.ItemClass in Blizzard_APIDocumentationGenerated ItemConstantsDocumentation.lua).
local CLASS = { consumable = 0, weapon = 2, armor = 4, tradegoods = 7, itemEnhancement = 8, quest = 12, misc = 15 }
-- Consumables that are plainly not used on another item: potions 1, elixirs 2, flasks 3, scrolls 4, food and drink 5,
-- bandages 7 (Enum.ItemConsumableSubclass, same file).
local NOT_ON_ITEMS = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true }

-- Poisons turned out (checked in the game with /ubf item: Crippling Poison 3775 and Instant Poison 6947) to be class 0,
-- subclass 8 ("Other"), the same group as many other consumables. So for a consumable the item's own tooltip decides: its
-- "Use:" line has to talk about a weapon (poisons, sharpening stones, weightstones and oils all do). The tooltip comes from
-- C_TooltipInfo.GetItemByID (lines carry `leftText`, as Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua reads them).
-- If the tooltip cannot be read, the class rule alone is used.
local useCache = {}
-- The item's own "Use:" text, lower case, joined; nil when the tooltip cannot be read.
local function useText(itemID)
    if useCache[itemID] ~= nil then return useCache[itemID] or nil end
    local text
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            local parts = {}
            local prefix = tostring(_G.ITEM_SPELL_TRIGGER_ONUSE or "Use:"):lower()
            for _, line in ipairs(data.lines) do
                local t = type(line) == "table" and line.leftText
                if type(t) == "string" then
                    local l = t:lower()
                    if l:sub(1, #prefix) == prefix then parts[#parts + 1] = l end
                end
            end
            text = table.concat(parts, " ")
        end
    end
    if text ~= nil then useCache[itemID] = text end
    return text
end

-- The item's own use spell as the game answers it (`C_Item.GetItemSpell`, C147): spellName and spellID. It
-- is MayReturnNothing, so it can answer nothing even for an item that has a use (C148: Blizzard code calls
-- it with an item ID number).
local function useSpell(itemID)
    if not (itemID and C_Item and C_Item.GetItemSpell) then return nil end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, itemID)
    if not ok then return nil end
    return name, spellID
end

function M.spellID(itemID)
    local name, spellID = useSpell(itemID)
    return spellID
end

-- Whether the item has its own use. The spell lookup can answer nothing (C147), so the item's own tooltip
-- `Use:` line (read through `GetItemByID`, C149) counts as well: a weapon-buff item the lookup misses - the
-- user's Crippling Poison, item 3775 with spell 173555 (C150) - still gets its entries. This is not a rule for
-- that item alone: it holds for every item whose tooltip shows a Use: line.
local function hasUse(itemID)
    if not itemID then return false end
    local name, spellID = useSpell(itemID)
    if name ~= nil or spellID ~= nil then return true end
    return useText(itemID) ~= nil
end

-- Equipment slots in the game's numbering, with what the item's use text calls them. The wording comes from a scan of the
-- game's own items (/ubf scan): poisons "Coats a weapon ...", oils "While applied to target weapon ...", sharpening stones
-- "... on a melee weapon", armor kits "... of an item worn on the chest, legs, hands or feet", scopes "Attaches a permanent
-- scope to a bow or gun". Head, leg and shoulder enchants say "... to a leg or head slot item" (the Dire Maul arcanums, the
-- Zul'Gurub enchants and resistance guards) or "... to a shoulder slot item" (the Zandalar signets, the Naxxramas Scourge
-- enchants); the full list with each item's text is in docs/ITEM-USE-SCAN.md.
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
                     [9] = "Wrists", [10] = "Hands", [11] = "Ring", [12] = "Ring", [15] = "Back", [16] = "Main hand",
                     [17] = "Off hand", [18] = "Ranged" }
local ARMOR_WORDS = { { 1, "head" }, { 3, "shoulder" }, { 5, "chest" }, { 6, "waist" }, { 6, "belt" }, { 7, "leg" },
                      { 8, "feet" }, { 8, "foot" }, { 9, "wrist" }, { 9, "bracer" }, { 10, "hand" }, { 15, "back" },
                      { 15, "cloak" } }

-- Which equipment slots a use-on-item can go to, read from its use text: a list of slots, or nil when the text does not
-- say it goes on an item (then it is a potion, food ...). Ranged weapons take only what names a bow or gun.
function M.targets(itemID)
    local t = useText(itemID)
    if not t then return nil end
    if t:find("bow or gun", 1, true) or t:find("to a bow", 1, true) or t:find("to a gun", 1, true) then return { 18 } end
    local worn = t:find("worn on", 1, true) or t:find("piece of armor", 1, true) or t:find("slot item", 1, true)
    if worn then
        local out, seen = {}, {}
        for _, w in ipairs(ARMOR_WORDS) do
            if t:find(w[2], 1, true) and not seen[w[1]] then seen[w[1]] = true; out[#out + 1] = w[1] end
        end
        if #out == 0 then out = { 1, 3, 5, 6, 7, 8, 9, 10, 15 } end   -- "an item worn": any armor piece
        return out
    end
    if t:find("weapon", 1, true) then return { 16, 17 } end
    return nil
end

-- Items that are used on another item (sharpening stones, weightstones, poisons, oils, armor kits, scopes ...): the game's
-- "Item Enhancement" class counts; a consumable with a use that is not a potion, elixir, flask, scroll, food or bandage counts
-- when its use text says what it goes on (M.targets).
function M.usedOnItems(itemID)
    if not hasUse(itemID) then return false end
    local classID, subClassID = instant(itemID)
    if classID == CLASS.itemEnhancement then return true end
    if classID == CLASS.consumable and not NOT_ON_ITEMS[subClassID or -1] then
        local v = useText(itemID)
        if v == nil then return true end
        return M.targets(itemID) ~= nil
    end
    -- head, leg and shoulder enchants are quest items (class 12: the arcanums, the Zandalar signets, the Scourge enchants) or
    -- miscellaneous items (class 15: the Zul'Gurub enchants and guards) in the game's data; their use text names the slot
    if classID == CLASS.quest or classID == CLASS.misc then
        local v = useText(itemID)
        return v ~= nil and v:find("slot item", 1, true) ~= nil and M.targets(itemID) ~= nil
    end
    return false
end

-- The pieces you wear right now that this item can go on, each with its slot and name.
local function equippedTargets(itemID)
    local list = {}
    local slots = M.targets(itemID) or { 16, 17 }
    for _, slot in ipairs(slots) do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if id then list[#list + 1] = { slot = slot, id = id, name = SLOT_NAMES[slot] or ("Slot " .. slot) } end
    end
    return list
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

-- A locked item in the bags (lockboxes, junkboxes): its tooltip has a "Locked" line (the game's LOCKED) and
-- "Requires Lockpicking (N)" (seen on Wowhead's Classic tooltips: Battered Junkbox 16882, Ornate Bronze Lockbox 4632);
-- the "Locked" line goes once it is opened. Returns locked, and the skill it needs when the tooltip says.
local PICK_LOCK = 1804   -- the rogue's Pick Lock ("Allows opening of locked chests and doors.")
function M.lockInfo(lines)
    local locked, need = false, nil
    local word = LOCKED or "Locked"
    for _, l in ipairs(lines or {}) do
        local t = l.leftText
        if type(t) == "string" then
            if t == word then locked = true end
            local n = t:match("Lockpicking %((%d+)%)")
            if n then need = tonumber(n) end
        end
    end
    return locked, need
end
local function bagLock(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or not data then return false end
    return M.lockInfo(data.lines)
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
            if M.reopen then
                local back = M.reopen
                M.reopen = nil
                C_Timer.After(0, function() M.open(back) end)
                return
            end
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

-- An entry that puts something on a worn piece. When the piece already carries a temporary enchant this would replace (Applied.lua), the
-- entry opens the "are you sure?" question in the middle of the screen (ApplyConfirm.lua) instead of applying at once; A there
-- is yes, B is no. Otherwise (nothing there, or in combat where the question cannot be set up) it applies as before.
-- A permanent enchant (armor kits, scopes, enchants) is NOT asked about here: the game asks it itself, naming what is replaced and
-- with what ("Do you want to replace "Stamina +2 and Armor +16" with "Stamina +3 and Armor +24"?"), which says more than we can. The
-- game has no question for a temporary one (a poison, oil or stone replaced by another), so that is the one we ask. Returns the
-- sentence to show, or nil when no question is wanted.
function M.asksFirst(slot, kind)
    if kind ~= "temporary" or not UF.Applied then return nil end
    return UF.Applied.text(slot, "temporary")
end

local function useOn(label, macro, target, kind, what, pieceName)
    local warn = UF.ApplyConfirm and M.asksFirst(target.slot, kind)
    if warn and not (InCombatLockdown and InCombatLockdown()) then
        return add(label, nil, function()
            UF.ApplyConfirm.ask({
                title = "Replace what is on it?",
                text = string.format("%s (%s) %s.\n\nUsing %s on it will replace that.", pieceName or target.name, target.name, warn, what),
                macro = macro,
            })
        end)
    end
    return add(label, { type = "macro", macrotext = macro })
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
-- The auction house's Create Auction button, when an item is in its sell slot (AuctionHouseFrame.ItemSellFrame / CommoditiesSellFrame,
-- Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.xml; PostButton, Blizzard_AuctionHouseSellFrame.xml:259). The click is a secure
-- click on the game's own button, like "Pick up / move": nothing of ours is run in the click.
function M.auctionPost()
    local ah = _G.AuctionHouseFrame
    if not (ah and ah.IsShown and ah:IsShown()) then return nil end
    for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
        local sf = ah[key]
        if sf and sf.IsShown and sf:IsShown() and sf.PostButton then
            local ok, has = pcall(function() return sf.GetItem and sf:GetItem() end)
            if ok and has then return sf.PostButton end
        end
    end
    return nil
end
-- Runs before the click: says why nothing will happen when the game's button is greyed out.
function M.auctionHint()
    local post = M.auctionPost()
    if post and post.IsEnabled and not post:IsEnabled() then say("Create Auction is not ready: set a price (and duration) first.") end
end

local function openAuction()
    local post = M.auctionPost()
    if not post then return false end
    title:SetText("Auction")
    reset()
    add("Create auction", { type = "click", clickbutton = post }, M.auctionHint)
    return true
end

----------------------------------------------------------------------
-- Bags: put a bag from your bags into one of your bag slots, showing how many slots it gains or loses (ported from Ubermoc UI,
-- Extras.lua openBagSlotMenu and Toolbar.lua bag picker). The comparison is written on each entry, because the controller
-- highlight does not raise tooltips: "Bag slot 2: Small Brown Pouch +4".
----------------------------------------------------------------------
local CONTAINER, REAGENT_SUB = 1, 11

-- Is this item a bag you can equip? Returns true and whether it is a reagent bag.
function M.isBag(itemID)
    local classID, subClassID, equipLoc = instant(itemID)
    if classID ~= CONTAINER or equipLoc ~= "INVTYPE_BAG" then return false end
    return true, subClassID == REAGENT_SUB
end

-- The slot count written on a bag's tooltip ("%d Slot %s", the game's CONTAINER_SLOTS).
local function bagItemSlots(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or not data or not data.lines then return nil end
    local fmt = CONTAINER_SLOTS or "%d Slot %s"
    local pat = "^" .. fmt:gsub("%%d", "(%%d+)"):gsub("%%s", ".+") .. "$"
    for _, l in ipairs(data.lines) do
        local t = l.leftText
        if type(t) == "string" then
            local n = t:match(pat)
            if n then return tonumber(n) end
        end
    end
    return nil
end

-- The equipped bag slots a bag can go in: bag slots 1 to 4 for a normal bag, the reagent slot for a reagent bag.
-- Each: { bagID, inv (inventory slot), label, link of the bag there (nil when empty), size, used }
function M.bagSlotsFor(reagent)
    local out = {}
    local C = C_Container
    local ids = {}
    if reagent then
        local r = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        if r then ids[1] = { r, "Reagent bag slot" } end
    else
        for i = 1, (NUM_BAG_SLOTS or 4) do ids[#ids + 1] = { i, "Bag slot " .. i } end
    end
    for _, e in ipairs(ids) do
        local okI, inv = pcall(C.ContainerIDToInventoryID, e[1])
        if okI and inv then
            local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
            local size = (link and C.GetContainerNumSlots(e[1])) or 0
            local free = (link and C.GetContainerNumFreeSlots and C.GetContainerNumFreeSlots(e[1])) or size
            out[#out + 1] = { bagID = e[1], inv = inv, label = e[2], link = link, size = size, used = size - (free or 0) }
        end
    end
    return out
end

-- How a bag of `mine` slots compares with what a slot holds now, as text and as a number ("+4", "-2", "same").
function M.bagGain(mine, s)
    if not mine then return "", nil end
    local diff = mine - (s.link and s.size or 0)
    if diff > 0 then return "|cff40ff40+" .. diff .. "|r", diff end
    if diff < 0 then return "|cffff5050" .. diff .. "|r", diff end
    return "|cffaaaaaasame|r", 0
end

local function openBagSlots(btn, bag, slot, info, reagent)
    local name = itemName(info.hyperlink, "Bag")
    local mine = bagItemSlots(bag, slot)
    title:SetText("Put " .. name .. (mine and (" (" .. mine .. " slots)") or "") .. " in")
    reset()
    for _, s in ipairs(M.bagSlotsFor(reagent)) do
        local now = s.link and (itemName(s.link, "bag") .. " (" .. s.size .. ")") or "empty"
        local gain = M.bagGain(mine, s)
        local label = s.label:gsub("Bag slot ", "") .. ": " .. now .. "  " .. gain
        if s.link and s.used > 0 then label = label .. " |cffffaa33(holds items)|r" end
        add(label, nil, function()
            if InCombatLockdown() then say("Bags can't be changed in combat."); return end
            pcall(ClearCursor)
            pcall(C_Container.PickupContainerItem, bag, slot)
            if CursorHasItem and CursorHasItem() then pcall(PutItemInBag, s.inv) end
            if CursorHasItem and CursorHasItem() then ClearCursor(); say("The game would not put that bag there (a bag that holds items has to be emptied first).") end
        end)
    end
    add("Back", nil, function() M.reopen = btn end)
    menu:SetHeight(46 + count * 28)
end

-- The bags you carry that fit a bag slot (a reagent bag only in the reagent slot), with their slot counts.
local function carriedBags(reagent)
    local out = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local isBag, isReagent = M.isBag(info.itemID)
                if isBag and (isReagent and true or false) == (reagent and true or false) then
                    out[#out + 1] = { bag = bag, slot = slot, link = info.hyperlink, size = bagItemSlots(bag, slot) }
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.size or 0) > (b.size or 0) end)   -- the biggest first
    return out
end

-- Y on a bag slot of the bag bar: the bags you carry that fit there, each with how many slots it gains over the one there now.
local function openBagBarSlot(btn)
    local bagID, inv, reagent = M.bagBarSlot(btn)
    if not bagID then return false end
    local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
    local size = (link and C_Container.GetContainerNumSlots(bagID)) or 0
    local free = (link and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID)) or size
    local here = { link = link, size = size, used = size - (free or 0) }
    title:SetText((reagent and "Reagent bag slot" or ("Bag slot " .. bagID)) .. ": " .. (link and (itemName(link, "bag") .. " (" .. size .. ")") or "empty"))
    reset()
    local list = carriedBags(reagent)
    for _, b in ipairs(list) do
        if count >= MAX - 1 then break end
        local gain = M.bagGain(b.size, here)
        add(itemName(b.link, "Bag") .. (b.size and (" (" .. b.size .. ")") or "") .. "  " .. gain, nil, function()
            if InCombatLockdown() then say("Bags can't be changed in combat."); return end
            pcall(ClearCursor)
            pcall(C_Container.PickupContainerItem, b.bag, b.slot)
            if CursorHasItem and CursorHasItem() then pcall(PutItemInBag, inv) end
            if CursorHasItem and CursorHasItem() then ClearCursor(); say("The game would not put that bag there (a bag that holds items has to be emptied first).") end
        end)
    end
    if #list == 0 then say(reagent and "You carry no other reagent bag." or "You carry no other bag.") end
    if link and here.used > 0 and #list > 0 then say("The bag in that slot still holds " .. here.used .. " item" .. (here.used == 1 and "" or "s") .. ": the game may want it emptied first.") end
    add("Open this bag", { type = "click", clickbutton = btn })
    return true
end

local function openBag(btn)
    local bag, slot = bagSlot(btn)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not (ok and info) then return false end
    local itemID = info.itemID
    title:SetText(itemName(info.hyperlink, "Item"))
    reset()
    local vendor = MerchantFrame and MerchantFrame:IsShown()
    if vendor then
        -- Using an item at a vendor equips or uses it; selling is the right-click on the item button itself.
        local name = btn.GetName and btn:GetName()
        if name and name ~= "" then
            add("Sell", { type = "macro", macrotext = "/click " .. name .. " RightButton" })
        else
            add("Sell", nil, function()
                pcall(C_Container.PickupContainerItem, bag, slot)
                if CursorHasItem and CursorHasItem() then
                    pcall(PickupMerchantItem, 0)
                    if CursorHasItem() then ClearCursor() end
                end
            end)
        end
    else
        -- At the auction house the right-click on the bag item button puts the item in the sell slot (ContainerFrame.lua: AuctionHouseFrame:SetPostItem)
        local auction = AuctionHouseFrame and AuctionHouseFrame:IsShown()
        local bname = btn.GetName and btn:GetName()
        local post = M.auctionPost()
        if post then add("Create auction", { type = "click", clickbutton = post }, M.auctionHint) end
        if auction and bname and bname ~= "" then
            add("Sell at auction", { type = "macro", macrotext = "/click " .. bname .. " RightButton" })
        end
        -- 1.3.154: the same route as X, so both do the identical thing (C157, C158)
        add("Use / equip", { type = "macro", macrotext = "/use " .. bag .. " " .. slot })
    end

    -- a bag: put it in one of your bag slots, with the best gain on the entry itself
    do
        local isBag, reagent = M.isBag(itemID)
        if isBag and not vendor then
            local mine = bagItemSlots(bag, slot)
            local best
            for _, s in ipairs(M.bagSlotsFor(reagent)) do
                local _, d = M.bagGain(mine, s)
                if d and (not best or d > best) then best = d end
            end
            local hint = ""
            if best and best > 0 then hint = "  |cff40ff40+" .. best .. " slots|r"
            elseif best and best <= 0 then hint = "  |cffaaaaaano gain|r" end
            add("Equip in a bag slot" .. hint, nil, function() openBagSlots(btn, bag, slot, info, reagent) end, true)
        end
    end

    -- used on another item: one entry for each weapon you wear
    if not vendor and M.usedOnItems(itemID) then
        local kind = UF.Applied.kindFor(M.targets(itemID) or { 16, 17 })
        for _, w in ipairs(equippedTargets(itemID)) do
            local link = GetInventoryItemLink and GetInventoryItemLink("player", w.slot)
            useOn("Use on " .. w.name .. ": " .. itemName(link, "item"), "/use " .. bag .. " " .. slot .. "\n/use " .. w.slot,
                w, kind, itemName(info.hyperlink, "this item"), itemName(link, w.name))
        end
    end

    -- a locked box and a rogue who can pick it: cast Pick Lock on it
    if knownSpell(PICK_LOCK) then
        local locked, need = bagLock(bag, slot)
        local n = locked and spellName(PICK_LOCK)
        if n then
            add(n .. (need and (" (needs " .. need .. ")") or ""), { type = "macro", macrotext = "/cast " .. n .. "\n/use " .. bag .. " " .. slot })
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
                out[#out + 1] = { bag = bag, slot = slot, link = info.hyperlink, count = info.stackCount, itemID = info.itemID }
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
    -- everything in the bags that can be used on this piece
    do
        local ok, list = pcall(carriedEnhancers)
        if ok then
            for _, e in ipairs(list) do
                local fits = false
                for _, sl in ipairs(M.targets(e.itemID) or { 16, 17 }) do
                    if sl == id or (sl == 11 and id == 12) then fits = true end
                end
                if fits then
                    useOn("Use " .. itemName(e.link, "item") .. ((e.count and e.count > 1) and (" (" .. e.count .. ")") or ""),
                        "/use " .. e.bag .. " " .. e.slot .. "\n/use " .. id, { slot = id, name = SLOT_NAMES[id] or ("Slot " .. id) },
                        UF.Applied.kindFor(M.targets(e.itemID) or { 16, 17 }), itemName(e.link, "item"), itemName(link, "this piece"))
                end
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
        if p.spellBookItemInfo.isPassive then say("A passive spell cannot go on an action bar."); return end
        if UF.GameNav and UF.GameNav.beginPlace then UF.GameNav.beginPlace(btn, { slotIndex = p.slotIndex, spellBank = p.spellBank }) end
    end, true)
    return true
end

-- Open the list for the highlighted button. Returns true when it opened.
function M.open(btn)
    if InCombatLockdown() then return false end
    local kind = M.kind(btn)
    if not kind and M.auctionPost() then
        -- not on an item, but an item waits in the auction sell slot: the menu offers Create auction
        build()
        M.from = btn
        local okA, openedA = pcall(openAuction)
        if okA and openedA then
            menu:SetHeight(46 + count * 28)
            M.place(btn)
            menu:Show()
            return true
        end
        M.from = nil
    end
    if not kind then
        say("The options menu works on items in your bags, items you are wearing, your bag slots, and spells in the spellbook.")
        return false
    end
    build()
    M.from = btn
    local ok, opened = pcall(function()
        if kind == "bag" then return openBag(btn) end
        if kind == "equip" then return openEquip(btn) end
        if kind == "bagslot" then return openBagBarSlot(btn) end
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
    say(string.format("Item %d: class %s, subclass %s, equip %s, has a use: %s, spell %s, used on another item: %s.",
        itemID, tostring(classID), tostring(subClassID), tostring(equipLoc), tostring(hasUse(itemID)),
        tostring(M.spellID(itemID)), tostring(M.usedOnItems(itemID))))
    -- what X would do on this button, so the two can be compared in the game
    if bag then
        local act = M.rightClickAction(btn)
        local what = "nothing"
        if act then what = tostring(act.type) .. ": " .. (act.item or act.macrotext or "") end
        say("X on this slot: " .. what)
    end
end
