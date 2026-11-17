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

-- How much a legend of this natural width is shrunk to fit the room it has: not at all when it fits, else down to a quarter smaller.
local MIN_SCALE = 0.75
function UF.legendScale(total, maxWidth)
    if not maxWidth or total <= maxWidth then return 1 end
    return math.max(MIN_SCALE, maxWidth / total)
end

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
        -- First the natural width of everything on one row; with a limit it is shrunk to fit, and only wraps when that is not enough.
        local total, n = 0, 0
        for i, pad in ipairs(ROLES) do
            local t = self.texts[pad]
            if t then
                self.items[i]:SetText(UF.glyph(pad) .. " " .. t)
                total = total + (self.items[i]:GetStringWidth() or 0) + 10
                n = n + 1
            end
        end
        total = math.max(0, total - 10)
        local scale = UF.legendScale(total, self.maxWidth)
        self:SetScale(scale)
        local limit = self.maxWidth and (self.maxWidth / scale) or nil
        local x, row, widest = 0, 0, 0
        for i, pad in ipairs(ROLES) do
            local fs = self.items[i]
            local t = self.texts[pad]
            if t then
                fs:SetText(UF.glyph(pad) .. " " .. t)
                local w = fs:GetStringWidth()
                if limit and x > 0 and x + w > limit then
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
