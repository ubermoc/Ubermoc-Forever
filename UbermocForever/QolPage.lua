----------------------------------------------------------------------
-- Ubermoc Forever: the Quality of life page of the options window (fifth page): the aim dot for ground spells (Aim.lua),
-- fast loot (Loot.lua), selling junk and repairing at a vendor (Vendor.lua), name-only nameplates (Nameplates.lua)
-- and the nameplate distance (PlateRange.lua).
-- Built like the Chat and Bars pages: the game's own buttons, a heading per group, a grey note under each.
----------------------------------------------------------------------
local ADDON, UF = ...
local QP = {}
UF.QolPage = QP

local page, aimBtn, distBtn, sizeBtn, lootBtn, sellBtn, repairBtn, guildBtn, enemyBtn, friendlyBtn, healthBtn, percentBtn, rangeBtn

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
    rangeBtn:SetText("Increased plate range: " .. (UF.PlateRange.enabled() and "On" or "Off"))
    if guildBtn.SetEnabled then guildBtn:SetEnabled(v.repair and true or false) end
end

function QP.build(parent, inset)
    if page then return page end
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    page:Hide()

    local tip = UF.Describe.set   -- the title and text show in the tooltip and in the description panel (Describe.lua)
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
    tip(aimBtn, "Aim dot", "A small white dot shows where a ground spell (Heroic Leap, Blizzard, Rain of Fire) will land. It only appears while you are aiming one. A switches it on or off.")
    tip(distBtn, "Aim distance", "Where the aim dot starts when you press a ground spell: Closest, Close, Middle, Far or Furthest from your character. It moves the game's pointer up or down the screen; exact yards cannot be set. A steps further, X steps back.")
    tip(sizeBtn, "Dot size", "How big the white aim dot is: Small, Medium or Large. A steps up, X steps back.")
    note("A white dot shows where a ground spell will land while you aim it.", -50)

    heading("Looting", -82)
    lootBtn = button(page, 150); lootBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -104)
    toggle(lootBtn, UF.Loot.toggle)
    tip(lootBtn, "Fast loot", "Takes everything from a corpse or chest the moment the loot window opens. The window only stays if something is left (full bags, or an item that asks you first). Not used while you are the master looter. It switches the game's Auto Loot on, once for each character.")
    note("Everything is taken at once when you loot, instead of one item at a time.", -132)

    heading("At a vendor", -164)
    sellBtn = button(page, 150); sellBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -186)
    repairBtn = button(page, 130); repairBtn:SetPoint("LEFT", sellBtn, "RIGHT", 6, 0)
    guildBtn = button(page, 190); guildBtn:SetPoint("LEFT", repairBtn, "RIGHT", 6, 0)
    toggle(sellBtn, UF.Vendor.toggleSell)
    toggle(repairBtn, UF.Vendor.toggleRepair)
    toggle(guildBtn, UF.Vendor.toggleGuild)
    tip(sellBtn, "Sell junk", "When you open a vendor, every grey item in your bags is sold and a chat line says what it made. A switches it on or off.")
    tip(repairBtn, "Repair", "When you open a vendor that repairs, all your gear is repaired and a chat line says what it cost. A switches it on or off.")
    tip(guildBtn, "Guild bank first", "Pays for repairs from the guild bank when your guild allows it and the bank and your daily allowance cover the whole cost; otherwise your own money pays. Only matters while Repair is on.")
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
    rangeBtn = button(page, 220); rangeBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -320)
    toggle(rangeBtn, UF.PlateRange.toggle)
    tip(enemyBtn, "Enemies: name only", "Enemy nameplates show only the unit's name: the health bar and its highlight are hidden, the level stays. Off brings the bar back.")
    tip(friendlyBtn, "Friendly: name only", "Friendly nameplates show only the name. For friendly players this switches on the game's own name-only setting (your old value is kept and given back on Off); for friendly NPCs the bar is hidden by this addon.")
    tip(healthBtn, "Name shows health", "On a name-only plate the name itself is the health bar: it keeps its colour (class colour for players, otherwise by attitude) for the health left, and the part for the health lost turns white. Only works while one of the name-only options is on.")
    tip(percentBtn, "Health percent", "Writes the unit's health percent to the right of its name on a name-only plate. Only works while one of the name-only options is on.")
    tip(rangeBtn, "Increased plate range", "The game draws nameplates only up to a set distance: 45 yards for NPCs and 40 for players. On sets both to 45, so player plates reach as far as NPC plates. Off gives back the values you had. Nothing farther than 45 is drawn.")
    note("A nameplate can show only the name. Off brings the bar back on the plates already shown. The distance row writes the game's distance settings, and Off gives back the values you had before.", -348)

    QP.refresh()
    return page
end

function QP.frame() return page end

function QP.navRows()
    if not page then return {} end
    return { { aimBtn, distBtn, sizeBtn }, { lootBtn }, { sellBtn, repairBtn, guildBtn }, { enemyBtn, friendlyBtn }, { healthBtn, percentBtn }, { rangeBtn } }
end
