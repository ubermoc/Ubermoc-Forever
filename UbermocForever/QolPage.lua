----------------------------------------------------------------------
-- Ubermoc Forever: the Quality of life page of the options window (fifth page): the aim dot for ground spells (Aim.lua),
-- fast loot (Loot.lua), selling junk and repairing at a vendor (Vendor.lua), name-only nameplates (Nameplates.lua)
-- and the nameplate distance (PlateRange.lua).
-- Built like the Chat and Bars pages: the game's own buttons, a heading per group, a grey note under each.
----------------------------------------------------------------------
local ADDON, UF = ...
local QP = {}
UF.QolPage = QP

local page, aimBtn, distBtn, sizeBtn, lootBtn, sellBtn, repairBtn, guildBtn, enemyBtn, friendlyBtn, healthBtn, percentBtn, rangeBtn, yardsBtn

local function button(parent, w, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text or "")
    return b
end

function QP.refresh()
    if not page then return end
    local v = UF.Vendor.cfg()
    aimBtn:SetText("Aim dot: " .. (UF.Aim.cfg().on and "On" or "Off"))
    distBtn:SetText("Aim distance: " .. UF.Aim.distanceName())
    sizeBtn:SetText("Dot: " .. UF.Aim.sizeName())
    lootBtn:SetText("Fast loot: " .. (UF.Loot.enabled() and "On" or "Off"))
    sellBtn:SetText("Sell junk: " .. (v.sell and "On" or "Off"))
    repairBtn:SetText("Repair: " .. (v.repair and "On" or "Off"))
    guildBtn:SetText("Guild bank first: " .. (v.guild and "On" or "Off"))
    enemyBtn:SetText("Enemies: name only: " .. (UF.Nameplates.enabled("enemy") and "On" or "Off"))
    friendlyBtn:SetText("Friendly: name only: " .. (UF.Nameplates.enabled("friendly") and "On" or "Off"))
    local pl = UF.NameHealth.db()
    healthBtn:SetText("Name shows health: " .. (pl.health and "On" or "Off"))
    percentBtn:SetText("Health percent: " .. (pl.percent and "On" or "Off"))
    rangeBtn:SetText("Plate range: " .. (UF.PlateRange.enabled() and "On" or "Off"))
    yardsBtn:SetText("Plate distance: " .. UF.PlateRange.name())
    if guildBtn.SetEnabled then guildBtn:SetEnabled(v.repair and true or false) end
end

function QP.build(parent, inset)
    if page then return page end
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    page:Hide()

    local function tip(b, title, text)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local function heading(text, y)
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
        fs:SetText(text)
    end
    local function note(text, y)
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
        fs:SetPoint("RIGHT", page, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
    end
    local function toggle(b, fn) UF.cycleButton(b, function() fn() end, QP.refresh) end

    heading("Aim dot", 0)
    aimBtn = button(page, 120); aimBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
    distBtn = button(page, 180); distBtn:SetPoint("LEFT", aimBtn, "RIGHT", 6, 0)
    sizeBtn = button(page, 110); sizeBtn:SetPoint("LEFT", distBtn, "RIGHT", 6, 0)
    toggle(aimBtn, UF.Aim.toggle)
    UF.cycleButton(distBtn, UF.Aim.nextDistance, QP.refresh)   -- A forward, X back
    UF.cycleButton(sizeBtn, UF.Aim.nextSize, QP.refresh)
    tip(aimBtn, "Aim dot", "A white dot shows where a ground spell (Heroic Leap, Blizzard, Rain of Fire) will land, only while you are aiming it.")
    tip(distBtn, "Aim distance", "How far from your character the aim point rests (higher on the screen is further). Exact yards cannot be set. A steps forward, X steps back.")
    tip(sizeBtn, "Dot size", "Small, medium or large. A steps forward, X steps back.")
    note("A white dot shows where a ground spell will land while you aim it.", -50)

    heading("Looting", -82)
    lootBtn = button(page, 150); lootBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -104)
    toggle(lootBtn, UF.Loot.toggle)
    tip(lootBtn, "Fast loot", "With the game's Auto Loot on, everything is taken the moment the loot opens, and the loot window only shows if something is left (full bags, an item that asks first). Not while you are the master looter. The game's Auto Loot is switched on once for each character.")
    note("Everything is taken at once when you loot, instead of one item at a time.", -132)

    heading("At a vendor", -164)
    sellBtn = button(page, 150); sellBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -186)
    repairBtn = button(page, 130); repairBtn:SetPoint("LEFT", sellBtn, "RIGHT", 6, 0)
    guildBtn = button(page, 190); guildBtn:SetPoint("LEFT", repairBtn, "RIGHT", 6, 0)
    toggle(sellBtn, UF.Vendor.toggleSell)
    toggle(repairBtn, UF.Vendor.toggleRepair)
    toggle(guildBtn, UF.Vendor.toggleGuild)
    tip(sellBtn, "Sell junk", "When a vendor opens, every grey item in your bags is sold (the game's own Sell all junk). A chat line says what it made.")
    tip(repairBtn, "Repair", "When a vendor that repairs opens, all your gear is repaired. A chat line says what it cost.")
    tip(guildBtn, "Guild bank first", "Repairs are paid from the guild bank when your guild lets you and the bank and your daily allowance cover the whole cost; otherwise from your own money.")
    note("Grey items are sold and your gear is repaired as soon as you talk to a vendor. The guild bank pays for repairs when it can.", -214)

    heading("Nameplates", -246)
    enemyBtn = button(page, 180); enemyBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -268)
    friendlyBtn = button(page, 180); friendlyBtn:SetPoint("LEFT", enemyBtn, "RIGHT", 6, 0)
    healthBtn = button(page, 180); healthBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -294)
    percentBtn = button(page, 180); percentBtn:SetPoint("LEFT", healthBtn, "RIGHT", 6, 0)
    toggle(enemyBtn, function() UF.Nameplates.toggle("enemy") end)
    toggle(friendlyBtn, function() UF.Nameplates.toggle("friendly") end)
    toggle(healthBtn, function() UF.NameHealth.toggle("health") end)
    toggle(percentBtn, function() UF.NameHealth.toggle("percent") end)
    rangeBtn = button(page, 150); rangeBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -320)
    yardsBtn = button(page, 180); yardsBtn:SetPoint("LEFT", rangeBtn, "RIGHT", 6, 0)
    toggle(rangeBtn, UF.PlateRange.toggle)
    UF.cycleButton(yardsBtn, UF.PlateRange.nextYards, QP.refresh)
    tip(enemyBtn, "Enemies: name only", "An enemy nameplate shows its name and nothing else: the health bar and the highlight are made invisible (the level stays). Off puts the bar back.")
    tip(friendlyBtn, "Friendly: name only", "Friendly players: the game's own setting for that (Nameplates options) is switched on, and its previous value is kept so it can be given back. Friendly NPCs also get the bar made invisible, which the game cannot do by itself.")
    tip(healthBtn, "Name shows health", "On a name-only plate the name itself is the health bar: it keeps its colour (class colour for a player, reaction colour otherwise) for the health left, and the part standing for the health lost is white. Only while an Enemies or Friendly name-only option is on.")
    tip(percentBtn, "Health percent", "The current health percent is written to the right of the name, in the reaction colour. Only while a name-only option is on.")
    tip(rangeBtn, "Plate range", "How far from the camera the game draws nameplates. On writes the number next to it into the game's distance settings (the game's own values are 45 yards for units and 40 for players, and there is no settings row for them); Off gives back the values you had before.")
    tip(yardsBtn, "Plate distance", "30, 45, 60, 80 or 100 yards (60 to start). A steps forward, X steps back. Nothing is written during combat, and what waits is applied when the fight ends.")
    note("A nameplate can show only the name. Off brings the bar back on the plates already shown. The distance row writes the game's distance settings, and Off gives back the values you had before.", -348)

    QP.refresh()
    return page
end

function QP.frame() return page end

function QP.navRows()
    if not page then return {} end
    return { { aimBtn, distBtn, sizeBtn }, { lootBtn }, { sellBtn, repairBtn, guildBtn }, { enemyBtn, friendlyBtn }, { healthBtn, percentBtn }, { rangeBtn, yardsBtn } }
end
