----------------------------------------------------------------------
-- Ubermoc Forever: the Quality of life page of the options window (fifth page): fast loot (Loot.lua) and selling junk
-- and repairing at a vendor (Vendor.lua). Built like the Chat and Bars pages: the game's own buttons, a heading per group,
-- a grey note under each.
----------------------------------------------------------------------
local ADDON, UF = ...
local QP = {}
UF.QolPage = QP

local page, lootBtn, sellBtn, repairBtn, guildBtn

local function button(parent, w, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text or "")
    return b
end

function QP.refresh()
    if not page then return end
    local v = UF.Vendor.cfg()
    lootBtn:SetText("Fast loot: " .. (UF.Loot.enabled() and "On" or "Off"))
    sellBtn:SetText("Sell junk: " .. (v.sell and "On" or "Off"))
    repairBtn:SetText("Repair: " .. (v.repair and "On" or "Off"))
    guildBtn:SetText("Guild bank first: " .. (v.guild and "On" or "Off"))
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

    heading("Looting", 0)
    lootBtn = button(page, 150); lootBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
    toggle(lootBtn, UF.Loot.toggle)
    tip(lootBtn, "Fast loot", "With the game's Auto Loot on, everything is taken the moment the loot opens, and the loot window only shows if something is left (full bags, an item that asks first). Not while you are the master looter. The game's Auto Loot is switched on once for each character.")
    note("Everything is taken at once when you loot, instead of one item at a time.", -50)

    heading("At a vendor", -82)
    sellBtn = button(page, 150); sellBtn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -104)
    repairBtn = button(page, 130); repairBtn:SetPoint("LEFT", sellBtn, "RIGHT", 6, 0)
    guildBtn = button(page, 190); guildBtn:SetPoint("LEFT", repairBtn, "RIGHT", 6, 0)
    toggle(sellBtn, UF.Vendor.toggleSell)
    toggle(repairBtn, UF.Vendor.toggleRepair)
    toggle(guildBtn, UF.Vendor.toggleGuild)
    tip(sellBtn, "Sell junk", "When a vendor opens, every grey item in your bags is sold (the game's own Sell all junk). A chat line says what it made.")
    tip(repairBtn, "Repair", "When a vendor that repairs opens, all your gear is repaired. A chat line says what it cost.")
    tip(guildBtn, "Guild bank first", "Repairs are paid from the guild bank when your guild lets you and the bank and your daily allowance cover the whole cost; otherwise from your own money.")
    note("Grey items are sold and your gear is repaired as soon as you talk to a vendor. The guild bank pays for repairs when it can.", -132)

    QP.refresh()
    return page
end

function QP.frame() return page end

function QP.navRows()
    if not page then return {} end
    return { { lootBtn }, { sellBtn, repairBtn, guildBtn } }
end
