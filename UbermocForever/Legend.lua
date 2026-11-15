----------------------------------------------------------------------
-- Ubermoc Forever: the legend
-- A row of the game's own button pictures with what each does on the page you are on:
--   first button  = select / accept       second button = decline / back
--   third button  = clear (only on the key binds page)
--   fourth button = menus, and changes to fit the page.
--   left / right bumper = the previous / next hold on the key binds page.
-- The pictures follow the controller in use, so a Switch controller shows its own letters.
----------------------------------------------------------------------
local _, UF = ...

-- (the triggers and D-pad are used by the bar shown over the game's own windows, see GameNav.lua)
local ROLES = { "PAD1", "PAD2", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADDUP" }

function UF.CreateLegend(parent)
    local legend = CreateFrame("Frame", nil, parent)
    legend:SetHeight(22)
    legend.items = {}
    for i, pad in ipairs(ROLES) do
        local fs = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
        legend.items[i] = fs
    end
    legend.texts = {}

    function legend:Set(texts)
        self.texts = texts or {}
        self:Refresh()
    end

    function legend:Refresh()
        local x = 0
        for i, pad in ipairs(ROLES) do
            local fs = self.items[i]
            local t = self.texts[pad]
            if t then
                fs:SetText(UF.glyph(pad) .. " " .. t)
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", self, "LEFT", x, 0)
                fs:Show()
                x = x + fs:GetStringWidth() + 10
            else
                fs:Hide()
            end
        end
        self:SetWidth(math.max(x, 1))
    end

    UF.OnDetect(function() if legend:IsVisible() then legend:Refresh() end end)
    return legend
end
