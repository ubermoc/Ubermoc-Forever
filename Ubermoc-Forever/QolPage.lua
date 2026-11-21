----------------------------------------------------------------------
-- Ubermoc Forever: the Quality of life page of the options window (fifth page): the aim dot for ground spells (Aim.lua),
-- fast loot (Loot.lua), selling junk and repairing at a vendor (Vendor.lua), name-only nameplates (Nameplates.lua)
-- and the nameplate distance (PlateRange.lua).
-- Built like the Chat and Bars pages: the game's own buttons, a heading per group, a grey note under each.
----------------------------------------------------------------------
local ADDON, UF = ...
local QP = {}
UF.QolPage = QP

local page, aimBtn, distBtn, sizeBtn, lootBtn, sellBtn, repairBtn, guildBtn, enemyBtn, friendlyBtn, healthBtn, percentBtn, rangeBtn, questBtn, questTextBtn, levelBtn, arrowBtn, arrowModeBtn, arrowSizeBtn, arrowPosBtn, arrowOpacityBtn

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
    questBtn:SetText("Quest mobs: " .. (UF.PlateQuest.enabled() and "On" or "Off"))
    questTextBtn:SetText("Quest progress: " .. (UF.PlateQuest.textEnabled() and "On" or "Off"))
    levelBtn:SetText("Friendly level: " .. (UF.PlateLevel.enabled() and "On" or "Off"))
    rangeBtn:SetText("Increased plate range: " .. (UF.PlateRange.enabled() and "On" or "Off"))
    arrowBtn:SetText("Quest arrow: " .. UF.QuestArrow.name())
    arrowModeBtn:SetText("Aim: " .. UF.QuestArrow.modeName())
    arrowSizeBtn:SetText("Size: " .. UF.QuestArrow.sizeName())
    arrowPosBtn:SetText("Place: " .. UF.QuestArrow.positionName())
    arrowOpacityBtn:SetText("Opacity: " .. UF.QuestArrow.opacityName())
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
    questBtn = button(page, 180); questBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -346)
    questTextBtn = button(page, 180); questTextBtn:SetPoint("LEFT", questBtn, "RIGHT", 6, 0)
    toggle(questBtn, function() UF.PlateQuest.toggle("quest") end)
    toggle(questTextBtn, function() UF.PlateQuest.toggle("text") end)
    levelBtn = button(page, 200); levelBtn:SetPoint("LEFT", questTextBtn, "RIGHT", 6, 0)
    toggle(levelBtn, UF.PlateLevel.toggle)
    tip(enemyBtn, "Enemies: name only", "Enemy nameplates show only the unit's name: the health bar and its highlight are hidden, the level stays. Off brings the bar back.")
    tip(friendlyBtn, "Friendly: name only", "Friendly nameplates show only the name. For friendly players this switches on the game's own name-only setting (your old value is kept and given back on Off); for friendly NPCs the bar is hidden by this addon.")
    tip(healthBtn, "Name shows health", "On a name-only plate the name itself is the health bar: it keeps its colour (class colour for players, otherwise by attitude) for the health left, and the part for the health lost turns white. Only works while one of the name-only options is on.")
    tip(percentBtn, "Health percent", "Writes the unit's health percent to the right of its name on a name-only plate. Only works while one of the name-only options is on.")
    tip(rangeBtn, "Increased plate range", "The game draws nameplates only up to a set distance: 45 yards for NPCs and 40 for players. On sets both to 45, so player plates reach as far as NPC plates. Off gives back the values you had. Nothing farther than 45 is drawn.")
    tip(questBtn, "Quest mobs", "A small quest mark appears beside the name of a unit that one of your active quests is about, so you can tell which mobs count. A unit whose objectives are all done is not marked. A switches it on or off.")
    tip(questTextBtn, "Quest progress", "Writes how far the quest objective has got next to the quest mark, for example 3/8 or 45%. It is the same line the unit's tooltip shows. A switches it on or off.")
    tip(levelBtn, "Friendly level", "The game hides the level of a friendly player when its name-only nameplate setting is on, which the Friendly: name only button above switches on. On draws the level number to the left of the name, in grey. Only for friendly players with name-only on; everyone else keeps the game's own level. A switches it on or off.")
    note("A nameplate can show only the name. Off brings the bar back on the plates already shown. The plate range row writes the game's distance settings, and Off gives back the values you had before. The quest mark and progress work on every nameplate.", -376)

    heading("Quest arrow", -408)
    arrowBtn = button(page, 120); arrowBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -430)
    toggle(arrowBtn, UF.QuestArrow.toggle)
    arrowModeBtn = button(page, 150); arrowModeBtn:SetPoint("LEFT", arrowBtn, "RIGHT", 6, 0)
    arrowSizeBtn = button(page, 105); arrowSizeBtn:SetPoint("LEFT", arrowModeBtn, "RIGHT", 6, 0)
    arrowPosBtn = button(page, 160); arrowPosBtn:SetPoint("LEFT", arrowSizeBtn, "RIGHT", 6, 0)
    arrowOpacityBtn = button(page, 140); arrowOpacityBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -456)
    UF.cycleButton(arrowModeBtn, function(dir) UF.QuestArrow.nextMode(dir) end, QP.refresh)
    UF.cycleButton(arrowSizeBtn, function(dir) UF.QuestArrow.nextSize(dir) end, QP.refresh)
    UF.cycleButton(arrowPosBtn, function(dir) UF.QuestArrow.nextPosition(dir) end, QP.refresh)
    UF.cycleButton(arrowOpacityBtn, function(dir) UF.QuestArrow.nextOpacity(dir) end, QP.refresh)
    tip(arrowOpacityBtn, "Quest arrow: opacity", "How solid the arrow and its distance are, from 100 percent down to 10 in steps of ten. A makes it one step fainter, X one step more solid, and it wraps round.")
    tip(arrowModeBtn, "Quest arrow: aim", "Direct points straight at the objective. Route follows the game's own route, which uses the roads and paths it plans. Around obstacles points straight, and bends along the game's route only where that route shows something in the way. The game gives addons no terrain data, so the third reads the obstacle from the route. A steps forward, X steps back.")
    tip(arrowSizeBtn, "Quest arrow: size", "How wide the arrow is on the screen, in pixels. A makes it one step bigger, X one step smaller (16 to 128), and it wraps round.")
    tip(arrowPosBtn, "Quest arrow: place", "Where the arrow sits on the screen. With a mouse or the trackpad you can also drag the arrow itself and it stays where you drop it (Custom). A steps forward, X steps back.")
    tip(arrowBtn, "Quest arrow", "While a quest is in progress on the map you are on, a small arrow near the top right of the screen points at its objective and turns as you turn. It only shows while the game can say both your spot and the objective spot on that map, and only for quests on that map. A switches it on or off.")
    note("The arrow points at the quest the game has selected (click a quest in the tracker), or else the first quest in progress on the map you are on, with the game's own tracked-quest arrow. Aim, size and place are the three buttons beside it.", -488)

    QP.refresh()
    return page
end

function QP.frame() return page end

function QP.navRows()
    if not page then return {} end
    return { { aimBtn, distBtn, sizeBtn }, { lootBtn }, { sellBtn, repairBtn, guildBtn }, { enemyBtn, friendlyBtn }, { healthBtn, percentBtn }, { rangeBtn }, { questBtn, questTextBtn, levelBtn }, { arrowBtn, arrowModeBtn, arrowSizeBtn, arrowPosBtn }, { arrowOpacityBtn } }
end
