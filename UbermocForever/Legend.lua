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

    -- With a maximum width (the bar under a game window) the items wrap onto more rows instead of running wider than the window.
    function legend:SetMaxWidth(w)
        if self.maxWidth ~= w then
            self.maxWidth = w
            self:Refresh()
        end
    end

    function legend:Refresh()
        local x, row, widest = 0, 0, 0
        for i, pad in ipairs(ROLES) do
            local fs = self.items[i]
            local t = self.texts[pad]
            if t then
                fs:SetText(UF.glyph(pad) .. " " .. t)
                local w = fs:GetStringWidth()
                if self.maxWidth and x > 0 and x + w > self.maxWidth then
                    x, row = 0, row + 1
                end
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", self, "TOPLEFT", x, -11 - row * 22)
                fs:Show()
                x = x + w + 10
                widest = math.max(widest, x - 10)
            else
                fs:Hide()
            end
        end
        self:SetWidth(math.max(widest, 1))
        self:SetHeight(22 * (row + 1))
    end

    UF.OnDetect(function() if legend:IsVisible() then legend:Refresh() end end)
    return legend
end
