----------------------------------------------------------------------
-- Ubermoc Forever: the Bars page of the options window (fourth page): the gamepad layout (GamepadBar.lua).
-- Plain buttons, as on the other pages, so the D-pad and A work on all of them.
----------------------------------------------------------------------
local ADDON, UF = ...
local BP = {}
UF.BarsPage = BP

local page, rows, note

local function button(parent, w, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 24)
    b:SetText(text or "")
    return b
end

function BP.refresh()
    if not page then return end
    local B = UF.GamepadBar
    local c = B.cfg()
    rows.on:SetText("Gamepad layout: " .. (c.on and "On" or "Off"))
    rows.empty:SetText("Hide empty buttons: " .. (c.hideEmpty and "On" or "Off"))
    rows.art:SetText("Hide the game's art: " .. (c.hideArt and "On" or "Off"))
    rows.size:SetText("Button size: " .. c.size)
    rows.gap:SetText("Gap: " .. c.gap)
    rows.raise:SetText("Height: " .. c.raise)
end

function BP.build(parent, inset)
    if page then return page end
    local B = UF.GamepadBar
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

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    head:SetText("Gamepad layout")
    rows = {}
    rows.on = button(page, 190); rows.on:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
    rows.empty = button(page, 220); rows.empty:SetPoint("LEFT", rows.on, "RIGHT", 6, 0)
    rows.art = button(page, 220); rows.art:SetPoint("LEFT", rows.empty, "RIGHT", 6, 0)
    rows.size = button(page, 190); rows.size:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -56)
    rows.gap = button(page, 140); rows.gap:SetPoint("LEFT", rows.size, "RIGHT", 6, 0)
    rows.raise = button(page, 140); rows.raise:SetPoint("LEFT", rows.gap, "RIGHT", 6, 0)
    rows.on:SetScript("OnClick", function() B.toggle(); BP.refresh() end)
    rows.empty:SetScript("OnClick", function() B.toggleEmpty(); BP.refresh() end)
    rows.art:SetScript("OnClick", function() B.toggleArt(); BP.refresh() end)
    rows.size:SetScript("OnClick", function() B.nextSize(); BP.refresh() end)
    rows.gap:SetScript("OnClick", function() B.nextGap(); BP.refresh() end)
    rows.raise:SetScript("OnClick", function() B.nextRaise(); BP.refresh() end)
    tip(rows.on, "Gamepad layout", "One row of action buttons at the bottom of the screen: nothing held shows action bar 1, the first modifier bar 2, the second bar 3, both bar 4 (the layers the default binds fill). The game's bottom art goes. Off puts everything back.")
    tip(rows.empty, "Hide empty buttons", "Buttons with nothing on them are removed from the row and the rest are centred and spaced evenly. Changes wait until a fight is over.")
    tip(rows.art, "Hide the game's art", "Hides the main bar's art and end caps, action bars 2 to 4, the micro menu, the bags and the experience bar, and the key labels on the buttons. A part you set on the Fading page keeps your setting.")
    tip(rows.size, "Button size", "How big each button is. Press to step through the choices.")
    tip(rows.gap, "Gap", "The space between buttons, the same everywhere in the row.")
    tip(rows.raise, "Height", "How far the row sits above the bottom edge of the screen.")

    note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -96)
    note:SetWidth(640); note:SetJustifyH("LEFT")
    note:SetText("Action bars 2, 3 and 4 must be switched on in the game's own action bar settings for their layers to show. Moving the buttons waits until a fight is over. Type /ubf bars to see what the layout found.")
    BP.refresh()
    return page
end

function BP.frame() return page end

function BP.navRows()
    local out = {}
    if not page then return out end
    out[1] = { rows.on, rows.empty, rows.art }
    out[2] = { rows.size, rows.gap, rows.raise }
    return out
end
